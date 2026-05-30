# StunGuts
# Temporarily disables Brains and Legs when a stun status is applied
# Disables all INTENT and STEERING category components for the stun duration

class_name StunGuts extends CDEntityComponent

# --- exports ---

# status name to listen for (allows different status types per entity)
@export var target_status: StringName = &"stun"

# signals that apply a status effect (StringName status, float duration)
@export_group("Listen Signals")
@export var status_signals: Array[StringName] = [&"apply_status"]

# emitted when stun begins (StringName status)
@export_group("Emit Signals")
@export var status_began_signals: Array[StringName] = [&"status_began"]
# emitted when stun ends (StringName status)
@export var status_ended_signals: Array[StringName] = [&"status_ended"]

# --- state ---

# countdown to stun ending
var _stun_timer: float = 0.0
# whether the entity is currently stunned
var _is_stunned: bool = false
# components that were disabled during stun (to re-enable on end)
var _disabled_components: Array[CDEntityComponent] = []

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect status listener
func _on_initialize() -> void:
	for sig in status_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_apply_status)

# --- signal handlers ---

# apply stun if status name matches; extend duration if already stunned
func _on_apply_status(status_name: StringName, duration: float) -> void:
	if status_name != target_status:
		return
	
	# refresh duration if already stunned
	if _is_stunned:
		_stun_timer = duration
		return
	
	_is_stunned = true
	_stun_timer = duration
	_disable_brains_and_legs()
	
	# notify listeners that stun has begun
	for sig in status_began_signals:
		entity.emit_signal(sig, target_status)

# --- processing ---

# tick stun timer and end stun when it expires
func _physics_process(delta: float) -> void:
	if not _is_stunned:
		return
	
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_end_stun()

# --- helpers ---

# disable physics processing on all INTENT and STEERING components
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

# re-enable all disabled components and notify listeners
func _end_stun() -> void:
	_is_stunned = false
	_stun_timer = 0.0
	
	# restore physics processing on all disabled components
	for comp in _disabled_components:
		if is_instance_valid(comp):
			comp.set_physics_process(true)
	_disabled_components.clear()
	
	# notify listeners that stun has ended
	for sig in status_ended_signals:
		entity.emit_signal(sig, target_status)

# --- cleanup ---

# end any active stun and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _is_stunned:
		_end_stun()
	for sig in status_signals:
		if entity.is_connected(sig, _on_apply_status):
			entity.disconnect(sig, _on_apply_status)
	set_physics_process(false)

# reset stun state on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_is_stunned = false
	_stun_timer = 0.0
	_disabled_components.clear()
	set_physics_process(true)
