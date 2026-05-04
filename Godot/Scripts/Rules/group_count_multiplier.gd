# Adds to the game score multiplier based on the count of entities in a target group.
# Uses additive delta so it coexists with other multiplier sources (level bonuses, etc.).
# Useful for scaling difficulty or scoring based on active enemy count.

extends UniversalComponent

# Group configuration
@export var target_group: String

var _my_contribution: float = 0.0

# Update multiplier additively when group count changes
func _physics_process(_delta: float) -> void:
	var count = get_group_count(target_group)
	var new_contribution = float(count)
	if new_contribution != _my_contribution:
		var delta = new_contribution - _my_contribution
		game.current_multiplier += delta
		_my_contribution = new_contribution
