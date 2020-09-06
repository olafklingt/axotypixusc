# road map
# 1) gui
# 3) proper termination
# so i learned now that the midi in crshes if i stop the server ...
# so if the server stops midi in should be stopped too
# for this I need some kind of supervision tree I guess...
# 2) ugen functions that allow option strings so that one can mix parameter names

defmodule Axotypixusc do
  use Application

  @midi_in_device Application.get_env(:axotypixusc, :midi_in_device, nil)

  def start_soundserver do
    # {:ok, s} = SCSoundServer.start_link(:sc3_server, '127.0.0.1', 57110, 5000, 1_000_000, 10)
    {:ok, s} = SCSoundServer.GenServer.start_link(:sc0)
    s
  end

  def make_synth do
    def = %SCSynthDef{name: "pstr"}

    # Control and UOp and BOp are nonstandard UGens
    # they do not support the variety of interfaces of normal ugens
    # this is the most practical way to use them:
    freq = Control.kr(freq: 440.0)
    amp = Control.kr(amp: 1)
    gate = Control.kr(gate: 1)
    rf = UOp.reciprocal(freq)

    # ugens can be created by a ar or kr or ir or new function (which is available depends on the implementation on the server)
    env =
      Linen.kr(
        # (the impulse ensures that the env is triggered )
        # (even when the key is released within one processing block)
        BOp.add(gate, Impulse.kr(0)),
        0,
        BOp.mul(amp, 0.3),
        0.5,
        2
      )

    noise = %BrownNoise.Ar{}

    coef = %BOp{
      selector: :+,
      a: %Linen.Kr{gate: gate, attackTime: 0, susLevel: 0.3, releaseTime: 0.1},
      b: 0.02
    }

    plucks_list =
      Enum.reduce([1, 1.003, 1.005], [], fn rm, list ->
        r = Rand.new(1, rm)
        t = BOp.mul(rf, r)

        list ++
          [
            # one can also create the structs directly
            # the benefit are explicit keywords
            # i might implement functions with option lists later
            %Pluck.Ar{
              in: noise,
              trig: 100,
              maxdelaytime: t,
              delaytime: t,
              decaytime: 100,
              coef: coef
            }
          ]
      end)

    # sum3 is also not a standard ugen ... should be implemented better
    plucks = %Sum3.New{
      in0: Enum.at(plucks_list, 0),
      in1: Enum.at(plucks_list, 1),
      in2: Enum.at(plucks_list, 2)
    }

    lpf = BOp.mul(freq, 4)
    lp = LPF.ar(plucks, lpf)
    sig = LeakDC.ar(lp)
    es = BOp.mul(sig, env)
    out = Out.ar(0, [es, es])

    def = SCSynthDef.Maker.add_ugen(def, out)

    # if one wants to poll a value a seprate ugen has to be included after the ugen_graph has been added to the def
    # def = SCSynthDef.Maker.add_ugen(def, SendTrig.kr(Impulse.kr(1), -1, rf))
    IO.inspect(def)
    bytes = SCSynthDef.Writer.byte_encode(def)
    SCSoundServer.send_synthdef_sync(:sc0, bytes)
  end

  def start(_type, _args) do
    s = start_soundserver()
    make_synth()
    default_group = SCSoundServer.init_default_group(:sc0)

    IO.puts("all midi input devices:")
    IO.inspect(PortMidi.devices().input)
    IO.puts("////////////////////")

    {:ok, mi} = MidiIn.start_link(default_group)

    IO.inspect(PortMidi.devices().input)

    if(@midi_in_device == nil) do
      for x <- PortMidi.devices().input do
        {:ok, input} = PortMidi.open(:input, x.name)
        PortMidi.listen(input, mi)
      end
    else
      {:ok, input} = PortMidi.open(:input, @midi_in_device)
      PortMidi.listen(input, mi)
    end

    {:ok, self()}
  end
end
