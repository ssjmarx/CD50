## cd_grid_row.gd
## Produces: one row of PackedScene cells (null = gap) for a CDGridLayout.
## Consumes: nothing — pure data authored independently and collected by CDGridLayout.
class_name CDGridRow extends Resource

## cell entries for this row — null means skip/empty
@export var cells: Array[PackedScene] = []
