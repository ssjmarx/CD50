## ensures entity stays snapped to a pseudo-grid
class_name GridAlignmentLeg extends CDEntityComponent

@export var cell_size: Vector2 = Vector2(16, 16)
@export var grid_origin: Vector2 = Vector2.ZERO
@export var check_interval: float = 1.0  # time in seconds
@export var drift_threshold: float = 0.01  # primarily for floating point noise

var _check_timer: float = 0.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	entity.request_position_set(_snap(entity.global_position))

func _physics_process(delta: float) -> void:
	if not entity:
		return
	
	if check_interval > 0.0:
		_check_timer += delta
		if _check_timer < check_interval:
			return
		_check_timer = 0.0
	
	var pos := entity.global_position
	var aligned := _snap(pos)
	if pos.distance_to(aligned) >= drift_threshold:
		entity.request_position_set(aligned)

func _snap(pos: Vector2) -> Vector2:
	var relative := pos - grid_origin
	var grid_pos := (relative / cell_size).round() * cell_size
	return grid_origin + grid_pos

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_check_timer = 0.0
