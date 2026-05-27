## configuration for spawned entities when they enter the tree
class_name CDSpawnContext extends Resource

@export var velocity: Vector2 = Vector2.ZERO
@export var use_random_angle: bool = false
@export var random_angle_min: float = 0.0
@export var random_angle_max: float = TAU
@export var random_flip_h: bool = false
@export var random_flip_v: bool = false
@export var rotation: float = 0.0
