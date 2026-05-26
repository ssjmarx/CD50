## generic pool for any entity resource
class_name ResourcepoolGuts extends CDEntityComponent

@export var max_resource: float = 100.0
@export var starting_resource: float = -1.0  # -1 = use max
@export var regen_rate: float = 5.0

@export_group("Listen Signals")
@export var spend_signals: Array[StringName] = [&"spend_resource"]

@export_group("Emit Signals")
@export var resource_changed_signals: Array[StringName] = [&"resource_changed"]
@export var resource_depleted_signals: Array[StringName] = [&"resource_depleted"]
@export var spend_failed_signals: Array[StringName] = [&"resource_spend_failed"]

var _current_resource: float = 0.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	
	for sig in spend_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_spend_resource)

func _on_spend_resource(amount: float) -> void:
	if _current_resource < amount:
		for sig in spend_failed_signals:
			entity.emit_signal(sig, amount)
		return
	
	_current_resource -= amount
	
	for sig in resource_changed_signals:
		entity.emit_signal(sig, _current_resource)
	
	if _current_resource <= 0.0:
		_current_resource = 0.0
		for sig in resource_depleted_signals:
			entity.emit_signal(sig)

func _physics_process(delta: float) -> void:
	if _current_resource >= max_resource:
		return
	
	_current_resource = minf(_current_resource + regen_rate * delta, max_resource)
	for sig in resource_changed_signals:
		entity.emit_signal(sig, _current_resource)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	for sig in spend_signals:
		if entity.is_connected(sig, _on_spend_resource):
			entity.disconnect(sig, _on_spend_resource)
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	set_physics_process(true)
