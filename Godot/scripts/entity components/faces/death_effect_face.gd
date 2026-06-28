## DeathEffectFace
## Spawns CDEffect scenes at the entity's position when it dies
## Supports multiple effect scenes and optional position inheritance

class_name DeathEffectFace extends CDEntityComponent

## effect scenes to spawn on death
@export var effect_scenes: Array[PackedScene] = []

## copy entity's global_position to each spawned effect
@export var inherit_position: bool = true

## optional colors to override the effect's default color palette
@export var colors: Array[Color] = []

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.VISUAL
	super._ready()

## connect death signals
func _on_initialize() -> void:
	for sig in death_signals:
		self.bus_connect(sig, _on_death)

## instantiate all effect scenes at entity position
func _on_death() -> void:
	for scene in effect_scenes:
		if scene == null:
			continue
		var effect: CDEffect = scene.instantiate()
		
		# Override colors if configured on the Face component
		if not colors.is_empty():
			effect.colors = colors
			
		if inherit_position:
			effect.global_position = entity.global_position
		game.add_child(effect)

## disconnect all death signals
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		self.bus_disconnect(sig, _on_death)
