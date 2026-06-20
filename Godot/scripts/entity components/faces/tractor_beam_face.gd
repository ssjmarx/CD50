## TractorBeamFace
## Visual component that spawns and despawns the TractorConeEffect
## Listens to tractor beam signals to sync visuals with the arm.

class_name TractorBeamFace extends CDEntityComponent

## The TractorConeEffect scene to spawn. Should be configured in the inspector.
@export var effect_scene: PackedScene

@export_group("Listen Signals")
## signals that trigger the start of the vacuum effect
@export var windup_signals: Array[StringName] = [&"tractor_beam_windup"]
## signals that trigger the end of the vacuum effect
@export var miss_signals: Array[StringName] = [&"capture_missed"]
@export var complete_signals: Array[StringName] = [&"tractor_beam_complete"]

## currently active effect instance
var _active_effect: TractorConeEffect = null

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.VISUAL
	super._ready()

## connect to entity bus signals
func _on_initialize() -> void:
	for sig in windup_signals:
		self.bus_connect(sig, _on_windup)
	for sig in miss_signals:
		self.bus_connect(sig, _on_end)
	for sig in complete_signals:
		self.bus_connect(sig, _on_end)

## spawn the effect and start vacuuming
func _on_windup() -> void:
	if _active_effect or not effect_scene:
		return
		
	_active_effect = effect_scene.instantiate()
	add_child(_active_effect)
	
	if _active_effect.has_method("start_vacuum"):
		_active_effect.start_vacuum()

## stop vacuuming and destroy the effect
func _on_end() -> void:
	if not _active_effect:
		return
		
	if _active_effect.has_method("stop_vacuum"):
		_active_effect.stop_vacuum()
		
	_active_effect.queue_free()
	_active_effect = null

## disconnect signals and clean up on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	
	if _active_effect:
		_active_effect.queue_free()
		_active_effect = null
		
	for sig in windup_signals:
		self.bus_disconnect(sig, _on_windup)
	for sig in miss_signals:
		self.bus_disconnect(sig, _on_end)
	for sig in complete_signals:
		self.bus_disconnect(sig, _on_end)
