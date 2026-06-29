## die_out_of_bounds_guts.gd
## Produces: a death request when the entity leaves game.game_bounds (plus margin).
## Consumes: game.game_bounds; a configurable activation delay.

class_name DieOutOfBoundsGuts extends CDEntityComponent

## --- exports ---

## extra pixels beyond game bounds before triggering death
@export var margin: float = 16.0
## seconds to wait before checking bounds (prevents dying on spawn)
@export var activation_delay: float = 3.0

## --- state ---

## countdown before bounds checking begins
var _delay_remaining: float = 0.0
## whether bounds checking is active
var _active: bool = false

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## begin delay countdown
func _on_initialize() -> void:
	_delay_remaining = activation_delay
	_active = true

## --- processing ---

## wait for delay, then deactivate if entity is outside game bounds + margin
func _physics_process(delta: float) -> void:
	if not _active:
		return
	
	if _delay_remaining > 0.0:
		_delay_remaining -= delta
		return
	
	if not game or not game.game_bounds.has_area():
		return
	
	## check horizontal bounds
	var pos = entity.global_position
	var bounds = game.game_bounds
	if pos.x < bounds.position.x - margin or pos.x > bounds.end.x + margin:
		entity.deactivate()
		_active = false
	elif pos.y < bounds.position.y - margin or pos.y > bounds.end.y + margin:
		entity.deactivate()
		_active = false

## --- cleanup ---

## stop processing for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_active = false
	set_physics_process(false)

## restart delay cycle on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_delay_remaining = activation_delay
	_active = true
	set_physics_process(true)
