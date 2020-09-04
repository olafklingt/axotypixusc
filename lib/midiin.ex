defmodule MidiIn do
  use GenServer

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

          {153, _, _} ->
            note_on(group, notes, note, vel)

          {137, _, 0} ->
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
