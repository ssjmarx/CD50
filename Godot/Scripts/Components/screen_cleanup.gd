extends UniversalComponent

@export var margin: int = 16
@export var activation_time: float = 3.0

@onready var bounds: Vector2 = get_viewport().get_visible_rect().size

var _counter: float = 0.0

func _physics_process(delta: float) -> void:
	_counter += delta
	if _counter < activation_time:
		return
	
	var pos = parent.global_position
	if pos.x < -margin or pos.x > bounds.x + margin or pos.y < -margin or pos.y > bounds.y + margin:
		#print("cleaning up enemy")
		parent.queue_free()
