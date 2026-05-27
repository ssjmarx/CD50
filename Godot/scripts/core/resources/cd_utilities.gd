## pure static utility functions used across V2
class_name CDUtilities

## applies a CDSpawnContext to an entity before it enters the tree
static func apply_spawn_context(entity: CDEntity, context: CDSpawnContext) -> void:
	if context == null:
		return

	entity.velocity = context.velocity

	if context.use_random_angle:
		var speed := entity.velocity.length()
		var angle := Vector2.from_angle(randf_range(context.random_angle_min, context.random_angle_max))
		entity.velocity = angle * speed

	if context.random_flip_h:
		entity.velocity.x *= [-1, 1].pick_random()

	if context.random_flip_v:
		entity.velocity.y *= [-1, 1].pick_random()

	entity.rotation = context.rotation

## evaluates a string expression with named variables, returns result as int
static func evaluate_int(equation: String, var_names: PackedStringArray, var_values: Array, context_name: String) -> int:
	var expr := Expression.new()
	var error := expr.parse(equation, var_names)
	if error != OK:
		push_error("%s: failed to parse equation '%s': %s" % [context_name, equation, expr.get_error_text()])
		return 0
	var result = expr.execute(var_values)
	if expr.has_execute_failed():
		push_error("%s: failed to execute equation '%s': %s" % [context_name, equation, expr.get_error_text()])
		return 0
	return int(result)
