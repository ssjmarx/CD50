# PieceSplitterArm
# Splits a Block Drop piece into individual SettledCell entities when locked
# Emits piece_settled on the game bus, then deactivates the parent entity

class_name PieceSplitterArm extends CDEntityComponent

# scene for each individual settled cell
@export var settled_cell_scene: PackedScene

# optional object pool for settled cells
@export var pool: CDObjectPool = null

# group to add each settled cell to (for row-clear detection)
@export var settled_group: StringName = &"settled"

@export_group("Listen Signals")
@export var lock_signals: Array[StringName] = [&"piece_locked"]

@export_group("Emit Signals")
@export var on_piece_settled: Array[StringName] = [&"piece_settled"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect lock signals
func _on_initialize() -> void:
	for sig in lock_signals:
		entity.connect(sig, _on_piece_locked)

# spawn a cell at each position, notify game, then deactivate self
func _on_piece_locked(cell_positions: Array) -> void:
	for cell_pos: Vector2 in cell_positions:
		_spawn_cell(cell_pos)

	# notify game that the piece has settled
	for sig in on_piece_settled:
		game.bus_emit(sig, [])

	# the piece entity is no longer needed
	entity.emit_signal("request_deactivate")

# spawn a single settled cell at the given position
func _spawn_cell(cell_position: Vector2) -> void:
	if settled_cell_scene == null:
		return

	var cell: CDEntity

	# acquire from pool or instantiate fresh
	if pool:
		cell = pool.acquire()
		if cell == null:
			return
		cell.global_position = cell_position
	else:
		cell = settled_cell_scene.instantiate()
		cell.global_position = cell_position

	# add to the settled group for row-clear detection
	cell.add_to_group(settled_group)

	# activate pooled entity or add to scene tree
	if pool:
		cell.activate()
	else:
		game.add_child(cell)

# disconnect all lock signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in lock_signals:
		if entity.is_connected(sig, _on_piece_locked):
			entity.disconnect(sig, _on_piece_locked)
