extends UniversalComponent

@export var listen_signal: String = "body_collided"

func _ready() -> void:
	parent.connect(listen_signal, _on_collision)

func _on_collision(_collider: Node, _normal = null) -> void:
	parent.queue_free()
