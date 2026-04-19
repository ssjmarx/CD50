# Monitors a group and emits victory/defeat when all nodes in that group are destroyed.

extends UniversalComponent

@export var target_group: String = ""
@export var victory_on_clear: bool = false
@export var defeat_on_clear: bool = false
@export var lose_life_on_clear: bool = false
@export var extra_life_on_clear: bool = false

var _previous_count: int = -1

func _physics_process(_delta: float) -> void:
	var count = get_tree().get_nodes_in_group(target_group).size()
	
	# First frame: record initial count
	if _previous_count == -1:
		_previous_count = count
		return
	
	# Count decreased = something died
	if count < _previous_count:
		game.group_member_removed.emit(target_group)
	
	# Count hit zero = group cleared (existing behavior)
	if count == 0 and _previous_count > 0:
		game.group_cleared.emit(target_group)
		if lose_life_on_clear:
			game.get_node("LivesCounter").lose_life()
		if extra_life_on_clear:
			game.get_node("LivesCounter").extra_life()
		if victory_on_clear:
			game.victory.emit()
		if defeat_on_clear:
			game.defeat.emit()
	
	_previous_count = count
