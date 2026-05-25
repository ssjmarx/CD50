## AI that emits aim direction towards the nearest thing in target groups
class_name AIAimAtNearestBrain extends CDEntityComponent

@export var target_groups: Array[StringName] = [&"enemies"]
@export var update_interval: float = 0.0
@export var targeting_noise: float = 0.0

@export_group("Emit Signals")
@export var aim_signals: Array[StringName] = [&"aim"]

var _update_timer: float = 0.0
var _last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in aim_signals:
		entity.ensure_signal(sig)

func _physics_process(delta: float) -> void:
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			for sig in aim_signals:
				entity.emit_signal(sig, _last_direction)
			return
		_update_timer = 0.0
	
	for group in target_groups:
		var target := game.group_registry.get_nearest(group, entity.global_position)
		if target:
			var target_pos := _apply_noise(target.global_position)
			_last_direction = entity.global_position.direction_to(target_pos)
			for sig in aim_signals:
				entity.emit_signal(sig, _last_direction)
			return

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
