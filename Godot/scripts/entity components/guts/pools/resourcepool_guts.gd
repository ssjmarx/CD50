# ResourcepoolGuts
# Generic pool for any entity resource (fuel, energy, ammo, etc.)
# Writes current value and delta to entity blackboard; emits zero-arg signals on events
# Supports spending with failure feedback and passive regeneration

class_name ResourcepoolGuts extends CDEntityComponent

# --- exports ---

# maximum resource capacity
@export var max_resource: float = 100.0
# starting resource; -1 means use max_resource
@export var starting_resource: float = -1.0
# resource points recovered per second
@export var regen_rate: float = 5.0

@export_group("Blackboard Keys")
@export var value_key: StringName = &"resource"
@export var delta_key: StringName = &"resource_delta"

# signals that attempt to spend resource
@export_group("Listen Signals")
@export var spend_signals: Array[StringName] = [&"spend_resource"]

# emitted when resource changes
@export_group("Emit Signals")
@export var resource_changed_signals: Array[StringName] = [&"resource_changed"]
# emitted when resource hits zero
@export var resource_depleted_signals: Array[StringName] = [&"resource_depleted"]
# emitted when a spend fails due to insufficient resource
@export var spend_failed_signals: Array[StringName] = [&"resource_spend_failed"]

# --- state ---

var _current_resource: float = 0.0

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	entity.blackboard[value_key] = _current_resource
	entity.blackboard[delta_key] = 0.0
	
	for sig in spend_signals:
		entity.bus_connect(sig, _on_spend_resource)

# --- signal handlers ---

# attempt to spend resource; read amount from blackboard delta_key
func _on_spend_resource() -> void:
	var amount: float = entity.blackboard.get(delta_key, 1.0)
	if _current_resource < amount:
		entity.blackboard[delta_key] = -amount
		for sig in spend_failed_signals:
			entity.bus_emit(sig)
		return
	
	_current_resource -= amount
	entity.blackboard[value_key] = _current_resource
	entity.blackboard[delta_key] = -amount
	
	for sig in resource_changed_signals:
		entity.bus_emit(sig)
	
	if _current_resource <= 0.0:
		_current_resource = 0.0
		entity.blackboard[value_key] = 0.0
		for sig in resource_depleted_signals:
			entity.bus_emit(sig)

# --- processing ---

# passively regenerate resource over time
func _physics_process(delta: float) -> void:
	if _current_resource >= max_resource:
		return
	
	var old = _current_resource
	_current_resource = minf(_current_resource + regen_rate * delta, max_resource)
	entity.blackboard[value_key] = _current_resource
	entity.blackboard[delta_key] = _current_resource - old
	for sig in resource_changed_signals:
		entity.bus_emit(sig)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	entity.blackboard.erase(value_key)
	entity.blackboard.erase(delta_key)
	for sig in spend_signals:
		entity.bus_disconnect(sig, _on_spend_resource)
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	entity.blackboard[value_key] = _current_resource
	entity.blackboard[delta_key] = 0.0
	set_physics_process(true)