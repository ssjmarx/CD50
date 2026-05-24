# Spawns visual effect scenes at the parent's position when the parent is removed from the tree.
# Works with any death path (die_on_hit, die_on_timer, screen_cleanup, etc.).

extends UniversalComponent2D

# Effects to spawn on removal
@export var effect_scenes: Array[PackedScene]

# Connect to parent's tree_exiting signal (fires before node is freed)
func _ready() -> void:
	parent.tree_exiting.connect(_on_tree_exiting)

# Spawn all effect scenes at the parent's position on the game node.
# Instantiates immediately (before this node is freed), then defers only the add_child
# on the game node (which survives). If we deferred the whole method, the HitEffect
# would be freed before the call executes.
func _on_tree_exiting() -> void:
	var pos: Vector2 = parent.global_position
	var game_node: Node = game
	for scene: PackedScene in effect_scenes:
		if not is_instance_valid(game_node):
			return
		var new_scene: Node2D = scene.instantiate()
		new_scene.global_position = pos
		game_node.call_deferred("add_child", new_scene)
