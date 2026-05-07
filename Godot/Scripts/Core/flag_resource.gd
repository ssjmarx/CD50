# Defines a flag pattern as a character grid with a color palette.
# Each row is a string of single-character keys that map to colors.

class_name FlagResource extends Resource

@export var flag_name: String = ""
@export var columns: int = 11
@export var palette_keys: String = ""
@export var palette_colors: Array = []
@export var rows: PackedStringArray = PackedStringArray()


func get_color(row: int, col: int) -> Color:
	if row >= rows.size():
		return Color.WHITE
	var r: String = rows[row]
	if col >= r.length():
		return Color.WHITE
	var key: String = r[col]
	var idx: int = palette_keys.find(key)
	if idx < 0 or idx >= palette_colors.size():
		return Color.WHITE
	return palette_colors[idx]


func get_row_count() -> int:
	return rows.size()