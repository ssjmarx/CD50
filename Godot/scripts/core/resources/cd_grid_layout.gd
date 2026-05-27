## data-driven grid definition
class_name CDGridLayout extends Resource

@export var columns: int = 5
@export var rows: Array[CDGridRow] = []

## counts non-null cells across all rows
func get_spawn_count() -> int:
	var count := 0
	for row in rows:
		for cell in row.cells:
			if cell != null:
				count += 1
	return count

## returns the PackedScene at the given flat index or null
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

## one row of the grid
class CDGridRow extends Resource:
	@export var cells: Array[PackedScene] = []
