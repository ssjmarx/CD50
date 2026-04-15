# Marks non-UniversalBody nodes for CollisionMatrix auto-configuration.

class_name CollisionMarker extends Node

@export var collision_groups: Array[String] = [] # Collision group identifiers (first is primary)
