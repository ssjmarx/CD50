## picks random nearby points and meanders toward them with idles in between
class_name AIIdleWanderBrain extends CDEntityComponent

@export var wander_radius: float = 100.0
@export var idle_time: float = 2.0
@export var arrival_distance: float = 5.0

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]

var _center: Vector2
var _target: Vector2
var _idle_timer: float = 0.0
var _is_idle: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	_center = entity._spawn_position
	_pick_new_target()

func _physics_process(delta: float) -> void:
	if _is_idle:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_is_idle = false
			_pick_new_target()
		return
	
	for sig in move_signals:
		entity.emit_signal(sig, _target)
	
	if entity.global_position.distance_to(_target) < arrival_distance:
		_is_idle = true
		_idle_timer = idle_time

func _pick_new_target() -> void:
	var angle := randf() * TAU
	var distance := randf() * wander_radius
	_target = _center + Vector2(cos(angle), sin(angle)) * distance

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_idle = false
	_idle_timer = 0.0
