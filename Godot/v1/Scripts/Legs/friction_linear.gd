# Linear friction that increases with velocity. Proportional resistance up to max_friction.

extends UniversalComponent

# Friction configuration
@export var top_speed: int = 400
@export var max_friction: int = 400


# Set high process priority to run after other movement components
func _ready() -> void:
	process_priority = 50
	process_physics_priority = 50

# Apply friction proportional to current velocity
func _physics_process(delta: float):
	if top_speed > 0:
		var resistance = max_friction * (parent.velocity / top_speed)
		parent.velocity -= resistance * delta
