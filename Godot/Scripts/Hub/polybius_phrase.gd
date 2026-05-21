@tool
# A sequence of PolybiusLines forming a complete animation (intro, outro, taunt, etc.).
# The face plays each line in order with its expression and syllable timeline.

extends Resource
class_name PolybiusPhrase

@export var lines: Array = []  # Array of PolybiusLine
