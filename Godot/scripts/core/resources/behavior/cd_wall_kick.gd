## CDWallKick
## Tetris-style wall kick offset table
## Defines kick positions to try when a rotation is blocked by collision

class_name CDWallKick extends Resource

## 8 kick arrays indexed by rotation transition
## each inner array is Array[Vector2i] of offsets tried in order
@export var kicks: Array[Array] = [
	[], [], [], [], [], [], []
]

## --- Query ---

## get kick offsets for a rotation transition (from_state, to_state)
func get_kicks(from: int, to: int) -> Array[Vector2i]:
	var index := _kick_index(from, to)
	if index < 0 or index >= kicks.size():
		return []
	return kicks[index]

## --- Internal ---

## map rotation state pair to kick table index
## states: 0=spawn, 1=right, 2=180°, 3=left
func _kick_index(from: int, to: int) -> int:
	match [from, to]:
		[0, 1]: return 0   # 0→R
		[1, 0]: return 1   # R→0
		[1, 2]: return 2   # R→2
		[2, 1]: return 3   # 2→R
		[2, 3]: return 4   # 2→L
		[3, 2]: return 5   # L→2
		[3, 0]: return 6   # L→0
		[0, 3]: return 7   # 0→L
	return -1
