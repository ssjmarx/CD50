extends UniversalComponent

@export var f: float = 160.0
@export var duration: float = 0.1

var _stream: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _frames_remaining: int = 0
var _frame_position: int = 0

func _ready() -> void:
	_stream = AudioStreamGenerator.new()
	_stream.mix_rate = 22050
	
	var player = $AudioStreamPlayer2D
	player.stream = _stream
	player.play()
	
	_playback = player.get_stream_playback()
	_frames_remaining = int(duration * _stream.mix_rate)
	_frame_position = 0

func _process(_delta: float) -> void:
	var to_fill = _playback.get_frames_available()
	for i in to_fill:
		var t = float(_frame_position) / _stream.mix_rate
		var sample = 2.0 * (f * t - floor(f * t + 0.5))
		_playback.push_frame(Vector2(sample, sample))
		_frame_position += 1
