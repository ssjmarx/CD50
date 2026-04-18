# connects to signals in universal_game_script, and emits a wave-spawning signal when the connected signal fires

extends UniversalComponent2D

# Conditional exports based on trigger_type
@export var trigger_type: CommonEnums.Trigger = CommonEnums.Trigger.GROUP_CLEARED
@export var trigger_value: String = ""
@export var wave_delay: float = 2.0
@export var max_waves: int = 0

var current_wave: int = 1

# connect to configured trigger
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


# spawn configured wave when trigger fires
func _on_wave_triggered(arg1 = null) -> void:
	#print("on wave triggered1")
	if trigger_value != "" and arg1 != trigger_value:
		return
	
	if max_waves > 0 and current_wave > max_waves:
		return
	
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	#print("on wave triggered2")
	
	await get_tree().create_timer(wave_delay).timeout
	
	parent.spawning_wave.emit(self, current_wave)
	current_wave += 1
	#print("on wave triggered3")
