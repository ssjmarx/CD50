# Defines a single game entry in the arcade playlist.
# Contains the game scene and property overrides for arcade fast rules.

class_name ArcadeGameEntry extends Resource

@export var game_scene: PackedScene
@export var overrides: Array[PropertyOverride] = []
@export var time_limit: float = 30.0  # seconds; 0 = no limit
