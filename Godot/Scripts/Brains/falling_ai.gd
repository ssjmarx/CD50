extends UniversalComponent

@export var fall_interval: float = 1.0  # seconds between downward moves
@export var direction: Vector2 = Vector2.DOWN  # which direction is "down"

var _timer: float = 0.0
var paused: bool = false

func _process(delta: float) -> void:
	if paused:
		return
	_timer += delta
	if _timer >= fall_interval:
		_timer = 0.0
		parent.move.emit(direction)

func reset() -> void:
	_timer = 0.0
