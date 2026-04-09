# Pong-style acceleration.  Takes an object with static velocity and ramps it up through eight velocity levels.

extends Node

signal speed_changed(speed_level)

@export var acceleration_factor: float = 1.2
@export var acceleration_levels: int = 8

var current_acceleration_level: int = 1

@onready var parent = get_parent()

func accelerate() -> void:
	if current_acceleration_level < acceleration_levels:
		parent.velocity = parent.velocity * acceleration_factor
		current_acceleration_level += 1
		
	emit_signal("speed_changed", current_acceleration_level)

func reset() -> void:
	current_acceleration_level = 1
	emit_signal("speed_changed", current_acceleration_level)
