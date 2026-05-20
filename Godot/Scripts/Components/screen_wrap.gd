# Space Rocks-style screen wrapping. Warps parent to opposite side when off-playfield.

extends UniversalComponent

@export var margin: int = 8 # Extra space off-screen before wrapping
@export var wrap_x: bool = true
@export var wrap_y: bool = true

# Playfield dimensions (from game.playfield_size, fallback to viewport)
var playfield: Vector2

# Initialize playfield from game playfield_size, fallback to viewport
func _ready() -> void:
	if game and "playfield_size" in game:
		playfield = game.playfield_size
	else:
		playfield = get_viewport().get_visible_rect().size

func _physics_process(_delta: float) -> void:
	if wrap_x:
		# Wrap right to left
		if parent.global_position.x > playfield.x + margin:
			parent.global_position.x = 0.0 - margin
			parent.reset_physics_interpolation()

		# Wrap left to right
		if parent.global_position.x < 0.0 - margin:
			parent.global_position.x = playfield.x
			parent.reset_physics_interpolation()

	if wrap_y:
		# Wrap bottom to top
		if parent.global_position.y > playfield.y + margin:
			parent.global_position.y = 0.0
			parent.reset_physics_interpolation()

		# Wrap top to bottom
		if parent.global_position.y < 0.0 - margin:
			parent.global_position.y = playfield.y
			parent.reset_physics_interpolation()
