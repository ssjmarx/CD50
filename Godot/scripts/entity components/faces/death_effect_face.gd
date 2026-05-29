## spawns CDEffect scenes at the entity's position when it dies
class_name DeathEffectFace extends CDEntityComponent

@export var effect_scenes: Array[PackedScene] = []
@export var inherit_position: bool = true

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.VISUAL
	super._ready()

func _on_initialize() -> void:
	for sig in death_signals:
		entity.connect(sig, _on_death)

func _on_death() -> void:
	for scene in effect_scenes:
		if scene == null:
			continue
		var effect: Node2D = scene.instantiate()
		if inherit_position:
			effect.global_position = entity.global_position
		game.add_child(effect)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		if entity.is_connected(sig, _on_death):
			entity.disconnect(sig, _on_death)
