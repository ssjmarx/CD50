# Grid rotation leg. Snaps facing direction to discrete rotation steps based on
# movement input or action button, for grid-aligned entity orientation.

extends UniversalComponent

# Rotation configuration
@export var rotation_step: int = 90
@export var auto_face: bool = true
@export var clockwise: bool = true 
@export var on_action: bool = false

# Connect to movement or action signals based on configuration
func _ready() -> void:
	if auto_face:
		parent.move.connect(_on_move)
	if on_action:
		parent.action.connect(_on_action)

# Snap rotation to nearest step in the direction of movement
func _on_move(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var angle = direction.angle()
	parent.rotation = snappedf(angle, deg_to_rad(rotation_step))

# Rotate one step on action button press
func _on_action(button: InputEvent) -> void:
	if button.is_action("button_l"):
		var step = deg_to_rad(rotation_step)
		parent.rotation += step if clockwise else -step
