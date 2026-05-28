## periodically selects entities from target groups and makes them shoot
class_name SwarmShootingDirector extends CDGameComponent

enum ShootSelect { RANDOM, NEAREST, BOTTOM_ROW }

@export var target_groups: Array[StringName] = [&"enemies"]
@export var shoot_interval: float = 2.0
@export var random_variance: float = 1.0
@export var shoot_count: int = 1
@export var selection_mode: ShootSelect = ShootSelect.RANDOM

## for NEAREST mode — the group whose members are the "targets" to be near
@export var reference_group: StringName = &"players"
## for BOTTOM_ROW mode — how wide each column is (entities within this X range share a column)
@export var column_width: float = 20.0

var _timer: float = 0.0
var _next_interval: float = 0.0

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES

func _on_initialize() -> void:
	_reset_timer()

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_fire()
		_reset_timer()

## timer fired — gather candidates, select, emit "shoot"
func _fire() -> void:
	var candidates := _gather_candidates()
	if candidates.is_empty():
		return

	var selected := _select(candidates)

	for entity in selected:
		if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
			entity.ensure_signal("shoot")
			entity.emit_signal("shoot")

## queries all target groups and deduplicates
func _gather_candidates() -> Array[CDEntity]:
	var seen: Dictionary = {}
	var result: Array[CDEntity] = []

	for group_name in target_groups:
		var group := game.group_registry.get_group(group_name)
		for entity in group:
			if not seen.has(entity):
				seen[entity] = true
				result.append(entity)

	return result

## dispatches to mode-specific selection
func _select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	match selection_mode:
		ShootSelect.RANDOM:
			return _select_random(candidates)
		ShootSelect.NEAREST:
			return _select_nearest(candidates)
		ShootSelect.BOTTOM_ROW:
			return _select_bottom_row(candidates)
	return []

## RANDOM — pick N random entities without replacement
func _select_random(candidates: Array[CDEntity]) -> Array[CDEntity]:
	var pool := candidates.duplicate()
	var count := mini(shoot_count, pool.size())
	var result: Array[CDEntity] = []

	for i in count:
		var idx := randi() % pool.size()
		result.append(pool[idx])
		pool.remove_at(idx)

	return result

## NEAREST — pick N entities closest to nearest entity in reference_group
func _select_nearest(candidates: Array[CDEntity]) -> Array[CDEntity]:
	var ref_entities := game.group_registry.get_group(reference_group)
	if ref_entities.is_empty():
		return _select_random(candidates)  # no reference → fallback

	# find the nearest reference entity to the centroid of candidates
	var centroid := Vector2.ZERO
	for e in candidates:
		centroid += e.global_position
	centroid /= maxf(1.0, candidates.size())

	var nearest_ref: CDEntity = ref_entities[0]
	var nearest_dist := centroid.distance_squared_to(nearest_ref.global_position)
	for i in range(1, ref_entities.size()):
		var dist := centroid.distance_squared_to(ref_entities[i].global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_ref = ref_entities[i]

	var ref_pos := nearest_ref.global_position

	# sort candidates by distance to nearest reference (ascending)
	var scored: Array = []  # [{entity, dist}]
	for e in candidates:
		scored.append({entity = e, dist = e.global_position.distance_squared_to(ref_pos)})
	scored.sort_custom(func(a, b): return a.dist < b.dist)

	var count := mini(shoot_count, scored.size())
	var result: Array[CDEntity] = []
	for i in count:
		result.append(scored[i].entity)
	return result

## BOTTOM_ROW — group by X into columns, pick the entity with the highest Y in each column
## (highest Y = lowest on screen in Godot's coordinate system)
func _select_bottom_row(candidates: Array[CDEntity]) -> Array[CDEntity]:
	if candidates.is_empty():
		return []

	# find the leftmost X to use as column origin
	var min_x := candidates[0].global_position.x
	for e in candidates:
		min_x = minf(min_x, e.global_position.x)

	# group entities into columns by X proximity
	# column index = floor((entity.x - min_x) / column_width)
	var columns: Dictionary = {}  # {col_index: Array[CDEntity]}
	for e in candidates:
		var col_index: int = int(floorf((e.global_position.x - min_x) / column_width))
		if not columns.has(col_index):
			columns[col_index] = []
		columns[col_index].append(e)

	# for each column, find the entity with the highest Y (lowest on screen)
	var bottom_row: Array[CDEntity] = []
	for col_index in columns:
		var col_entities: Array = columns[col_index]
		var bottom: CDEntity = col_entities[0]
		var max_y: float = bottom.global_position.y
		for i in range(1, col_entities.size()):
			var y: float = col_entities[i].global_position.y
			if y > max_y:
				max_y = y
				bottom = col_entities[i]
		bottom_row.append(bottom)

	# if we want fewer than all columns' bottoms, pick random from bottom_row
	if shoot_count < bottom_row.size():
		var pool := bottom_row.duplicate()
		var result: Array[CDEntity] = []
		for i in shoot_count:
			var idx := randi() % pool.size()
			result.append(pool[idx])
			pool.remove_at(idx)
		return result

	return bottom_row

func _reset_timer() -> void:
	_next_interval = shoot_interval
	if random_variance > 0.0:
		_next_interval += randf_range(-random_variance, random_variance)
	_timer = maxf(0.1, _next_interval)

func reset() -> void:
	_reset_timer()
