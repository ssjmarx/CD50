extends UniversalComponent

@export var formation_group: String = "invaders"
@export var max_shot_interval: float = 3.0
@export var fire_direction: Vector2 = Vector2.DOWN
@export var edge: String = "bottom"
@export var column_tolerance: float = 16.0
@export var row_tolerance: float = 16.0

var _time_since_shot: float = 0.0

func _process(delta: float) -> void:
	_time_since_shot += delta
	
	var probability = _time_since_shot / max_shot_interval
	
	if randf() <= probability:
		if _is_on_edge():
			parent.shoot.emit()
			_time_since_shot = 0.0

func _is_on_edge() -> bool:
	var members = get_tree().get_nodes_in_group(formation_group)
	var my_pos = parent.global_position
	
	match edge:
		"bottom":
			for member in members:
				if member == parent: continue
				if abs(member.global_position.x - my_pos.x) <= column_tolerance:
					if member.global_position.y > my_pos.y:
						return false
			return true
		"top":
			for member in members:
				if member == parent: continue
				if abs(member.global_position.x - my_pos.x) <= column_tolerance:
					if member.global_position.y < my_pos.y:
						return false
			return true
		"left":
			for member in members:
				if member == parent: continue
				if abs(member.global_position.y - my_pos.y) <= row_tolerance:
					if member.global_position.x < my_pos.x:
						return false
			return true
		"right":
			for member in members:
				if member == parent: continue
				if abs(member.global_position.y - my_pos.y) <= row_tolerance:
					if member.global_position.x > my_pos.x:
						return false
			return true
	return true
