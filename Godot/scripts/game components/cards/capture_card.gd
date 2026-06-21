## CaptureCard
## Tracks currently captured entities on a global level.
## Listens for a capture signal on the Game Bus and maintains a count in the Game Blackboard.
## Connects to tracked entities to automatically clean up the count if they die or are rescued.

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

## ready
func _ready() -> void:
	super._ready()
	
	# Defer initialization to ensure game structure is ready
	call_deferred("_on_initialize")

## on initialize
func _on_initialize() -> void:
	# Initialize the blackboard count
	game.blackboard[count_key] = 0
	
	# Connect to the game bus to listen for capture events
	game.bus_connect(listen_signal, _on_capture_event)
	
	# Connect to the game bus to listen for rescue events
	if not rescue_signal.is_empty():
		game.bus_connect(rescue_signal, _on_rescue_event)

## handle a capture event from the game bus
func _on_capture_event() -> void:
	# Read the captured entity directly from the blackboard (written by CaptureOnHitArm)
	var captured_entity: CDEntity = game.blackboard.get(blackboard_source_key)
	
	if not is_instance_valid(captured_entity):
		return
		
	# Prevent duplicate tracking
	if captured_entity in _captured_entities:
		return
		
	# Add to tracking and connect for cleanup
	_captured_entities.append(captured_entity)
	
	# Use string-based connection to safely handle both native and dynamic signals
	if captured_entity.has_signal("entity_deactivating"):
		captured_entity.connect("entity_deactivating", _on_captured_entity_deactivating.bind(captured_entity))
	
	_update_count()

## handle a rescue event from the game bus
func _on_rescue_event() -> void:
	# Read the rescued entity from the signal emitters (set by AnnouncerGuts via bus_emit_from)
	var rescued_entity: CDEntity = game._signal_emitters.get(rescue_signal)
	
	if is_instance_valid(rescued_entity) and rescued_entity in _captured_entities:
		# Remove from tracking
		_captured_entities.erase(rescued_entity)
		
		# Disconnect the death handler since the entity is rescued, not dead
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
	
	# Use the inherited _update_label which checks the internal _label created by CDCueCard
	_update_label("CAPTURE: %d" % count)
