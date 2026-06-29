## cd_collision_group.gd
## Produces: a collision-group mapping (group name → groups it collides with).
## Consumes: nothing — pure data resource collected by CDCollisionMatrix.
class_name CDCollisionGroup extends Resource

## name of the entity group (maps to a collision layer)
@export var group_name: StringName

## list of groups this one should physically interact with
@export var collides_with: Array[StringName]
