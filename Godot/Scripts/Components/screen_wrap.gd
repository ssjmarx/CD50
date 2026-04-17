# Asteroids-style screen wrapping. Warps parent to opposite side when off-screen.

extends UniversalComponent

@export var margin: int = 8 # Extra space off-screen before wrapping

@onready var viewport_size: Vector2 = get_viewport().get_visible_rect().size # Screen dimensions

func _physics_process(_delta: float) -> void:
	# Wrap right to left
	if parent.global_position.x > viewport_size.x + margin:
		parent.global_position.x = 0.0 - margin
		parent.reset_physics_interpolation()

	# Wrap left to right
	if parent.global_position.x < 0.0 - margin:
		parent.global_position.x = viewport_size.x
		parent.reset_physics_interpolation()

	# Wrap bottom to top
	if parent.global_position.y > viewport_size.y + margin:
		parent.global_position.y = 0.0
		parent.reset_physics_interpolation()

	# Wrap top to bottom
	if parent.global_position.y < 0.0 - margin:
		parent.global_position.y = viewport_size.y
		parent.reset_physics_interpolation()
