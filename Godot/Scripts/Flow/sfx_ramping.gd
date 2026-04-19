extends UniversalComponent

@export var source_node: Node
@export var source_property: String
@export var use_vector_length: bool = false
@export var min_value: float = 100.0
@export var max_value: float = 500.0
@export var base_semitone: int = 48
@export var max_semitone: int = 72
@export var source_signal: String
@export var filter_value: String = ""

var _synth: Node

func _ready() -> void:
	_synth = $SoundSynth
	source_node.connect(source_signal, _on_signal)

func _on_signal(arg1 = "", _arg2 = null) -> void:
	if filter_value != "" and arg1 != filter_value:
		return
	
	# Read the property value
	var raw_value = source_node[source_property]
	var value: float
	
	if use_vector_length:
		value = raw_value.length()
	else:
		value = float(raw_value)
	
	# Map value to semitone range
	var ratio = clampf(
		inverse_lerp(min_value, max_value, value), 0.0, 1.0
	)
	var target_semitone = int(lerpf(float(base_semitone), float(max_semitone), ratio))
	
	# Update synth's note and play
	_synth.note = target_semitone
	_synth.play_one_shot()
