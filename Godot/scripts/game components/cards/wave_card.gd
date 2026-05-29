## tracks current wave number and acts as a signal relay for spawners
class_name WaveCard extends CDCueCard

@export var starting_wave: int = 1

@export_group("Listen Signals")
@export var on_advance_wave: Array[StringName] = [&"game_play", &"wave_cleared"]
@export var on_reset_wave: Array[StringName] = [&"wave_reset"]

@export_group("Emit Signals")
@export var on_wave_start: Array[StringName] = [&"wave_start"]
@export var on_wave_changed: Array[StringName] = [&"wave_changed"]

var current_wave: int

func _ready() -> void:
	super._ready()
	current_wave = starting_wave
	_update_label("Wave %d" % current_wave)
	call_deferred("_on_initialize")

func _on_initialize() -> void:
	for sig in on_advance_wave:
		game.bus_connect(sig, _advance_wave)
	for sig in on_reset_wave:
		game.bus_connect(sig, _reset_wave)

func _advance_wave(_arg1 = null, _arg2 = null) -> void:
	_update_label("Wave %d" % current_wave)
	for sig in on_wave_start:
		game.bus_emit(sig, [current_wave])
	for sig in on_wave_changed:
		game.bus_emit(sig, [current_wave])
	current_wave += 1

func _reset_wave(_arg1 = null, _arg2 = null) -> void:
	current_wave = starting_wave
	_update_label("Wave %d" % current_wave)
	for sig in on_wave_changed:
		game.bus_emit(sig, [current_wave])
