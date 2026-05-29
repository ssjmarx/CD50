@tool

## draws a single Texture2D, swaps texture based on signal-to-frame bindings
class_name SpriteFace extends CDEntityComponent

### setters for visual editing

@export var frames: Array[Texture2D] = []:
	set(v):
		frames = v
		_show_frame(default_frame)

@export var default_frame: int = 0:
	set(v):
		default_frame = v
		_show_frame(default_frame)

@export var bindings: Array[CDFaceBinding] = []

var _sprite: Sprite2D
var _restore_timer: SceneTreeTimer

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.VISUAL
	super._ready()
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_show_frame(default_frame)

func _on_initialize() -> void:
	for binding in bindings:
		entity.ensure_signal(binding.signal_name)
		entity.connect(binding.signal_name, _on_binding_signal.bind(binding))
	_show_frame(default_frame)

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
	if _sprite == null:
		return
	if index >= 0 and index < frames.size():
		_sprite.texture = frames[index]
