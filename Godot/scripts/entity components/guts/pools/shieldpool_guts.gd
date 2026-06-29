## shieldpool_guts.gd
## Produces: shield_hit/broken/recharged/overflow signals; writes value_key + delta_key.
## Consumes: damage_key for amount; take_damage signal.

class_name ShieldpoolGuts extends CDEntityComponent

## --- exports ---

## maximum shield capacity
@export var max_shield: float = 50.0
## seconds after damage before recharge begins
@export var recharge_delay: float = 3.0
## shield points recovered per second while recharging
@export var recharge_rate: float = 10.0

@export_group("Blackboard Keys")
@export var value_key: StringName = &"shield"
@export var delta_key: StringName = &"shield_delta"
## key to read incoming damage amount from (shared with damage source / healthpool)
@export var damage_key: StringName = &"damage_amount"

## signals that deal damage
@export_group("Listen Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]

## emitted when shield absorbs damage
@export_group("Emit Signals")
@export var shield_hit_signals: Array[StringName] = [&"shield_hit"]
## emitted when shield is fully depleted
@export var shield_broken_signals: Array[StringName] = [&"shield_broken"]
## emitted when shield recharges to full after being depleted
@export var shield_recharged_signals: Array[StringName] = [&"shield_recharged"]
## emitted with overflow damage that exceeded shield
@export var overflow_signals: Array[StringName] = [&"take_health_damage"]

## --- state ---

var _current_shield: float = 0.0
var _recharge_timer: float = 0.0

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Seed the shield to blackboard and connect the damage listener.
func _on_initialize() -> void:
	_current_shield = max_shield
	entity.blackboard[value_key] = _current_shield
	entity.blackboard[delta_key] = 0.0
	
	for sig in damage_signals:
		self.bus_connect(sig, _on_take_damage)

## absorb damage into shield, overflow excess to health damage signals
func _on_take_damage() -> void:
	var amount: int = entity.blackboard.get(damage_key, 1)
	
	## no shield left — forward all damage as overflow
	if _current_shield <= 0.0:
		entity.blackboard[delta_key] = -amount
		for sig in overflow_signals:
			entity.bus_emit(sig)
		return
	
	_recharge_timer = recharge_delay
	
	var absorbed: int = mini(amount, int(_current_shield))
	_current_shield -= absorbed
	var overflow: int = amount - absorbed
	
	entity.blackboard[value_key] = _current_shield
	entity.blackboard[delta_key] = -absorbed
	
	for sig in shield_hit_signals:
		entity.bus_emit(sig)
	
	if _current_shield <= 0.0:
		for sig in shield_broken_signals:
			entity.bus_emit(sig)
	
	## forward remaining damage as overflow
	if overflow > 0:
		entity.blackboard[damage_key] = overflow
		for sig in overflow_signals:
			entity.bus_emit(sig)

## Recharge the shield after its delay and emit shield_recharged when full.
func _physics_process(delta: float) -> void:
	if _current_shield >= max_shield:
		return
	
	_recharge_timer -= delta
	if _recharge_timer <= 0.0:
		var was_empty = _current_shield <= 0.0
		_current_shield = minf(_current_shield + recharge_rate * delta, max_shield)
		entity.blackboard[value_key] = _current_shield
		
		if was_empty and _current_shield >= max_shield:
			for sig in shield_recharged_signals:
				entity.bus_emit(sig)

## Reset shield and disconnect the damage listener on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_shield = max_shield
	_recharge_timer = 0.0
	entity.blackboard.erase(value_key)
	entity.blackboard.erase(delta_key)
	for sig in damage_signals:
		self.bus_disconnect(sig, _on_take_damage)
	set_physics_process(false)

## Reset shield and re-enable physics processing on activation.
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_current_shield = max_shield
	_recharge_timer = 0.0
	entity.blackboard[value_key] = _current_shield
	entity.blackboard[delta_key] = 0.0
	set_physics_process(true)