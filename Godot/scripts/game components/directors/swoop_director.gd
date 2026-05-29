## generates bezier entry curves for entities entering the play field.
class_name SwoopDirector extends CDGameComponent

@export var swooping_group: StringName = &"swooping"
@export var trigger_signal: StringName = &"wave_start"
@export var entry_speed: float = 200.0
@export var curve_amplitude: float = 100.0
@export var entry_point_spread: float = 50.0
@export var target_y: float = 0.0

## per-entity slot tracking curve + progress
var _slots: Dictionary = {}  # { CDEntity: { curve: Curve2D, progress: float } }

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES

func _on_initialize() -> void:
	if trigger_signal != &"":
		game.bus_connect(trigger_signal, _on_trigger)

## triggered by game bus signal (typically "wave_start" from WaveCard)
func _on_trigger(_wave_number: int = 0) -> void:
	var entities := game.group_registry.get_group(swooping_group)
	if entities.is_empty():
		return

	var count := entities.size()
	var formation_center_y := target_y if target_y > 0.0 else global_position.y

	for i in count:
		var entity: CDEntity = entities[i]
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			continue

		var start := entity.global_position
		var end := Vector2(
			global_position.x + (i - count * 0.5 + 0.5) * entry_point_spread,
			formation_center_y
		)

		var curve := _generate_swoop_curve(start, end, i)
		_slots[entity] = { curve = curve, progress = 0.0 }

## per-frame: advance curves, emit move_to, detect completions
func _physics_process(delta: float) -> void:
	var to_remove: Array[CDEntity] = []

	for entity: CDEntity in _slots:
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			to_remove.append(entity)
			continue

		var slot: Dictionary = _slots[entity]
		var curve: Curve2D = slot.curve

		# approximate progress increment based on curve length and speed
		var curve_length := curve.get_baked_length()
		if curve_length <= 0.0:
			slot.progress = 1.0
		else:
			var step := (entry_speed * delta) / curve_length
			slot.progress = minf(slot.progress + step, 1.0)

		# emit target position
		var target := curve.sample_baked(slot.progress * curve_length)
		entity.ensure_signal("move_to")
		entity.emit_signal("move_to", target)

		# detect completion
		if slot.progress >= 1.0:
			game.bus_emit("swoop_complete", [entity])
			to_remove.append(entity)

	for entity in to_remove:
		_slots.erase(entity)

## creates a 2-point Curve2D with perpendicular bezier handles.
func _generate_swoop_curve(start: Vector2, end: Vector2, index: int) -> Curve2D:
	var curve := Curve2D.new()
	var to_end := end - start
	var perp := Vector2(-to_end.y, to_end.x).normalized()
	var swoop_sign := 1.0 if index % 2 == 0 else -1.0

	curve.add_point(start, Vector2.ZERO, perp * curve_amplitude * swoop_sign)
	curve.add_point(end, -perp * curve_amplitude * swoop_sign * 0.5, Vector2.ZERO)

	return curve

func reset() -> void:
	_slots.clear()
