# WaveCard
# Tracks current wave number and relays start/changed signals to spawners
# Emits zero-arg signals, publishes current_wave to game blackboard

class_name WaveCard extends CDCueCard

# --- exports ---

# wave number at game start (typically 1)
@export var starting_wave: int = 1

@export_group("Blackboard Keys")
# key for publishing current wave to game blackboard
@export var wave_key: StringName = &"current_wave"

# game bus signals that trigger wave advance
@export_group("Listen Signals")
@export var on_advance_wave: Array[StringName] = [&"game_play", &"wave_cleared"]
# game bus signals that reset wave to starting value
@export var on_reset_wave: Array[StringName] = [&"wave_reset"]

# game bus signals emitted on wave advance
@export_group("Emit Signals")
@export var on_wave_start: Array[StringName] = [&"wave_start"]
@export var on_wave_changed: Array[StringName] = [&"wave_changed"]

# --- state ---

# current wave number
var current_wave: int

# --- lifecycle ---

# initialize wave count and display
func _ready() -> void:
	super._ready()
	current_wave = starting_wave
	_update_label("Wave %d" % current_wave)
	call_deferred("_on_initialize")

# connect advance and reset signals to the game bus
func _on_initialize() -> void:
	_publish_tracked(wave_key, current_wave)
	for sig in on_advance_wave:
		game.bus_connect(sig, _advance_wave)
	for sig in on_reset_wave:
		game.bus_connect(sig, _reset_wave)

# --- wave control ---

# emit current wave, then increment for next call
func _advance_wave() -> void:
	_update_label("Wave %d" % current_wave)
	_publish_tracked(wave_key, current_wave)
	# emit before incrementing so listeners get the correct wave
	for sig in on_wave_start:
		game.bus_emit(sig)
	for sig in on_wave_changed:
		game.bus_emit(sig)
	current_wave += 1

# reset wave to starting value
func _reset_wave() -> void:
	current_wave = starting_wave
	_update_label("Wave %d" % current_wave)
	_publish_tracked(wave_key, current_wave)
	for sig in on_wave_changed:
		game.bus_emit(sig)
