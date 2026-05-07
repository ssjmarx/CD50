# CRT Tuner — visual test scene for dialing in CRT shader parameters.
# Two test modes: RASTER (color bars + bodies) and VECTOR (line art on black).
# Press V to toggle vector mode, R to toggle raster mode.
# Select CRTController in the scene tree to adjust all parameters live from the inspector.

extends Node2D

const VIEWPORT_W: float = 640.0
const VIEWPORT_H: float = 360.0
const GRID_SPACING: float = 40.0
const VECTOR_GREEN := Color(0.2, 1.0, 0.2)  # Classic phosphor green
const VECTOR_CYAN := Color(0.0, 0.9, 1.0)

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
var _material: ShaderMaterial = null
var _raster_layer: Node2D = null
var _vector_layer: Node2D = null
var _vector_angle: float = 0.0
var _status_label: Label = null

func _ready() -> void:
	# Build raster test pattern
	_raster_layer = Node2D.new()
	_raster_layer.name = "RasterTest"
	add_child(_raster_layer)
	_draw_color_bars()
	_draw_center_gradient()
	_draw_grid(_raster_layer, Color(1.0, 1.0, 1.0, 0.15))
	_draw_corner_circles()
	_scatter_bodies()
	
	# Build vector test pattern
	_vector_layer = Node2D.new()
	_vector_layer.name = "VectorTest"
	_vector_layer.visible = false
	add_child(_vector_layer)
	_draw_vector_test()
	
	# CRT controller last (renders on top)
	_attach_crt()
	_add_status_label()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.keycode == KEY_V):
		_switch_to_vector()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.keycode == KEY_R):
		_switch_to_raster()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Animate vector shapes
	if _vector_layer.visible:
		_vector_angle += delta * 0.5
		_animate_vector_shapes()

func _switch_to_vector() -> void:
	_raster_layer.visible = false
	_vector_layer.visible = true
	if _crt_controller:
		_crt_controller.set_vector_mode(true)
	_update_status_label()

func _switch_to_raster() -> void:
	_raster_layer.visible = true
	_vector_layer.visible = false
	if _crt_controller:
		_crt_controller.set_vector_mode(false)
	_update_status_label()

func _update_status_label() -> void:
	if _status_label:
		var mode := "VECTOR" if _vector_layer.visible else "RASTER"
		_status_label.text = "CRT TUNER [%s] — V=vector  R=raster | select CRTController to adjust" % mode

# --- Raster test pattern ---

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

# --- Vector test pattern ---

func _draw_vector_test() -> void:
	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	bg.z_index = -100
	_vector_layer.add_child(bg)
	
	# Grid (bright green, thin)
	_draw_grid(_vector_layer, Color(0.2, 1.0, 0.2, 0.12))
	
	# Starburst from center
	_draw_starburst()
	
	# Concentric circles
	_draw_concentric_circles()
	
	# Wireframe ship (Space Rocks-style)
	_draw_ship(Vector2(VIEWPORT_W * 0.25, VIEWPORT_H * 0.5), 40.0, VECTOR_GREEN)
	_draw_ship(Vector2(VIEWPORT_W * 0.75, VIEWPORT_H * 0.35), 30.0, VECTOR_CYAN)
	
	# Asteroid shapes
	_draw_asteroid(Vector2(VIEWPORT_W * 0.55, VIEWPORT_H * 0.6), 35.0, VECTOR_GREEN)
	_draw_asteroid(Vector2(VIEWPORT_W * 0.35, VIEWPORT_H * 0.3), 25.0, VECTOR_GREEN)
	_draw_asteroid(Vector2(VIEWPORT_W * 0.8, VIEWPORT_H * 0.7), 20.0, VECTOR_CYAN)
	
	# Diagonal cross lines (screen corners)
	_draw_corner_cross()
	
	# Center crosshair
	_draw_crosshair()
	
	# Text labels
	_draw_vector_labels()

func _draw_starburst() -> void:
	var cx := VIEWPORT_W / 2.0
	var cy := VIEWPORT_H / 2.0
	var rays := 24
	var max_r := 160.0
	for i in rays:
		var angle := (float(i) / float(rays)) * TAU
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = VECTOR_GREEN
		line.add_point(Vector2(cx, cy))
		var r := max_r if i % 2 == 0 else max_r * 0.5
		line.add_point(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
		line.z_index = -90
		_vector_layer.add_child(line)

func _draw_concentric_circles() -> void:
	var cx := VIEWPORT_W / 2.0
	var cy := VIEWPORT_H / 2.0
	for radius in [40.0, 80.0, 120.0, 160.0]:
		var segments := 48
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = VECTOR_GREEN
		for j in segments + 1:
			var angle := (float(j) / float(segments)) * TAU
			line.add_point(Vector2(cx + cos(angle) * radius, cy + sin(angle) * radius))
		line.z_index = -89
		_vector_layer.add_child(line)

func _draw_ship(pos: Vector2, size: float, color: Color) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	# Triangle ship pointing up
	line.add_point(pos + Vector2(0, -size))
	line.add_point(pos + Vector2(-size * 0.7, size * 0.6))
	line.add_point(pos + Vector2(0, size * 0.3))
	line.add_point(pos + Vector2(size * 0.7, size * 0.6))
	line.add_point(pos + Vector2(0, -size))
	line.z_index = -88
	_vector_layer.add_child(line)

func _draw_asteroid(pos: Vector2, size: float, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 100 + pos.y)
	var points := 8
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = color
	for j in points + 1:
		var angle := (float(j) / float(points)) * TAU
		var r := size * rng.randf_range(0.7, 1.0)
		line.add_point(pos + Vector2(cos(angle) * r, sin(angle) * r))
	line.z_index = -88
	_vector_layer.add_child(line)

func _draw_corner_cross() -> void:
	var color := Color(0.2, 1.0, 0.2, 0.5)
	# Top-left to bottom-right
	var line1 := Line2D.new()
	line1.width = 1.0
	line1.default_color = color
	line1.add_point(Vector2(0, 0))
	line1.add_point(Vector2(VIEWPORT_W, VIEWPORT_H))
	line1.z_index = -87
	_vector_layer.add_child(line1)
	# Top-right to bottom-left
	var line2 := Line2D.new()
	line2.width = 1.0
	line2.default_color = color
	line2.add_point(Vector2(VIEWPORT_W, 0))
	line2.add_point(Vector2(0, VIEWPORT_H))
	line2.z_index = -87
	_vector_layer.add_child(line2)

func _draw_crosshair() -> void:
	var cx := VIEWPORT_W / 2.0
	var cy := VIEWPORT_H / 2.0
	var color := VECTOR_CYAN
	var size := 12.0
	# Horizontal
	var h := Line2D.new()
	h.width = 1.5
	h.default_color = color
	h.add_point(Vector2(cx - size, cy))
	h.add_point(Vector2(cx + size, cy))
	h.z_index = -86
	_vector_layer.add_child(h)
	# Vertical
	var v := Line2D.new()
	v.width = 1.5
	v.default_color = color
	v.add_point(Vector2(cx, cy - size))
	v.add_point(Vector2(cx, cy + size))
	v.z_index = -86
	_vector_layer.add_child(v)

func _draw_vector_labels() -> void:
	var labels_data: Array[Dictionary] = [
		{"text": "VECTOR MONITOR TEST", "pos": Vector2(8, 4), "color": VECTOR_GREEN},
		{"text": "press V for vector / R for raster", "pos": Vector2(8, VIEWPORT_H - 14), "color": Color(0.2, 1.0, 0.2, 0.6)},
	]
	for data in labels_data:
		var label := Label.new()
		label.text = data.text
		label.position = data.pos
		label.add_theme_color_override("font_color", data.color)
		label.add_theme_font_size_override("font_size", 10)
		label.z_index = 999
		_vector_layer.add_child(label)

func _animate_vector_shapes() -> void:
	# Rotate the starburst slowly
	pass  # Starburst is static for now — could add rotation later

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
	_update_status_label()

func _disable_collisions_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = true
		elif child is CollisionPolygon2D:
			child.disabled = true
		_disable_collisions_recursive(child)
