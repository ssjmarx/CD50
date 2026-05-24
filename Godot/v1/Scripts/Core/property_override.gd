# Defines a single property override: targets a node path and sets a named property to a value.
# Used by scene instancing to customize individual instances without modifying the base scene.

class_name PropertyOverride extends Resource

# Target and value
@export var node_path: NodePath
@export var property_name: String
@export var value: Variant
