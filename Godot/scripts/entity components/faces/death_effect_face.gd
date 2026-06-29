## death_effect_face.gd
## Produces: death burst effects (CDEffect scenes) at the entity position.
## Consumes: death_signals (entity bus); optional color/position overrides.

class_name DeathEffectFace extends CDEntityComponent

## effect scenes to spawn on death
@export var effect_scenes: Array[PackedScene] = []

## copy entity's global_position to each spawned effect
@export var inherit_position: bool = true

## optional colors to override the effect's default color palette
@export var colors: Array[Color] = []

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

## Set the visual component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.VISUAL
	super._ready()

## Connect each death signal to the spawn handler during initialization.
func _on_initialize() -> void:
	for sig in death_signals:
		self.bus_connect(sig, _on_death)

## Spawn every configured effect scene at the entity's position on death.
func _on_death() -> void:
	for scene in effect_scenes:
		if scene == null:
			continue
		var effect: CDEffect = scene.instantiate()

		if not colors.is_empty():
			effect.colors = colors
			
		if inherit_position:
			effect.global_position = entity.global_position
		game.add_child(effect)

## Disconnect all death signal handlers on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		self.bus_disconnect(sig, _on_death)
