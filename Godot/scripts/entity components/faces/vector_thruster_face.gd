@tool

## four vector engine flames in an X pattern
class_name VectorThrusterFace extends CDEntityComponent

@export var flame_size: float = 4.0:
	set(v):
		flame_size = v
		queue_redraw()

@export var flame_width: float = 3.0:
	set(v):
		flame_width = v
		queue_redraw()

@export var distance: float = 6.0:
	set(v):
		distance = v
		queue_redraw()

@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

@export var flicker_speed: float = 0.08
@export var flicker_size: float = 2.0
@export var line_width: float = 1.5:
	set(v):
		line_width = v
		queue_redraw()

# pre-normalized diagonal directions: UL, UR, LL, LR
var FLAME_DIRS: Array[Vector2] = [
	Vector2(-0.707107, -0.707107),  # UL
	Vector2(0.707107, -0.707107),   # UR
	Vector2(-0.707107, 0.707107),   # LL
	Vector2(0.707107, 0.707107),    # LR
]

var _active: Array[bool] = [false, false, false, false]
var _direction: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _tips: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _any_active: bool = false

func _on_initialize() -> void:
	entity.connect("move", _on_move)
	set_physics_process(false)

func _on_move(dir: Vector2) -> void:
	_direction = dir
	if dir != Vector2.ZERO and not _any_active:
		set_physics_process(true)

func _physics_process(delta: float) -> void:
	var local_dir: Vector2 = _direction.rotated(-entity.rotation)
	
	_active = [false, false, false, false]
	
	if local_dir.x > 0.1:
		_active[0] = true
		_active[2] = true
	elif local_dir.x < -0.1:
		_active[1] = true
		_active[3] = true
	
	if local_dir.y > 0.1:
		_active[0] = true
		_active[1] = true
	elif local_dir.y < -0.1:
		_active[2] = true
		_active[3] = true
	
	_any_active = _active[0] or _active[1] or _active[2] or _active[3]
	
	if _direction == Vector2.ZERO:
		_any_active = false
		set_physics_process(false)
		return
	
	_timer += delta
	if _timer > flicker_speed:
		for i in 4:
			_tips[i] = randf_range(0.0, flicker_size)
		_timer = 0.0
	
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	var is_editor: bool = Engine.is_editor_hint()
	
	for i in 4:
		if not _active[i] and not is_editor:
			continue
		if not _active[i] and is_editor:
			continue
		
		var flame_dir: Vector2 = FLAME_DIRS[i]
		var base_pos: Vector2 = flame_dir * distance
		var tip: Vector2 = base_pos + flame_dir * (flame_size + _tips[i])
		
		var perp: Vector2 = Vector2(-flame_dir.y, flame_dir.x)
		var left: Vector2 = base_pos + perp * (flame_width / 2.0)
		var right: Vector2 = base_pos - perp * (flame_width / 2.0)
		
		draw_polyline([left, tip, right], color, line_width, true)
