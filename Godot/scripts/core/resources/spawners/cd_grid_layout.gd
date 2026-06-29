## cd_grid_layout.gd
## Produces: a hand-crafted grid layout of PackedScene cells (null = gap), in rows.
## Consumes: nothing — pure data read by grid_trapdoor Mode A.
class_name CDGridLayout extends Resource

## grid width in cells (used for flat-index-to-row-col math)
@export var columns: int = 5

## row data, each containing cell PackedScenes (null = skip)
@export var rows: Array[CDGridRow] = []

## count non-null cells across all rows
func get_spawn_count() -> int:
	var count := 0
	for row in rows:
		for cell in row.cells:
			if cell != null:
				count += 1
	return count

## return the PackedScene at the given flat index (row-major order)
func get_cell(index: int) -> PackedScene:
	if rows.is_empty():
		return null

	@warning_ignore("integer_division")
	var row_index := index / columns
	var col_index := index % columns

	if row_index >= rows.size():
		return null

	if col_index >= rows[row_index].cells.size():
		return null

	return rows[row_index].cells[col_index]
