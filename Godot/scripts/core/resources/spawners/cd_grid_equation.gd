## CDGridEquation
## Math-driven grid definition with random skip support
## Used for uniform grids with optional holes (Breakout, Space Invaders)

class_name CDGridEquation extends Resource

## number of columns in the grid
@export var columns: int = 10

## number of rows in the grid
@export var rows: int = 8

## probability that any given cell is empty (0.0 = solid, 1.0 = all empty)
@export var skip_chance: float = 0.0

## guaranteed minimum number of skips per row
@export var min_skips_per_row: int = 0
