## vector_face.gd
## Produces: polyline rendering from CDShape resources with open/closed frame bindings.
## Consumes: CDFaceBinding signals; optional shape_points blackboard override.

@tool
class_name VectorFace extends CDEntityComponent

## --- export setters for editor live preview ---

## shape resources defining polyline frames
@export var shapes: Array[CDShape] = []:
	set(v):
		shapes = v
		_update_frame()
		queue_redraw()

## which frame to show by default and restore to after bindings
@export var default_frame: int = 0:
	set(v):
		default_frame = v
		_update_frame()
		queue_redraw()

## signal → frame bindings for animation triggers
@export var bindings: Array[CDFaceBinding] = []

## line color
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

## line thickness in pixels
@export var width: float = 1.0:
	set(v):
		width = v
		queue_redraw()

@export var shape_key: StringName = &"shape_points"

## currently active polyline points
var _current_points: PackedVector2Array = PackedVector2Array()

## whether the current shape should close its loop
var _current_closed: bool = true

## timer for auto-restore after binding trigger
var _restore_timer: SceneTreeTimer

## connect bindings and set default frame
func _on_initialize() -> void:
	for binding in bindings:
		self.bus_connect(binding.signal_name, _on_binding_signal.bind(binding))
	
	_update_frame()
	queue_redraw()

## redraw each frame in editor for live preview
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		var points = entity.blackboard.get(shape_key)
		if points and points != _current_points:
			_current_points = points
			_current_closed = true
			queue_redraw()

## switch to binding's frame, optionally schedule restore
func _on_binding_signal(binding: CDFaceBinding = null) -> void:
	if binding == null:
		return
	if binding.frame_index >= 0 and binding.frame_index < shapes.size():
		_current_points = shapes[binding.frame_index].points
		_current_closed = shapes[binding.frame_index].closed
		queue_redraw()
	
	## schedule auto-restore if configured
	if binding.restore_after > 0.0:
		if _restore_timer != null and _restore_timer.time_left > 0.0:
			_restore_timer.timeout.disconnect(_on_restore)
		_restore_timer = get_tree().create_timer(binding.restore_after)
		_restore_timer.timeout.connect(_on_restore)

## restore to the default frame after a binding's timer expires
func _on_restore() -> void:
	if not shapes.is_empty() and default_frame >= 0 and default_frame < shapes.size():
		_current_points = shapes[default_frame].points
		_current_closed = shapes[default_frame].closed
	queue_redraw()

## draw the current polyline, closing the loop if _current_closed
func _draw() -> void:
	if _current_points.size() < 2:
		return
	
	if _current_closed:
		## close the loop by appending first point
		var closed_points := PackedVector2Array(_current_points)
		closed_points.append(_current_points[0])
		draw_polyline(closed_points, color, width, true)
	else:
		draw_polyline(_current_points, color, width, true)

## Disconnect each binding signal on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for binding in bindings:
		self.bus_disconnect(binding.signal_name, _on_binding_signal.bind(binding))

## set _current_points and _current_closed from the default frame's shape
func _update_frame() -> void:
	if not shapes.is_empty() and default_frame >= 0 and default_frame < shapes.size():
		_current_points = shapes[default_frame].points
		_current_closed = shapes[default_frame].closed
