class_name UniversalComponent2D extends Node2D

@onready var parent: Node = get_parent()
@onready var game: UniversalGameScript = UniversalGameScript.find_ancestor(self)

func get_group_nodes(group_name: String) -> Array:
	return GroupCache.get_group(group_name)

func get_group_count(group_name: String) -> int:
	return GroupCache.get_count(group_name)
