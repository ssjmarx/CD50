extends UniversalBody

enum Shape { I, O, T, S, Z, L, J }

@export var shape: Shape = Shape.T
@export var color: Color = Color.CYAN
@export var tile_size: float = 20.0

const SHAPE_OFFSETS: Dictionary = {
	Shape.I: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(2,0)],
	Shape.O: [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
	Shape.T: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1)],
	Shape.S: [Vector2i(0,0), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1)],
	Shape.Z: [Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,-1)],
	Shape.L: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(1,-1)],
	Shape.J: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,-1)],
}

var current_offsets: Array[Vector2i] = []

func _ready():
	velocity = Vector2.ZERO
	set_physics_process(false)
	current_offsets.assign(SHAPE_OFFSETS[shape])
	_build_collision()
	super._ready()

func _draw():
	for offset in current_offsets:
		var pos = Vector2(offset.x * tile_size, offset.y * tile_size)
		draw_rect(Rect2(pos - Vector2(tile_size/2, tile_size/2), Vector2(tile_size, tile_size)), color)

func update_offsets(new_offsets: Array[Vector2i]):
	current_offsets = new_offsets
	_rebuild_collision()  # optional — only needed for physics scenes
	queue_redraw()
	# Or outline style:
	# draw_rect(Rect2(pos - Vector2(tile_size/2, tile_size/2), Vector2(tile_size, tile_size)), color, false, 2.0)

func _build_collision():
	# One CollisionShape2D per tile, centered on each offset
	var offsets = SHAPE_OFFSETS[shape]
	for offset in offsets:
		var shape_node = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		shape_node.shape = rect
		shape_node.position = Vector2(offset.x * tile_size, offset.y * tile_size)
		add_child(shape_node)

func _rebuild_collision():
	# Remove existing collision shapes
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	# Create new ones at current offset positions
	for offset in current_offsets:
		var shape_node = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		shape_node.shape = rect
		shape_node.position = Vector2(offset.x * tile_size, offset.y * tile_size)
		add_child(shape_node)
