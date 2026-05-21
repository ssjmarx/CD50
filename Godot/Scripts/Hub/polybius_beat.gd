@tool
# A single syllable event in a PolybiusLine timeline.
# start_time: absolute time (seconds) from line start when the mouth opens.
# hold_time: seconds to hold the mouth position before closing.
# Hand-adjust these in the inspector to sync lip movement to voice.

extends Resource
class_name PolybiusBeat

@export var start_time: float = 0.0      # Seconds from line start to open mouth
@export var mouth_frame: int = 1         # Mouth frame to show during this syllable (0=closed, 1=open)
@export var hold_time: float = 0.12      # Seconds to hold the mouth position