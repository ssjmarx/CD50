# plays a sound on a hit

extends Node

@export var sound: AudioStreamPlayer2D

@onready var parent = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent.body_entered(_on_body_entered)

func _on_body_entered() -> void:
	sound.play()