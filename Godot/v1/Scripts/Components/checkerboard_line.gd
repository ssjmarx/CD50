@tool
# Draws a checkerboard pattern of alternating squares. Configurable via exports.
# Useful as a center-line replacement for Paddle Ball.

extends Node2D

@export var cell_size: int = 4:
	set(v):
		cell_size = v
		queue_redraw()

@export var columns: int = 3:
	set(v):
		columns = v
		queue_redraw()

@export var rows: int = 64:
	set(v):
		rows = v
		queue_redraw()

@export var color_a: Color = Color.WHITE:
	set(v):
		color_a = v
		queue_redraw()

@export var color_b: Color = Color.TRANSPARENT:
	set(v):
		color_b = v
		queue_redraw()

func _draw() -> void:
	var half_w: float = (columns * cell_size) / 2.0
	for row in rows:
		for col in columns:
			if (row + col) % 2 == 0:
				var x: float = -half_w + col * cell_size
				var y: float = row * cell_size
				draw_rect(Rect2(x, y, cell_size, cell_size), color_a)