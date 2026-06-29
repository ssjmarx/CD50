## lasso_effect.gd
## Produces: a dynamic rope effect between two entities (loose sine-wave → taut line).
## Consumes: parent CDEntity.blackboard[captor_key/target_key]; game bus signals.
extends CDEffect
class_name LassoEffect

enum RopeState { LOOSE, TAUT }

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"lasso_captor"
@export var target_key: StringName = &"lasso_target"
@export var game_captured_key: StringName = &"captured_entity"

@export_group("Visuals")
@export var wave_amplitude: float = 8.0
@export var wave_length: float = 40.0 ## length in pixels of one full sine wave cycle
@export var rope_width: float = 2.0

var _state: RopeState = RopeState.LOOSE
var _source_entity: CDEntity = null
var _captor: Node2D = null
var _target: Node2D = null
var _rope_color: Color

@onready var game = CDGame.find_ancestor(self)

## Arm the timer, read endpoints from the parent's blackboard, and connect bus signals.
func _ready() -> void:
	super._ready() ## initialize CDEffect timer/fallback
	
	_rope_color = get_random_color()
	
	var parent = get_parent()
	if parent is CDEntity:
		_source_entity = parent as CDEntity
	else:
		push_error("LassoEffect must be parented to a CDEntity to read its blackboard!")
		queue_free()
		return
		
	_captor = _source_entity.blackboard.get(captor_key)
	_target = _source_entity.blackboard.get(target_key)
		
	## listen for capture phase end on the source node (e.g., the Spider)
	if _source_entity.has_method("bus_connect"):
		_source_entity.bus_connect("lasso_end", _on_lasso_end)
		
	## listen for player capture on game bus
	if game and game.has_method("bus_connect"):
		game.bus_connect("player_captured", _on_player_captured)
		
## Clear endpoints if either vanishes, then request a redraw.
func _process(_delta: float) -> void:
	## if either endpoint vanishes, stop drawing
	if not is_instance_valid(_captor) or not is_instance_valid(_target):
		_captor = null
		_target = null
		
	queue_redraw()
	
## Draw the rope as a sine wave (loose) or straight line (taut) between the endpoints.
func _draw() -> void:
	if not _captor or not _target:
		return
		
	var p1 = _captor.global_position
	var p2 = _target.global_position
	
	## convert global positions to local drawing space
	p1 = to_local(p1)
	p2 = to_local(p2)
	
	if _state == RopeState.LOOSE:
		_draw_sine_wave(p1, p2)
	else:
		draw_line(p1, p2, _rope_color, rope_width)
		
## Sample a sine wave along p1→p2 and draw it as an anti-aliased polyline.
func _draw_sine_wave(p1: Vector2, p2: Vector2) -> void:
	var dist = p1.distance_to(p2)
	if dist <= 0.0:
		return

	var dir = (p2 - p1).normalized()
	var perp = dir.orthogonal()
	
	var points = PackedVector2Array()
	
	## fixed pixel step for resolution prevents shimmering/jitter
	var step = 2.0 
	var segments = max(1, int(dist / step))
	
	for i in range(segments + 1):
		var d = float(i) * step
		if i == segments:
			d = dist ## ensure exact endpoint connection
			
		var base_pos = p1 + dir * d
		
		## phase is based on absolute distance, acting like a repeating texture
		var phase = (d / wave_length) * TAU
		var wave_offset = sin(phase) * wave_amplitude
		
		points.append(base_pos + perp * wave_offset)
		
	if points.size() > 1:
		## true enables anti-aliasing for smooth, non-jagged edges
		draw_polyline(points, _rope_color, rope_width, true) 
		
## On player capture, retarget the rope to the captured entity and switch to taut.
func _on_player_captured() -> void:
	if game and game_captured_key in game.blackboard:
		_target = game.blackboard[game_captured_key]
		_state = RopeState.TAUT
		
## Free the effect when the lasso ends.
func _on_lasso_end() -> void:
	queue_free()