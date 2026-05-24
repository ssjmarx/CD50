# Music ramping. Accelerates a two-voice synth beat as the count of a target
# group decreases, creating tension that builds as enemies are destroyed.

extends UniversalComponent2D

# Group tracking and timing
@export var target_group: String = "space_rocks"
@export var min_interval: float = 0.1
@export var max_interval: float = 1.0

# Runtime state
var _synth_a: Node
var _synth_b: Node
var _beat_timer: float = 0.0
var _current_interval: float = 1.0
var _toggle: bool = false
var _initial_count: int = 0
var _peak_interval: float = INF

# Cache synth child nodes and initial group count
func _ready() -> void:
	_synth_a = $SoundSynth_A
	_synth_b = $SoundSynth_B
	_initial_count = get_group_count(target_group)
	_current_interval = max_interval

# Adjust beat interval based on remaining group members and fire beats
func _process(delta: float) -> void:
	if game.current_state != CommonEnums.State.PLAYING:
		return
	
	var count = get_group_count(target_group)
	
	if count == 0:
		_initial_count = 0
		_peak_interval = INF
		return
	
	# Track the highest count seen (handles spawning mid-game)
	if count > _initial_count:
		_initial_count = count
	
	var ratio = clampf(float(count) / float(_initial_count), 0.0, 1.0)
	var target_interval = lerpf(min_interval, max_interval, ratio)
	
	# Interval only ever decreases (ramps up), never returns to slower tempo
	_current_interval = minf(target_interval, _peak_interval)
	_peak_interval = _current_interval
	
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_timer = _current_interval
		_play_beat()

# Alternate between the two synth voices on each beat
func _play_beat() -> void:
	_toggle = not _toggle
	if _toggle:
		_synth_a.play_one_shot()
	else:
		_synth_b.play_one_shot()
