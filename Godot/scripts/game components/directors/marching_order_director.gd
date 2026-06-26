class_name MarchingOrderDirector extends CDGameComponent

## MarchingOrderDirector
## A blind conductor that issues directional marching steps to the game bus.
## Intended for Space Invaders-style discrete grid movement where entities
## listen for the "march_step" signal and read "march_direction" from the blackboard.

enum MarchState { RIGHT, LEFT, DOWN }

@export_group("Marching Config")
## Time in seconds between each march step.
@export var step_interval: float = 0.5
## How many horizontal steps to take before stepping down.
@export var horizontal_steps: int = 10
## The game bus signal that starts the marching. Leave empty to start immediately.
@export var start_signal: StringName = &"wave_start"
## The game bus signal that stops the marching.
@export var stop_signal: StringName = &"wave_clear"

var _timer: float = 0.0
var _state: MarchState = MarchState.RIGHT
var _prev_horizontal_state: MarchState = MarchState.RIGHT
var _current_horizontal_steps: int = 0
var _is_marching: bool = false

func _on_initialize() -> void:
	super._on_initialize()
	
	if start_signal != &"":
		bus_connect(start_signal, _start_marching)
	else:
		_start_marching()
		
	if stop_signal != &"":
		bus_connect(stop_signal, _stop_marching)

func _exit_tree() -> void:
	if start_signal != &"" and is_instance_valid(game) and game.has_signal(start_signal):
		bus_disconnect(start_signal, _start_marching)
	if stop_signal != &"" and is_instance_valid(game) and game.has_signal(stop_signal):
		bus_disconnect(stop_signal, _stop_marching)

func _start_marching() -> void:
	_is_marching = true
	_timer = step_interval
	_state = MarchState.RIGHT
	_prev_horizontal_state = MarchState.RIGHT
	_current_horizontal_steps = 0
	set_physics_process(true)

func _stop_marching() -> void:
	_is_marching = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _is_marching:
		return
		
	_timer -= delta
	if _timer <= 0.0:
		_timer += step_interval
		_process_step()

func _process_step() -> void:
	var dir: Vector2 = Vector2.ZERO
	
	match _state:
		MarchState.RIGHT:
			dir = Vector2.RIGHT
			_current_horizontal_steps += 1
			if _current_horizontal_steps >= horizontal_steps:
				_prev_horizontal_state = MarchState.RIGHT
				_state = MarchState.DOWN
				
		MarchState.LEFT:
			dir = Vector2.LEFT
			_current_horizontal_steps += 1
			if _current_horizontal_steps >= horizontal_steps:
				_prev_horizontal_state = MarchState.LEFT
				_state = MarchState.DOWN
				
		MarchState.DOWN:
			dir = Vector2.DOWN
			_current_horizontal_steps = 0
			if _prev_horizontal_state == MarchState.RIGHT:
				_state = MarchState.LEFT
			else:
				_state = MarchState.RIGHT
				
	game.blackboard["march_direction"] = dir
	game.bus_emit("march_step")
