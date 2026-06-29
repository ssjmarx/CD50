## kbm_guts.gd
## Produces: steer signal; writes steer_direction_key (entity blackboard).
## Consumes: move/move_to signals (keyboard Vector2, mouse target Vector2).

class_name KBMGuts extends CDEntityComponent

## --- exports ---

## signals providing keyboard direction (Vector2)
@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]
## signals providing mouse target position (Vector2)
@export var move_to_signals: Array[StringName] = [&"move_to"]

## unified steering direction output (Vector2)
@export_group("Emit Signals")
@export var steer_signals: Array[StringName] = [&"steer"]

@export_group("Blackboard Keys")
@export var steer_direction_key: StringName = &"steer_direction"

## --- state ---

## last keyboard direction received
var _kb_direction: Vector2 = Vector2.ZERO
## last mouse target position received
var _mouse_target: Vector2 = Vector2.ZERO

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Connect move/move_to listeners and ensure the steer signal exists on the entity.
func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)
	for sig in move_to_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move_to)
	for sig in steer_signals:
		entity.ensure_signal(sig)

## --- signal handlers ---

## Cache the latest keyboard direction vector.
func _on_move(direction: Vector2) -> void:
	_kb_direction = direction

## Cache the latest mouse target position.
func _on_move_to(target: Vector2) -> void:
	_mouse_target = target

## --- processing ---

## Emit steer using the held keyboard direction, otherwise aim toward the mouse target.
func _physics_process(_delta: float) -> void:
	## keyboard takes priority
	if _kb_direction != Vector2.ZERO:
		entity.blackboard[steer_direction_key] = _kb_direction
		for sig in steer_signals:
			entity.bus_emit(sig)
		return
	
	## only aim if mouse is within the viewport
	var vp := get_viewport()
	var mouse_pos := vp.get_mouse_position()
	if not vp.get_visible_rect().has_point(mouse_pos):
		return
	
	var direction := entity.global_position.direction_to(_mouse_target)
	entity.blackboard[steer_direction_key] = direction
	for sig in steer_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## Disconnect move/move_to listeners on deactivation for pool reuse.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in move_signals:
		if entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
	for sig in move_to_signals:
		if entity.is_connected(sig, _on_move_to):
			entity.disconnect(sig, _on_move_to)
