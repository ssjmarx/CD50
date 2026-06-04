## CDSpawnContext
## Configuration for spawned entities when they enter the tree
## Applied by CDUtilities.apply_spawn_context() before entity enters tree

class_name CDSpawnContext extends Resource

## initial velocity (direction + speed)
@export var velocity: Vector2 = Vector2.ZERO

## if true, randomize velocity direction within angle range (preserves speed)
@export var use_random_angle: bool = false

## min angle for random direction (radians)
@export var random_angle_min: float = 0.0

## max angle for random direction (radians)
@export var random_angle_max: float = TAU

## randomly flip horizontal velocity component (50/50 chance)
@export var random_flip_h: bool = false

## randomly flip vertical velocity component (50/50 chance)
@export var random_flip_v: bool = false

## initial rotation in radians
@export var rotation: float = 0.0

## extra groups to add the entity to beyond its scene-defined groups
@export var additional_groups: Array[StringName] = []
