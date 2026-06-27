## CDTwinklingStarsEffect
## Creates a randomized, non-scrolling star background that twinkles
## configurable size, density, shape, and twinkle speed

class_name CDTwinklingStarsEffect extends CDEffect

enum StarType { CIRCLE, FOUR_POINT, SIX_POINT }

@export var star_count: int = 100
@export var min_size: float = 1.0
@export var max_size: float = 4.0
@export var min_alpha: float = 0.2
@export var max_alpha: float = 1.0
@export var twinkle_speed: float = 2.0
@export var star_colors: Array[Color] = [Color.WHITE, Color.RED, Color.BLUE, Color.ORANGE, Color.GREEN]

## effect size defaults to game bounds, override it here
@export var effect_width: float = 0.0
@export var effect_height: float = 0.0

var _positions: Array = []
var _sizes: Array = []
var _base_colors: Array = []
var _types: Array[int] = []
var _phases: Array = []

func _ready() -> void:
	super._ready()
	
	if effect_width <= 0.0 or effect_height <= 0.0:
		var viewport_size := get_viewport_rect().size
		if effect_width <= 0.0:
			effect_width = viewport_size.x
		if effect_height <= 0.0:
			effect_height = viewport_size.y
			
	for index in star_count:
		var star_position: Vector2
		star_position.x = randf_range(0, effect_width)
		star_position.y = randf_range(0, effect_height)
		_positions.append(star_position)
		
		var size: float = randf_range(min_size, max_size)
		_sizes.append(size)
		
		var color: Color = star_colors[randi() % star_colors.size()]
		_base_colors.append(color)
		
		var type: int = randi() % 3 # CIRCLE, FOUR_POINT, or SIX_POINT
		_types.append(type)
		
		# Random phase so they don't all twinkle in sync
		var phase: float = randf() * TAU
		_phases.append(phase)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for index in star_count:
		var size: float = _sizes[index]
		var half: float = size / 2.0
		var pos: Vector2 = _positions[index]
		var type: int = _types[index]
		
		# Calculate twinkle alpha
		var phase = _phases[index]
		var t = sin(time * twinkle_speed + phase) * 0.5 + 0.5 # Range 0 to 1
		var alpha = lerpf(min_alpha, max_alpha, t)
		
		var color: Color = _base_colors[index]
		color.a = alpha
		
		match type:
			StarType.CIRCLE:
				draw_circle(pos, half, color)
			StarType.FOUR_POINT:
				_draw_star_shape(pos, half, 4, color)
			StarType.SIX_POINT:
				_draw_star_shape(pos, half, 6, color)
			_:
				draw_circle(pos, half, color)

func _draw_star_shape(center: Vector2, radius: float, points: int, color: Color) -> void:
	var pts = PackedVector2Array()
	var inner_radius = radius * 0.4
	for i in range(points * 2):
		var angle = (PI / points) * i - PI / 2
		var r = radius if i % 2 == 0 else inner_radius
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, color)
