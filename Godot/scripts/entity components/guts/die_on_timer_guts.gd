## destroys the entity after a set duration
class_name DieOnTimerGuts extends CDEntityComponent

@export var lifespan: float = 3.0

@export_group("Emit Signals")
@export var timer_expired_signals: Array[StringName] = [&"timer_expired"]
@export var death_signals: Array[StringName] = [&"request_deactivate"]

var _time_remaining: float = 0.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_time_remaining = lifespan

func _physics_process(delta: float) -> void:
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		for sig in timer_expired_signals:
			entity.emit_signal(sig)
		entity.deactivate()
		set_physics_process(false)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_time_remaining = lifespan
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_time_remaining = lifespan
	set_physics_process(true)
