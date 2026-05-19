# SaveData autoload. Manages persistent progression data via JSON at user://cd50_save.json.
# Tracks: best run score, high scores (top 5), modifier unlocks, active modifier selections.
# Unlock thresholds are hardcoded — modifiers unlock as best_run_score crosses each tier.

extends Node

const SAVE_PATH := "user://cd50_save.json"
const MAX_HIGH_SCORES := 5

# Modifier definitions: key = internal name, value = { threshold, display_name }
const MODIFIER_DEFS := {
	"scope_creep":     { "threshold": 100,     "display": "SCOPE CREEP" },
	"shotgun_mode":    { "threshold": 1000,    "display": "SHOTGUN MODE" },
	"overclocked_cpu": { "threshold": 10000,   "display": "OVERCLOCKED CPU" },
	"feature_creep":   { "threshold": 50000,   "display": "FEATURE CREEP" },
	"crunch_time":     { "threshold": 100000,  "display": "CRUNCH TIME" },
}

# Ordered list of modifier keys (matches display order)
const MODIFIER_ORDER := ["scope_creep", "shotgun_mode", "overclocked_cpu", "feature_creep", "crunch_time"]

# Persistent data
var best_run_score: int = 0
var high_scores: Array[Dictionary] = []
var modifiers_unlocked: Array[String] = []
var modifiers_active: Array[String] = []

signal save_data_changed()
signal modifier_unlocked(modifier_name: String, display_name: String)

func _ready() -> void:
	_load_data()

# --- Save / Load ---

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_defaults()
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("SaveData: failed to open save file")
		_init_defaults()
		return
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		push_warning("SaveData: failed to parse save JSON")
		_init_defaults()
		return
	
	var data: Dictionary = json.data
	
	best_run_score = int(data.get("best_run_score", 0))
	
	# High scores
	high_scores.clear()
	var hs_raw: Array = data.get("high_scores", [])
	for entry in hs_raw:
		high_scores.append({
			"score": int(entry.get("score", 0)),
			"initials": str(entry.get("initials", "---")),
			"date": str(entry.get("date", ""))
		})
	
	# Modifiers unlocked
	modifiers_unlocked.clear()
	for m in data.get("modifiers_unlocked", []):
		modifiers_unlocked.append(str(m))
	
	# Modifiers active
	modifiers_active.clear()
	for m in data.get("modifiers_active", []):
		modifiers_active.append(str(m))
	
	# Ensure unlocks match best run score (in case thresholds changed)
	_refresh_unlocks()

func _init_defaults() -> void:
	best_run_score = 0
	high_scores = _default_high_scores()
	modifiers_unlocked.clear()
	modifiers_active.clear()
	_refresh_unlocks()

func _default_high_scores() -> Array[Dictionary]:
	# Default top 5 scores set by "PLY" at each unlock threshold
	return [
		{"score": 100000, "initials": "PLY", "date": ""},
		{"score": 50000,  "initials": "PLY", "date": ""},
		{"score": 10000,  "initials": "PLY", "date": ""},
		{"score": 1000,   "initials": "PLY", "date": ""},
		{"score": 100,    "initials": "PLY", "date": ""},
	]

func _save_data() -> void:
	var data := {
		"best_run_score": best_run_score,
		"high_scores": high_scores,
		"modifiers_unlocked": modifiers_unlocked,
		"modifiers_active": modifiers_active,
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("SaveData: failed to write save file")
		return
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func save() -> void:
	_save_data()

func wipe_save() -> void:
	# Deletes the save file and resets all data to defaults
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_init_defaults()
	save_data_changed.emit()
	print("SaveData: save wiped")

# --- Score & Progression ---

func add_score(amount: int) -> Array[String]:
	# Updates best run score. Returns array of newly unlocked modifier keys.
	var new_unlocks: Array[String] = []
	if amount > best_run_score:
		best_run_score = amount
	
	for key in MODIFIER_ORDER:
		if key in modifiers_unlocked:
			continue
		var threshold: int = MODIFIER_DEFS[key]["threshold"]
		if best_run_score >= threshold:
			modifiers_unlocked.append(key)
			new_unlocks.append(key)
	
	_save_data()
	
	for key in new_unlocks:
		modifier_unlocked.emit(key, MODIFIER_DEFS[key]["display"])
	
	return new_unlocks

func add_high_score(score: int, initials: String) -> int:
	# Inserts score into high scores. Returns rank (0-based) or -1 if not top 5.
	var today := Time.get_date_string_from_system()
	
	# Check if it qualifies
	if high_scores.size() >= MAX_HIGH_SCORES:
		var lowest: int = high_scores[high_scores.size() - 1]["score"]
		if score <= lowest:
			return -1
	
	var entry := {"score": score, "initials": initials, "date": today}
	high_scores.append(entry)
	
	# Sort descending by score
	high_scores.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Trim to max
	while high_scores.size() > MAX_HIGH_SCORES:
		high_scores.pop_back()
	
	_save_data()
	
	# Find rank
	for i in high_scores.size():
		if high_scores[i] == entry:
			return i
	return -1

func is_new_high_score(score: int) -> bool:
	if high_scores.size() < MAX_HIGH_SCORES:
		return true
	return score > high_scores[high_scores.size() - 1]["score"]

# --- Modifiers ---

func is_modifier_unlocked(name: String) -> bool:
	return name in modifiers_unlocked

func is_modifier_active(name: String) -> bool:
	return name in modifiers_active

func toggle_modifier(name: String) -> void:
	if not is_modifier_unlocked(name):
		return
	var idx := modifiers_active.find(name)
	if idx >= 0:
		modifiers_active.remove_at(idx)
	else:
		modifiers_active.append(name)
	_save_data()
	save_data_changed.emit()

func get_active_modifiers() -> Dictionary:
	# Returns dict of all modifiers with their active state (for AO to read).
	var result := {}
	for key in MODIFIER_ORDER:
		result[key] = key in modifiers_active
	return result

func get_best_run_score() -> int:
	return best_run_score

func get_high_scores() -> Array[Dictionary]:
	return high_scores

func get_modifier_display_name(key: String) -> String:
	if key in MODIFIER_DEFS:
		return MODIFIER_DEFS[key]["display"]
	return key

func get_modifier_threshold(key: String) -> int:
	if key in MODIFIER_DEFS:
		return MODIFIER_DEFS[key]["threshold"]
	return 0

# --- Internal ---

func _refresh_unlocks() -> void:
	# Ensures unlock state matches current best_run_score.
	for key in MODIFIER_ORDER:
		if key in modifiers_unlocked:
			continue
		if best_run_score >= MODIFIER_DEFS[key]["threshold"]:
			modifiers_unlocked.append(key)