# DirectTargetLeg
# Moves at constant speed toward a world-space target position
# Sets velocity directly (no momentum), stops within arrival_distance

class_name DirectTargetLeg extends CDEntityComponent

# --- exports ---

# movement speed in pixels per second
@export var speed: float = 200.0
# distance at which the entity stops and clears the target
@export var arrival_distance: float = 5.0

# target position signals (Vector2 world position)
@export_group("Listen Signals")
@export var target_signals: Array[StringName] = [&"move_to"]

# --- state ---

# current target position
var _target: Vector2 = Vector2.ZERO
# whether a valid target has been received
var _has_target: bool = false

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# connect target listeners
func _on_initialize() -> void:
	for sig in target_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_target)

# --- signal handlers ---

# store target position
func _on_target(target: Vector2) -> void:
	_target = target
	_has_target = true

# --- processing ---

# set velocity toward target, stop when close enough
func _physics_process(_delta: float) -> void:
	if not entity or not _has_target:
		return
	
	var to_target := _target - entity.global_position
	var distance := to_target.length()
	
	# arrive at target
	if distance <= arrival_distance:
		entity.request_velocity_set(Vector2.ZERO)
		_has_target = false
		return
	
	# set velocity directly toward target
	var direction := to_target.normalized()
	entity.request_velocity_set(direction * speed)

# --- cleanup ---

# reset state and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_target = Vector2.ZERO
	_has_target = false
	for sig in target_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_target):
			entity.disconnect(sig, _on_target)
