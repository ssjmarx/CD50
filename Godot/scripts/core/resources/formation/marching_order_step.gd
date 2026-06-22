@tool

## MarchingOrderStep
## Defines a physical movement of the formation by a relative offset over a duration.

class_name MarchingOrderStep extends CDMarchingOrder

## --- exports ---

## the relative offset to apply to the formation center
@export var offset: Vector2 = Vector2.ZERO

## duration of the movement in seconds
@export var duration: float = 2.0
