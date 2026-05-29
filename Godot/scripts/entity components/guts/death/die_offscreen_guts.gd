# DieOffscreenGuts
# Destroys entity when it leaves all camera views
# Uses VisibleOnScreenNotifier2D with an activation delay to prevent spawn deaths

class_name DieOffscreenGuts extends CDEntityComponent

# --- exports ---

# node path to the VisibleOnScreenNotifier2D child
@export var notifier_path: NodePath = "VisibleOnScreenNotifier2D"
# seconds to wait before monitoring (prevents dying on spawn)
@export var activation_delay: float = 3.0

# --- state ---

# reference to the screen notifier node
var _notifier: VisibleOnScreenNotifier2D
# countdown before monitoring begins
var _delay_remaining: float = 0.0
# whether the notifier is actively monitoring
var _monitoring: bool = false

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# find notifier, connect screen_exited, begin delay countdown
func _on_initialize() -> void:
	_delay_remaining = activation_delay
	
	_notifier = get_node_or_null(notifier_path) as VisibleOnScreenNotifier2D
	if _notifier == null:
		push_error("DieOffscreenGuts: no VisibleOnScreenNotifier2D at path '%s'" % notifier_path)
		set_physics_process(false)
		return
	
	_notifier.connect("screen_exited", _on_screen_exited)
	_notifier.set_process(false)
	_monitoring = false

# --- processing ---

# count down activation delay, then enable notifier monitoring
func _physics_process(delta: float) -> void:
	if _monitoring:
		return
	
	_delay_remaining -= delta
	if _delay_remaining <= 0.0:
		_monitoring = true
		_notifier.set_process(true)
		set_physics_process(false)

# --- signal handlers ---

# deactivate entity after confirming it's still off-screen next physics frame
func _on_screen_exited() -> void:
	await get_tree().physics_frame
	if is_instance_valid(entity) and _notifier and not _notifier.is_on_screen():
		entity.deactivate()

# --- cleanup ---

# disconnect notifier and stop processing for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _notifier and _notifier.is_connected("screen_exited", _on_screen_exited):
		_notifier.disconnect("screen_exited", _on_screen_exited)
	set_physics_process(false)

# restart delay cycle on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_delay_remaining = activation_delay
	_monitoring = false
	if _notifier:
		_notifier.set_process(false)
		_notifier.connect("screen_exited", _on_screen_exited)
	set_physics_process(true)