# CDShape
# A polygon shape defined by 2D points
# Used by Faces to set entity collision polygons at init time

class_name CDShape extends Resource

# vertices of the polygon in local-space coordinates
@export var points: PackedVector2Array = PackedVector2Array()

# whether the polygon auto-closes (last point connects to first)
@export var closed: bool = true