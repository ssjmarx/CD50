class_name CDWallKick extends Resource

## 8 kick arrays: 0→R, R→0, R→2, 2→R, 2→L, L→2, L→0, 0→L
## each array is an Array[Vector2i] of kick offsets to try in order
@export var kicks: Array[Array] = [
	[], [], [], [], [], [], [], []
]

func get_kicks(from: int, to: int) -> Array[Vector2i]:
	var index := _kick_index(from, to)
	if index < 0 or index >= kicks.size():
		return []
	return kicks[index]

func _kick_index(from: int, to: int) -> int:
	# 0=spawn, 1=R, 2=180, 3=L
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
