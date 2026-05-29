## active-frames arm that captures entities in a tractor beam zone.
class_name TractorBeamArm extends CDEntityComponent

@export var windup_frames: int = 30
@export var hold_frames: int = 15

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"fire_tractor_beam"]
@export var zone_entered_signals: Array[StringName] = [&"start_shooting"]
@export var zone_exited_signals: Array[StringName] = [&"stop_shooting"]

@export_group("Emit Signals")
@export var windup_signals: Array[StringName] = [&"tractor_beam_windup"]
@export var capture_signals: Array[StringName] = [&"player_captured"]
@export var miss_signals: Array[StringName] = [&"capture_missed"]
@export var complete_signals: Array[StringName] = [&"tractor_beam_complete"]

var _is_active: bool = false
var _frame_count: int = 0
var _targets_in_zone: Array[Node2D] = []
var _capture_attempted: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in windup_signals:
		entity.ensure_signal(sig)
	for sig in capture_signals:
		entity.ensure_signal(sig)
	for sig in miss_signals:
		entity.ensure_signal(sig)
	for sig in complete_signals:
		entity.ensure_signal(sig)
	for sig in fire_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_fire)
	for sig in zone_entered_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_zone_entered)
	for sig in zone_exited_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_zone_exited)

func _on_fire() -> void:
	if _is_active:
		return
	_is_active = true
	_frame_count = 0
	_capture_attempted = false
	_targets_in_zone.clear()
	set_physics_process(true)
	for sig in windup_signals:
		entity.emit_signal(sig)

func _physics_process(_delta: float) -> void:
	if not _is_active:
		set_physics_process(false)
		return

	_frame_count += 1

	if _frame_count == windup_frames and not _capture_attempted:
		_capture_attempted = true
		var target := _find_closest_target()
		if target:
			for sig in capture_signals:
				game.bus_emit(sig, [target, entity])
		else:
			for sig in miss_signals:
				entity.emit_signal(sig)

	if _frame_count >= windup_frames + hold_frames:
		_end_tractor_beam()

func _end_tractor_beam() -> void:
	_is_active = false
	_targets_in_zone.clear()
	set_physics_process(false)
	for sig in complete_signals:
		entity.emit_signal(sig)

func _find_closest_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist_sq: float = INF
	for target: Node2D in _targets_in_zone:
		if not is_instance_valid(target):
			continue
		var dist_sq := entity.global_position.distance_squared_to(target.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = target
	return closest

func _on_zone_entered(body: Node2D) -> void:
	if body == entity:
		return
	if not _targets_in_zone.has(body):
		_targets_in_zone.append(body)

func _on_zone_exited(body: Node2D) -> void:
	_targets_in_zone.erase(body)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_active = false
	_targets_in_zone.clear()
	for sig in fire_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_fire):
			entity.disconnect(sig, _on_fire)
	for sig in zone_entered_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_zone_entered):
			entity.disconnect(sig, _on_zone_entered)
	for sig in zone_exited_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_zone_exited):
			entity.disconnect(sig, _on_zone_exited)
