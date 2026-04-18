extends UniversalComponent2D

@export var effect_scenes: Array[PackedScene]

@onready var health = parent.get_node("Health")

func _ready() -> void:
	health.zero_health.connect(_on_death)

func _on_death(_arg) -> void:
	for scene in effect_scenes:
		var new_scene = scene.instantiate()
		new_scene.global_position = parent.global_position
		game.add_child(new_scene)
