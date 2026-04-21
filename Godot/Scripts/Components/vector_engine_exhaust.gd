# Visual engine exhaust flame drawn as a flickering triangle behind the parent body.
# Shows/hides on thrust signals, with random flicker for a burning effect.

extends UniversalComponent2D

# Flame appearance
@export var flame_size: float = 6.0
@export var flame_width: float = 8.0
@export var flame_offset: float = 4.0
@export var color: Color = Color.WHITE
@export var flicker_speed: float = 0.1
@export var flicker_size: float = 4.0

# Flame triangle vertices
var tip = Vector2(0, flame_size + flame_offset)
var left = Vector2(-flame_width / 2.0, 0 + flame_offset)
var right = Vector2(flame_width / 2.0, 0 + flame_offset)

# Flicker timer
var _timer: float = 0.0

# Hide flame and connect to thrust signals
func _ready() -> void:
	visible = false
	
	parent.thrust.connect(_on_thrust)
	parent.end_thrust.connect(_on_end_thrust)
	
	if "color" in parent:
		color = parent.color

# Flicker the flame tip at regular intervals, redraw if visible
func _physics_process(delta: float) -> void:
	_timer += delta
	
	if _timer > flicker_speed:
		var flicker = randf_range(0.0, flicker_size)
		tip = Vector2(0, flame_size + flame_offset + flicker)
		_timer = 0.0
	
	if visible:
		queue_redraw()

# Show flame when thrusting
func _on_thrust() -> void:
	visible = true

# Hide flame when not thrusting
func _on_end_thrust() -> void:
	visible = false

# Draw the flame as a polyline triangle
func _draw() -> void:
	draw_polyline([left, tip, right], color, 2.0)
