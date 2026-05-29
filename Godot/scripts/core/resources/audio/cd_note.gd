# CDNote
# A single note in a sound sequence — pitch + duration
# Used inside CDSoundDef.notes arrays for one-shots and jingles

class_name CDNote extends Resource

# which semitone to play (CDEnums.Semitone enum: C2 through B6)
@export var note: CDEnums.Semitone = CDEnums.Semitone.C4

# how long this note lasts in seconds
@export var duration: float = 0.15