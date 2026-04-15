# Pong-style acceleration. Ramps velocity through 8 levels on paddle/ball collision.

extends Node

# Emitted when speed level changes
signal speed_changed(speed_level)

@export var acceleration_factor: float = 1.2 # Velocity multiplier per level
@export var acceleration_levels: int = 8 # Maximum speed level

var current_acceleration_level: int = 1 # Current speed level (1-8)

@onready var parent = get_parent() # Reference to attached body

# Increase speed to next level and emit signal
func accelerate() -> void:
	if current_acceleration_level < acceleration_levels:
		parent.velocity = parent.velocity * acceleration_factor
		current_acceleration_level += 1
		
		emit_signal("speed_changed", current_acceleration_level)

# Reset to level 1 and emit signal
func reset() -> void:
	current_acceleration_level = 1
	emit_signal("speed_changed", current_acceleration_level)
