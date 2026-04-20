extends UniversalComponent

@export var bus_group: String = "swarm_bus"

func _ready() -> void:
	_connect_to_bus()

func _connect_to_bus() -> void:
	var bus = get_tree().get_first_node_in_group(bus_group)
	if bus:
		bus.swarm_move.connect(_on_swarm_move)
	else:
		# Controller not in tree yet, retry next frame
		await get_tree().process_frame
		_connect_to_bus()

func _on_swarm_move(direction: Vector2) -> void:
	parent.move.emit(direction)
