## LassoBullet
## Specialized projectile entity for the lasso capture mechanic.
## Emits standard tractor beam complete/miss signals on the firing entity (captor) upon deactivation,
## ensuring the LassoBrain resolves its state regardless of hit or miss.
## Detects successful captures by verifying the target's blackboard state on collision.

class_name LassoBullet extends CDEntity

@export_group("Target Filtering")
## groups to verify for capture status. If empty, assumes any collision with 'captured_by' set is a success.
@export var target_groups: Array[StringName] = [&"player"]

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"captor"
@export var success_key: StringName = &"did_capture"
@export var target_captured_by_key: StringName = &"captured_by"

@export_group("Emit Signals on Captor")
@export var success_signals: Array[StringName] = [&"capture_succeeded"]
@export var complete_signals: Array[StringName] = [&"tractor_beam_complete"]
@export var miss_signals: Array[StringName] = [&"capture_missed"]

## connect to collision signal to detect successful hits
func _on_initialize() -> void:
	super._on_initialize()
	entity.collision.connect(_on_collision)

## detect if we successfully captured a target by checking the target's blackboard
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	## check target groups if specified
	if not target_groups.is_empty():
		var is_valid_target: bool = false
		for group_name: StringName in target_groups:
			if collider.is_in_group(group_name):
				is_valid_target = true
				break
		if not is_valid_target:
			return
	
	## verify that the capture arm (e.g. CaptureOnHitArm) has marked this target
	## as captured by this specific bullet entity
	if collider.blackboard.get(target_captured_by_key) == entity:
		blackboard[success_key] = true

## Hooks into deactivation to trigger the completion logic for the LassoBrain
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	
	var captor = blackboard.get(captor_key)
	var was_capture = blackboard.get(success_key, false)
	
	if is_instance_valid(captor):
		if was_capture:
			for sig in success_signals:
				captor.bus_emit(sig)
		else:
			for sig in miss_signals:
				captor.bus_emit(sig)
		
		for sig in complete_signals:
			captor.bus_emit(sig)
