@tool
# Mouth frame data for Polybius face. Each frame defines the mouth polyline.
# Mouth frames are independent from eye/expression frames — swap them freely
# for lip sync at any facial expression.

extends Resource
class_name PolybiusMouth

@export var mouth: PackedVector2Array = PackedVector2Array()
@export var lower_lip: PackedVector2Array = PackedVector2Array()
