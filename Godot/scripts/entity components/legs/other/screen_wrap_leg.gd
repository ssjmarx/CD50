## ScreenWrapLeg
## Produces: a wrapped position request when the entity leaves game bounds.
## Consumes: entity global position; game.game_bounds rect.

class_name ScreenWrapLeg extends CDEntityComponent

## --- exports ---

@export var wrap_margin: float = 20.0
@export var check_interval: float = 0.1

@export_group("Emit Signals")
## entity bus signals emitted immediately BEFORE the entity wraps
@export var wrapping_signals: Array[StringName] = [&"screen_wrapping"]
## entity bus signals emitted AFTER the entity wraps (deferred to idle)
@export var wrapped_signals: Array[StringName] = [&"screen_wrapped"]

## --- state ---

var _check_timer: float = 0.0

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## check bounds at intervals and wrap to opposite side if needed
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
	
	## check vertical wrap
	if pos.y > bounds.end.y + wrap_margin:
		pos.y = bounds.position.y - wrap_margin
		wrapped = true
	elif pos.y < bounds.position.y - wrap_margin:
		pos.y = bounds.end.y + wrap_margin
		wrapped = true
	
	if wrapped:
		## emit before-wrap signals immediately
		for sig in wrapping_signals:
			entity.bus_emit(sig)
		
		entity.request_position_set(pos)
		
		## defer after-wrap signals to ensure position has updated
		if not wrapped_signals.is_empty():
			_emit_wrapped_signals.call_deferred()

## emit signals after the position update has processed
func _emit_wrapped_signals() -> void:
	if not entity or not is_instance_valid(entity):
		return
	for sig in wrapped_signals:
		entity.bus_emit(sig)

## reset timer for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_check_timer = 0.0
