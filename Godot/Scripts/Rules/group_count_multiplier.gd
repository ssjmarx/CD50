extends UniversalComponent

@export var target_group: String

func _physics_process(_delta: float) -> void:
	game.current_multiplier = get_tree().get_nodes_in_group(target_group).size()
