## StunGuts
## Temporarily disables Brains and Legs when a stun status is applied
## Reads status name and duration from entity blackboard on signal trigger Disables all INTENT and STEERING category components for the stun duration

class_name StunGuts extends CDEntityComponent

## --- exports ---

## status name to listen for (allows different status types per entity)
@export var target_status: StringName = &"stun"

@export_group("Blackboard Keys")
## key to read status name from
@export var status_key: StringName = &"status_name"
## key to read duration from
@export var duration_key: StringName = &"status_duration"

## signals that apply a status effect
@export_group("Listen Signals")
@export var status_signals: Array[StringName] = [&"apply_status"]

## emitted when stun begins
@export_group("Emit Signals")
@export var status_began_signals: Array[StringName] = [&"status_began"]
## emitted when stun ends
@export var status_ended_signals: Array[StringName] = [&"status_ended"]

## --- state ---

var _stun_timer: float = 0.0
var _is_stunned: bool = false
var _disabled_components: Array[CDEntityComponent] = []

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## on initialize
func _on_initialize() -> void:
	for sig in status_signals:
		entity.bus_connect(sig, _on_apply_status)

## --- signal handlers ---

## read status from blackboard; apply stun if name matches
func _on_apply_status() -> void:
	var status_name: StringName = entity.blackboard.get(status_key, &"")
	if status_name != target_status:
		return
	
	var duration: float = entity.blackboard.get(duration_key, 1.0)
	
	if _is_stunned:
		_stun_timer = duration
		return
	
	_is_stunned = true
	_stun_timer = duration
	_disable_brains_and_legs()
	
	for sig in status_began_signals:
		entity.bus_emit(sig)

## --- processing ---

## physics process
func _physics_process(delta: float) -> void:
	if not _is_stunned:
		return
	
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_end_stun()

## --- helpers ---

## disable brains and legs
func _disable_brains_and_legs() -> void:
	for child in entity.get_children():
		if child == self:
			continue
		if child is CDEntityComponent:
			var comp: CDEntityComponent = child
			if comp.component_category == CDEnums.ComponentCategory.INTENT or \
			   comp.component_category == CDEnums.ComponentCategory.STEERING:
				comp.set_physics_process(false)
				_disabled_components.append(comp)

## end stun
func _end_stun() -> void:
	_is_stunned = false
	_stun_timer = 0.0
	
	for comp in _disabled_components:
		if is_instance_valid(comp):
			comp.set_physics_process(true)
	_disabled_components.clear()
	
	for sig in status_ended_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _is_stunned:
		_end_stun()
	for sig in status_signals:
		entity.bus_disconnect(sig, _on_apply_status)
	set_physics_process(false)

## on entity activated
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_is_stunned = false
	_stun_timer = 0.0
	_disabled_components.clear()
	set_physics_process(true)