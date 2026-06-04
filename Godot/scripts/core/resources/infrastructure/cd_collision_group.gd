## CDCollisionGroup
## Data resource for CDCollisionMatrix collision layer configuration
## Each entry maps a group name to the groups it can collide with

class_name CDCollisionGroup extends Resource

## name of the entity group (maps to a collision layer)
@export var group_name: StringName

## list of groups this one should physically interact with
@export var collides_with: Array[StringName]
