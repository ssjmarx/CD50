@tool

# VectorEngineFace
# Draws a single exhaust flame behind the entity when thrusting
# Listens for thrust/end_thrust signals; flickers the flame tip on a timer

class_name VectorEngineFace extends CDEntityComponent

# distance the flame extends from the entity center
@export var flame_size: float = 6.0:
	set(v):
		flame_size = v
		queue_redraw()

# width of the flame base
@export var flame_width: float = 8.0:
	set(v):
		flame_width = v
		queue_redraw()

# how far behind the entity the flame starts
@export var flame_offset: float = 4.0:
	set(v):
		flame_offset = v
		queue_redraw()

# flame color
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

# seconds between flicker updates
@export var flicker_speed: float = 0.1

# max random variation in flame tip length
@export var flicker_size: float = 4.0

# line thickness
@export var line_width: float = 2.0:
	set(v):
		line_width = v
		queue_redraw()

# whether the entity is currently thrusting
var _is_thrusting: bool = false

# time since last flicker update
var _timer: float = 0.0

# current random tip offset
var _tip_flicker: float = 0.0

# --- lifecycle ---

# connect thrust signals and disable physics processing until active
func _on_initialize() -> void:
	entity.connect("thrust", _on_thrust)
	entity.connect("end_thrust", _on_end_thrust)
	set_physics_process(false)

# --- signal handlers ---

# enable thrusting and start physics processing
func _on_thrust() -> void:
	_is_thrusting = true
	set_physics_process(true)

# disable thrusting and stop physics processing
func _on_end_thrust() -> void:
	_is_thrusting = false
	set_physics_process(false)
	queue_redraw()

# --- processing ---

# update flicker tip on timer, redraw each frame while thrusting
func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer > flicker_speed:
		_tip_flicker = randf_range(0.0, flicker_size)
		_timer = 0.0
	queue_redraw()

# redraw each frame in editor for live preview
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# --- drawing ---

# draw the V-shaped flame behind the entity
func _draw() -> void:
	if not _is_thrusting and not Engine.is_editor_hint():
		return
	
	# flame is a V shape: left base → tip → right base
	var tip := Vector2(0, flame_size + flame_offset + _tip_flicker)
	var left := Vector2(-flame_width / 2.0, flame_offset)
	var right := Vector2(flame_width / 2.0, flame_offset)
	draw_polyline([left, tip, right], color, line_width, true)