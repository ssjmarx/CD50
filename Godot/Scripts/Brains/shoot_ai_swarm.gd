# Swarm shooting AI. Fires with increasing probability over time, but only when the entity is on the specified edge of the formation.

extends UniversalComponent

# Formation and firing configuration
@export var formation_group: String = "invaders"
@export var max_shot_interval: float = 3.0
@export var fire_direction: Vector2 = Vector2.DOWN
@export var edge: String = "bottom"
@export var column_tolerance: float = 16.0
@export var row_tolerance: float = 16.0

var _time_since_shot: float = 0.0

# Accumulate time and fire probabilistically when on the formation edge
func _process(delta: float) -> void:
	_time_since_shot += delta
	
	var probability: float = _time_since_shot / max_shot_interval
	
	if randf() <= probability:
		if _is_on_edge():
			parent.shoot.emit()
			_time_since_shot = 0.0

# Check if this entity is the outermost member on the specified edge within its column/row
func _is_on_edge() -> bool:
	var members := get_group_nodes(formation_group)
	var my_pos: Vector2 = parent.global_position
	
	match edge:
		"bottom":
			for member in members:
				if member == parent: continue
				if not is_instance_valid(member): continue
				if abs(member.global_position.x - my_pos.x) <= column_tolerance:
					if member.global_position.y > my_pos.y:
						return false
			return true
		"top":
			for member in members:
				if member == parent: continue
				if not is_instance_valid(member): continue
				if abs(member.global_position.x - my_pos.x) <= column_tolerance:
					if member.global_position.y < my_pos.y:
						return false
			return true
		"left":
			for member in members:
				if member == parent: continue
				if not is_instance_valid(member): continue
				if abs(member.global_position.y - my_pos.y) <= row_tolerance:
					if member.global_position.x < my_pos.x:
						return false
			return true
		"right":
			for member in members:
				if member == parent: continue
				if not is_instance_valid(member): continue
				if abs(member.global_position.y - my_pos.y) <= row_tolerance:
					if member.global_position.x > my_pos.x:
						return false
			return true
	return true