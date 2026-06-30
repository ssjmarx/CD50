## WaveCard
## Produces: current_wave on game.blackboard + wave_started/wave_changed game bus signals.
## Consumes: game bus next_wave/advance_wave signals.
@tool

class_name WaveCard extends CDCueCard

## --- exports ---

## wave number at game start (typically 1)
@export var starting_wave: int = 1:
	set(value):
		starting_wave = value
		_update_preview()

@export_group("Blackboard Keys")
## key for publishing current wave to game blackboard
@export var wave_key: StringName = &"wave_number"

## game bus signals that trigger wave advance
@export_group("Listen Signals")
@export var on_advance_wave: Array[StringName] = [&"game_play", &"wave_cleared"]
## game bus signals that reset wave to starting value
@export var on_reset_wave: Array[StringName] = [&"wave_reset"]

## game bus signals emitted on wave advance
@export_group("Emit Signals")
@export var on_wave_start: Array[StringName] = [&"wave_start"]
@export var on_wave_changed: Array[StringName] = [&"wave_changed"]

## --- state ---

## current wave number
var current_wave: int

## --- lifecycle ---

## initialize wave count and display
func _ready() -> void:
	super._ready()
	current_wave = starting_wave
	_update_preview()
	_update_label("Wave %d" % current_wave)

## connect advance and reset signals to the game bus
func _on_initialize() -> void:
	super._on_initialize()
	_publish_tracked(wave_key, current_wave)
	connect_all(on_advance_wave, _advance_wave)
	connect_all(on_reset_wave, _reset_wave)

## --- wave control ---

## emit current wave, then increment for next call
func _advance_wave() -> void:
	_update_label("Wave %d" % current_wave)
	_publish_tracked(wave_key, current_wave)
	## emit before incrementing so listeners get the correct wave
	for sig in on_wave_start:
		game.bus_emit(sig)
	for sig in on_wave_changed:
		game.bus_emit(sig)
	current_wave += 1

## reset wave to starting value
func _reset_wave() -> void:
	current_wave = starting_wave
	_update_label("Wave %d" % current_wave)
	_publish_tracked(wave_key, current_wave)
	for sig in on_wave_changed:
		game.bus_emit(sig)

## updates the editor preview text based on starting wave
func _update_preview() -> void:
	_preview_value = "Wave %d" % starting_wave
	_update_interface()
