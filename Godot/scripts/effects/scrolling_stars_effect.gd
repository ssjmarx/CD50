## CDScrollingStarsEffect
## Creates randomized stars that scroll down
## configurable size, speed, density

class_name CDScrollingStarsEffect extends CDEffect

@export var star_count: int = 100
@export var min_speed: Vector2 = Vector2(0, 10.0)
@export var max_speed: Vector2 = Vector2(0, 50.0)
@export var min_size: float = 1.0
@export var max_size: float = 4.0
@export var star_colors: Array[Color] = [Color.WHITE, Color.RED, Color.BLUE, Color.ORANGE, Color.GREEN]

## effect size defaults to game bounds, override it here
@export var effect_width: float = 0.0
@export var effect_height: float = 0.0

var _positions: Array = []
var _speeds: Array = []
var _sizes: Array = []
var _colors: Array = []

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
		
		var speed: Vector2
		speed.x = randf_range(min_speed.x, max_speed.x)
		speed.y = randf_range(min_speed.y, max_speed.y)
		_speeds.append(speed)
		
		var size: float = randf_range(min_size, max_size)
		_sizes.append(size)
		
		var color: Color = star_colors[randi() % star_colors.size()]
		_colors.append(color)

func _process(delta: float) -> void:
	for index in star_count:
		_positions[index] += _speeds[index] * delta
		if _positions[index].y > effect_height:
			_positions[index].y = 0.0
			_positions[index].x = randf_range(0, effect_width)
		if _positions[index].x > effect_width:
			_positions[index].x = 0.0
			_positions[index].y = randf_range(0, effect_width)
	
	queue_redraw()

func _draw() -> void:
	for index in star_count:
		var size: float = _sizes[index]
		var half: float = size / 2.0
		draw_rect(Rect2(_positions[index].x - half, _positions[index].y - half, size, size), _colors[index])
