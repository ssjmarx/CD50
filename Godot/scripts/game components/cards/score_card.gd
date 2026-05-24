## tracks score with optional multiplier
class_name ScoreCard extends CDCueCard

@export var starting_score: int = 0
@export var starting_multiplier: float = 1.0

@export_group("Listen Signals")
@export var on_add_score: Array[StringName] = [&"add_score"]
@export var on_set_score: Array[StringName] = [&"set_score"]

## note: leave empty for no multiplier behavior
@export var on_add_multiplier: Array[StringName] = []
@export var on_set_multiplier: Array[StringName] = []

@export_group("Emit Signals")
@export var on_score_changed: Array[StringName] = [&"score_changed"]
@export var on_multiplier_changed: Array[StringName] = [&"multiplier_changed"]

var current_score: int
var current_multiplier: float = 1.0

func _ready() -> void:
	super._ready()
	current_score = starting_score
	current_multiplier = starting_multiplier
	_update_label(str(current_score))
	call_deferred("_on_initialize")

func _on_initialize() -> void:
	for sig in on_add_score:
		game.bus_connect(sig, _on_add_score)
	for sig in on_set_score:
		game.bus_connect(sig, _on_set_score)
	
	for sig in on_add_multiplier:
		game.bus_connect(sig, _on_add_multiplier)
	for sig in on_set_multiplier:
		game.bus_connect(sig, _on_set_multiplier)

func _on_add_score(amount: int) -> void:
	current_score += int(amount * current_multiplier)
	_update_label(str(current_score))
	for sig in on_score_changed:
		game.bus_emit(sig, [current_score])

func _on_set_score(new_score: int) -> void:
	current_score = new_score
	_update_label(str(current_score))
	for sig in on_score_changed:
		game.bus_emit(sig, [current_score])

func _on_add_multiplier(amount: float) -> void:
	current_multiplier += amount
	for sig in on_multiplier_changed:
		game.bus_emit(sig, [current_multiplier])

func _on_set_multiplier(new_mult: float) -> void:
	current_multiplier = new_mult
	for sig in on_multiplier_changed:
		game.bus_emit(sig, [current_multiplier])
