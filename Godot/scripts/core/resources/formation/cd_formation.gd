## CDFormation
## Defines a sub-formation grid: dimensions, cell layout, preferred group, and offset
## Used by FormationDirector to manage multiple tiered formations in one scene

@tool
class_name CDFormation extends Resource

## --- exports ---

## group name for entities that should be assigned to this formation's slots
## empty = any unassigned entity can fill these slots
@export var preferred_group: StringName = &""

## grid dimensions
@export var columns: int = 10
@export var rows: int = 5

## size of each grid cell
@export var cell_size: Vector2 = Vector2(16, 16)

## spacing between cells (base spacing, scaled by breathing)
@export var cell_spacing: Vector2 = Vector2(4, 4)

## offset from the FormationDirector's center position
@export var offset: Vector2 = Vector2.ZERO

## fill direction for slot assignment priority
@export var fill_direction: Vector2 = Vector2.ZERO

## --- runtime state ---

## flat array of slot contents (null = empty, CDEntity = occupied)
var slots: Array = []

## --- lifecycle ---

## initialize the slot array
func init_slots() -> void:
	slots.clear()
	slots.resize(columns * rows)
	for i in slots.size():
		slots[i] = null

## --- slot queries ---

## calculate world position for a slot index (relative to formation center + offset)
func get_slot_position(slot_index: int, center: Vector2, breathing_scale: float = 1.0) -> Vector2:
	return center + offset + _calculate_local_position(slot_index, breathing_scale)

## calculate local position for a slot index (used for editor preview)
func get_slot_position_local(slot_index: int, breathing_scale: float = 1.0) -> Vector2:
	return offset + _calculate_local_position(slot_index, breathing_scale)

## find the best empty slot based on fill_direction priority
func find_empty_slot() -> int:
	var best_index := -1
	var best_score := INF

	for i in slots.size():
		if slots[i] != null:
			continue
		var pos := _calculate_local_position(i, 1.0)
		var score: float
		if fill_direction == Vector2.ZERO:
			score = pos.length()
		else:
			score = -pos.dot(fill_direction)
		if score < best_score:
			best_score = score
			best_index = i

	return best_index

## --- internal ---

## calculate position within the grid (no offset, no center)
func _calculate_local_position(slot_index: int, breathing_scale: float) -> Vector2:
	@warning_ignore("integer_division")
	var col := slot_index % columns
	@warning_ignore("integer_division")
	var row := slot_index / columns

	var scaled_spacing := cell_spacing * breathing_scale

	var step_x := cell_size.x + scaled_spacing.x
	var step_y := cell_size.y + scaled_spacing.y
	var grid_width := columns * step_x - scaled_spacing.x
	var grid_height := rows * step_y - scaled_spacing.y

	var x := col * step_x - grid_width * 0.5 + cell_size.x * 0.5
	var y := row * step_y - grid_height * 0.5 + cell_size.y * 0.5

	return Vector2(x, y)