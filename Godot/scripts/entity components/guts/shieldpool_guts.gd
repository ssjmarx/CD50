## rechargeable health buffer, uses "catch and release" signal pattern
class_name ShieldpoolGuts extends CDEntityComponent

@export var max_shield: float = 50.0
@export var recharge_delay: float = 3.0
@export var recharge_rate: float = 10.0

@export_group("Listen Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]

@export_group("Emit Signals")
@export var shield_hit_signals: Array[StringName] = [&"shield_hit"]
@export var shield_broken_signals: Array[StringName] = [&"shield_broken"]
@export var shield_recharged_signals: Array[StringName] = [&"shield_recharged"]
@export var overflow_signals: Array[StringName] = [&"take_health_damage"]

var _current_shield: float = 0.0
var _recharge_timer: float = 0.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_current_shield = max_shield
	
	for sig in damage_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_take_damage)

func _on_take_damage(amount: int, source: CDEntity) -> void:
	if _current_shield <= 0.0:
		for sig in overflow_signals:
			entity.emit_signal(sig, amount, source)
		return
	
	_recharge_timer = recharge_delay
	
	var absorbed: int = mini(amount, int(_current_shield))
	_current_shield -= absorbed
	var overflow: int = amount - absorbed
	
	for sig in shield_hit_signals:
		entity.emit_signal(sig, _current_shield)
	
	if _current_shield <= 0.0:
		for sig in shield_broken_signals:
			entity.emit_signal(sig)
	
	if overflow > 0:
		for sig in overflow_signals:
			entity.emit_signal(sig, overflow, source)

func _physics_process(delta: float) -> void:
	if _current_shield >= max_shield:
		return
	
	_recharge_timer -= delta
	if _recharge_timer <= 0.0:
		var was_empty = _current_shield <= 0.0
		_current_shield = minf(_current_shield + recharge_rate * delta, max_shield)
		
		if was_empty and _current_shield >= max_shield:
			for sig in shield_recharged_signals:
				entity.emit_signal(sig)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_shield = max_shield
	_recharge_timer = 0.0
	for sig in damage_signals:
		if entity.is_connected(sig, _on_take_damage):
			entity.disconnect(sig, _on_take_damage)
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_current_shield = max_shield
	_recharge_timer = 0.0
	set_physics_process(true)
