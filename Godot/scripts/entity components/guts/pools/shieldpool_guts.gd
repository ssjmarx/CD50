# ShieldpoolGuts
# Rechargeable health buffer that absorbs damage before overflowing to health
# Uses "catch and release" signal pattern: absorbs what it can, forwards the rest

class_name ShieldpoolGuts extends CDEntityComponent

# --- exports ---

# maximum shield capacity
@export var max_shield: float = 50.0
# seconds after damage before recharge begins
@export var recharge_delay: float = 3.0
# shield points recovered per second while recharging
@export var recharge_rate: float = 10.0

# signals that deal damage (int amount, CDEntity source)
@export_group("Listen Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]

# emitted when shield absorbs damage (float current_shield)
@export_group("Emit Signals")
@export var shield_hit_signals: Array[StringName] = [&"shield_hit"]
# emitted when shield is fully depleted
@export var shield_broken_signals: Array[StringName] = [&"shield_broken"]
# emitted when shield recharges to full after being depleted
@export var shield_recharged_signals: Array[StringName] = [&"shield_recharged"]
# emitted with overflow damage that exceeded shield (int amount, CDEntity source)
@export var overflow_signals: Array[StringName] = [&"take_health_damage"]

# --- state ---

var _current_shield: float = 0.0
var _recharge_timer: float = 0.0

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# initialize shield and connect damage listener
func _on_initialize() -> void:
	_current_shield = max_shield
	
	for sig in damage_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_take_damage)

# --- signal handlers ---

# absorb damage into shield, overflow excess to health damage signals
func _on_take_damage(amount: int, source: CDEntity) -> void:
	# no shield left — forward all damage as overflow
	if _current_shield <= 0.0:
		for sig in overflow_signals:
			entity.emit_signal(sig, amount, source)
		return
	
	# reset recharge delay on hit
	_recharge_timer = recharge_delay
	
	# absorb what the shield can hold
	var absorbed: int = mini(amount, int(_current_shield))
	_current_shield -= absorbed
	var overflow: int = amount - absorbed
	
	# notify shield hit
	for sig in shield_hit_signals:
		entity.emit_signal(sig, _current_shield)
	
	# notify shield break if depleted
	if _current_shield <= 0.0:
		for sig in shield_broken_signals:
			entity.emit_signal(sig)
	
	# forward remaining damage as overflow
	if overflow > 0:
		for sig in overflow_signals:
			entity.emit_signal(sig, overflow, source)

# --- processing ---

# recharge shield after delay, emit recharged signal when full
func _physics_process(delta: float) -> void:
	if _current_shield >= max_shield:
		return
	
	# wait for recharge delay to expire
	_recharge_timer -= delta
	if _recharge_timer <= 0.0:
		var was_empty = _current_shield <= 0.0
		_current_shield = minf(_current_shield + recharge_rate * delta, max_shield)
		
		# notify when shield recovers from empty to full
		if was_empty and _current_shield >= max_shield:
			for sig in shield_recharged_signals:
				entity.emit_signal(sig)

# --- cleanup ---

# reset shield and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_shield = max_shield
	_recharge_timer = 0.0
	for sig in damage_signals:
		if entity.is_connected(sig, _on_take_damage):
			entity.disconnect(sig, _on_take_damage)
	set_physics_process(false)

# restore shield state on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_current_shield = max_shield
	_recharge_timer = 0.0
	set_physics_process(true)