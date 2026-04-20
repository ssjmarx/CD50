extends UniversalComponent2D

@export var head_scene: PackedScene
@export var spawn_grid_pos: Vector2i = Vector2i(5, 0)
@export var randomizer_mode: String = "bag7"
@export var additional_components_on_head: Array[PackedScene] = []

const PIECES: Dictionary = {
	"I": {"offsets": [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(2,0)]},
	"O": {"offsets": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]},
	"T": {"offsets": [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1)]},
	"S": {"offsets": [Vector2i(0,0), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1)]},
	"Z": {"offsets": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,-1)]},
	"L": {"offsets": [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(1,-1)]},
	"J": {"offsets": [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,-1)]},
}

var _grid: Node2D
var _active_piece: Node
var _bag: Array[String] = []
var _next_piece: String = ""

signal next_piece_changed(piece_name: String)
signal piece_did_lock

func _ready() -> void:
	_grid = get_tree().get_first_node_in_group("grid")
	game.on_game_start.connect(_on_game_start)
	
	if randomizer_mode == "bag7":
		_refill_bag()
	_next_piece = _get_next_piece()
	next_piece_changed.emit(_next_piece)

func _on_game_start() -> void:
	_spawn_next()

func _spawn_next():
	var piece_name = _next_piece
	_next_piece = _get_next_piece()
	next_piece_changed.emit(_next_piece)
	
	var piece = head_scene.instantiate()
	piece.shape = _name_to_shape(piece_name)
	piece.position = _grid.grid_to_world(spawn_grid_pos.y, spawn_grid_pos.x)
	game.add_child(piece)
	_active_piece = piece
	
	for scene in additional_components_on_head:
		var comp = scene.instantiate()
		piece.add_child(comp)
	
	var formation = piece.get_node_or_null("TetrominoFormation")
	if formation:
		formation.piece_locked.connect(_on_piece_locked)

func _refill_bag() -> void:
	_bag = ["I", "O", "T", "S", "Z", "L", "J"]
	_bag.shuffle()

func _get_typed_offsets(piece_name: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(PIECES[piece_name].offsets)
	return result

func _get_next_piece() -> String:
	match randomizer_mode:
		"bag7":
			if _bag.is_empty():
				_refill_bag()
			return _bag.pop_back()
		_:
			var keys = PIECES.keys()
			return keys[randi() % keys.size()]

func _on_piece_locked() -> void:
	piece_did_lock.emit()
	_active_piece = null
	
	if _grid.is_occupied(spawn_grid_pos.y, spawn_grid_pos.x):
		game.defeat.emit()
		return
	
	var piece_data = PIECES[_next_piece]
	var typed_offsets: Array[Vector2i] = []
	typed_offsets.assign(piece_data.offsets)
	if not _can_spawn(typed_offsets):
		game.defeat.emit()
		return
	
	await get_tree().create_timer(0.1).timeout
	if game.current_state == CommonEnums.State.PLAYING:
		_spawn_next()

func _can_spawn(piece_offsets: Array[Vector2i]) -> bool:
	for offset in piece_offsets:
		var cell = spawn_grid_pos + offset
		if _grid.is_occupied(cell.y, cell.x):
			return false
	return true

func _name_to_shape(piece_name: String) -> int:
	var map = {
		"I": 0, "O": 1, "T": 2, "S": 3, "Z": 4, "L": 5, "J": 6
	}
	return map.get(piece_name, 0)
