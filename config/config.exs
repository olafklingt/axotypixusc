import Config

config :portmidi,
  buffer_size: 1024,
  input_poll_sleep: 100

config :axotypixusc,
# midi_in_device: "Launchpad MIDI 1"
#  midi_in_device: "Virtual Keyboard"
#  midi_in_device: "out"
# midi_in_device: "Mamba"
#  midi_in_device: "Midi Through Port-0"
  midi_in_device: "KOMPLETE KONTROL A61 MIDI 1"
