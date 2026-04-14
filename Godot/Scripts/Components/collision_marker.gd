# node that marks non-UniversalBody nodes for collision_matrix setup

class_name CollisionMarker extends Node

@export var collision_groups: Array[String] = []
@export var logical_groups: Array[String] = []

func _ready() -> void:
	for group in logical_groups:
		owner.add_to_group(group)
