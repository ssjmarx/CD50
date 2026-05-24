# Defines a collision group with a name and list of target groups it collides with.
# Used by CollisionMatrix to auto-configure physics layers.

class_name CollisionGroup extends Resource

# Group identity and collision targets
@export var group_name: String
@export var targets: Array[String]
