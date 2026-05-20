# BootScreen — shows title, modifier toggles (mouse-driven), and high scores.
# Attached to the BootScreen Control node inside ArcadeOrchestrator.

extends Control

const MODIFIER_KEYS: Array[String] = ["scope_creep", "shotgun_mode", "overclocked_cpu", "feature_creep", "crunch_time"]

@onready var _lifetime_label: Label = $LifetimeLabel
@onready var _high_score_labels: Array[Label] = [$HS0, $HS1, $HS2, $HS3, $HS4]
@onready var _modifier_buttons: Array[Button] = [$ModBtnScopeCreep, $ModBtnShotgunMode, $ModBtnOverclockedCPU, $ModBtnFeatureCreep, $ModBtnCrunchTime]
@onready var _tooltip_label: Label = $TooltipLabel

func _ready() -> void:
	# Connect modifier buttons to handler
	for i in MODIFIER_KEYS.size():
		_modifier_buttons[i].pressed.connect(_on_modifier_button.bind(MODIFIER_KEYS[i]))
		_modifier_buttons[i].mouse_entered.connect(_on_modifier_hover.bind(MODIFIER_KEYS[i]))
		_modifier_buttons[i].mouse_exited.connect(_on_modifier_unhover)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _refresh() -> void:
	# Update lifetime score
	_lifetime_label.text = "BEST: %d" % SaveData.get_best_run_score()
	
	# Update high scores
	var scores: Array[Dictionary] = SaveData.get_high_scores()
	for i in _high_score_labels.size():
		if i < scores.size():
			var entry: Dictionary = scores[i]
			_high_score_labels[i].text = "%2d. %s  %06d" % [i + 1, entry.get("initials", "---"), entry.get("score", 0)]
		else:
			_high_score_labels[i].text = ""
	
	# Update modifier buttons
	for i in MODIFIER_KEYS.size():
		var key: String = MODIFIER_KEYS[i]
		var btn: Button = _modifier_buttons[i]
		var display: String = SaveData.get_modifier_display_name(key)
		var threshold: int = SaveData.get_modifier_threshold(key)
		var unlocked: bool = SaveData.is_modifier_unlocked(key)
		var active: bool = SaveData.is_modifier_active(key)
		
		if unlocked:
			btn.text = "[ %s ] %s" % ["X" if active else " ", display]
			btn.disabled = false
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.text = "[   ] %s  (%d)" % [display, threshold]
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	# Hide tooltip on refresh
	_tooltip_label.visible = false

func _input(event: InputEvent) -> void:
	# Debug: hold Shift + press Escape to wipe save
	if OS.is_debug_build() and event.is_action_pressed("ui_cancel") and Input.is_key_pressed(KEY_SHIFT):
		SaveData.wipe_save()
		_refresh()
		get_viewport().set_input_as_handled()

func _on_modifier_button(key: String) -> void:
	SaveData.toggle_modifier(key)
	_refresh()

func _on_modifier_hover(key: String) -> void:
	if not SaveData.is_modifier_unlocked(key):
		return
	_tooltip_label.text = SaveData.get_modifier_description(key)
	_tooltip_label.visible = true

func _on_modifier_unhover() -> void:
	_tooltip_label.visible = false

func _on_visibility_changed() -> void:
	if visible:
		_refresh()