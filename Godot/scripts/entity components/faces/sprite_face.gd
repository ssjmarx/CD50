@tool

## SpriteFace
## Draws a single Texture2D via a child Sprite2D node
## Swaps texture based on signal-to-frame bindings via CDFaceBinding

class_name SpriteFace extends CDEntityComponent

## --- export setters for editor live preview ---

## texture frames to swap between
@export var frames: Array[Texture2D] = []:
	set(v):
		frames = v
		_show_frame(default_frame)

## which frame to show by default and restore to after bindings
@export var default_frame: int = 0:
	set(v):
		default_frame = v
		_show_frame(default_frame)

## signal → frame bindings for animation triggers
@export var bindings: Array[CDFaceBinding] = []

## child sprite node that renders the current texture
var _sprite: Sprite2D

## timer for auto-restore after binding trigger
var _restore_timer: SceneTreeTimer

## create the child Sprite2D and show the default frame
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.VISUAL
	super._ready()
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_show_frame(default_frame)

## connect bindings and show default frame
func _on_initialize() -> void:
	for binding in bindings:
		entity.bus_connect(binding.signal_name, _on_binding_signal.bind(binding))
	_show_frame(default_frame)

## --- signal handlers ---

## switch to binding's frame, optionally schedule restore
func _on_binding_signal(binding: CDFaceBinding = null):
	if binding == null:
		return
	_show_frame(binding.frame_index)
	
	## schedule auto-restore if configured
	if binding.restore_after > 0.0:
		if _restore_timer != null and _restore_timer.time_left > 0.0:
			_restore_timer.timeout.disconnect(_on_restore)
		_restore_timer = get_tree().create_timer(binding.restore_after)
		_restore_timer.timeout.connect(_on_restore)

## restore to the default frame after a binding's timer expires
func _on_restore() -> void:
	_show_frame(default_frame)

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for binding in bindings:
		entity.bus_disconnect(binding.signal_name, _on_binding_signal.bind(binding))

## --- helpers ---

## set the sprite's texture to the frame at the given index
func _show_frame(index: int) -> void:
	if _sprite == null:
		return
	if index >= 0 and index < frames.size():
		_sprite.texture = frames[index]
