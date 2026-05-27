## on piece_locked, spawns individual SettledCell entities
class_name PieceSplitterArm extends CDEntityComponent

@export var settled_cell_scene: PackedScene
@export var pool: CDObjectPool = null
@export var settled_group: StringName = &"settled"

@export_group("Listen Signals")
@export var lock_signals: Array[StringName] = [&"piece_locked"]

@export_group("Emit Signals")
@export var on_piece_settled: Array[StringName] = [&"piece_settled"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in lock_signals:
		entity.connect(sig, _on_piece_locked)

func _on_piece_locked(cell_positions: Array) -> void:
	for cell_pos: Vector2 in cell_positions:
		_spawn_cell(cell_pos)

	for sig in on_piece_settled:
		game.bus_emit(sig, [])

	entity.emit_signal("request_deactivate")

func _spawn_cell(cell_position: Vector2) -> void:
	if settled_cell_scene == null:
		return

	var cell: CDEntity

	if pool:
		cell = pool.acquire()
		if cell == null:
			return
		cell.global_position = cell_position
	else:
		cell = settled_cell_scene.instantiate()
		cell.global_position = cell_position

	cell.add_to_group(settled_group)

	if pool:
		cell.activate()
	else:
		game.add_child(cell)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in lock_signals:
		if entity.is_connected(sig, _on_piece_locked):
			entity.disconnect(sig, _on_piece_locked)
