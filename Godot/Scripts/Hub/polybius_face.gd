@tool
# Polybius vector CRT face. Draws expression from two independent channels:
#   - Eyes channel (outline, eyes, pupils, eyebrows) — controls expression
#   - Mouth channel (mouth shape) — controls lip sync
# Both combine freely: any eye frame + any mouth frame.
# All frame data is defined in PolybiusEyes and PolybiusMouth resources,
# editable directly in the Godot inspector with live viewport preview.
#
# Playback engine: play_phrase(phrase) plays a PolybiusPhrase with per-syllable
# lip sync and typewriter text reveal. Emits phrase_finished when done.
#
# Editor preview: Use the "Preview" section in the inspector to play intro/outro
# animations directly in the editor viewport. Phrase data is fully editable.
#
# Menace effects: Glitch, static, glow pulse, scan disruption, and corrupt flash
# can be dialed in via the "Menace" export group.

extends Control

# --- Signal for AO integration ---
signal phrase_finished

# --- Phrases (editable in inspector, defaults built in _ready) ---
@export var intro_phrase: PolybiusPhrase:
	set(v):
		intro_phrase = v
		queue_redraw()

@export var outro_phrase: PolybiusPhrase:
	set(v):
		outro_phrase = v
		queue_redraw()

# Eye/expression frames — one per expression state (neutral, displeased, etc.)
@export var eye_frames: Array[PolybiusEyes] = []:
	set(v):
		eye_frames = v
		queue_redraw()

@export var nose_frames: Array[PolybiusNose] = []:
	set(v):
		nose_frames = v
		queue_redraw()

# Mouth frames — one per mouth position for lip sync
@export var mouth_frames: Array[PolybiusMouth] = []:
	set(v):
		mouth_frames = v
		queue_redraw()

# Current frame indices — switch in inspector to preview any combination
@export var current_eye_frame: int = 0:
	set(v):
		current_eye_frame = v
		queue_redraw()

@export var current_nose_frame: int = 0:
	set(v):
		current_nose_frame = v
		queue_redraw()

@export var current_mouth_frame: int = 0:
	set(v):
		current_mouth_frame = v
		queue_redraw()

# Appearance
@export var face_color: Color = Color("ffb300"):
	set(v):
		face_color = v
		queue_redraw()

@export var line_width: float = 2.0:
	set(v):
		line_width = v
		queue_redraw()

@export var reference_image: Texture2D:
	set(v):
		reference_image = v
		queue_redraw()

@export var show_reference: bool = true:
	set(v):
		show_reference = v
		queue_redraw()

@export var reference_offset: Vector2 = Vector2.ZERO:
	set(v):
		reference_offset = v if v != null else Vector2.ZERO
		queue_redraw()

@export var center_x: float = 320.0

@export var mirror_left_to_right: bool = false:
	set(v):
		mirror_left_to_right = false
		if v:
			_do_mirror()

# --- Menace Effects ---
@export_group("Menace")

# Glitch — horizontal slice displacement
@export var glitch_enabled: bool = true
@export_range(0.0, 30.0) var glitch_intensity: float = 3.0
@export_range(0.0, 1.0) var glitch_chance: float = 0.06
@export_range(1.0, 20.0) var glitch_band_height: float = 4.0

# Static / noise overlay
@export var static_enabled: bool = true
@export_range(0.0, 1.0) var static_density: float = 0.03
@export_range(0.0, 1.0) var static_burst_chance: float = 0.04
@export_range(1.0, 4.0) var static_size: float = 1.5

# Glow pulse — multi-pass bloom on face lines
@export var glow_enabled: bool = true
@export_range(0, 5) var glow_passes: int = 2
@export_range(2.0, 12.0) var glow_base_width: float = 4.0
@export_range(0.0, 1.0) var glow_intensity: float = 0.25
@export_range(0.0, 10.0) var glow_pulse_speed: float = 1.5
@export_range(0.0, 1.0) var glow_pulse_amount: float = 0.15

# Scan disruption — harsh horizontal scan lines
@export var scan_disruption_enabled: bool = true
@export_range(0.0, 1.0) var scan_disruption_chance: float = 0.03
@export_range(1.0, 6.0) var scan_disruption_thickness: float = 2.0
@export_range(0.0, 1.0) var scan_disruption_brightness: float = 0.3

# Corrupt frame flash — brief vertex corruption + color inversion
@export var corrupt_flash_enabled: bool = true
@export_range(0.0, 1.0) var corrupt_flash_chance: float = 0.015
@export_range(0.0, 40.0) var corrupt_displacement: float = 8.0

# --- Typewriter label settings ---
@export_group("Typewriter")
@export var typewriter_font: Font
@export var typewriter_font_size: int = 48
@export var typewriter_color: Color = Color.WHITE
@export var typewriter_y_offset: float = 0.0  # Extra Y offset from auto-position

# --- Preview controls (editor only) ---
@export_group("Preview")
enum PreviewAction { NONE, PLAY_INTRO, PLAY_OUTRO, STOP }
@export var preview_action: PreviewAction = PreviewAction.NONE:
	set(v):
		preview_action = PreviewAction.NONE  # Reset immediately (acts as a button)
		if v == PreviewAction.PLAY_INTRO:
			_do_preview_intro()
		elif v == PreviewAction.PLAY_OUTRO:
			_do_preview_outro()
		elif v == PreviewAction.STOP:
			_stop_all()

@export var preview_typewriter_speed: float = 0.05:
	set(v):
		preview_typewriter_speed = v

# --- Runtime state ---
var _text_label: Label = null
var _voice_player: AudioStreamPlayer = null
var _playback_tween: Tween = null
var _mouth_tween: Tween = null
var _is_playing: bool = false

# --- Menace runtime state ---
var _glitch_timer: float = 0.0
var _glitch_active: bool = false
var _glitch_slices: Array = []  # Array of {y_start, y_end, x_offset}

var _static_active: bool = false
var _static_particles: Array = []  # Array of {x, y}

var _scan_active: bool = false
var _scan_y: float = 0.0

var _corrupt_active: bool = false
var _corrupt_timer: float = 0.0
var _corrupt_seed: int = 0

var _elapsed_time: float = 0.0

func _ready() -> void:
	# Build default phrases if not set in inspector
	if not intro_phrase:
		intro_phrase = _build_intro_phrase()
	if not outro_phrase:
		outro_phrase = _build_outro_phrase()
	
	# Create typewriter label (works in both editor and runtime)
	_ensure_label()
	_ensure_voice_player()

func _ensure_label() -> void:
	if _text_label and is_instance_valid(_text_label):
		return
	
	_text_label = Label.new()
	_text_label.name = "TypeWriterLabel"
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor to bottom of screen
	_text_label.anchor_left = 0.0
	_text_label.anchor_right = 1.0
	_text_label.anchor_top = 0.0
	_text_label.anchor_bottom = 1.0
	_text_label.offset_top = 280.0
	_text_label.offset_bottom = -5.0
	if typewriter_font:
		_text_label.add_theme_font_override("font", typewriter_font)
	_text_label.add_theme_font_size_override("font_size", typewriter_font_size)
	_text_label.add_theme_color_override("font_color", typewriter_color)
	_text_label.add_theme_constant_override("outline_size", 4)
	_text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_text_label.text = ""
	_text_label.visible = false
	add_child(_text_label)

func _ensure_voice_player() -> void:
	if _voice_player and is_instance_valid(_voice_player):
		return
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.bus = "SFX"
	add_child(_voice_player)

# --- Phrase Builders ---

func _build_intro_phrase() -> PolybiusPhrase:
	var line1 := PolybiusLine.new()
	line1.text = "I hunger"
	line1.eye_frame = 0  # neutral
	line1.voice_clip = load("res://Assets/Voice/i_hunger.ogg")
	line1.beats = _make_beats([0.0, 0.15, 0.35], [1, 1, 1], [0.12, 0.12, 0.12])
	line1.end_pause = 0.4
	
	var line2 := PolybiusLine.new()
	line2.text = "for SCORE."
	line2.eye_frame = 1  # displeased
	line2.voice_clip = load("res://Assets/Voice/for_score.ogg")
	line2.beats = _make_beats([0.1, 0.45], [1, 1], [0.12, 0.2])
	line2.end_pause = 0.5
	
	var phrase := PolybiusPhrase.new()
	phrase.lines = [line1, line2]
	return phrase

func _build_outro_phrase() -> PolybiusPhrase:
	var line1 := PolybiusLine.new()
	line1.text = "Pathetic."
	line1.eye_frame = 0  # neutral
	line1.voice_clip = load("res://Assets/Voice/pathetic.ogg")
	line1.beats = _make_beats([0.05, 0.2, 0.4], [1, 1, 1], [0.12, 0.12, 0.12])
	line1.end_pause = 0.5
	
	var line2 := PolybiusLine.new()
	line2.text = "You're not even on the leaderboard."
	line2.eye_frame = 0  # neutral
	line2.voice_clip = load("res://Assets/Voice/leaderboard.ogg")
	line2.beats = _make_beats([0.2, 0.4, 0.55, 0.7, 0.85, 1.05, 1.3, 1.4, 1.7], [1, 1, 1, 1, 1, 1, 1, 1, 1], [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.12])
	line2.end_pause = 0.5
	
	var line3 := PolybiusLine.new()
	line3.text = "PLAY AGAIN!"
	line3.eye_frame = 1  # displeased
	line3.voice_clip = load("res://Assets/Voice/again.ogg")
	line3.beats = _make_beats([0.15, 0.5], [1, 1], [0.15, 0.2])
	line3.end_pause = 0.6
	
	var phrase := PolybiusPhrase.new()
	phrase.lines = [line1, line2, line3]
	return phrase

# Helper: create array of PolybiusBeat from parallel arrays
func _make_beats(start_times: Array, p_mouth_frames: Array, hold_times: Array) -> Array:
	var result: Array = []
	for i in start_times.size():
		var beat := PolybiusBeat.new()
		beat.start_time = start_times[i]
		beat.mouth_frame = p_mouth_frames[i] if i < p_mouth_frames.size() else 1
		beat.hold_time = hold_times[i] if i < hold_times.size() else 0.1
		result.append(beat)
	return result

func _process(delta: float) -> void:
	_elapsed_time += delta
	if Engine.is_editor_hint():
		queue_redraw()
	_update_menace(delta)
	queue_redraw()

# --- Menace Effect Updates ---

func _update_menace(delta: float) -> void:
	# --- Glitch ---
	if glitch_enabled:
		if _glitch_active:
			_glitch_timer -= delta
			if _glitch_timer <= 0.0:
				_glitch_active = false
				_glitch_slices.clear()
		else:
			if randf() < glitch_chance:
				_glitch_active = true
				_glitch_timer = randf_range(0.03, 0.12)
				_generate_glitch_slices()
	else:
		_glitch_active = false
		_glitch_slices.clear()
	
	# --- Static ---
	if static_enabled:
		if _static_active:
			_static_particles.clear()
			_generate_static_particles()
			if randf() > static_burst_chance * 3.0:
				_static_active = false
		else:
			_static_particles.clear()
			if randf() < static_burst_chance:
				_static_active = true
				_generate_static_particles()
	else:
		_static_active = false
		_static_particles.clear()
	
	# --- Scan disruption ---
	if scan_disruption_enabled:
		if _scan_active:
			_scan_y += delta * 800.0
			if _scan_y > size.y:
				_scan_active = false
		else:
			if randf() < scan_disruption_chance:
				_scan_active = true
				_scan_y = -20.0
	else:
		_scan_active = false
	
	# --- Corrupt flash ---
	if corrupt_flash_enabled:
		if _corrupt_active:
			_corrupt_timer -= delta
			if _corrupt_timer <= 0.0:
				_corrupt_active = false
		else:
			if randf() < corrupt_flash_chance:
				_corrupt_active = true
				_corrupt_timer = randf_range(0.03, 0.08)
				_corrupt_seed = randi()
	else:
		_corrupt_active = false

func _generate_glitch_slices() -> void:
	_glitch_slices.clear()
	var face_h: float = 360.0
	var num_slices: int = randi_range(1, 4)
	for _i in num_slices:
		var y_start: float = randf_range(0.0, face_h)
		var y_end: float = y_start + randf_range(glitch_band_height, glitch_band_height * 4.0)
		var x_off: float = randf_range(-glitch_intensity, glitch_intensity)
		_glitch_slices.append({"y_start": y_start, "y_end": y_end, "x_offset": x_off})

func _generate_static_particles() -> void:
	_static_particles.clear()
	var face_w: float = 640.0
	var face_h: float = 360.0
	var count: int = int(static_density * 500.0)
	for _i in count:
		_static_particles.append({
			"x": randf_range(0.0, face_w),
			"y": randf_range(0.0, face_h)
		})

func _get_glitch_offset_for_y(y: float) -> float:
	if not _glitch_active or _glitch_slices.is_empty():
		return 0.0
	for slice in _glitch_slices:
		if y >= slice.y_start and y <= slice.y_end:
			return slice.x_offset
	return 0.0

func _corrupt_point(p: Vector2) -> Vector2:
	if not _corrupt_active:
		return p
	var seed_val := _corrupt_seed
	var px := p.x + _seeded_rand(seed_val, int(p.x) * 7 + int(p.y) * 13) * corrupt_displacement
	var py := p.y + _seeded_rand(seed_val + 1, int(p.x) * 11 + int(p.y) * 3) * corrupt_displacement
	return Vector2(px, py)

func _seeded_rand(s: int, index: int) -> float:
	var v := s ^ (index * 1664525 + 1013904223)
	v = (v >> 16) ^ v
	v = v * 0x45d9f3b
	v = (v >> 16) ^ v
	return (float(v & 0x7FFFFFFF) / float(0x7FFFFFFF)) * 2.0 - 1.0

# --- Preview Controls ---

func _do_preview_intro() -> void:
	_ensure_label()
	if intro_phrase:
		play_phrase(intro_phrase)

func _do_preview_outro() -> void:
	_ensure_label()
	if outro_phrase:
		play_phrase(outro_phrase)

func _stop_all() -> void:
	if _playback_tween and _playback_tween.is_valid():
		_playback_tween.kill()
	if _mouth_tween and _mouth_tween.is_valid():
		_mouth_tween.kill()
	_is_playing = false
	current_mouth_frame = 0
	current_eye_frame = 0
	if _voice_player:
		_voice_player.stop()
	if _text_label:
		_text_label.visible = false
		_text_label.text = ""
	# Reset menace state
	_glitch_active = false
	_glitch_slices.clear()
	_static_active = false
	_static_particles.clear()
	_scan_active = false
	_corrupt_active = false

# --- Playback Engine ---

func play_phrase(phrase: PolybiusPhrase) -> void:
	if not phrase or phrase.lines.is_empty():
		phrase_finished.emit()
		return
	
	# Kill any running playback
	_stop_all()
	
	_is_playing = true
	_playback_tween = create_tween()
	
	# Show typewriter label
	_ensure_label()
	_text_label.visible = true
	_text_label.text = ""
	
	# Build ONE mouth tween for the entire phrase with cumulative delays
	_mouth_tween = create_tween()
	_mouth_tween.set_parallel(true)
	var _mouth_time: float = 0.0  # cumulative time offset across all lines
	
	for line_idx in phrase.lines.size():
		var line: PolybiusLine = phrase.lines[line_idx]
		
		# Set expression + play voice clip for this line
		_playback_tween.tween_callback(_set_expression.bind(line.eye_frame))
		_playback_tween.tween_callback(_play_voice.bind(line.voice_clip))
		_playback_tween.tween_callback(_clear_text)
		
		# --- Typewriter: letter-by-letter reveal, independent of beats ---
		var text_len: int = line.text.length()
		var char_interval: float = preview_typewriter_speed
		var typewriter_duration: float = text_len * char_interval
		if text_len > 0:
			for char_idx in text_len:
				var partial: String = line.text.substr(0, char_idx + 1)
				_playback_tween.tween_callback(_reveal_text.bind(partial))
				_playback_tween.tween_interval(char_interval)
		
		# --- Mouth beats: schedule into the single phrase-level mouth tween ---
		if not line.beats.is_empty():
			for beat_idx in line.beats.size():
				var beat: PolybiusBeat = line.beats[beat_idx]
				var open_at: float = _mouth_time + beat.start_time
				_mouth_tween.tween_callback(_set_mouth.bind(beat.mouth_frame)).set_delay(open_at)
				_mouth_tween.tween_callback(_set_mouth.bind(0)).set_delay(open_at + beat.hold_time)
		
		# Advance cumulative mouth time by this line's typewriter duration + pause
		_mouth_time += typewriter_duration + line.end_pause
		
		# End-of-line pause (mouth closed, full text visible)
		_playback_tween.tween_callback(_set_mouth.bind(0))
		_playback_tween.tween_interval(line.end_pause)
	
	# Finish: hide text, emit signal
	_playback_tween.tween_callback(_on_phrase_done)

func play_intro(callback: Callable) -> void:
	var phrase: PolybiusPhrase = intro_phrase
	if not phrase:
		callback.call()
		return
	_disconnect_all_phrase_finished()
	phrase_finished.connect(callback)
	play_phrase(phrase)

func play_outro(callback: Callable) -> void:
	var phrase: PolybiusPhrase = outro_phrase
	if not phrase:
		callback.call()
		return
	_disconnect_all_phrase_finished()
	phrase_finished.connect(callback)
	play_phrase(phrase)

func _disconnect_all_phrase_finished() -> void:
	for connection in phrase_finished.get_connections():
		phrase_finished.disconnect(connection.callable)

func _set_expression(frame: int) -> void:
	current_eye_frame = frame

func _play_voice(clip: AudioStream) -> void:
	if not _voice_player:
		return
	_voice_player.stop()
	if clip:
		_voice_player.stream = clip
		_voice_player.play()

func _set_mouth(frame: int) -> void:
	current_mouth_frame = frame

func _clear_text() -> void:
	if _text_label:
		_text_label.text = ""

func _reveal_text(text: String) -> void:
	if _text_label:
		_text_label.text = text

func _on_phrase_done() -> void:
	_is_playing = false
	current_mouth_frame = 0
	current_eye_frame = 0
	if _text_label:
		_text_label.visible = false
	phrase_finished.emit()

# --- Drawing ---

func _draw() -> void:
	if reference_image and show_reference:
		var offset: Vector2 = reference_offset if reference_offset else Vector2.ZERO
		draw_texture(reference_image, offset)

	# Compute glow pulse
	var pulse: float = 0.0
	if glow_enabled:
		pulse = sin(_elapsed_time * glow_pulse_speed) * glow_pulse_amount

	# Determine current draw color (may be inverted during corrupt flash)
	var draw_color: Color = face_color
	if _corrupt_active and corrupt_flash_enabled:
		draw_color = Color(face_color.g, face_color.r, face_color.b * 0.5, face_color.a)

	# --- Glow passes (drawn FIRST, behind the crisp lines) ---
	if glow_enabled and glow_passes > 0:
		for pass_idx in glow_passes:
			var extra_width: float = glow_base_width * float(pass_idx + 1)
			var alpha: float = (glow_intensity + pulse) / float(pass_idx + 1)
			var glow_color: Color = Color(draw_color.r, draw_color.g, draw_color.b, clamp(alpha, 0.0, 1.0))
			_draw_face(glow_color, line_width + extra_width, true)

	# --- Crisp face lines ---
	_draw_face(draw_color, line_width, false)

	# --- Static overlay ---
	if _static_active and static_enabled:
		var static_color: Color = Color(draw_color.r, draw_color.g, draw_color.b, 0.6)
		for p in _static_particles:
			draw_rect(Rect2(p.x, p.y, static_size, static_size), static_color)

	# --- Scan disruption line ---
	if _scan_active and scan_disruption_enabled:
		var scan_color: Color = Color(draw_color.r, draw_color.g, draw_color.b, scan_disruption_brightness)
		draw_rect(Rect2(0.0, _scan_y, size.x, scan_disruption_thickness), scan_color)
		# Secondary faint line trailing behind
		var trail_color: Color = Color(draw_color.r, draw_color.g, draw_color.b, scan_disruption_brightness * 0.3)
		draw_rect(Rect2(0.0, _scan_y - scan_disruption_thickness * 2.0, size.x, scan_disruption_thickness * 0.5), trail_color)

func _draw_face(color: Color, width: float, is_glow_pass: bool) -> void:
	# Draw eye/expression channel
	if eye_frames.size() > 0 and current_eye_frame >= 0 and current_eye_frame < eye_frames.size():
		var eyes: PolybiusEyes = eye_frames[current_eye_frame]
		_draw_polyline_menace(eyes.outline, color, width, is_glow_pass)
		_draw_polyline_menace(eyes.left_eye, color, width, is_glow_pass)
		_draw_polyline_menace(eyes.right_eye, color, width, is_glow_pass)
		_draw_polyline_menace(eyes.left_pupil, color, width, is_glow_pass)
		_draw_polyline_menace(eyes.right_pupil, color, width, is_glow_pass)
		_draw_polyline_menace(eyes.left_eyebrow, color, width, is_glow_pass)
		_draw_polyline_menace(eyes.right_eyebrow, color, width, is_glow_pass)
	
	if nose_frames.size() > 0 and current_nose_frame >= 0 and current_nose_frame < nose_frames.size():
		var nose: PolybiusNose = nose_frames[current_nose_frame]
		_draw_polyline_menace(nose.left_nostril, color, width, is_glow_pass)
		_draw_polyline_menace(nose.right_nostril, color, width, is_glow_pass)
	
	# Draw mouth channel
	if mouth_frames.size() > 0 and current_mouth_frame >= 0 and current_mouth_frame < mouth_frames.size():
		var mouth_res: PolybiusMouth = mouth_frames[current_mouth_frame]
		_draw_polyline_menace(mouth_res.mouth, color, width, is_glow_pass)
		_draw_polyline_menace(mouth_res.lower_lip, color, width, is_glow_pass)

func _draw_polyline_menace(points: PackedVector2Array, color: Color, width: float, is_glow_pass: bool) -> void:
	if points.size() < 2:
		return
	
	# Apply glitch displacement and corrupt distortion
	var modified := PackedVector2Array()
	for p in points:
		var pt := p
		# Glitch: offset based on Y position
		if _glitch_active and glitch_enabled and not is_glow_pass:
			pt.x += _get_glitch_offset_for_y(pt.y)
		# Corrupt: vertex-level random displacement
		if _corrupt_active and corrupt_flash_enabled:
			pt = _corrupt_point(pt)
		modified.append(pt)
	
	# Clamp alpha for glow passes
	var draw_col := color
	if is_glow_pass:
		draw_col.a = clamp(color.a, 0.0, 1.0)
	
	draw_polyline(modified, draw_col, width, true)

func _draw_polyline_if_set(points: PackedVector2Array) -> void:
	if points.size() >= 2:
		draw_polyline(points, face_color, line_width, true)

func _do_mirror() -> void:
	if eye_frames.size() == 0:
		return
	var eyes: PolybiusEyes = eye_frames[current_eye_frame]
#	print("\n--- Mirrored frame ", current_eye_frame, " (center_x = ", center_x, ") ---")
#	print("right_eye:     ", _mirror_points(eyes.left_eye))
#	print("right_pupil:   ", _mirror_points(eyes.left_pupil))
#	print("right_eyebrow: ", _mirror_points(eyes.left_eyebrow))
#	print("---")

func _mirror_points(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(Vector2(center_x * 2.0 - p.x, p.y))
	return result