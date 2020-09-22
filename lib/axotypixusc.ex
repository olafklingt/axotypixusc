# road map
# 2) gui
# 3) ugen functions that allow option strings so that one can mix parameter names
# 4) specs for ugens

defmodule Axotypixusc do
  use Application

  @midi_in_device Application.get_env(:axotypixusc, :midi_in_device, :all)

  @spec init_midi_input(atom | binary) :: any
  def init_midi_input(:all) do
    i =
      try do
        PortMidi.devices().input
      rescue
        _ ->
          IO.puts("could not get midi input devices")
          []
      end

    input_pids =
      for x <- i do
        if(x.opened > 0) do
          IO.puts("midi init will fail because midi port already open #{inspect(x.name)}")
        end

        r = PortMidi.open(:input, x.name)
        {:ok, input} = r
        input
      end

    input_pids
  end

  def init_midi_input(mid) do
    {:ok, input} = PortMidi.open(:input, mid)
    # PortMidi.listen(input, mi)
    [input]
  end

  def make_synth do
    import UGen

    # def = %SCSynthDef.Struct{name: "pstr"}

    # Control and UOp and BOp are nonstandard UGens
    # they do not support the variety of interfaces of normal ugens
    # this is the most practical way to use them:
    freq = Control.kr(freq: 440.0)
    amp = Control.kr(amp: 1)
    gate = Control.kr(gate: 1)
    rf = reciprocal(freq)

    # ugens can be created by a ar or kr function (which is available depends on the implementation on the server)
    env =
      Linen.kr(
        # (the impulse ensures that the env is triggered )
        # (even when the key is released within one processing block)
        add(gate, Impulse.kr(0)),
        0,
        mul(amp, 0.3),
        0.5,
        2
      )

    noise = %UGen.BrownNoise.Ar{}

    coef = add(%UGen.Linen.Kr{gate: gate, attackTime: 0, susLevel: 0.3, releaseTime: 0.1}, 0.02)

    plucks_list =
      Enum.reduce([1, 1.003, 1.005], [], fn rm, list ->
        r = Rand.new(1, rm)
        t = mul(rf, r)

        list ++
          [
            # one can also create the structs directly
            # the benefit are explicit keywords
            # i might implement functions with option lists later
            %UGen.Pluck.Ar{
              in: noise,
              trig: 100,
              maxdelaytime: t,
              delaytime: t,
              decaytime: 100,
              coef: coef
            }
          ]
      end)

    plucks = sum(plucks_list)

    lpf = mul(freq, 4)
    lp = LPF.ar(plucks, lpf)
    sig = LeakDC.ar(lp)
    es = mul(sig, env)
    out = Out.ar(0, [es, es])

    # def = SCSynthDef.new("pstr")
    # def = SCSynthDef.Maker.add_ugen(def, out)
    # if one wants to poll a value a seprate ugen has to be included after the ugen_graph has been added to the def
    # def = SCSynthDef.Maker.add_ugen(def, SendTrig.kr(Impulse.kr(1), -1, rf))
    # IO.inspect(def)
    # bytes = SCSynthDef.Writer.byte_encode(def)
    # IO.inspect(def.metadata)
    # SCSoundServer.send_synthdef_sync(bytes)

    SCSoundServer.add_def("pstr", out)
  end

  def setup_soundserver(config) do
    {:ok, gs} = SCSoundServer.start_link(config)
    Axotypixusc.make_synth()
    {:ok, gs}
  end

  def start(_type, _args) do
    Axotypixusc.setup_soundserver(%SCSoundServer.Config{})

    # children = [
    #   %{
    #     id: SCSoundServer,
    #     start: {Axotypixusc, :setup_soundserver, [%SCSoundServer.Config{}]}
    #   }
    # ]
    #
    # opts = [strategy: :one_for_one, name: SCSoundServer.Supervisor]
    # Supervisor.start_link(children, opts)

    try do
      IO.puts("all midi input devices:")
      IO.inspect(PortMidi.devices().input)
      IO.puts("////////////////////")
    rescue
      _ ->
        IO.puts("can not get midi input devices for print")
    end

    # portmidi is too unstable to be restarted ...
    # thats why i open the midi in device
    # outside of the listener
    input_pids = init_midi_input(@midi_in_device)

    children = [
      %{
        id: Axotypixusc.Midi.Listener,
        start: {Axotypixusc.Midi.Listener, :start_link, [input_pids]}
      }
    ]

    opts = [strategy: :one_for_one, name: Midi.Supervisor]
    Supervisor.start_link(children, opts)

    {:ok, self()}
  end
end
