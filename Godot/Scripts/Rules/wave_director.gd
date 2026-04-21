# Wave director. Connects to a game trigger signal and emits a wave-spawning
# signal after a configurable delay, with optional wave count limits.

extends UniversalComponent2D

# Trigger configuration
@export var trigger_type: CommonEnums.Trigger = CommonEnums.Trigger.GROUP_CLEARED
@export var trigger_value: String = ""
@export var wave_delay: float = 2.0
@export var max_waves: int = 0

# Runtime state
var current_wave: int = 1

# Connect to the configured trigger signal
func _ready() -> void:
	match trigger_type:
		CommonEnums.Trigger.GROUP_CLEARED:
			parent.group_cleared.connect(_on_wave_triggered)
		CommonEnums.Trigger.TIMER_EXPIRED:
			parent.timer_expired.connect(_on_wave_triggered)
		CommonEnums.Trigger.LIVES_DEPLETED:
			parent.lives_depleted.connect(_on_wave_triggered)
		CommonEnums.Trigger.GAME_START:
			game.on_game_start.connect(_on_wave_triggered)

# Validate trigger conditions, wait for delay, then emit the wave spawn signal
func _on_wave_triggered(arg1 = null) -> void:
	if trigger_value != "" and arg1 != trigger_value:
		return
	
	if max_waves > 0 and current_wave > max_waves:
		return
	
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	
	await get_tree().create_timer(wave_delay).timeout
	
	parent.spawning_wave.emit(self, current_wave)
	current_wave += 1
