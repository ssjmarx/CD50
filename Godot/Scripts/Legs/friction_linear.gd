# Linear friction that increases with velocity. Proportional resistance up to max_friction.

extends Node

@export var top_speed: int = 400 # Speed at which max_friction is reached
@export var max_friction: int = 400 # Maximum deceleration (pixels per second squared)

@onready var parent = get_parent() # Reference to attached body

# Set high process priority to run after other movement components
func _ready() -> void:
	process_priority = 50
	process_physics_priority = 50

# Apply friction proportional to current velocity
func _physics_process(delta):
	if top_speed > 0:
		var resistance = max_friction * (parent.velocity / top_speed)
		parent.velocity -= resistance * delta
