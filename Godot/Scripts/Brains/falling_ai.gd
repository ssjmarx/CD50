# AI brain that emits a move signal at regular intervals, used for Tetris-style falling movement.

extends UniversalComponent

# Timing and direction
@export var fall_interval: float = 1.0
@export var direction: Vector2 = Vector2.DOWN

# Runtime state
var _timer: float = 0.0
var paused: bool = false

# Accumulate time and emit move signal each interval
func _process(delta: float) -> void:
	if paused:
		return
	_timer += delta
	if _timer >= fall_interval:
		_timer = 0.0
		parent.move.emit(direction)

# Reset the fall timer (e.g., after a successful move)
func reset() -> void:
	_timer = 0.0