## single source of truth for an entity's health value
class_name HealthpoolGuts extends CDEntityComponent

@export var max_health: int = 3
@export var starting_health: int = -1  # -1 = use max_health
@export var invincible: bool = false   # use with signal for spawn protection

@export_group("Listen Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]
@export var heal_signals: Array[StringName] = [&"heal"]
@export var invincibility_signals: Array[StringName] = [&"set_invincible"]

@export_group("Emit Signals")
@export var health_changed_signals: Array[StringName] = [&"health_changed"]
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

var _current_health: int = 0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_current_health = starting_health if starting_health >= 0 else max_health
	
	for sig in damage_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_take_damage)
	
	for sig in heal_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_heal)
	
	for sig in invincibility_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_set_invincible)
		
	for sig in health_changed_signals:
		entity.ensure_signal(sig)
		
	for sig in zero_health_signals:
		entity.ensure_signal(sig)

func _on_take_damage(amount: int, _source: CDEntity) -> void:
	#print("Bug taking %d damage from: %s" % [amount, _source.name if is_instance_valid(_source) else "invalid"])
	if invincible or _current_health <= 0:
		return
	
	_current_health -= amount
	
	for sig in health_changed_signals:
		entity.emit_signal(sig, _current_health, -amount)
	
	if _current_health <= 0:
		for sig in zero_health_signals:
			entity.emit_signal(sig)

func _on_heal(amount: int) -> void:
	if _current_health <= 0:
		return
	
	var old = _current_health
	_current_health = mini(_current_health + amount, max_health)
	
	if _current_health != old:
		for sig in health_changed_signals:
			entity.emit_signal(sig, _current_health, _current_health - old)

func _on_set_invincible(value: bool) -> void:
	invincible = value

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
