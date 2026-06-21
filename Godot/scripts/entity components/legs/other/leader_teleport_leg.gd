## LeaderTeleportLeg
## Connects to a signal on a leader entity (found via blackboard) 
## and teleports the parent entity to the leader's position + offset 
## when that signal fires. Used to keep captured entities attached 
## to a leader that teleports (e.g., screen wrapping).

class_name LeaderTeleportLeg extends CDEntityComponent

enum BlackboardSource {
	ENTITY,
	GAME
}

## --- exports ---

## whether to read the leader from the entity blackboard or game blackboard
@export var blackboard_source: BlackboardSource = BlackboardSource.ENTITY

## key to read the target CDEntity (the leader) from
@export var leader_key: StringName = &"captured_by"

## signal on the leader entity that triggers the teleport
@export var teleport_signal: StringName = &"screen_wrapped"

## offset from the leader's position where this entity will land
@export var teleport_offset: Vector2 = Vector2(0.0, -16.0)

@export_group("Emit Signals")
## entity bus signals emitted AFTER the entity teleports (deferred to idle)
@export var teleported_signals: Array[StringName] = [&"teleported_by_leader"]

## --- state ---

var _current_leader: CDEntity

## --- lifecycle ---

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## --- processing ---

## poll blackboard for leader reference and manage signal connection
func _physics_process(_delta: float) -> void:
	_check_leader()

## --- internal ---

## check blackboard and connect/disconnect leader signals as needed
func _check_leader() -> void:
	var bb: Dictionary
	if blackboard_source == BlackboardSource.ENTITY:
		bb = entity.blackboard
	else:
		bb = game.blackboard
		
	var new_leader = bb.get(leader_key)
	
	if new_leader != _current_leader:
		_disconnect_leader()
		_current_leader = new_leader
		_connect_leader()

## connect to the leader's teleport signal
func _connect_leader() -> void:
	if is_instance_valid(_current_leader):
		if _current_leader.has_signal(teleport_signal):
			if not _current_leader.is_connected(teleport_signal, _on_leader_teleport_signal):
				_current_leader.connect(teleport_signal, _on_leader_teleport_signal)

## disconnect from the leader's teleport signal
func _disconnect_leader() -> void:
	if is_instance_valid(_current_leader):
		if _current_leader.has_signal(teleport_signal):
			if _current_leader.is_connected(teleport_signal, _on_leader_teleport_signal):
				_current_leader.disconnect(teleport_signal, _on_leader_teleport_signal)

## called when the leader emits the teleport signal
func _on_leader_teleport_signal() -> void:
	if not is_instance_valid(_current_leader) or not is_instance_valid(entity):
		return
		
	## calculate target position based on leader and offset
	var target_pos := _current_leader.global_position + teleport_offset
	
	## request position update (processed by physics system)
	entity.request_position_set(target_pos)
	
	## defer after-teleport signals to ensure position has updated
	if not teleported_signals.is_empty():
		_emit_teleported_signals.call_deferred()

## emit signals after the position update has processed
func _emit_teleported_signals() -> void:
	if not entity or not is_instance_valid(entity):
		return
	for sig in teleported_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## disconnect from leader on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_disconnect_leader()
