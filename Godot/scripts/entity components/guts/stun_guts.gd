## temporarily disables Brains and Legs when a stun status is applied
class_name StunGuts extends CDEntityComponent

@export var target_status: StringName = &"stun"

@export_group("Listen Signals")
@export var status_signals: Array[StringName] = [&"apply_status"]

@export_group("Emit Signals")
@export var status_began_signals: Array[StringName] = [&"status_began"]
@export var status_ended_signals: Array[StringName] = [&"status_ended"]

var _stun_timer: float = 0.0
var _is_stunned: bool = false
var _disabled_components: Array[CDEntityComponent] = []

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in status_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_apply_status)

func _on_apply_status(status_name: StringName, duration: float) -> void:
	if status_name != target_status:
		return
	
	if _is_stunned:
		_stun_timer = duration
		return
	
	_is_stunned = true
	_stun_timer = duration
	_disable_brains_and_legs()
	
	for sig in status_began_signals:
		entity.emit_signal(sig, target_status)

func _physics_process(delta: float) -> void:
	if not _is_stunned:
		return
	
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_end_stun()

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

func _end_stun() -> void:
	_is_stunned = false
	_stun_timer = 0.0
	
	for comp in _disabled_components:
		if is_instance_valid(comp):
			comp.set_physics_process(true)
	_disabled_components.clear()
	
	for sig in status_ended_signals:
		entity.emit_signal(sig, target_status)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _is_stunned:
		_end_stun()
	for sig in status_signals:
		if entity.is_connected(sig, _on_apply_status):
			entity.disconnect(sig, _on_apply_status)
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_is_stunned = false
	_stun_timer = 0.0
	_disabled_components.clear()
	set_physics_process(true)
