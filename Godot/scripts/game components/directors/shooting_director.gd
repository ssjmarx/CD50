## ShootingDirector
## Produces: a game bus shoot signal directed at a selected entity.
## Consumes: CDTrigger resources (when) + CDSelector resources (who).

@tool
class_name ShootingDirector extends CDGameComponent

## --- exports ---

## groups containing entities that can be selected to shoot
@export var target_groups: Array[StringName] = [&"enemies"]

## trigger resource — determines when a fire cycle occurs
@export var trigger: CDTrigger

## selector resource — narrows candidates to the final shooters
@export var selector: CDSelector

@export_group("Signals")
## signal emitted on each selected entity
@export var shoot_signal: StringName = &"shoot"

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

## on initialize
func _on_initialize() -> void:
	if trigger:
		trigger.initialize(game)
	if selector:
		selector.initialize(game)

## --- processing ---

## physics process
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not trigger:
		return
	
	if trigger.evaluate(delta):
		_fire()

## --- fire logic ---

## gather candidates, select via selector, emit shoot on each
func _fire() -> void:
	var candidates := _gather_candidates()
	if candidates.is_empty():
		return
	
	## selector narrows the pool (or all fire if no selector)
	var selected: Array[CDEntity]
	if selector:
		selected = selector.select(candidates)
	else:
		selected = candidates
	
	## command selected entities to shoot
	for entity in selected:
		if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
			entity.bus_emit(shoot_signal)

## query all target groups and deduplicate, filtering to valid + active
func _gather_candidates() -> Array[CDEntity]:
	return game.group_registry.get_groups_union(target_groups, true)

## --- reset ---

## reset trigger state for game restart
func reset() -> void:
	if trigger:
		trigger.reset()