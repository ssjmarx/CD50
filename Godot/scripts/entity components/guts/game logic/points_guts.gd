# PointsGuts
# Data holder for an entity's point value when destroyed
# Read by game-level scoring systems (e.g., Goals) via entity lookup

class_name PointsGuts extends CDEntityComponent

# --- exports ---

# point value awarded when this entity is destroyed
@export var points: int = 100

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()
