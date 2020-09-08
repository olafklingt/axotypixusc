defmodule Axotypixusc.Midi.Listener do
  use GenServer
  use Bitwise
  @spec init_midi_input(pid, atom | binary) :: any
  def init_midi_input(mi, :all) do
    i =
      try do
        PortMidi.devices().input
      rescue
        _ ->
          IO.puts("could not get midi input devices")
          []
      end

    for x <- i do
      {:ok, input} = PortMidi.open(:input, x.name)
      PortMidi.listen(input, mi)
    end

    {:ok}
  end

  def init_midi_input(mi, mid) do
    {:ok, input} = PortMidi.open(:input, mid)
    PortMidi.listen(input, mi)
  end

  def note_off(notes, note) do
    s = Enum.at(notes, note)
    SCSynth.set(s, ["gate", 0.0])
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
          # try:
          # c1 e1 gis1 h1 dis2 dis2
          # g2 g2 g2 dis2
          # g2 g2 g2 dis2
          # h1 h1 h1 gis1 gis1
          # e1 e1 e1 c1
          :math.pow(2, (note - 69) / 24) * 450,
          "amp",
          vel / 127
        ]
        # ,
        # true
      )

    notes = List.replace_at(notes, note, synth)
    notes
  end

  def start_link(default_group, midi_in_device) do
    {:ok, mi} = GenServer.start_link(__MODULE__, [default_group], name: :midiin)
    init_midi_input(mi, midi_in_device)
    {:ok, mi}
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
        chan = rem(type, 16)
        msgtype = type >>> 4
        IO.inspect({type, msgtype, chan, note, vel})

        case {msgtype, chan, note, vel} do
          {9, _, 127, _} ->
            SCSoundServer.dumpTree()
            notes

          {9, _, 57, _} ->
            SCSoundServer.quit()
            notes

          {8, _, _, _} ->
            note_off(notes, note)

          {9, _, _, 0} ->
            note_off(notes, note)

          {9, _, _, _} ->
            note_on(group, notes, note, vel)

          {176, _, 104, 0} ->
            # todo update for chan
            SCSoundServer.dumpTree()
            notes

          {_, _, _, _} ->
            IO.puts("unmatched midi event: #{inspect(event)}")
            notes
        end
      end)

    {:noreply, %{state | notes: notes}}
  end
end
