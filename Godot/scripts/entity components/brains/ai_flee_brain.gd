## AI that emits a movement direction away from the nearest thing in target groups
class_name AIFleeBrain extends CDEntityComponent

@export var threat_groups: Array[StringName] = [&"player"]
@export var flee_distance: float = 150.0
@export var update_interval: float = 0.0
@export var targeting_noise: float = 0.0

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move"]

var _update_timer: float = 0.0
var _last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)

func _physics_process(delta: float) -> void:
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			for sig in move_signals:
				entity.emit_signal(sig, _last_direction)
			return
		_update_timer = 0.0
	
	var nearest := _find_nearest()
	if nearest == null:
		_last_direction = Vector2.ZERO
		for sig in move_signals:
			entity.emit_signal(sig, Vector2.ZERO)
		return
	
	var threat_pos := _apply_noise(nearest.global_position)
	var distance := entity.global_position.distance_to(threat_pos)
	
	if distance > flee_distance:
		_last_direction = Vector2.ZERO
		for sig in move_signals:
			entity.emit_signal(sig, Vector2.ZERO)
		return
	
	_last_direction = threat_pos.direction_to(entity.global_position)
	for sig in move_signals:
		entity.emit_signal(sig, _last_direction)

func _find_nearest() -> CDEntity:
	for group in threat_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			return candidate
	return null

func _apply_noise(pos: Vector2) -> Vector2:
	if targeting_noise <= 0.0:
		return pos
	return pos + Vector2(
		randf_range(-targeting_noise, targeting_noise),
		randf_range(-targeting_noise, targeting_noise)
	)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_update_timer = 0.0
	_last_direction = Vector2.ZERO
