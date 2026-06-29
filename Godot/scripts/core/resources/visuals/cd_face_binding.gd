## cd_face_binding.gd
## Produces: a signal→frame binding (signal name, frame index, optional restore timer).
## Consumes: nothing — pure data collected by face components into lookup tables.
class_name CDFaceBinding extends Resource

## entity bus signal that triggers the frame change
@export var signal_name: StringName = &""

## sprite frame index to switch to when signal is received
@export var frame_index: int = 0

## seconds before reverting to default frame (0 = permanent switch)
@export var restore_after: float = 0.0
