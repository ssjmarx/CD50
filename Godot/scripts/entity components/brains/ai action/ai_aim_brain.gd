# AIAimAtNearestBrain
# Emits aim direction toward the nearest entity in target groups
# Supports update_interval for throttled targeting and targeting_noise for imprecision

class_name AIAimAtNearestBrain extends CDEntityComponent

# groups to search for aim targets
@export var target_groups: Array[StringName] = [&"enemies"]

# seconds between target recalculation (0 = every frame)
@export var update_interval: float = 0.0

# random offset added to target position for imprecision
@export var targeting_noise: float = 0.0

@export_group("Emit Signals")
@export var aim_signals: Array[StringName] = [&"aim"]

# timer for throttled updates
var _update_timer: float = 0.0

# cached direction for throttled frames
var _last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure aim signals exist on entity
func _on_initialize() -> void:
	for sig in aim_signals:
		entity.ensure_signal(sig)

# emit aim direction each frame, recalculate target on interval
func _physics_process(delta: float) -> void:
	# if throttled, emit cached direction until interval expires
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			for sig in aim_signals:
				entity.emit_signal(sig, _last_direction)
			return
		_update_timer = 0.0

	# find nearest target in any target group
	for group in target_groups:
		var target := game.group_registry.get_nearest(group, entity.global_position)
		if target:
			var target_pos := _apply_noise(target.global_position)
			_last_direction = entity.global_position.direction_to(target_pos)
			for sig in aim_signals:
				entity.emit_signal(sig, _last_direction)
			return

# add random offset to target position if noise is configured
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
