## tracks player lives
class_name LivesCard extends CDCueCard

@export var starting_lives: int = 3

@export_group("Listen Signals")
@export var on_life_lost: Array[StringName] = [&"life_lost"]
@export var on_life_gained: Array[StringName] = [&"life_gained"]

@export_group("Emit Signals")
@export var on_lives_changed: Array[StringName] = [&"lives_changed"]
@export var on_lives_depleted: Array[StringName] = [&"lives_depleted"]

var current_lives: int

func _ready() -> void:
	super._ready()
	current_lives = starting_lives
	_update_label(str(current_lives))
	call_deferred("_on_initialize")

func _on_initialize() -> void:
	for sig in on_life_lost:
		game.bus_connect(sig, _on_life_lost)
	for sig in on_life_gained:
		game.bus_connect(sig, _on_life_gained)

func _on_life_lost() -> void:
	current_lives -= 1
	_update_label(str(current_lives))
	for sig in on_lives_changed:
		game.bus_emit(sig, [current_lives])
	if current_lives <= 0:
		for sig in on_lives_depleted:
			game.bus_emit(sig)

func _on_life_gained() -> void:
	current_lives += 1
	_update_label(str(current_lives))
	for sig in on_lives_changed:
		game.bus_emit(sig, [current_lives])
