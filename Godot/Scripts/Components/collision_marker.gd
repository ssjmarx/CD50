# Marks non-UniversalBody nodes for CollisionMatrix auto-configuration.
# Attach to Area2D or static nodes that need collision layer assignment.

class_name CollisionMarker extends Node

# Collision group identifiers (first entry is the primary layer)
@export var collision_groups: Array[String] = []