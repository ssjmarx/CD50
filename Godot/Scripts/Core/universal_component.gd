class_name UniversalComponent extends Node

@onready var parent: Node = get_parent()
@onready var game_script: UniversalGameScript = UniversalGameScript.find_ancestor(self)
