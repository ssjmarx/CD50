## TractorConeEffect
## Visual effect for the tractor beam, draws a cone and vacuums stars inward.
## Attach as a child of a Face component or Entity.
## Note: Set lifetime to 0 in the inspector if spawned/despawned manually by a Face component.

extends CDEffect

class_name TractorConeEffect

## number of active stars to maintain during vacuum
@export var star_count: int = 40

## distance from the ship to the wide end of the cone
@export var cone_length: float = 100.0

## total width of the cone's wide end
@export var cone_width: float = 75.0

## how fast stars get sucked into the origin
@export var vacuum_speed: float = 250.0

## color of the stars and the faint cone background
@export var star_color: Color = Color.WHITE

## size of the drawn stars in pixels
@export var star_size: float = 1.0

var _is_vacuuming: bool = false
var _stars_pos: Array[Vector2] = []
var _stars_vel: Array[Vector2] = []

func _ready() -> void:
	super._ready()
	set_process(false)

## start spawning and moving stars
func start_vacuum() -> void:
	_is_vacuuming = true
	set_process(true)

## stop spawning new stars (existing stars will finish their journey unless cleared)
func stop_vacuum() -> void:
	_is_vacuuming = false

## spawn a star at the wide edge with velocity pointing exactly at (0,0)
func _spawn_star() -> void:   
	var center := Vector2(cone_length, 0.0)                               
	var radius := cone_width * 0.5                                        
	var angle := randf_range(-PI / 2.0, PI / 2.0)                        
	var spawn_pos := center + (Vector2.from_angle(angle) * radius)        
	var dir := -spawn_pos.normalized()                                    
	var speed := randf_range(vacuum_speed * 0.7, vacuum_speed)            
	
	_stars_pos.append(spawn_pos)                                          
	_stars_vel.append(dir * speed)

func _process(delta: float) -> void:
	if _is_vacuuming:
		if _stars_pos.size() < star_count:
			_spawn_star()
			
	var i := 0
	while i < _stars_pos.size():
		_stars_pos[i] += _stars_vel[i] * delta
		
		# if the star reaches the origin, remove it
		if _stars_pos[i].x <= 0.0 or _stars_pos[i].length() < 5.0:
			_stars_pos.remove_at(i)
			_stars_vel.remove_at(i)
		else:
			i += 1
			
	queue_redraw()

func _draw() -> void:
	var half_size := star_size / 2.0
	for pos in _stars_pos:
		draw_rect(Rect2(pos.x - half_size, pos.y - half_size, star_size, star_size), star_color)
