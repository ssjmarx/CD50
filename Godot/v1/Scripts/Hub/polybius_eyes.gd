@tool
# Eye/expression frame data for Polybius face. Each frame defines all eye-related
# polylines as PackedVector2Arrays, editable directly in the Godot inspector.
# Combined independently with a mouth frame for two-channel expression + lip sync.

extends Resource
class_name PolybiusEyes

@export var outline: PackedVector2Array = PackedVector2Array()
@export var left_eye: PackedVector2Array = PackedVector2Array()
@export var right_eye: PackedVector2Array = PackedVector2Array()
@export var left_pupil: PackedVector2Array = PackedVector2Array()
@export var right_pupil: PackedVector2Array = PackedVector2Array()
@export var left_eyebrow: PackedVector2Array = PackedVector2Array()
@export var right_eyebrow: PackedVector2Array = PackedVector2Array()