## defines one entity swap rule for StageDirector
class_name CDDirectorRule extends Resource

@export var trigger_signals: Array[StringName] = []
@export var target_group: StringName = &""
@export var selector: CDSelector = null
@export var swap_scene: PackedScene = null
@export var deactivate_original: bool = true
