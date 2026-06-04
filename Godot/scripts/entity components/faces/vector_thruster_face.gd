@tool

## VectorThrusterFace
## Draws four diagonal thruster flames in an X pattern
## Activates individual flames based on move signal direction

class_name VectorThrusterFace extends CDEntityComponent

## distance each flame extends from center
@export var flame_size: float = 4.0:
	set(v):
		flame_size = v
		queue_redraw()

## width of each flame base
@export var flame_width: float = 3.0:
	set(v):
		flame_width = v
		queue_redraw()

## distance from center to flame base
@export var distance: float = 6.0:
	set(v):
		distance = v
		queue_redraw()

## flame color
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

## seconds between flicker updates
@export var flicker_speed: float = 0.08

## max random variation in flame tip length
@export var flicker_size: float = 2.0

## line thickness
@export var line_width: float = 1.5:
	set(v):
		line_width = v
		queue_redraw()

@export var move_key: StringName = &"move_direction"

## pre-normalized diagonal directions: UL, UR, LL, LR
var FLAME_DIRS: Array[Vector2] = [
	Vector2(-0.707107, -0.707107),
	Vector2(0.707107, -0.707107),
	Vector2(-0.707107, 0.707107),
	Vector2(0.707107, 0.707107),
]

## which flames are currently active
var _active: Array[bool] = [false, false, false, false]

## current move direction from entity signals
var _direction: Vector2 = Vector2.ZERO

## time since last flicker update
var _timer: float = 0.0

## per-flame random tip offsets
var _tips: Array[float] = [0.0, 0.0, 0.0, 0.0]

## whether any flame is active
var _any_active: bool = false

## --- processing ---

## on initialize
func _on_initialize() -> void:
	set_process(true)

## redraw each frame in editor for live preview
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		_direction = entity.blackboard.get(move_key, Vector2.ZERO)
		
		var local_dir: Vector2 = _direction.rotated(-entity.rotation)
		
		_active = [false, false, false, false]
		
		## horizontal movement activates opposite-side thrusters (to push)
		if local_dir.x > 0.1:
			_active[0] = true  # UL fires for rightward push
			_active[2] = true  # LL fires for rightward push
		elif local_dir.x < -0.1:
			_active[1] = true  # UR fires for leftward push
			_active[3] = true  # LR fires for leftward push
		
		## vertical movement activates opposite-side thrusters
		if local_dir.y > 0.1:
			_active[0] = true  # UL fires for downward push
			_active[1] = true  # UR fires for downward push
		elif local_dir.y < -0.1:
			_active[2] = true  # LL fires for upward push
			_active[3] = true  # LR fires for upward push
		
		_any_active = _active[0] or _active[1] or _active[2] or _active[3]
		
		## stop processing if direction is zero
		if _direction == Vector2.ZERO:
			_any_active = false
			queue_redraw()
			return
		
		## update flicker tips on timer
		_timer += delta
		if _timer > flicker_speed:
			for i in 4:
				_tips[i] = randf_range(0.0, flicker_size)
			_timer = 0.0
		
		queue_redraw()

## --- drawing ---

## draw active thruster flames as V-shapes along their diagonal directions
func _draw() -> void:
	var is_editor: bool = Engine.is_editor_hint()
	
	for i in 4:
		if not _active[i] and not is_editor:
			continue
		
		var flame_dir: Vector2 = FLAME_DIRS[i]
		var base_pos: Vector2 = flame_dir * distance
		var tip: Vector2 = base_pos + flame_dir * (flame_size + _tips[i])
		
		var perp: Vector2 = Vector2(-flame_dir.y, flame_dir.x)
		var left: Vector2 = base_pos + perp * (flame_width / 2.0)
		var right: Vector2 = base_pos - perp * (flame_width / 2.0)
		
		draw_polyline([left, tip, right], color, line_width, true)
