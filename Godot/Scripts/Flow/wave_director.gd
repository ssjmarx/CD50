# connects to signals in universal_game_script, and emits a wave-spawning signal when the connected signal fires

extends Node

# Conditional exports based on trigger_type
@export var trigger_type: Trigger = Trigger.GROUP_CLEARED
@export var trigger_value: Variant = null
@export var wave_delay: float = 2.0
@export var max_waves: int = 0

var current_wave: int = 1

@onready var parent = get_parent()

# Trigger types
enum Trigger {
	GROUP_CLEARED,
	TIMER_EXPIRED,
	LIVES_DEPLETED
}

# connect to configured trigger
func _ready() -> void:
	match trigger_type:
		Trigger.GROUP_CLEARED:
			parent.group_cleared.connect(_on_wave_triggered)
		Trigger.TIMER_EXPIRED:
			parent.timer_expired.connect(_on_wave_triggered)
		Trigger.LIVES_DEPLETED:
			parent.lives_depleted.connect(_on_wave_triggered)

# spawn configured wave when trigger fires
func _on_wave_triggered(arg1 = null) -> void:
	if trigger_value != null and arg1 != trigger_value:
		return
	
	if max_waves > 0 and current_wave > max_waves:
		return
	
	await get_tree().create_timer(wave_delay).timeout
	
	parent.spawning_wave.emit(self, current_wave)
	current_wave += 1
