# road map
# 1) gui
# 2) ugen functions that allow option strings so that one can mix parameter names

defmodule Axotypixusc do
  use Application

  @midi_in_device Application.get_env(:axotypixusc, :midi_in_device, nil)

  def start_synth do
    {:ok, s} = SCSoundServer.start_link(:sc0)
    s
  end

  def startup_sc do
    # {:ok, s} = SCSoundServer.start_link(:sc3_server, '127.0.0.1', 57110, 5000, 1_000_000, 10)
    {:ok, s} = SCSoundServer.start_link(:sc0)
    soundserver_udp_port = SCSoundServer.get_udp_port(:sc0)

    {:ok, l} = SCLang.start_link()

    SCLang.eval_sync(
      "s=Server.remote(\\a, NetAddr(\"127.0.0.1\", #{soundserver_udp_port}), s.options, 1);"
    )

    %{server: s, lang: l}
  end

  def make_synth2 do
    def = %SCSynthDef{name: "pstr"}

    # Control and UOp and BOp are nonstandard UGens
    # they do not support the variety of interfaces of normal ugens
    # this is the most practical way to use them:
    freq = Control.kr(freq: 440.0)
    # freq = %Control.Kr{key: :freq, value: 440}
    # io.
    # amp = Control.kr(amp: 1)
    amp = %Control.Kr{key: :amp, value: 1}
    # gate = Control.kr(gate: 1)
    gate = %Control.Kr{key: :gate, value: 1}
    # rf = %UOp{selector: :reciprocal, a: freq}
    rf = %BOp{selector: :/, a: 1.0, b: freq}
    # rf = UOp.reciprocal(freq)
    # rf = UOp.reciprocal(freq)
    # rf = BOp.div(1, freq)

    # ugens can be created by a ar or kr or ir or new function (which is available depends on the implementation on the server)
    env = %Linen.Kr{
      gate: %BOp{selector: :+, a: gate, b: %Impulse.Kr{freq: 0}},
      attackTime: 0,
      susLevel: %BOp{selector: :*, a: amp, b: 0.3},
      # susLevel: 1,
      releaseTime: 0.5,
      doneAction: 2
    }

    # one can also create the structs directly
    noise = %BrownNoise.Ar{}

    # the benefit are explicit keywords
    # coef = %BOp{
    #   selector: :+,
    #   a: %Linen.Kr{gate: gate, attackTime: 0, susLevel: 0.3, releaseTime: 0.1},
    #   b: 0.02
    # }

    # i might implement functions with option lists later

    plucks_list =
      Enum.reduce([1.003, 1.004, 1.005], [], fn rm, list ->
        r = %Rand.New{lo: 1, hi: rm}
        t = %BOp{selector: :*, a: rf, b: r}

        list ++
          [
            %Pluck.Ar{
              in: noise,
              trig: 100,
              maxdelaytime: t,
              delaytime: t,
              decaytime: 100,
              coef: 0.31
            }
          ]
      end)

    plucks = %Sum3.New{
      in0: Enum.at(plucks_list, 0),
      in1: Enum.at(plucks_list, 1),
      in2: Enum.at(plucks_list, 2)
    }

    # plucks = %Pluck.Ar{
    #   in: noise,
    #   trig: 100,
    #   maxdelaytime: rf,
    #   delaytime: rf,
    #   decaytime: 100,
    #   coef: 0.31
    # }

    lpf = %BOp{selector: :*, a: freq, b: 4}
    lp = %LPF.Ar{in: plucks, freq: lpf}
    sig = %LeakDC.Ar{in: lp}
    es = %BOp{selector: :*, a: sig, b: env}
    out = %Out.Ar{bus: 0, channelsArray: [es, es]}

    def = SCSynthDef.Maker.add_ugen(def, out)
    # def = SCSynthDef.Maker.add_ugen(def, SendTrig.kr(Impulse.kr(1), -1, rf))
    IO.inspect(def)
    bytes = SCSynthDef.Writer.byte_encode(def)
    # IO.inspect(bytes, limit: :infinity)
    SCSoundServer.send_synthdef_sync(:sc0, bytes)

    :timer.sleep(1000)
  end

  def load_synth2 do
    SCLang.eval_sync("""
    SynthDef(\\pstr,{arg freq=600,amp=1,gate=1;
    var end=1-LagUD.ar(K2A.ar(gate),0,0.3);
    var q = (1/pi)-(end/3);
    var fs=freq*Rand([1,1,1],1.005);
    var env =Linen.kr(gate: gate+Impulse.kr(0), attackTime: 0, susLevel: 1.0, releaseTime: 0.5, doneAction: 2);
    var sig=LeakDC.ar(LPF1.ar(Pluck.ar(BrownNoise.ar,100,1/fs,1/fs,100,q).sum,freq*2));
    Out.ar(0,sig*1/3*env!2)
    }).send;
    """)
  end

  def load_synth do
    SCLang.eval_sync("""
    SynthDef(\\pstr,{arg freq=600,amp=1,gate=1;
    var end=1-LagUD.ar(K2A.ar(gate),0,0.3);
    var fs=freq*Rand([1,1,1],1.005);
    var env = EnvGen.ar(Env.asr(0,amp,1),gate+Impulse.kr(0),doneAction:2);
    var sig=LeakDC.ar(LPF1.ar(Pluck.ar(BrownNoise.ar,100,1/fs,1/fs,100,(1/pi)-(end/3)).sum,freq*2));
    Out.ar(0,sig*1/3*env!2)
    }).send;
    """)
  end

  def start(_type, _args) do
    s = start_synth()
    # %{server: s, lang: l} = startup_sc()
    # load_synth2()
    make_synth2()
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
