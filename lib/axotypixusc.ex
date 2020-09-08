# road map
# 1) gui
# 2) proper termination
# so i learned now that the midi in crshes if i stop the server ...
# so if the server stops midi in should be stopped too
# for this I need some kind of supervision tree I guess...
# 3) ugen functions that allow option strings so that one can mix parameter names
# 4) specs for ugens

defmodule Axotypixusc do
  use Application

  @midi_in_device Application.get_env(:axotypixusc, :midi_in_device, :all)

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
    SCSoundServer.send_synthdef_sync(bytes)
  end

  def start(_type, _args) do
    {:ok, s} = SCSoundServer.GenServer.start_link()
    default_group = SCSoundServer.init_default_group()
    make_synth()

    try do
      IO.puts("all mstart_linkidi input devices:")
      IO.inspect(PortMidi.devices().input)
      IO.puts("////////////////////")

      {:ok, mi} = Axotypixusc.Midi.Listener.start_link(default_group, @midi_in_device)

      {:ok, self()}
    rescue
      _ ->
        IO.puts("can not get midi input devices for print")
        {:error, self()}
    end
  end
end
