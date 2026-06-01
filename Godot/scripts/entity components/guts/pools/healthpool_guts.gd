# HealthpoolGuts
# Single source of truth for an entity's health value
# Writes current value and delta to entity blackboard; emits zero-arg signals on events
# Supports damage, healing, invincibility, and zero-health detection

class_name HealthpoolGuts extends CDEntityComponent

# --- exports ---

# maximum health the entity can have
@export var max_health: int = 3
# starting health; -1 means use max_health
@export var starting_health: int = -1
# if true, all damage is ignored (e.g., spawn protection)
@export var invincible: bool = false

@export_group("Blackboard Keys")
@export var value_key: StringName = &"health"
@export var delta_key: StringName = &"health_delta"

# signals that trigger damage
@export_group("Listen Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]
# signals that trigger healing
@export var heal_signals: Array[StringName] = [&"heal"]
# signals that toggle invincibility
@export var invincibility_signals: Array[StringName] = [&"set_invincible"]

# emitted when health changes
@export_group("Emit Signals")
@export var health_changed_signals: Array[StringName] = [&"health_changed"]
# emitted when health reaches zero
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

# --- state ---

var _current_health: int = 0

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_current_health = starting_health if starting_health >= 0 else max_health
	entity.blackboard[value_key] = _current_health
	entity.blackboard[delta_key] = 0
	
	for sig in damage_signals:
		entity.bus_connect(sig, _on_take_damage)
	for sig in heal_signals:
		entity.bus_connect(sig, _on_heal)
	for sig in invincibility_signals:
		entity.bus_connect(sig, _on_set_invincible)

# --- signal handlers ---

func _on_take_damage() -> void:
	if invincible or _current_health <= 0:
		return
	# read damage amount from blackboard delta key (writer's responsibility)
	var amount: int = entity.blackboard.get(delta_key, 1)
	_current_health -= amount
	entity.blackboard[value_key] = _current_health
	entity.blackboard[delta_key] = -amount
	
	for sig in health_changed_signals:
		entity.bus_emit(sig)
	if _current_health <= 0:
		for sig in zero_health_signals:
			entity.bus_emit(sig)

func _on_heal() -> void:
	if _current_health <= 0:
		return
	var amount: int = entity.blackboard.get(delta_key, 1)
	var old = _current_health
	_current_health = mini(_current_health + amount, max_health)
	if _current_health != old:
		entity.blackboard[value_key] = _current_health
		entity.blackboard[delta_key] = _current_health - old
		for sig in health_changed_signals:
			entity.bus_emit(sig)

func _on_set_invincible() -> void:
	invincible = not invincible

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_health = starting_health if starting_health >= 0 else max_health
	entity.blackboard.erase(value_key)
	entity.blackboard.erase(delta_key)
	for sig in damage_signals:
		entity.bus_disconnect(sig, _on_take_damage)
	for sig in heal_signals:
		entity.bus_disconnect(sig, _on_heal)
	for sig in invincibility_signals:
		entity.bus_disconnect(sig, _on_set_invincible)