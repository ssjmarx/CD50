# Auto-configures collision layers/masks from group definitions. Supports UniversalBody and CollisionMarker.
class_name CollisionMatrix extends RefCounted

var _game_script: Node # Parent game coordinator
var _collision_groups: Dictionary = {} # Group relationships: {primary: [target1, target2]}
var _group_to_bit: Dictionary = {} # Group name to bit flag mapping

# Initialize and connect to game script's child add/remove signals
func initialize(game_script: Node) -> void:
	_game_script = game_script
	_game_script.child_entered_tree.connect(_on_child_added)
	_game_script.child_exiting_tree.connect(_on_child_removed)

# Set up collision group relationships and configure all existing bodies
func setup(collision_groups: Dictionary) -> void:
	_collision_groups = collision_groups
	_build_bit_mapping()
	_configure_existing_bodies()

# Convert group names to bit flags (bit 0, bit 1, bit 2, etc.)
func _build_bit_mapping() -> void:	
	var current_bit: int = 0
	
	for key in _collision_groups.keys():
		var bit_mask = 1 << current_bit
		_group_to_bit[key] = bit_mask
		current_bit += 1

# Configure UniversalBody's collision layer and mask from its groups
func _configure_body(body: UniversalBody) -> void:	
	if _group_to_bit.is_empty():
		return
	
	if not body.is_node_ready():
		body.ready.connect(_configure_body.bind(body), CONNECT_ONE_SHOT)
		return
	
	if body.collision_groups.is_empty():
		return
	
	var primary_group = body.collision_groups[0]
	if primary_group in _group_to_bit:
		body.collision_layer = _group_to_bit[primary_group]
	else:
		print("Attempted to configure non-existent collision group '", primary_group, "' on body: ", body.name)
		return
	
	var target_groups = _collision_groups[primary_group]
	var collision_mask = 0
	for target_group in target_groups:
		if target_group in _group_to_bit:
			var target_bit = _group_to_bit[target_group]
			collision_mask = collision_mask | target_bit
		else:
			print("Attempted to configure non-existent collision target '", target_group, "' on body: ", body.name)
	
	body.collision_mask = collision_mask

# Find and configure all existing bodies in the game tree
func _configure_existing_bodies() -> void:
	
	var all_nodes = _collect_all_descendants(_game_script)
	
	for node in all_nodes:
		if node is UniversalBody:
			_configure_body(node)
		elif node.get_child_count() > 0:
			var marker = _find_collision_marker(node)
			if marker:
				_configure_body_from_marker(node, marker)

# Recursively collect all descendants of a node
func _collect_all_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	
	if node == null:
		return result
		
	result.append(node)
	
	for child in node.get_children():
		var child_descendants = _collect_all_descendants(child)
		result.append_array(child_descendants)
	
	return result

# Find CollisionMarker child if present
func _find_collision_marker(node: Node) -> CollisionMarker:
	for child in node.get_children():
		if child is CollisionMarker:
			return child
	return null

# Configure non-UniversalBody using its CollisionMarker child
func _configure_body_from_marker(body: Node, marker: CollisionMarker) -> void:
	
	if _group_to_bit.is_empty():
		return
	
	if not body.is_node_ready():
		body.ready.connect(_configure_body_from_marker.bind(body, marker), CONNECT_ONE_SHOT)
		return
	
	if marker.collision_groups.is_empty():
		return
	
	var primary_group = marker.collision_groups[0]
	if primary_group in _group_to_bit:
		body.collision_layer = _group_to_bit[primary_group]
	else:
		print("Attempted to configure non-existent collision group '", primary_group, "' on body: ", body.name)
		return
	
	var target_groups = _collision_groups[primary_group]
	var collision_mask = 0
	for target_group in target_groups:
		if target_group in _group_to_bit:
			var target_bit = _group_to_bit[target_group]
			collision_mask = collision_mask | target_bit
		else:
			print("Attempted to configure non-existent collision target '", target_group, "' on body: ", body.name)
	
	body.collision_mask = collision_mask

# Clear collision configuration when body is removed
func _cleanup_body(node: Node) -> void:
	node.collision_layer = 0
	node.collision_mask = 0

# Configure newly added child node
func _on_child_added(node: Node) -> void:	
	if node is UniversalBody:
		_configure_body(node)
	else:
		var marker = _find_collision_marker(node)
		if marker:
			_configure_body_from_marker(node, marker)

# Clear collision configuration when child is removed
func _on_child_removed(node: Node) -> void:
	if node is UniversalBody:
		_cleanup_body(node)
	else:
		var marker = _find_collision_marker(node)
		if marker:
			_cleanup_body(node)

# Public method to reconfigure all bodies
func configure_all_bodies() -> void:
	_configure_existing_bodies()
