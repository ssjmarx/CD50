## wraps entity to opposite side of screen when out of bounds
class_name ScreenWrapLeg extends CDEntityComponent

@export var wrap_margin: float = 20.0
@export var check_interval: float = 0.1 # seconds in between checks

var _check_timer: float = 0.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _physics_process(delta: float) -> void:
	if not entity:
		return
	_check_timer += delta
	if _check_timer < check_interval:
		return
	_check_timer = 0.0
	
	var pos := entity.global_position
	var bounds := game.game_bounds
	var wrapped := false
	
	if pos.x > bounds.end.x + wrap_margin:
		pos.x = bounds.position.x - wrap_margin
		wrapped = true
	elif pos.x < bounds.position.x - wrap_margin:
		pos.x = bounds.end.x + wrap_margin
		wrapped = true
	
	if pos.y > bounds.end.y + wrap_margin:
		pos.y = bounds.position.y - wrap_margin
		wrapped = true
	elif pos.y < bounds.position.y - wrap_margin:
		pos.y = bounds.end.y + wrap_margin
		wrapped = true
	
	if wrapped:
		entity.request_position_set(pos)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_check_timer = 0.0
