# Spawns visual effect scenes at the parent's position when health reaches zero.

extends UniversalComponent2D

# Effects to spawn on death
@export var effect_scenes: Array[PackedScene]

@onready var health: Node = parent.get_node("Health")

# Connect to Health's zero_health signal
func _ready() -> void:
	health.zero_health.connect(_on_death)

# Instantiate all effect scenes at the parent's position and add them to the game.
# Called synchronously (not deferred) so effects spawn before die() disables/frees nodes.
func _on_death(_arg: Variant) -> void:
	var pos: Vector2 = parent.global_position
	_spawn_effects(effect_scenes, pos, game)

func _spawn_effects(scenes: Array[PackedScene], pos: Vector2, game_node: Node) -> void:
	for scene: PackedScene in scenes:
		if not is_instance_valid(game_node):
			return
		var new_scene: Node2D = scene.instantiate()
		new_scene.global_position = pos
		game_node.add_child(new_scene)
