# ScoreCard
# Tracks score with optional multiplier applied on add (not on set)
# Leave multiplier signal arrays empty to disable multiplier behavior

class_name ScoreCard extends CDCueCard

# --- exports ---

# score at game start
@export var starting_score: int = 0
# multiplier at game start
@export var starting_multiplier: float = 1.0

# game bus signals for score changes
@export_group("Listen Signals")
@export var on_add_score: Array[StringName] = [&"add_score"]
@export var on_set_score: Array[StringName] = [&"set_score"]

# game bus signals for multiplier changes (leave empty to disable)
@export var on_add_multiplier: Array[StringName] = []
@export var on_set_multiplier: Array[StringName] = []

# game bus signals emitted when values change
@export_group("Emit Signals")
@export var on_score_changed: Array[StringName] = [&"score_changed"]
@export var on_multiplier_changed: Array[StringName] = [&"multiplier_changed"]

# --- state ---

# current score value
var current_score: int
# current multiplier applied to add_score
var current_multiplier: float = 1.0

# --- lifecycle ---

# initialize score, multiplier, and display
func _ready() -> void:
	super._ready()
	current_score = starting_score
	current_multiplier = starting_multiplier
	_update_label(str(current_score))
	call_deferred("_on_initialize")

# connect all listen signals to the game bus
func _on_initialize() -> void:
	for sig in on_add_score:
		game.bus_connect(sig, _on_add_score)
	for sig in on_set_score:
		game.bus_connect(sig, _on_set_score)
	
	# connect multiplier signals only if configured
	for sig in on_add_multiplier:
		game.bus_connect(sig, _on_add_multiplier)
	for sig in on_set_multiplier:
		game.bus_connect(sig, _on_set_multiplier)

# --- score handlers ---

# add amount multiplied by current multiplier
func _on_add_score(amount: int) -> void:
	current_score += int(amount * current_multiplier)
	_update_label(str(current_score))
	for sig in on_score_changed:
		game.bus_emit(sig, [current_score])

# set score to an exact value (ignores multiplier)
func _on_set_score(new_score: int) -> void:
	current_score = new_score
	_update_label(str(current_score))
	for sig in on_score_changed:
		game.bus_emit(sig, [current_score])

# --- multiplier handlers ---

# add to the current multiplier
func _on_add_multiplier(amount: float) -> void:
	current_multiplier += amount
	for sig in on_multiplier_changed:
		game.bus_emit(sig, [current_multiplier])

# set the multiplier to an exact value
func _on_set_multiplier(new_mult: float) -> void:
	current_multiplier = new_mult
	for sig in on_multiplier_changed:
		game.bus_emit(sig, [current_multiplier])