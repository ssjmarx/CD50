# Plays a sound effect when the parent body is hit (via body_entered or body_collided).

extends UniversalComponent

# Sound configuration
@export var sound: AudioStreamPlayer2D

# Connect to parent's collision signal (works for both Area2D and CharacterBody2D)
func _ready() -> void:
	if parent.has_signal("body_entered"):
		parent.body_entered.connect(_play_sound)
	if parent.has_signal("body_collided"):
		parent.body_collided.connect(_play_sound)

# Play the assigned sound effect
func _play_sound(_arg1 = null, _arg2 = null) -> void:
	sound.play()
