@tool

## main engine exhaust flame for "asteroids"-style ship
class_name VectorEngineFace extends CDEntityComponent

@export var flame_size: float = 6.0:
	set(v):
		flame_size = v
		queue_redraw()

@export var flame_width: float = 8.0:
	set(v):
		flame_width = v
		queue_redraw()

@export var flame_offset: float = 4.0:
	set(v):
		flame_offset = v
		queue_redraw()

@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

@export var flicker_speed: float = 0.1
@export var flicker_size: float = 4.0
@export var line_width: float = 2.0:
	set(v):
		line_width = v
		queue_redraw()

var _is_thrusting: bool = false
var _timer: float = 0.0
var _tip_flicker: float = 0.0

func _on_initialize() -> void:
	entity.connect("thrust", _on_thrust)
	entity.connect("end_thrust", _on_end_thrust)
	set_physics_process(false)

func _on_thrust() -> void:
	_is_thrusting = true
	set_physics_process(true)

func _on_end_thrust() -> void:
	_is_thrusting = false
	set_physics_process(false)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer > flicker_speed:
		_tip_flicker = randf_range(0.0, flicker_size)
		_timer = 0.0
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not _is_thrusting and not Engine.is_editor_hint():
		return
	
	var tip := Vector2(0, flame_size + flame_offset + _tip_flicker)
	var left := Vector2(-flame_width / 2.0, flame_offset)
	var right := Vector2(flame_width / 2.0, flame_offset)
	draw_polyline([left, tip, right], color, line_width, true)
