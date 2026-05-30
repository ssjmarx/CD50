# ResourcepoolGuts
# Generic pool for any entity resource (fuel, energy, ammo, etc.)
# Supports spending with failure feedback and passive regeneration

class_name ResourcepoolGuts extends CDEntityComponent

# --- exports ---

# maximum resource capacity
@export var max_resource: float = 100.0
# starting resource; -1 means use max_resource
@export var starting_resource: float = -1.0
# resource points recovered per second
@export var regen_rate: float = 5.0

# signals that attempt to spend resource (float amount)
@export_group("Listen Signals")
@export var spend_signals: Array[StringName] = [&"spend_resource"]

# emitted when resource changes (float current)
@export_group("Emit Signals")
@export var resource_changed_signals: Array[StringName] = [&"resource_changed"]
# emitted when resource hits zero
@export var resource_depleted_signals: Array[StringName] = [&"resource_depleted"]
# emitted when a spend fails due to insufficient resource (float attempted)
@export var spend_failed_signals: Array[StringName] = [&"resource_spend_failed"]

# --- state ---

# current resource value
var _current_resource: float = 0.0

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# initialize resource and connect spend listener
func _on_initialize() -> void:
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	
	for sig in spend_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_spend_resource)

# --- signal handlers ---

# attempt to spend resource; emit failed if insufficient
func _on_spend_resource(amount: float) -> void:
	if _current_resource < amount:
		for sig in spend_failed_signals:
			entity.emit_signal(sig, amount)
		return
	
	_current_resource -= amount
	
	# notify listeners of resource change
	for sig in resource_changed_signals:
		entity.emit_signal(sig, _current_resource)
	
	# notify depletion if empty
	if _current_resource <= 0.0:
		_current_resource = 0.0
		for sig in resource_depleted_signals:
			entity.emit_signal(sig)

# --- processing ---

# passively regenerate resource over time
func _physics_process(delta: float) -> void:
	if _current_resource >= max_resource:
		return
	
	_current_resource = minf(_current_resource + regen_rate * delta, max_resource)
	for sig in resource_changed_signals:
		entity.emit_signal(sig, _current_resource)

# --- cleanup ---

# reset resource and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	for sig in spend_signals:
		if entity.is_connected(sig, _on_spend_resource):
			entity.disconnect(sig, _on_spend_resource)
	set_physics_process(false)

# restore resource state on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_current_resource = starting_resource if starting_resource >= 0.0 else max_resource
	set_physics_process(true)
