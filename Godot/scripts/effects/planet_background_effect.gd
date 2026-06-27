## CDPlanetBackgroundEffect
## Procedurally generated planet horizon background.
## Features a dark night sky with twinkling stars, a curved blue planet surface,
## organic green continents, and bright pulsing city lights.

class_name CDPlanetBackgroundEffect extends CDEffect

@export_group("Sky")
@export var sky_color: Color = Color("030314")
@export var star_count: int = 150
@export var star_color: Color = Color.WHITE

@export_group("Planet")
@export var horizon_ratio: float = 0.65
@export var planet_color: Color = Color("0e2a5e")
@export var continent_count: int = 8
@export var continent_color: Color = Color("1a5c20")

@export_group("Cities")
@export var city_light_count: int = 50
@export var city_light_color: Color = Color("ffcc66")

var _stars: Array = []
var _continents: Array[PackedVector2Array] = []
var _city_lights: Array[Vector2] = []

var _screen_size: Vector2
var _horizon_y: float

func _ready() -> void:
	# Set lifetime to 0 so the effect persists as a background
	lifetime = 0.0
	super._ready()
	
	_screen_size = get_viewport_rect().size
	_horizon_y = _screen_size.y * horizon_ratio
	
	_generate_stars()
	_generate_continents()
	_generate_city_lights()

func _process(_delta: float) -> void:
	# Redraw every frame to animate twinkling stars and city lights
	queue_redraw()

func _generate_stars() -> void:
	for i in range(star_count):
		var pos = Vector2(
			randf_range(0, _screen_size.x),
			randf_range(0, _horizon_y)
		)
		_stars.append({
			"pos": pos,
			"base_size": randf_range(0.5, 2.5),
			"phase": randf() * TAU,
			"speed": randf_range(1.0, 4.0),
			"color": star_color
		})

func _generate_continents() -> void:
	for i in range(continent_count):
		var center = Vector2(
			randf_range(0, _screen_size.x),
			randf_range(_horizon_y, _horizon_y + 100.0)
		)
		var points = PackedVector2Array()
		var segments = 12
		var base_radius = randf_range(30.0, 80.0)
		
		for j in range(segments):
			var angle = (float(j) / segments) * TAU
			var r = base_radius * randf_range(0.6, 1.4)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		
		_continents.append(points)

func _generate_city_lights() -> void:
	for i in range(city_light_count):
		if _continents.is_empty():
			break
			
		var attempts = 0
		while attempts < 10:
			var poly = _continents[randi() % _continents.size()]
			if poly.size() < 3:
				break
				
			var min_p = poly[0]
			var max_p = poly[0]
			for p in poly:
				min_p.x = min(min_p.x, p.x)
				min_p.y = min(min_p.y, p.y)
				max_p.x = max(max_p.x, p.x)
				max_p.y = max(max_p.y, p.y)
				
			var random_point = Vector2(
				randf_range(min_p.x, max_p.x),
				randf_range(min_p.y, max_p.y)
			)
			
			if Geometry2D.is_point_in_polygon(random_point, poly):
				_city_lights.append(random_point)
				break
				
			attempts += 1

func _draw() -> void:
	# 1. Draw Sky
	draw_rect(Rect2(Vector2.ZERO, Vector2(_screen_size.x, _horizon_y)), sky_color, true)
	
	# 2. Draw Planet Arc (Massive circle to simulate curvature)
	var curve_radius = _screen_size.x * 2.0
	var planet_center = Vector2(_screen_size.x / 2.0, _horizon_y + curve_radius)
	draw_circle(planet_center, curve_radius, planet_color)
	
	# 3. Draw Continents
	for poly in _continents:
		draw_colored_polygon(poly, continent_color)
		
	# 4. Draw City Lights
	var time = Time.get_ticks_msec() / 1000.0
	for light_pos in _city_lights:
		var pulse = 0.8 + sin(time * 3.0 + light_pos.x) * 0.2
		draw_circle(light_pos, 1.5 * pulse, city_light_color)
		
	# 5. Draw Twinkling Stars
	for star in _stars:
		var twinkle = (sin(time * star.speed + star.phase) + 1.0) / 2.0
		var current_size = star.base_size * (0.3 + twinkle * 0.7)
		draw_circle(star.pos, current_size, star.color)
