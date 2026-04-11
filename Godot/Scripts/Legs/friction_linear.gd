extends Node

@export var top_speed: int = 300
@export var max_friction: int = 300

@onready var parent = get_parent()

func _ready() -> void:
	process_priority = 50
	process_physics_priority = 50

func _physics_process(delta):
	if top_speed > 0:
		var resistance = max_friction * (parent.velocity / top_speed)
		parent.velocity -= resistance * delta
