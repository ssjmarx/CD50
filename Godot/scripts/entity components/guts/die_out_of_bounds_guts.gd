## destroys entity if it leaves the game bounds
class_name DieOutOfBoundsGuts extends CDEntityComponent

@export var margin: float = 16.0       # extra pixels beyond game bounds
@export var activation_delay: float = 3.0  # prevents dying on spawn

var _delay_remaining: float = 0.0
var _active: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	_delay_remaining = activation_delay
	_active = true

func _physics_process(delta: float) -> void:
	if not _active:
		return
	
	if _delay_remaining > 0.0:
		_delay_remaining -= delta
		return
	
	if not game or not game.game_bounds.has_area():
		return
	
	var pos = entity.global_position
	var bounds = game.game_bounds
	if pos.x < bounds.position.x - margin or pos.x > bounds.end.x + margin:
		entity.deactivate()
		_active = false
	elif pos.y < bounds.position.y - margin or pos.y > bounds.end.y + margin:
		entity.deactivate()
		_active = false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_active = false
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_delay_remaining = activation_delay
	_active = true
	set_physics_process(true)
