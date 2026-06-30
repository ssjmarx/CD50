## CaptureCard
## Produces: a game-blackboard count of currently captured entities.
## Consumes: game.blackboard["captured_entity"] + capture/rescue game bus signals.
@tool

class_name CaptureCard extends CDCueCard

## The signal to listen for on the Game Bus to detect a capture event.
## Requires an AnnouncerGuts on the captured entity to broadcast this signal.
@export var listen_signal: StringName = &"player_captured"

## The signal to listen for on the Game Bus to detect a rescue event.
## Requires an AnnouncerGuts on the rescued entity to broadcast this signal.
@export var rescue_signal: StringName = &"player_rescued"

## The key in the Game Blackboard where the current count of active captures is stored.
@export var count_key: StringName = &"active_capture_count"

## The key in the Game Blackboard where the capturing arm writes the target entity reference.
## Must match the 'target_blackboard_key' in CaptureOnHitArm.
@export var blackboard_source_key: StringName = &"captured_entity"

var _captured_entities: Array[CDEntity] = []

## initialize preview text
func _ready() -> void:
	super._ready()
	_preview_value = "CAPTURE: 0"
	_update_interface()

## on initialize
func _on_initialize() -> void:
	super._on_initialize()
	
	_publish_tracked(count_key, 0)
	
	bus_connect(listen_signal, _on_capture_event)
	
	if not rescue_signal.is_empty():
		bus_connect(rescue_signal, _on_rescue_event)

## handle a capture event from the game bus
func _on_capture_event() -> void:
	var captured_entity: CDEntity = game.blackboard.get(blackboard_source_key)
	
	if not is_instance_valid(captured_entity):
		return
		
	if captured_entity in _captured_entities:
		return
		
	_captured_entities.append(captured_entity)
	
	## bind the entity so the deactivating callback knows which one to forget
	if captured_entity.has_signal("entity_deactivating"):
		captured_entity.connect("entity_deactivating", _on_captured_entity_deactivating.bind(captured_entity))
	
	_update_count()

## handle a rescue event from the game bus
func _on_rescue_event() -> void:
	var rescued_entity: CDEntity = game._signal_emitters.get(rescue_signal)
	
	if is_instance_valid(rescued_entity) and rescued_entity in _captured_entities:
		_captured_entities.erase(rescued_entity)
		
		if rescued_entity.is_connected("entity_deactivating", _on_captured_entity_deactivating.bind(rescued_entity)):
			rescued_entity.disconnect("entity_deactivating", _on_captured_entity_deactivating.bind(rescued_entity))
	
		_update_count()

## handle a tracked entity deactivating (death)
func _on_captured_entity_deactivating(captured_entity: CDEntity) -> void:
	if captured_entity in _captured_entities:
		_captured_entities.erase(captured_entity)
	
	_update_count()

## update the game blackboard and optional UI
func _update_count() -> void:
	var count: int = _captured_entities.size()
	game.blackboard[count_key] = count
	
	_update_label("CAPTURE: %d" % count)
