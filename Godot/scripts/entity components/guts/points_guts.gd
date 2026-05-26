## data holder for points
class_name PointsGuts extends CDEntityComponent

@export var points: int = 100

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()
