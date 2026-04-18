class_name UniversalComponent2D extends Node2D

@onready var parent: Node = get_parent()
@onready var game: UniversalGameScript = UniversalGameScript.find_ancestor(self)
