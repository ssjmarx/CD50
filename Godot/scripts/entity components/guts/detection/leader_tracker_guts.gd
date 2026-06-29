## leader_tracker_guts.gd
## Produces: leader_destroyed signal when the tracked leader entity deactivates.
## Consumes: target_entity_key (entity or game blackboard); leader's entity_deactivating signal.

class_name LeaderTrackerGuts extends CDEntityComponent

enum BlackboardSource {
	ENTITY,
	GAME
}

## whether to read the target from the entity blackboard or game blackboard
@export var blackboard_source: BlackboardSource = BlackboardSource.ENTITY

## key to read the target CDEntity from
@export var target_entity_key: StringName = &"captured_by"

@export_group("Emit Signals")
@export var leader_destroyed_signals: Array[StringName] = [&"leader_destroyed"]

var _current_leader: CDEntity

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Poll the blackboard each physics frame for changes to the target reference.
func _physics_process(_delta: float) -> void:
	_check_for_leader()

## check blackboard and connect/disconnect leader signals as needed
func _check_for_leader() -> void:
	var bb: Dictionary
	if blackboard_source == BlackboardSource.ENTITY:
		bb = entity.blackboard
	else:
		bb = game.blackboard
		
	var new_leader = bb.get(target_entity_key)
	
	if new_leader != _current_leader:
		_disconnect_leader()
		_current_leader = new_leader
		_connect_leader()

## connect to leader's entity_deactivating signal
func _connect_leader() -> void:
	if is_instance_valid(_current_leader):
		if _current_leader.has_signal("entity_deactivating"):
			if not _current_leader.is_connected("entity_deactivating", _on_leader_deactivating):
				_current_leader.connect("entity_deactivating", _on_leader_deactivating)

## disconnect from leader's entity_deactivating signal
func _disconnect_leader() -> void:
	if is_instance_valid(_current_leader):
		if _current_leader.has_signal("entity_deactivating"):
			if _current_leader.is_connected("entity_deactivating", _on_leader_deactivating):
				_current_leader.disconnect("entity_deactivating", _on_leader_deactivating)

## called when the tracked leader dies
func _on_leader_deactivating() -> void:
	for sig in leader_destroyed_signals:
		entity.bus_emit(sig)
	_current_leader = null

## cleanup on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_disconnect_leader()
