defmodule MidiIn do
  use GenServer

  def note_off(notes, note) do
    s = Enum.at(notes, note)
    SCSynth.set(s, ["gate", 0])
    List.replace_at(notes, note, nil)
  end

  def note_on(group, notes, note, vel) do
    target_s = SCGroup.head(group)

    if nil != Enum.at(notes, note) do
      note_off(notes, note)
    end

    {:ok, synth} =
      SCSynth.start_link(
        target_s,
        "pstr",
        [
          "freq",
          # because A = 450 is heaven
          # :math.pow(2, (note - 69) / 12) * 450,
          :math.pow(2, (note - 69) / 24) * 450,
          "amp",
          vel / 127
        ]
        # ,
        # :sync
      )

    notes = List.replace_at(notes, note, synth)
    notes
  end

  def start_link(default_group) do
    GenServer.start_link(__MODULE__, [default_group], name: :midiin)
  end

  @impl true
  def init([default_group]) do
    {:ok, %{group: default_group, notes: List.duplicate(nil, 128)}}
  end

  @impl true
  def handle_info({_pid, msg}, state) do
    group = state.group

    notes =
      Enum.reduce(msg, state.notes, fn event, notes ->
        {{type, note, vel}, _time?} = event

        case {type, note, vel} do
          {128, _, _} ->
            note_off(notes, note)

          {144, _, 0} ->
            note_off(notes, note)

          {144, _, _} ->
            note_on(group, notes, note, vel)

          {176, 104, 0} ->
            SCSoundServer.dumpTree(:sc0)
            notes

          {176, 104, _} ->
            notes

          {_, _, _} ->
            IO.puts("unmatched midi event: #{inspect(event)}")
            notes
        end
      end)

    {:noreply, %{state | notes: notes}}
  end
end

defmodule Axotypixusc do
  use Application

  @moduledoc """
  Documentation for `Axotypixusc`.
  """
  def startup_sc do
    # {:ok, s} = SCSoundServer.start_link(:sc3_server, '127.0.0.1', 57110, 5000, 1_000_000, 10)
    {:ok, s} = SCSoundServer.start_link(:sc0)
    soundserver_udp_port = SCSoundServer.get_udp_port(:sc0)

    {:ok, l} = SCLang.start_link()

    SCLang.eval_sync(
      "s=Server.remote(\\a, NetAddr(\"127.0.0.1\", #{soundserver_udp_port}), s.options, 1);"
    )

    # :timer.sleep(1000)

    %{server: s, lang: l}
  end

  def load_synth do
    SCLang.eval_sync("""
    SynthDef(\\pstr,{arg freq=600,amp=1,gate=1;
    var end=1-LagUD.ar(K2A.ar(gate),0,0.3);
    var env=EnvGen.ar(Env.asr(0,amp,1),gate+Impulse.kr(0),doneAction:2);
    var sig=LeakDC.ar(LPF1.ar(Pluck.ar(BrownNoise.ar,100,1/freq,1/freq,100,(1/pi)-(end/3)),freq*2));Out.ar(0,sig*env!2)
    }).send;
    """)
  end

  def start(_type, _args) do
    IO.puts("starting")

    %{server: s, lang: l} = startup_sc()
    load_synth()
    default_group = SCSoundServer.init_default_group(:sc0)

    IO.puts("all midi devices:")
    IO.inspect(PortMidi.devices())
    IO.puts("////////////////////")

    {:ok, input} = PortMidi.open(:input, "Launchpad MIDI 1")

    # {:ok, input} = PortMidi.open(:input, "capture")

    {:ok, mi} = MidiIn.start_link(default_group)
    IO.puts("#{inspect(mi)}")

    PortMidi.listen(input, mi)

    {:ok, self()}
  end
end
