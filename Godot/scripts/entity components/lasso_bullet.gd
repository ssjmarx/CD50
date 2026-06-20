## LassoBullet
## Specialized projectile entity for the lasso capture mechanic.
## Emits standard tractor beam complete/miss signals on the firing entity (captor) upon deactivation,
## ensuring the LassoBrain resolves its state regardless of hit or miss.

class_name LassoBullet extends CDEntity

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"captor"
@export var success_key: StringName = &"did_capture"

@export_group("Emit Signals on Captor")
@export var complete_signals: Array[StringName] = [&"tractor_beam_complete"]
@export var miss_signals: Array[StringName] = [&"capture_missed"]

## Hooks into deactivation to trigger the completion logic for the LassoBrain
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	
	var captor = blackboard.get(captor_key)
	var was_capture = blackboard.get(success_key, false)
	
	if is_instance_valid(captor):
		if not was_capture:
			for sig in miss_signals:
				captor.bus_emit(sig)
		for sig in complete_signals:
			captor.bus_emit(sig)
