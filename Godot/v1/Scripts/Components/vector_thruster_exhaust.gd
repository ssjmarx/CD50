# VectorThrusterExhaust — four small maneuvering thruster flames in an X pattern.
# Activates flames opposite to the parent's movement direction via the "move" signal.
# Includes a subtle noise audio effect while any flame is active.

extends UniversalComponent2D

# Flame appearance
@export var flame_size: float = 4.0
@export var flame_width: float = 3.0
@export var distance: float = 6.0
@export var color: Color = Color.WHITE
@export var flicker_speed: float = 0.08
@export var flicker_size: float = 2.0

# Audio
@export var audio_volume: float = 0.05

# Pre-normalized diagonal directions: UL, UR, LL, LR
var FLAME_DIRS: Array[Vector2] = [
	Vector2(-0.707107, -0.707107),  # UL
	Vector2(0.707107, -0.707107),   # UR
	Vector2(-0.707107, 0.707107),   # LL
	Vector2(0.707107, 0.707107),    # LR
]

# State
var _active: Array[bool] = [false, false, false, false]
var _direction: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _tips: Array[float] = [0.0, 0.0, 0.0, 0.0]

# Audio
var _stream: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _player: AudioStreamPlayer2D
const MIX_RATE: int = 11025

func _ready() -> void:
	parent.move.connect(_on_move)
	
	if "color" in parent:
		color = parent.color
	
	# Set up subtle noise audio
	_stream = AudioStreamGenerator.new()
	_stream.mix_rate = MIX_RATE
	_player = AudioStreamPlayer2D.new()
	_player.stream = _stream
	_player.volume_db = linear_to_db(audio_volume)
	add_child(_player)

func _on_move(dir: Vector2) -> void:
	_direction = dir

func _physics_process(delta: float) -> void:
	# Transform direction to local space (ship-relative)
	var local_dir: Vector2 = _direction.rotated(-parent.rotation)
	
	# Determine active flames based on local movement direction
	_active = [false, false, false, false]
	
	# Move right (+X local) → fire left-side thrusters (UL=0, LL=2)
	if local_dir.x > 0.1:
		_active[0] = true
		_active[2] = true
	# Move left (-X local) → fire right-side thrusters (UR=1, LR=3)
	elif local_dir.x < -0.1:
		_active[1] = true
		_active[3] = true
	
	# Move down (+Y local) → fire top thrusters (UL=0, UR=1)
	if local_dir.y > 0.1:
		_active[0] = true
		_active[1] = true
	# Move up (-Y local) → fire bottom thrusters (LL=2, LR=3)
	elif local_dir.y < -0.1:
		_active[2] = true
		_active[3] = true
	
	# Flicker flame tips
	_timer += delta
	if _timer > flicker_speed:
		for i in 4:
			_tips[i] = randf_range(0.0, flicker_size)
		_timer = 0.0
	
	# Audio: play noise when any flame active
	var any_active: bool = _active[0] or _active[1] or _active[2] or _active[3]
	if any_active:
		if not _player.playing:
			_player.play()
			_playback = _player.get_stream_playback()
		if _playback:
			var to_fill: int = mini(_playback.get_frames_available(), 256)
			for i in to_fill:
				var sample: float = randf() * 2.0 - 1.0
				_playback.push_frame(Vector2(sample * 0.5, sample * 0.5))
	else:
		if _player.playing:
			_player.stop()
	
	queue_redraw()

# Draw active flames as small polyline triangles
func _draw() -> void:
	for i in 4:
		if not _active[i]:
			continue
		
		var flame_dir: Vector2 = FLAME_DIRS[i]
		var base_pos: Vector2 = flame_dir * distance
		var tip: Vector2 = base_pos + flame_dir * (flame_size + _tips[i])
		
		# Perpendicular for flame width
		var perp: Vector2 = Vector2(-flame_dir.y, flame_dir.x)
		var left: Vector2 = base_pos + perp * (flame_width / 2.0)
		var right: Vector2 = base_pos - perp * (flame_width / 2.0)
		
		draw_polyline([left, tip, right], color, 1.5)