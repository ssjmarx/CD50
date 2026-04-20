# Swarm AI brain. Connects to a swarm bus node and forwards movement commands to the parent body.

extends UniversalComponent

@export var bus_group: String = "swarm_bus"

# Connect to the swarm bus on ready
func _ready() -> void:
	_connect_to_bus()

# Find the bus node in the group and subscribe to its swarm_move signal; retries if not yet in tree
func _connect_to_bus() -> void:
	var bus: Node = get_tree().get_first_node_in_group(bus_group)
	if bus:
		bus.swarm_move.connect(_on_swarm_move)
	else:
		await get_tree().process_frame
		_connect_to_bus()

# Forward the swarm direction to the parent's move signal
func _on_swarm_move(direction: Vector2) -> void:
	parent.move.emit(direction)