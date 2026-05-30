# GridAlignmentLeg
# Ensures entity stays snapped to a pseudo-grid
# Periodically checks for drift and corrects position, with configurable tolerance

class_name GridAlignmentLeg extends CDEntityComponent

# --- exports ---

# size of each grid cell in pixels
@export var cell_size: Vector2 = Vector2(16, 16)
# origin offset for the grid
@export var grid_origin: Vector2 = Vector2.ZERO
# seconds between alignment checks
@export var check_interval: float = 1.0
# minimum drift before correction (handles floating point noise)
@export var drift_threshold: float = 0.01

# --- state ---

# accumulator for check interval
var _check_timer: float = 0.0

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# snap to grid immediately on initialize
func _on_initialize() -> void:
	entity.request_position_set(_snap(entity.global_position))

# --- processing ---

# periodically check and correct grid alignment
func _physics_process(delta: float) -> void:
	if not entity:
		return
	
	# respect check interval (0 = every frame)
	if check_interval > 0.0:
		_check_timer += delta
		if _check_timer < check_interval:
			return
		_check_timer = 0.0
	
	# correct position if drifted beyond threshold
	var pos := entity.global_position
	var aligned := _snap(pos)
	if pos.distance_to(aligned) >= drift_threshold:
		entity.request_position_set(aligned)

# --- helpers ---

# snap a world position to the nearest grid cell
func _snap(pos: Vector2) -> Vector2:
	var relative := pos - grid_origin
	var grid_pos := (relative / cell_size).round() * cell_size
	return grid_origin + grid_pos

# --- cleanup ---

# reset timer for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_check_timer = 0.0
