@tool
# One line of Polybius dialogue with expression + syllable-level timeline.
# The eye_frame sets the expression for the entire line.
# The beats array controls per-syllable mouth movement and text reveal timing.
# Voice clips are optional — text-only works for now.

extends Resource
class_name PolybiusLine

@export var text: String = ""                        # Full text for this line
@export var eye_frame: int = 0                       # Expression during this line (0=neutral, 1=displeased)
@export var voice_clip: AudioStream                  # Optional voice audio (deferred for now)
@export var beats: Array = []          # Syllable-level timeline (Array of PolybiusBeat)
@export var end_pause: float = 0.3                   # Pause after line before next