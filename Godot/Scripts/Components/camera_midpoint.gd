# Scrolling camera that tracks the midpoint between a tracked entity and the mouse position.
# UGS-level component — add as child of the game node, not the player body.
# Finds the tracked entity via a configurable group name (default "player_cameras").

extends UniversalComponent2D

# Group name used to find the entity the camera should track
@export var camera_group: String = "player_cameras"

# Smoothing speed for camera movement (higher = tighter follow)
@export var lerp_speed: float = 5.0

# Runtime
var _camera: Camera2D

# Create the Camera2D node
func _ready() -> void:
	_camera = Camera2D.new()
	_camera.name = "MidpointCamera"
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camera)

# Each frame: position camera so player and mouse are always both on screen.
# Uses screen-space mouse offset from center — no feedback loop.
func _physics_process(delta: float) -> void:
	if not _camera:
		return
	
	# Find the tracked entity
	var nodes := get_tree().get_nodes_in_group(camera_group)
	if nodes.is_empty():
		return
	
	var entity = nodes[0]
	if not is_instance_valid(entity):
		return
	
	# Mouse offset from screen center (in viewport pixels)
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var mouse_offset: Vector2 = mouse_screen - screen_center
	
	# Camera target: player position + mouse offset
	# This places the player at the mirror position of the cursor on screen
	var target: Vector2 = entity.global_position + mouse_offset
	
	# Clamp so camera never shows beyond playfield bounds
	var pf: Vector2 = game.playfield_size if game and "playfield_size" in game else Vector2(640, 360)
	var half_viewport: Vector2 = screen_center
	target.x = clampf(target.x, half_viewport.x, pf.x - half_viewport.x)
	target.y = clampf(target.y, half_viewport.y, pf.y - half_viewport.y)
	
	# Smooth follow
	_camera.global_position = _camera.global_position.lerp(target, lerp_speed * delta)
