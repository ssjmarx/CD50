# Destroys the parent body after a configurable delay.

extends UniversalComponent

@export var timer: float = 0.5

# Configure and start the Timer child node
func _ready() -> void:
	$Timer.wait_time = timer
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

# Free the parent when the timer elapses
func _on_timeout() -> void:
	parent.queue_free()