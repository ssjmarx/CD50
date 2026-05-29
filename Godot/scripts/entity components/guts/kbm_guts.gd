## merges keyboard "move" and mouse "move_to" inputs into a single "steer" signal
class_name KBMGuts extends CDEntityComponent

@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]
@export var move_to_signals: Array[StringName] = [&"move_to"]

@export_group("Emit Signals")
@export var steer_signals: Array[StringName] = [&"steer"]

var _kb_direction: Vector2 = Vector2.ZERO
var _mouse_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)
	for sig in move_to_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move_to)
	for sig in steer_signals:
		entity.ensure_signal(sig)

func _on_move(direction: Vector2) -> void:
	_kb_direction = direction

func _on_move_to(target: Vector2) -> void:
	_mouse_target = target

func _physics_process(_delta: float) -> void:
	if _kb_direction != Vector2.ZERO:
		for sig in steer_signals:
			entity.emit_signal(sig, _kb_direction)
		return
	
	var vp := get_viewport()
	var mouse_pos := vp.get_mouse_position()
	if not vp.get_visible_rect().has_point(mouse_pos):
		return
	
	var direction := entity.global_position.direction_to(_mouse_target)
	for sig in steer_signals:
		entity.emit_signal(sig, direction)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in move_signals:
		if entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
	for sig in move_to_signals:
		if entity.is_connected(sig, _on_move_to):
			entity.disconnect(sig, _on_move_to)
