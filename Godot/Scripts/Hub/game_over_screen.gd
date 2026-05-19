# GameOverScreen — shows final score, high scores, unlock notifications, and initials entry.
# Attached to the GameOverScreen Control node inside ArcadeOrchestrator.
# The AO calls setup() before sliding this screen in.

extends Control

const CHAR_COUNT := 26  # A-Z
const INITIALS_COUNT := 3

enum Phase { SCORES, INITIALS, DONE }

var _phase: Phase = Phase.SCORES
var _final_score: int = 0
var _is_new_high_score: bool = false
var _new_unlocks: Array[String] = []
var _initials: PackedByteArray = [ord("A"), ord("A"), ord("A")]
var _cursor: int = 0
var _initials_entered: bool = false

@onready var _career_label: Label = $CareerLabel
@onready var _score_labels: Array[Label] = [$GOHS0, $GOHS1, $GOHS2, $GOHS3, $GOHS4]
@onready var _unlock_label: Label = $UnlockLabel
@onready var _initials_label: Label = $InitialsDisplay
@onready var _initials_prompt: Label = $InitialsPrompt
@onready var _play_again_label: Label = $PlayAgainLabel

func setup(score: int, is_new_hs: bool, new_unlocks: Array[String]) -> void:
	_final_score = score
	_is_new_high_score = is_new_hs
	_new_unlocks = new_unlocks
	_initials_entered = false
	_cursor = 0
	_initials = [ord("A"), ord("A"), ord("A")]
	
	if is_new_hs:
		_phase = Phase.INITIALS
	else:
		_phase = Phase.SCORES
	
	_refresh()

func _refresh() -> void:
	# Career score
	_career_label.text = "BEST: %d" % SaveData.get_best_run_score()
	
	# High scores
	var scores: Array[Dictionary] = SaveData.get_high_scores()
	for i in _score_labels.size():
		if i < scores.size():
			var entry: Dictionary = scores[i]
			_score_labels[i].text = "%2d. %s  %06d" % [i + 1, entry.get("initials", "---"), entry.get("score", 0)]
		else:
			_score_labels[i].text = ""
	
	# Unlock notification
	if _new_unlocks.size() > 0:
		var lines: Array[String] = []
		for key in _new_unlocks:
			lines.append("UNLOCKED: %s!" % SaveData.get_modifier_display_name(key))
		_unlock_label.text = "\n".join(lines)
		_unlock_label.visible = true
	else:
		_unlock_label.visible = false
	
	# Initials entry
	var show_initials: bool = _is_new_high_score and not _initials_entered
	_initials_prompt.visible = show_initials
	_initials_label.visible = show_initials
	
	if show_initials:
		_update_initials_display()
	
	# Update play-again label hint
	if _play_again_label:
		if show_initials:
			_play_again_label.text = "UP/DOWN: LETTER  LEFT/RIGHT: CURSOR  START: CONFIRM"
		else:
			_play_again_label.text = "PRESS START TO PLAY AGAIN"

func _update_initials_display() -> void:
	var text := ""
	for i in INITIALS_COUNT:
		if i == _cursor:
			text += "[%c]" % _initials[i]
		else:
			text += " %c " % _initials[i]
	_initials_label.text = text

func _input(event: InputEvent) -> void:
	if _phase == Phase.INITIALS and not _initials_entered:
		if event.is_action_pressed("ui_up"):
			_advance_char(_cursor, 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			_advance_char(_cursor, -1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_cursor = mini(_cursor + 1, INITIALS_COUNT - 1)
			_update_initials_display()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_cursor = maxi(_cursor - 1, 0)
			_update_initials_display()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("start") or event.is_action_pressed("coin"):
			_confirm_initials()
			get_viewport().set_input_as_handled()

func _advance_char(pos: int, dir: int) -> void:
	var val := _initials[pos] - ord("A")
	val = (val + dir + CHAR_COUNT) % CHAR_COUNT
	_initials[pos] = val + ord("A")
	_update_initials_display()

func is_entering_initials() -> bool:
	return _phase == Phase.INITIALS and not _initials_entered

func _confirm_initials() -> void:
	var initials_str := ""
	for b in _initials:
		initials_str += char(b)
	
	SaveData.add_high_score(_final_score, initials_str)
	_initials_entered = true
	_phase = Phase.DONE
	_refresh()