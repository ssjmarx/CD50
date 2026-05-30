# CDGridRow
# One row of a CDGridLayout grid
# Each cell is a PackedScene (null = empty/gap)

class_name CDGridRow extends Resource

# cell entries for this row — null means skip/empty
@export var cells: Array[PackedScene] = []
