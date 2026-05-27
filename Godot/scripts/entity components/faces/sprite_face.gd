@tool

## draws a single Texture2D, swaps texture based on signal-to-frame bindings
class_name SpriteFace extends CDEntityComponent

### setters for visual editing

@export var frames: Array[Texture2D] = []:
	set(v):
		frames = v
		queue_redraw()

@export var default_frame: int = 0:
	set(v):
		default_frame = v
		queue_redraw()

@export var bindings: Array[CDFaceBinding] = []

var _sprite: Sprite2D
var _restore_timer: SceneTreeTimer

func _on_initialize() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	
	for binding in bindings:
		entity.connect(binding.signal_name, _on_binding_signal.bind(binding))
	
	_show_frame(default_frame)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _on_binding_signal(_arg1 = null, _arg2 = null, binding: CDFaceBinding = null) -> void:
	if binding == null:
		return
	_show_frame(binding.frame_index)
	
	if binding.restore_after > 0.0:
		if _restore_timer != null and _restore_timer.time_left > 0.0:
			_restore_timer.timeout.disconnect(_on_restore)
		_restore_timer = get_tree().create_timer(binding.restore_after)
		_restore_timer.timeout.connect(_on_restore)

func _on_restore() -> void:
	_show_frame(default_frame)

func _show_frame(index: int) -> void:
	if index >= 0 and index < frames.size():
		_sprite.texture = frames[index]
