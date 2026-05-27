@tool

## draws polylines from CDShape resources
class_name VectorFace extends CDEntityComponent

### setters for editor adjustment

@export var shapes: Array[CDShape] = []:
	set(v):
		shapes = v
		queue_redraw()

@export var default_frame: int = 0:
	set(v):
		default_frame = v
		queue_redraw()

@export var bindings: Array[CDFaceBinding] = []

@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()

@export var width: float = 1.0:
	set(v):
		width = v
		queue_redraw()

var _current_points: PackedVector2Array = PackedVector2Array()
var _current_closed: bool = true
var _restore_timer: SceneTreeTimer

func _on_initialize() -> void:
	for binding in bindings:
		entity.connect(binding.signal_name, _on_binding_signal.bind(binding))
	
	entity.connect("shape_changed", _on_shape_changed)
	
	if not shapes.is_empty() and default_frame >= 0 and default_frame < shapes.size():
		_current_points = shapes[default_frame].points
		_current_closed = shapes[default_frame].closed
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _on_binding_signal(_arg1 = null, _arg2 = null, binding: CDFaceBinding = null) -> void:
	if binding == null:
		return
	if binding.frame_index >= 0 and binding.frame_index < shapes.size():
		_current_points = shapes[binding.frame_index].points
		_current_closed = shapes[binding.frame_index].closed
		queue_redraw()
	
	if binding.restore_after > 0.0:
		if _restore_timer != null and _restore_timer.time_left > 0.0:
			_restore_timer.timeout.disconnect(_on_restore)
		_restore_timer = get_tree().create_timer(binding.restore_after)
		_restore_timer.timeout.connect(_on_restore)

func _on_shape_changed(points: PackedVector2Array) -> void:
	_current_points = points
	_current_closed = true
	queue_redraw()

func _on_restore() -> void:
	if not shapes.is_empty() and default_frame >= 0 and default_frame < shapes.size():
		_current_points = shapes[default_frame].points
		_current_closed = shapes[default_frame].closed
	queue_redraw()

func _draw() -> void:
	if _current_points.size() < 2:
		return
	
	if _current_closed:
		# close the loop by appending first point
		var closed_points := PackedVector2Array(_current_points)
		closed_points.append(_current_points[0])
		draw_polyline(closed_points, color, width, true)
	else:
		draw_polyline(_current_points, color, width, true)
