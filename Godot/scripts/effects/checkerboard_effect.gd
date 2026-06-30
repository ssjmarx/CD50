## checkerboard_effect.gd
## Produces: a configurable checkerboard visual effect.
## Consumes: @export cell dimensions and the colors array from CDEffect.
@tool
extends CDEffect

class_name CDCheckerboardEffect

## Size of each checkerboard square in pixels.
@export var cell_size: Vector2 = Vector2(16, 16):
	set(value):
		cell_size = value
		queue_redraw()

## Number of rows in the checkerboard.
@export var rows: int = 4:
	set(value):
		rows = value
		queue_redraw()

## Number of columns in the checkerboard.
@export var columns: int = 4:
	set(value):
		columns = value
		queue_redraw()

## Draws the checkerboard grid using the Godot 2D draw API.
func _draw() -> void:
	for y in range(rows):
		for x in range(columns):
			var rect := Rect2(Vector2(x * cell_size.x, y * cell_size.y), cell_size)
			## Draws the foreground squares, leaving the background squares transparent
			if (x + y) % 2 != 0:
				draw_rect(rect, get_random_color())
