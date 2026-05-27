@tool

## vector face with CRT menace effects: glitch, static, glow, scan, corrupt
class_name MenacingVectorFace extends VectorFace

@export_group("Glitch")
@export var glitch_enabled: bool = true
@export_range(0.0, 1.0) var glitch_chance: float = 0.06
@export_range(0.0, 30.0) var glitch_intensity: float = 3.0
@export_range(1.0, 20.0) var glitch_band_height: float = 4.0

@export_group("Static")
@export var static_enabled: bool = true
@export_range(0.0, 1.0) var static_chance: float = 0.04
@export_range(0.0, 0.1) var static_density: float = 0.03
@export_range(1.0, 4.0) var static_size: float = 1.5

@export_group("Glow")
@export var glow_enabled: bool = true
@export_range(0, 5) var glow_passes: int = 2
@export_range(2.0, 12.0) var glow_base_width: float = 4.0
@export_range(0.0, 1.0) var glow_intensity: float = 0.25
@export_range(0.0, 10.0) var glow_pulse_speed: float = 1.5
@export_range(0.0, 1.0) var glow_pulse_amount: float = 0.15

@export_group("Scan")
@export var scan_enabled: bool = true
@export_range(0.0, 1.0) var scan_chance: float = 0.03
@export_range(1.0, 6.0) var scan_thickness: float = 2.0
@export_range(0.0, 1.0) var scan_brightness: float = 0.3

@export_group("Corrupt")
@export var corrupt_enabled: bool = true
@export_range(0.0, 1.0) var corrupt_chance: float = 0.015
@export_range(0.0, 40.0) var corrupt_displacement: float = 8.0

@export_group("Listen Signals")
@export var trigger_glitch: Array[StringName] = []
@export var trigger_corrupt: Array[StringName] = []
@export var trigger_static: Array[StringName] = []

# --- menace runtime state ---
var _glitch_active: bool = false
var _glitch_timer: float = 0.0
var _glitch_slices: Array = []          # [{y_start, y_end, x_offset}]

var _static_active: bool = false
var _static_particles: Array = []       # [{x, y}]

var _scan_active: bool = false
var _scan_y: float = 0.0

var _corrupt_active: bool = false
var _corrupt_timer: float = 0.0
var _corrupt_seed: int = 0

var _elapsed: float = 0.0

func _on_initialize() -> void:
	super._on_initialize()

	for sig in trigger_glitch:
		entity.connect(sig, _force_glitch)
	for sig in trigger_corrupt:
		entity.connect(sig, _force_corrupt)
	for sig in trigger_static:
		entity.connect(sig, _force_static)

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		_elapsed += delta
		queue_redraw()
		return
	_elapsed += delta
	_update_menace(delta)
	queue_redraw()

### signal handlers force an immediate effect flash

func _force_glitch(_arg = null) -> void:
	_glitch_active = true
	_glitch_timer = randf_range(0.06, 0.15)
	_generate_glitch_slices()

func _force_corrupt(_arg = null) -> void:
	_corrupt_active = true
	_corrupt_timer = randf_range(0.05, 0.12)
	_corrupt_seed = randi()

func _force_static(_arg = null) -> void:
	_static_active = true
	_generate_static_particles()

### general menace, updates per frame

func _update_menace(delta: float) -> void:
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

	if static_enabled:
		if _static_active:
			_static_particles.clear()
			_generate_static_particles()
			if randf() > static_chance * 3.0:
				_static_active = false
		else:
			_static_particles.clear()
			if randf() < static_chance:
				_static_active = true
				_generate_static_particles()
	else:
		_static_active = false
		_static_particles.clear()

	if scan_enabled:
		if _scan_active:
			_scan_y += delta * 800.0
			if _scan_y > 360.0:
				_scan_active = false
		else:
			if randf() < scan_chance:
				_scan_active = true
				_scan_y = -20.0
	else:
		_scan_active = false

	if corrupt_enabled:
		if _corrupt_active:
			_corrupt_timer -= delta
			if _corrupt_timer <= 0.0:
				_corrupt_active = false
		else:
			if randf() < corrupt_chance:
				_corrupt_active = true
				_corrupt_timer = randf_range(0.03, 0.08)
				_corrupt_seed = randi()
	else:
		_corrupt_active = false

func _generate_glitch_slices() -> void:
	_glitch_slices.clear()
	var num_slices: int = randi_range(1, 4)
	for _i in num_slices:
		var y_start: float = randf_range(0.0, 360.0)
		var y_end: float = y_start + randf_range(glitch_band_height, glitch_band_height * 4.0)
		var x_off: float = randf_range(-glitch_intensity, glitch_intensity)
		_glitch_slices.append({"y_start": y_start, "y_end": y_end, "x_offset": x_off})

func _generate_static_particles() -> void:
	_static_particles.clear()
	var count: int = int(static_density * 500.0)
	for _i in count:
		_static_particles.append({
			"x": randf_range(0.0, 640.0),
			"y": randf_range(0.0, 360.0)
		})

func _get_glitch_offset(y: float) -> float:
	if not _glitch_active:
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

func _draw() -> void:
	if _current_points.size() < 2:
		return

	var modified := PackedVector2Array()
	for p in _current_points:
		var pt := p
		if _glitch_active and glitch_enabled:
			pt.x += _get_glitch_offset(pt.y)
			
		if _corrupt_active and corrupt_enabled:
			pt = _corrupt_point(pt)
		modified.append(pt)

	var draw_color := color
	if _corrupt_active and corrupt_enabled:
		draw_color = Color(color.g, color.r, color.b * 0.5, color.a)

	var pulse: float = 0.0
	if glow_enabled:
		pulse = sin(_elapsed * glow_pulse_speed) * glow_pulse_amount

	if glow_enabled and glow_passes > 0:
		for i in glow_passes:
			var extra_w: float = glow_base_width * float(i + 1)
			var alpha: float = clampf((glow_intensity + pulse) / float(i + 1), 0.0, 1.0)
			var glow_col := Color(draw_color.r, draw_color.g, draw_color.b, alpha)
			_draw_polyline(modified, glow_col, width + extra_w)

	_draw_polyline(modified, draw_color, width)

	if _static_active and static_enabled:
		var static_col := Color(draw_color.r, draw_color.g, draw_color.b, 0.6)
		for p in _static_particles:
			draw_rect(Rect2(p.x, p.y, static_size, static_size), static_col)

	if _scan_active and scan_enabled:
		var scan_col := Color(draw_color.r, draw_color.g, draw_color.b, scan_brightness)
		draw_rect(Rect2(0.0, _scan_y, 640.0, scan_thickness), scan_col)
		# trailing faint line
		var trail_col := Color(draw_color.r, draw_color.g, draw_color.b, scan_brightness * 0.3)
		draw_rect(Rect2(0.0, _scan_y - scan_thickness * 2.0, 640.0, scan_thickness * 0.5), trail_col)

func _draw_polyline(points: PackedVector2Array, draw_color: Color, draw_width: float) -> void:
	if points.size() < 2:
		return
	if _current_closed:
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		draw_polyline(closed, draw_color, draw_width, true)
	else:
		draw_polyline(points, draw_color, draw_width, true)
