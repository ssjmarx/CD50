# plays a sound on a hit

extends UniversalComponent

@export var sound: AudioStreamPlayer2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if parent.has_signal("body_entered"):
		parent.body_entered.connect(_play_sound)
	if parent.has_signal("body_collided"):
		parent.body_collided.connect(_play_sound)

func _play_sound(_arg1 = null, _arg2 = null) -> void:
	sound.play()
