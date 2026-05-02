# Swarm shooting AI. Fires after a random cooldown (with random initial offset so
# invaders don't all fire at once), but only when on the specified formation edge.

extends UniversalComponent

# Formation and firing configuration
@export var formation_group: String = "invaders"
@export var min_interval: float = 2.0
@export var max_interval: float = 5.0
@export var fire_direction: Vector2 = Vector2.DOWN
@export var edge: String = "bottom"
@export var column_tolerance: float = 16.0
@export var row_tolerance: float = 16.0

var _time_since_shot: float = 0.0
var _cooldown: float = 0.0

# Start each invader at a random point in its cooldown cycle
func _ready() -> void:
	_cooldown = randf_range(min_interval, max_interval)
	_time_since_shot = randf() * _cooldown

# Accumulate time and fire when cooldown expires and on the formation edge
func _physics_process(delta: float) -> void:
	_time_since_shot += delta
	
	if _time_since_shot >= _cooldown:
		if _is_on_edge():
			parent.aim.emit(fire_direction)
			parent.shoot.emit()
		_time_since_shot = 0.0
		_cooldown = randf_range(min_interval, max_interval)

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
