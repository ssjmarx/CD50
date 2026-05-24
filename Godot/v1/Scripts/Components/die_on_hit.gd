# Destroys the parent body immediately upon receiving a collision signal.

extends UniversalComponent

@export var listen_signal: String = "body_collided"

# Connect to the specified collision signal
func _ready() -> void:
	parent.connect(listen_signal, _on_collision)

# Free the parent on any collision
func _on_collision(_collider: Node, _normal: Variant = null) -> void:
	parent.queue_free()
