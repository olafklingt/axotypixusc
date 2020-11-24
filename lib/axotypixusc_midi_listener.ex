defmodule Axotypixusc.Midi.Listener do
  use GenServer
  use Bitwise

  @spec note_off(any, integer) :: any
  def note_off(notes, note) do
    synth_id = Enum.at(notes, note)
    SCSoundServer.set(synth_id, ["gate", 0.0])
    List.replace_at(notes, note, nil)
  end

  @spec note_on(non_neg_integer, any, integer, integer) :: any
  def note_on(group_id, notes, note, _vel) do
    if nil != Enum.at(notes, note) do
      note_off(notes, note)
    end

    nid = SCSoundServer.get_next_node_id()

    SCSoundServer.start_synth_async(
      "pstr",
      [
        "freq",
        SuperCollider.midi_to_freq(note)
        # :math.pow(2, (note - 69) / 24) * 440,
        # "amp",
        # vel / 127
      ],
      nid,
      0,
      # group_id
      group_id
    )

    # {:ok, synth} =
    #   SCSynth.start_link(
    #     target_s,
    #     "pstr",
    #     [
    #       "freq",
    #       # because A = 450 is heaven
    #       # :math.pow(2, (note - 69) / 12) * 450,
    #       # try:
    #       # c1 e1 gis1 h1 dis2 dis2
    #       # g2 g2 g2 dis2
    #       # g2 g2 g2 dis2
    #       # h1 h1 h1 gis1 gis1
    #       # e1 e1 e1 c1
    #       :math.pow(2, (note - 69) / 24) * 450,
    #       "amp",
    #       vel / 127
    #     ],
    #     :async
    #   )

    notes = List.replace_at(notes, note, nid)
    notes
  end

  @spec start_link(any) :: any
  def start_link(input_pids) do
    node_id = 0
    {:ok, mi} = GenServer.start_link(__MODULE__, {node_id, input_pids}, name: :midiin)
    {:ok, mi}
  end

  @impl true
  def init({node_id, input_pids}) do
    Process.flag(:trap_exit, true)

    for x <- input_pids do
      PortMidi.listen(x, self())
    end

    {:ok, %{node_id: node_id, notes: List.duplicate(nil, 128), input_pids: input_pids}}
  end

  @impl true
  def handle_info({_pid, msg}, state) do
    notes =
      Enum.reduce(msg, state.notes, fn event, notes ->
        {{type, note, vel}, _time?} = event
        chan = rem(type, 16)
        msgtype = type >>> 4

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
            note_on(state.node_id, notes, note, vel)

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

  @impl true
  def terminate(reason, state) do
    IO.puts("midi in terminate #{inspect(reason)}")
    IO.puts("midi in terminate #{inspect(state)}")
  end
end
