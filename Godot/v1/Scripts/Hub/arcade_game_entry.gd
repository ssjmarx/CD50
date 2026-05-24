# Defines a single game entry in the arcade playlist.
# Contains the game scene, property overrides for arcade fast rules,
# and bucket/tag metadata for the semi-random playlist system.

class_name ArcadeGameEntry extends Resource

enum GameBucket { REMAKE, LITE_REMIX, HEAVY_REMIX_ORIGINAL }

@export var game_scene: PackedScene
@export var overrides: Array[PropertyOverride] = []
@export var time_limit: float = 30.0  # seconds; 0 = no limit
@export var bucket: GameBucket = GameBucket.REMAKE
@export var similarity_tag: String = ""  # Single tag; same tag as previous game = blocked
