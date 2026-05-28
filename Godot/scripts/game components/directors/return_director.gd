## calculates return bezier curves for entities re-entering formation.
class_name ReturnDirector extends CDGameComponent

@export var trigger_signal: StringName = &"request_return_path"
@export var return_speed: float = 150.0
@export var curve_amplitude: float = 80.0

var _slots: Dictionary = {}  # { CDEntity: { curve: Curve2D, progress: float } }

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES

func _on_initialize() -> void:
	if trigger_signal != &"":
		game.bus_connect(trigger_signal, _on_return_requested)

## synchronous game bus handler — entity needs a return path
func _on_return_requested(entity: CDEntity) -> void:
	if not is_instance_valid(entity):
		return
	if entity.state != CDEnums.EntityState.ACTIVE:
		return
	# already has a return slot? skip
	if _slots.has(entity):
		return

	var bounds := game.game_bounds

	# calculate wrap position (top of screen)
	var wrap_pos := Vector2(
		entity.global_position.x,
		bounds.position.y - 20.0
	)

	# generate return curve from wrapped position to formation center
	var end_pos := Vector2(
		global_position.x + randf_range(-30.0, 30.0),
		global_position.y
	)
	var curve := _generate_return_curve(wrap_pos, end_pos)

	# assign slot
	_slots[entity] = { curve = curve, progress = 0.0 }

	# emit wrap_to — entity's own component handles the teleport
	entity.ensure_signal("wrap_to")
	entity.emit_signal("wrap_to", wrap_pos)

## per-frame: advance curves, emit move_to, detect completions
func _physics_process(delta: float) -> void:
	var to_remove: Array[CDEntity] = []

	for entity: CDEntity in _slots:
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			to_remove.append(entity)
			continue

		var slot: Dictionary = _slots[entity]
		var curve: Curve2D = slot.curve

		var curve_length := curve.get_baked_length()
		if curve_length <= 0.0:
			slot.progress = 1.0
		else:
			var step := (return_speed * delta) / curve_length
			slot.progress = minf(slot.progress + step, 1.0)

		var target := curve.sample_baked(slot.progress * curve_length)
		entity.ensure_signal("move_to")
		entity.emit_signal("move_to", target)

		if slot.progress >= 1.0:
			entity.ensure_signal("return_complete")
			entity.emit_signal("return_complete")
			to_remove.append(entity)

	for entity in to_remove:
		_slots.erase(entity)

## bezier curve with perpendicular handles, random direction
func _generate_return_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()
	var to_end := end - start
	var perp := Vector2(-to_end.y, to_end.x).normalized()
	var swoop_sign := 1.0 if randi() % 2 == 0 else -1.0

	curve.add_point(start, Vector2.ZERO, perp * curve_amplitude * swoop_sign)
	curve.add_point(end, -perp * curve_amplitude * swoop_sign * 0.5, Vector2.ZERO)

	return curve

func reset() -> void:
	_slots.clear()
