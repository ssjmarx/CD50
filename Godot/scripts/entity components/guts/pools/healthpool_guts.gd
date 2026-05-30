# HealthpoolGuts
# Single source of truth for an entity's health value
# Supports damage, healing, invincibility, and zero-health detection

class_name HealthpoolGuts extends CDEntityComponent

# --- exports ---

# maximum health the entity can have
@export var max_health: int = 3
# starting health; -1 means use max_health
@export var starting_health: int = -1
# if true, all damage is ignored (e.g., spawn protection)
@export var invincible: bool = false

# signals that trigger damage (int amount, CDEntity source)
@export_group("Listen Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]
# signals that trigger healing (int amount)
@export var heal_signals: Array[StringName] = [&"heal"]
# signals that toggle invincibility (bool value)
@export var invincibility_signals: Array[StringName] = [&"set_invincible"]

# emitted when health changes (int current, int delta)
@export_group("Emit Signals")
@export var health_changed_signals: Array[StringName] = [&"health_changed"]
# emitted when health reaches zero
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

# --- state ---

# current health value
var _current_health: int = 0

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# initialize health, connect all listen signals, ensure emit signals exist
func _on_initialize() -> void:
	_current_health = starting_health if starting_health >= 0 else max_health
	
	# connect damage, heal, and invincibility listeners
	for sig in damage_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_take_damage)
	
	for sig in heal_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_heal)
	
	for sig in invincibility_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_set_invincible)
	
	# ensure emit signals exist so other components can connect to them
	for sig in health_changed_signals:
		entity.ensure_signal(sig)
		
	for sig in zero_health_signals:
		entity.ensure_signal(sig)

# --- signal handlers ---

# apply damage if not invincible, emit health_changed and zero_health
func _on_take_damage(amount: int, _source: CDEntity) -> void:
	if invincible or _current_health <= 0:
		return
	
	_current_health -= amount
	
	# notify listeners of health change (negative delta)
	for sig in health_changed_signals:
		entity.emit_signal(sig, _current_health, -amount)
	
	# check for death
	if _current_health <= 0:
		for sig in zero_health_signals:
			entity.emit_signal(sig)

# restore health up to max, emit health_changed if value changed
func _on_heal(amount: int) -> void:
	if _current_health <= 0:
		return
	
	var old = _current_health
	_current_health = mini(_current_health + amount, max_health)
	
	if _current_health != old:
		for sig in health_changed_signals:
			entity.emit_signal(sig, _current_health, _current_health - old)

# toggle invincibility on or off
func _on_set_invincible(value: bool) -> void:
	invincible = value

# --- cleanup ---

# reset health and disconnect all signals for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_health = starting_health if starting_health >= 0 else max_health
	for sig in damage_signals:
		if entity.is_connected(sig, _on_take_damage):
			entity.disconnect(sig, _on_take_damage)
	for sig in heal_signals:
		if entity.is_connected(sig, _on_heal):
			entity.disconnect(sig, _on_heal)
	for sig in invincibility_signals:
		if entity.is_connected(sig, _on_set_invincible):
			entity.disconnect(sig, _on_set_invincible)
