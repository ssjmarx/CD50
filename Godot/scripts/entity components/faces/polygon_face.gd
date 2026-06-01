@tool

# PolygonFace
# Draws filled polygons from CDShape resources
# Supports signal-to-frame bindings via CDFaceBinding and timed restore

class_name PolygonFace extends CDEntityComponent

# --- export setters for editor live preview ---

# shape resources defining polygon frames
@export var shapes: Array[CDShape] = []:
	set(v):
		shapes = v
		_update_frame()
		queue_redraw()

# which frame to show by default and restore to after bindings
@export var default_frame: int = 0:
	set(v):
		default_frame = v
		_update_frame()
		queue_redraw()

# signal → frame bindings for animation triggers
@export var bindings: Array[CDFaceBinding] = []

# fill color for all polygons
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

@export var shape_key: StringName = &"shape_points"

# currently active polygon points
var _current_points: PackedVector2Array = PackedVector2Array()

# timer for auto-restore after binding trigger
var _restore_timer: SceneTreeTimer

# --- lifecycle ---

# connect bindings and set default frame
func _on_initialize() -> void:
	for binding in bindings:
		entity.bus_connect(binding.signal_name, _on_binding_signal.bind(binding))
	
	_update_frame()
	queue_redraw()

# redraw each frame in editor for live preview
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		var points = entity.blackboard.get(shape_key)
		if points and points != _current_points:
			_current_points = points
			queue_redraw()

# --- signal handlers ---

# switch to binding's frame, optionally schedule restore
func _on_binding_signal(binding: CDFaceBinding = null) -> void:
	if binding == null:
		return
	if binding.frame_index >= 0 and binding.frame_index < shapes.size():
		_current_points = shapes[binding.frame_index].points
		queue_redraw()
	
	# schedule auto-restore if configured
	if binding.restore_after > 0.0:
		if _restore_timer != null and _restore_timer.time_left > 0.0:
			_restore_timer.timeout.disconnect(_on_restore)
		_restore_timer = get_tree().create_timer(binding.restore_after)
		_restore_timer.timeout.connect(_on_restore)

# restore to the default frame after a binding's timer expires
func _on_restore() -> void:
	if not shapes.is_empty() and default_frame >= 0 and default_frame < shapes.size():
		_current_points = shapes[default_frame].points
	queue_redraw()

# --- drawing ---

# draw the current polygon filled with color
func _draw() -> void:
	if _current_points.size() < 3:
		return
	draw_colored_polygon(_current_points, color)

# --- helpers ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for binding in bindings:
		entity.bus_disconnect(binding.signal_name, _on_binding_signal.bind(binding))

# set _current_points from the default frame's shape
func _update_frame() -> void:
	if not shapes.is_empty() and default_frame >= 0 and default_frame < shapes.size():
		_current_points = shapes[default_frame].points
