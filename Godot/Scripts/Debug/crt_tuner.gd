# CRT Tuner — visual test scene for dialing in CRT shader parameters.
# Displays color bars, gradient, grid, corner markers, and scattered game bodies.
# Select CRTController in the scene tree to adjust all parameters live from the inspector.

extends Node2D

const VIEWPORT_W: float = 640.0
const VIEWPORT_H: float = 360.0
const GRID_SPACING: float = 40.0

# Body scenes to scatter (diverse mix of shapes)
const BODY_SCENES: Array[String] = [
	"res://Scenes/Bodies/generic/asteroid.tscn",
	"res://Scenes/Bodies/generic/ball.tscn",
	"res://Scenes/Bodies/generic/brick.tscn",
	"res://Scenes/Bodies/generic/paddle.tscn",
	"res://Scenes/Bodies/generic/triangle_ship.tscn",
	"res://Scenes/Bodies/generic/bullet_simple.tscn",
	"res://Scenes/Bodies/generic/invader.tscn",
	"res://Scenes/Bodies/generic/barrier.tscn",
	"res://Scenes/Bodies/generic/ufo.tscn",
	"res://Scenes/Bodies/generic/tetromino.tscn",
	"res://Scenes/Bodies/generic/brick_damaging.tscn",
	"res://Scenes/Bodies/generic/mystery_ship.tscn",
	"res://Scenes/Bodies/player/player_paddle.tscn",
	"res://Scenes/Bodies/player/player_triangle_ship.tscn",
]

# Color bar palette (classic CRT test pattern colors)
const BAR_COLORS: Array[Color] = [
	Color.WHITE, Color.YELLOW, Color.CYAN, Color.GREEN,
	Color.MAGENTA, Color.RED, Color.BLUE, Color.BLACK,
]

# How many bodies to place
@export_range(10, 60) var body_count: int = 20

# Seed for reproducible layout (change to get a different arrangement)
@export var layout_seed: int = 42

# CRT controller reference
var _crt_controller: Node2D = null
var _raster_layer: Node2D = null
var _status_label: Label = null

func _ready() -> void:
	# Build test pattern
	_raster_layer = Node2D.new()
	_raster_layer.name = "TestPattern"
	add_child(_raster_layer)
	_draw_color_bars()
	_draw_center_gradient()
	_draw_grid(_raster_layer, Color(1.0, 1.0, 1.0, 0.15))
	_draw_corner_circles()
	_scatter_bodies()
	
	# CRT controller last (renders on top)
	_attach_crt()
	_add_status_label()

func _process(_delta: float) -> void:
	pass

# --- Test pattern ---

func _draw_color_bars() -> void:
	var bar_w: float = VIEWPORT_W / BAR_COLORS.size()
	var bar_h: float = VIEWPORT_H * 0.15
	for i in BAR_COLORS.size():
		var rect := ColorRect.new()
		rect.color = BAR_COLORS[i]
		rect.position = Vector2(i * bar_w, 0)
		rect.size = Vector2(bar_w, bar_h)
		rect.z_index = -100
		_raster_layer.add_child(rect)
	for i in BAR_COLORS.size():
		var rect := ColorRect.new()
		rect.color = BAR_COLORS[i]
		rect.position = Vector2(i * bar_w, VIEWPORT_H - bar_h)
		rect.size = Vector2(bar_w, bar_h)
		rect.z_index = -100
		_raster_layer.add_child(rect)

func _draw_center_gradient() -> void:
	var steps := 16
	var step_w: float = VIEWPORT_W / steps
	var y_start: float = VIEWPORT_H * 0.15
	var h: float = VIEWPORT_H * 0.7
	for i in steps:
		var val: float = float(i) / float(steps - 1)
		var rect := ColorRect.new()
		rect.color = Color(val, val, val)
		rect.position = Vector2(i * step_w, y_start)
		rect.size = Vector2(step_w + 1, h)
		rect.z_index = -98
		_raster_layer.add_child(rect)

func _draw_corner_circles() -> void:
	var corners: Array[Vector2] = [
		Vector2(30, 30),
		Vector2(VIEWPORT_W - 30, 30),
		Vector2(30, VIEWPORT_H - 30),
		Vector2(VIEWPORT_W - 30, VIEWPORT_H - 30),
	]
	for pos in corners:
		var circle := ColorRect.new()
		circle.color = Color.WHITE
		circle.position = pos - Vector2(8, 8)
		circle.size = Vector2(16, 16)
		circle.z_index = -96
		_raster_layer.add_child(circle)

func _scatter_bodies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var margin := 60.0
	
	for i in body_count:
		var scene_path: String = BODY_SCENES[i % BODY_SCENES.size()]
		var scene: PackedScene = load(scene_path)
		if not scene:
			continue
		var instance := scene.instantiate()
		instance.position = Vector2(
			rng.randf_range(margin, VIEWPORT_W - margin),
			rng.randf_range(margin, VIEWPORT_H - margin)
		)
		instance.rotation = rng.randf_range(0, TAU)
		var s := rng.randf_range(0.5, 1.5)
		instance.scale = Vector2(s, s)
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		_raster_layer.add_child(instance)
		_disable_collisions_recursive(instance)

# --- Shared ---

func _draw_grid(parent: Node2D, grid_color: Color) -> void:
	for x in range(0, int(VIEWPORT_W) + 1, int(GRID_SPACING)):
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = grid_color
		line.add_point(Vector2(x, 0))
		line.add_point(Vector2(x, VIEWPORT_H))
		line.z_index = -97
		parent.add_child(line)
	for y in range(0, int(VIEWPORT_H) + 1, int(GRID_SPACING)):
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = grid_color
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(VIEWPORT_W, y))
		line.z_index = -97
		parent.add_child(line)

func _attach_crt() -> void:
	_crt_controller = Node2D.new()
	_crt_controller.name = "CRTController"
	_crt_controller.set_script(load("res://Scripts/Flow/crt_controller.gd"))
	add_child(_crt_controller)

func _add_status_label() -> void:
	_status_label = Label.new()
	_status_label.position = Vector2(8, VIEWPORT_H - 20)
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.z_index = 999
	add_child(_status_label)
	_status_label.text = "CRT TUNER — select CRTController to adjust parameters"

func _disable_collisions_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = true
		elif child is CollisionPolygon2D:
			child.disabled = true
		_disable_collisions_recursive(child)