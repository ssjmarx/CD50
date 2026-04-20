# Spawns visual effect scenes at the parent's position when health reaches zero.

extends UniversalComponent2D

# Effects to spawn on death
@export var effect_scenes: Array[PackedScene]

@onready var health: Node = parent.get_node("Health")

# Connect to Health's zero_health signal
func _ready() -> void:
	health.zero_health.connect(_on_death)

# Instantiate all effect scenes at the parent's position and add them to the game
func _on_death(_arg: Variant) -> void:
	for scene: PackedScene in effect_scenes:
		var new_scene: Node2D = scene.instantiate()
		new_scene.global_position = parent.global_position
		game.add_child(new_scene)