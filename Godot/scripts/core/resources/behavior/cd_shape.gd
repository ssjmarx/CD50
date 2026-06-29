## cd_shape.gd
## Produces: a polygon shape (2D point array) for entity collision polygons.
## Consumes: nothing — pure data resource consumed by Faces at init time.
class_name CDShape extends Resource

## vertices of the polygon in local-space coordinates
@export var points: PackedVector2Array = PackedVector2Array()

## whether the polygon auto-closes (last point connects to first)
@export var closed: bool = true
