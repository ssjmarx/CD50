# ScreenWrapLeg
# Wraps entity to the opposite side of game bounds when it leaves the screen
# Checks at configurable intervals to reduce overhead

class_name ScreenWrapLeg extends CDEntityComponent

# --- exports ---

# pixels beyond bounds before wrapping triggers
@export var wrap_margin: float = 20.0
# seconds between wrap checks
@export var check_interval: float = 0.1

# --- state ---

# accumulator for check interval
var _check_timer: float = 0.0

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# --- processing ---

# check bounds at intervals and wrap to opposite side if needed
func _physics_process(delta: float) -> void:
	if not entity:
		return
	_check_timer += delta
	if _check_timer < check_interval:
		return
	_check_timer = 0.0
	
	# check horizontal wrap
	var pos := entity.global_position
	var bounds := game.game_bounds
	var wrapped := false
	
	if pos.x > bounds.end.x + wrap_margin:
		pos.x = bounds.position.x - wrap_margin
		wrapped = true
	elif pos.x < bounds.position.x - wrap_margin:
		pos.x = bounds.end.x + wrap_margin
		wrapped = true
	
	# check vertical wrap
	if pos.y > bounds.end.y + wrap_margin:
		pos.y = bounds.position.y - wrap_margin
		wrapped = true
	elif pos.y < bounds.position.y - wrap_margin:
		pos.y = bounds.end.y + wrap_margin
		wrapped = true
	
	# teleport to wrapped position
	if wrapped:
		entity.request_position_set(pos)

# --- cleanup ---

# reset timer for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_check_timer = 0.0
