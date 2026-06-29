## cd_effect.gd
## Produces: a one-shot visual effect that auto-frees after its lifetime.
## Consumes: child particle/sprite nodes; @export lifetime and colors.
class_name CDEffect extends Node2D

## seconds before this effect auto-destructs
@export var lifetime: float = 1.0

## array of colors to use for this effect.
## if empty, defaults to [Color.WHITE]
@export var colors: Array[Color] = []

## create a one-shot timer that frees this node when it expires
func _ready() -> void:
	if lifetime > 0.0:
		var timer := get_tree().create_timer(lifetime)
		timer.timeout.connect(queue_free)

## returns a random color from the colors array, or white if empty
func get_random_color() -> Color:
	if colors.is_empty():
		return Color.WHITE
	return colors.pick_random()
