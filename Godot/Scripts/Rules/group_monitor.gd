# Monitors a group and emits victory/defeat when all nodes in that group are destroyed.

extends Node

@export var target_group: String = ""
@export var victory_on_clear: bool = false
@export var defeat_on_clear: bool = false

var _previous_count: int = 0 

@onready var parent = get_parent()

# Check if group count dropped to zero and emit appropriate signals
func _physics_process(_delta: float) -> void:
	var nodes := get_tree().get_nodes_in_group(target_group)
	var current_count := nodes.size()
	
	# Emit signals when count transitions from >0 to 0
	if _previous_count > 0 and current_count == 0:
		parent.group_cleared.emit(target_group)
		
		if victory_on_clear:
			parent.victory.emit()
		if defeat_on_clear:
			parent.defeat.emit()
	
	_previous_count = current_count
