extends UniversalComponent

@export var timer: float = 0.5

func _ready() -> void:
	$Timer.wait_time = timer
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

func _on_timeout() -> void:
	parent.queue_free()
