# Paddle cannon. Chunky horizontal base with a narrow turret on top.
# Drawn in forward=+X orientation; rotate the scene node -PI/2 to face upward.
# Drawing code only — all behavior handled by attached components.

extends UniversalBody

@export var color: Color = Color.WHITE

@export var base_width: float = 20.0
@export var base_height: float = 6.0
@export var turret_width: float = 4.0
@export var turret_height: float = 8.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Override collision shape to match the base footprint
func _ready() -> void:
	super._ready()
	if collision_shape:
		collision_shape.shape.size = Vector2(base_height, base_width)

# Draw the base (wide rectangle) and turret (narrow rectangle extending forward)
func _draw() -> void:
	# Base — wide rectangle centered on origin (appears horizontal when rotated -PI/2)
	draw_rect(Rect2(-base_height / 2.0, -base_width / 2.0, base_height, base_width), color)
	# Turret — narrow rectangle extending in +X (appears pointing up when rotated -PI/2)
	draw_rect(Rect2(base_height / 2.0, -turret_width / 2.0, turret_height, turret_width), color)