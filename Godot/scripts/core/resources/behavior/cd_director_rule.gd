# CDDirectorRule
# One entity swap rule for StageDirector
# When trigger signals fire, selected entities are swapped to a new scene

class_name CDDirectorRule extends Resource

# game bus signals that activate this rule
@export var trigger_signals: Array[StringName] = []

# which group to select entities from
@export var target_group: StringName = &""

# how to pick entities from the group (CDSelectAll, CDSelectN, etc.)
@export var selector: CDSelector = null

# scene to replace selected entities with
@export var swap_scene: PackedScene = null

# whether to deactivate the original entity after swapping
@export var deactivate_original: bool = true