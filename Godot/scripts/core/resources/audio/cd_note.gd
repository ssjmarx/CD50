## cd_note.gd
## Produces: a single note (pitch + duration) for use in CDSoundDef note arrays.
## Consumes: nothing — pure data resource consumed by CDSoundDef.notes.
class_name CDNote extends Resource

## which semitone to play (CDEnums.Semitone enum: C2 through B6)
@export var note: CDEnums.Semitone = CDEnums.Semitone.C4

## how long this note lasts in seconds
@export var duration: float = 0.15

## smoothly glide from previous note's frequency to this note's frequency
@export var glide: bool = false
