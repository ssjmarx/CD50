# Sets the game score multiplier to the count of entities in a target group.
# Useful for scaling difficulty or scoring based on active enemy count.

extends UniversalComponent

# Group configuration
@export var target_group: String

var _last_count: int = -1

# Update multiplier only when group count changes
func _physics_process(_delta: float) -> void:
	var count = get_group_count(target_group)
	if count != _last_count:
		_last_count = count
		game.current_multiplier = count
