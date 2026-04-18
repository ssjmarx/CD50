# Monitors a group and emits victory/defeat when all nodes in that group are destroyed.

extends UniversalComponent

@export var target_group: String = ""
@export var victory_on_clear: bool = false
@export var defeat_on_clear: bool = false
@export var lose_life_on_clear: bool = false
@export var extra_life_on_clear: bool = false

var _previous_count: int = 0 

# Check if group count dropped to zero and emit appropriate signals
func _physics_process(_delta: float) -> void:
	var nodes := get_tree().get_nodes_in_group(target_group)
	var current_count := nodes.size()
	
	# Emit signals when count transitions from >0 to 0
	if _previous_count > 0 and current_count == 0:
		game.group_cleared.emit(target_group)

		if lose_life_on_clear:
			game.get_node("LivesCounter").lose_life()
		if extra_life_on_clear:
			game.get_node("LivesCounter").extra_life()
		
		if victory_on_clear:
			game.victory.emit()
		if defeat_on_clear:
			game.defeat.emit()
	
	_previous_count = current_count
