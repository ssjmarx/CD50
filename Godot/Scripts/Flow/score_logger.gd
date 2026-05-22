## ScoreLogger — CSV-based scoring audit tool for balancing playtests.
## Only active in debug builds (OS.is_debug_build()). No-ops in export/release.
## Writes per-game rows to user://score_log.csv for offline analysis.
extends Node

const LOG_PATH := "user://score_log.csv"

var _run_id: int = 0
var _game_number: int = 0
var _header_written: bool = false
var _run_start_time: float = 0.0

func _ready() -> void:
	if not OS.is_debug_build():
		# Completely inert in release builds
		set_process(false)
		set_physics_process(false)
		return
	print("[ScoreLogger] Ready. Debug build: ", OS.is_debug_build())
	print("[ScoreLogger] Resolved user data dir: ", OS.get_user_data_dir())
	print("[ScoreLogger] Log path: ", LOG_PATH)
	
	# Generate a run ID from current timestamp
	_run_id = int(Time.get_unix_time_from_system()) % 100000
	_run_start_time = Time.get_ticks_msec() / 1000.0
	
	# Check if file exists to decide on header
	if FileAccess.file_exists(LOG_PATH):
		_header_written = true

## Call when a new arcade run starts (boot → first game)
func start_run() -> void:
	if not OS.is_debug_build():
		return
	_game_number = 0
	_run_id = int(Time.get_unix_time_from_system()) % 100000
	_run_start_time = Time.get_ticks_msec() / 1000.0

## Log a completed game. Call from ArcadeOrchestrator._on_game_over_signal.
## Data dict keys:
##   game_name: String (scene filename)
##   game_title: String (display title from UGS)
##   result: String ("WIN" or "LOSS")
##   raw_score: int (final_score from UGS before arcade multipliers)
##   time_elapsed_s: float (seconds from game start to game over)
##   time_bonus: int (arcade time bonus, 0 on loss)
##   game_multiplier: float (game's internal multiplier)
##   arcade_bonus: float (per-game count bonus from AO)
##   crunch_mult: float (1.0 or 3.0)
##   total_added: int (raw_score + time_bonus) × crunch_mult
##   running_total: int (running score after this game)
func log_game(data: Dictionary) -> void:
	if not OS.is_debug_build():
		return
	
	_game_number += 1
	
	var file: FileAccess
	if not _header_written:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if not file:
			push_warning("ScoreLogger: cannot open %s" % LOG_PATH)
			return
		file.store_line(_csv_header())
		_header_written = true
	else:
		file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if not file:
			push_warning("ScoreLogger: cannot open %s" % LOG_PATH)
			return
		file.seek_end()
	
	var elapsed: float = data.get("time_elapsed_s", 0.0)
	var raw: int = data.get("raw_score", 0)
	var score_per_sec: float = raw / max(elapsed, 0.001)
	
	var row := PackedStringArray([
		str(_run_id),
		str(_game_number),
		_csv_escape(data.get("game_name", "")),
		_csv_escape(data.get("game_title", "")),
		data.get("result", "???"),
		str(raw),
		"%.1f" % elapsed,
		str(data.get("time_bonus", 0)),
		"%.2f" % data.get("game_multiplier", 1.0),
		"%.2f" % data.get("arcade_bonus", 0.0),
		"%.1f" % data.get("crunch_mult", 1.0),
		str(data.get("total_added", 0)),
		str(data.get("running_total", 0)),
		"%.1f" % score_per_sec,
	])
	
	file.store_line(",".join(row))
	file.close()
	
	print("[ScoreLogger] Logging game: ", data.get("game_title", "?"), " result=", data.get("result", "?"))


## Clear the log file
func clear_log() -> void:
	if not OS.is_debug_build():
		return
	_header_written = false
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove("score_log.csv")

func _csv_header() -> String:
	return ",".join([
		"run_id", "game_num", "game_name", "game_title", "result",
		"raw_score", "time_elapsed_s", "time_bonus",
		"game_multiplier", "arcade_bonus", "crunch_mult",
		"total_added", "running_total", "score_per_second"
	])

func _csv_escape(value: String) -> String:
	if value.find(",") >= 0 or value.find('"') >= 0 or value.find("\n") >= 0:
		return '"' + value.replace('"', '""') + '"'
	return value
