# Sets the game score multiplier to the count of entities in a target group.
# Useful for scaling difficulty or scoring based on active enemy count.

extends UniversalComponent

# Group configuration
@export var target_group: String

# Update multiplier every physics frame to match group count
func _physics_process(_delta: float) -> void:
	game.current_multiplier = get_tree().get_nodes_in_group(target_group).size()
