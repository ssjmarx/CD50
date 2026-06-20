## LassoEffect
## A visual "rope" effect that dynamically connects two entities.
## Reads generic captor/target keys from a source blackboard on spawn.
## 
## State 1 (Loose): Sine wave between captor and target (bullet).
## State 2 (Taut): Straight line between captor and target (captured player).

extends CDEffect
class_name LassoEffect

enum RopeState { LOOSE, TAUT }

@export var source_node: Node2D

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"lasso_captor"
@export var target_key: StringName = &"lasso_target"
@export var game_captured_key: StringName = &"captured_entity"

@export_group("Visuals")
@export var wave_amplitude: float = 8.0
@export var wave_frequency: float = 0.5
@export var wave_speed: float = 10.0
@export var rope_color: Color = Color.WHITE
@export var rope_width: float = 2.0

var _state: RopeState = RopeState.LOOSE
var _captor: Node2D = null
var _target: Node2D = null
var _time: float = 0.0

@onready var game = CDGame.find_ancestor(self)

func _ready() -> void:
	super._ready() # Initialize CDEffect timer/fallback
	
	if source_node and "blackboard" in source_node:
		_captor = source_node.blackboard.get(captor_key)
		_target = source_node.blackboard.get(target_key)
	else:
		# No source, nothing to draw
		queue_free()
		return
		
	# Listen for capture phase end on the source node (e.g., the Spider)
	if source_node.has_method("bus_connect"):
		source_node.bus_connect("lasso_end", _on_lasso_end)
		
	# Listen for player capture on game bus
	if game and game.has_method("bus_connect"):
		game.bus_connect("player_captured", _on_player_captured)
		
func _process(delta: float) -> void:
	_time += delta
	
	# If either endpoint vanishes, stop drawing
	if not is_instance_valid(_captor) or not is_instance_valid(_target):
		_captor = null
		_target = null
		
	queue_redraw()
	
func _draw() -> void:
	if not _captor or not _target:
		return
		
	var p1 = _captor.global_position
	var p2 = _target.global_position
	
	# Convert global positions to local drawing space
	p1 = to_local(p1)
	p2 = to_local(p2)
	
	if _state == RopeState.LOOSE:
		_draw_sine_wave(p1, p2)
	else:
		draw_line(p1, p2, rope_color, rope_width)
		
func _draw_sine_wave(p1: Vector2, p2: Vector2) -> void:
	var dist = p1.distance_to(p2)
	var dir = (p2 - p1).normalized()
	var perp = dir.orthogonal()
	
	var points = PackedVector2Array()
	var segments = max(2, int(dist / 5.0)) # Resolution of the curve
	
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var base_pos = p1.lerp(p2, t)
		
		# Taper the amplitude at the ends so it looks securely attached
		var taper = sin(t * PI) 
		var wave_offset = sin(t * wave_frequency * PI * 2.0 + _time * wave_speed) * wave_amplitude * taper
		
		points.append(base_pos + perp * wave_offset)
		
	if points.size() > 1:
		draw_polyline(points, rope_color, rope_width)
		
func _on_player_captured() -> void:
	if game and game_captured_key in game.blackboard:
		_target = game.blackboard[game_captured_key]
		_state = RopeState.TAUT
		
func _on_lasso_end() -> void:
	queue_free()
