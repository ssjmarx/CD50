@tool

# MenacingVectorFace
# Extends VectorFace with CRT menace effects: glitch, static, glow, scan, corrupt
# Each effect is independently toggleable and can be triggered by entity signals

class_name MenacingVectorFace extends VectorFace

# --- glitch exports ---

@export_group("Glitch")
# enable horizontal band displacement
@export var glitch_enabled: bool = true
# per-frame probability of a glitch burst
@export_range(0.0, 1.0) var glitch_chance: float = 0.06
# max horizontal pixel offset per glitch slice
@export_range(0.0, 30.0) var glitch_intensity: float = 3.0
# min height of a glitch band in pixels
@export_range(1.0, 20.0) var glitch_band_height: float = 4.0

# --- static exports ---

@export_group("Static")
# enable random bright pixel noise
@export var static_enabled: bool = true
# per-frame probability of a static burst
@export_range(0.0, 1.0) var static_chance: float = 0.04
# density of static particles (fraction of screen)
@export_range(0.0, 0.1) var static_density: float = 0.03
# size of each static particle in pixels
@export_range(1.0, 4.0) var static_size: float = 1.5

# --- glow exports ---

@export_group("Glow")
# enable pulsing multi-pass bloom
@export var glow_enabled: bool = true
# number of glow passes (more = wider bloom)
@export_range(0, 5) var glow_passes: int = 2
# base width added per glow pass
@export_range(2.0, 12.0) var glow_base_width: float = 4.0
# glow opacity
@export_range(0.0, 1.0) var glow_intensity: float = 0.25
# speed of the glow pulse oscillation
@export_range(0.0, 10.0) var glow_pulse_speed: float = 1.5
# amplitude of the glow pulse
@export_range(0.0, 1.0) var glow_pulse_amount: float = 0.15

# --- scan exports ---

@export_group("Scan")
# enable horizontal sweep line
@export var scan_enabled: bool = true
# per-frame probability of a new scan line
@export_range(0.0, 1.0) var scan_chance: float = 0.03
# thickness of the scan line in pixels
@export_range(1.0, 6.0) var scan_thickness: float = 2.0
# brightness of the scan line
@export_range(0.0, 1.0) var scan_brightness: float = 0.3

# --- corrupt exports ---

@export_group("Corrupt")
# enable vertex displacement + color swap
@export var corrupt_enabled: bool = true
# per-frame probability of a corrupt burst
@export_range(0.0, 1.0) var corrupt_chance: float = 0.015
# max vertex displacement in pixels
@export_range(0.0, 40.0) var corrupt_displacement: float = 8.0

# --- listen signals ---

@export_group("Listen Signals")
# entity signals that force an immediate glitch flash
@export var trigger_glitch: Array[StringName] = []
# entity signals that force an immediate corrupt flash
@export var trigger_corrupt: Array[StringName] = []
# entity signals that force an immediate static flash
@export var trigger_static: Array[StringName] = []

# --- menace runtime state ---

# glitch: horizontal band displacement
var _glitch_active: bool = false
var _glitch_timer: float = 0.0
var _glitch_slices: Array = []          # [{y_start, y_end, x_offset}]

# static: random bright pixel noise
var _static_active: bool = false
var _static_particles: Array = []       # [{x, y}]

# scan: horizontal sweep line
var _scan_active: bool = false
var _scan_y: float = 0.0

# corrupt: vertex displacement + color swap
var _corrupt_active: bool = false
var _corrupt_timer: float = 0.0
var _corrupt_seed: int = 0

# elapsed time for glow pulse
var _elapsed: float = 0.0

# --- lifecycle ---

# connect signal-triggered effect handlers
func _on_initialize() -> void:
	super._on_initialize()

	for sig in trigger_glitch:
		entity.bus_connect(sig, _force_glitch)
	for sig in trigger_corrupt:
		entity.bus_connect(sig, _force_corrupt)
	for sig in trigger_static:
		entity.bus_connect(sig, _force_static)

# update elapsed time, menace effects, and redraw each frame
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

# force an immediate glitch burst with random duration
func _force_glitch() -> void:
	_glitch_active = true
	_glitch_timer = randf_range(0.06, 0.15)
	_generate_glitch_slices()

# force an immediate corrupt burst with random duration
func _force_corrupt() -> void:
	_corrupt_active = true
	_corrupt_timer = randf_range(0.05, 0.12)
	_corrupt_seed = randi()

# force an immediate static burst
func _force_static() -> void:
	_static_active = true
	_generate_static_particles()

### general menace, updates per frame

# update all enabled menace effects with random activation/deactivation
func _update_menace(delta: float) -> void:
	# glitch: random band displacement bursts
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

	# static: random pixel noise bursts
	if static_enabled:
		if _static_active:
			_static_particles.clear()
			_generate_static_particles()
			# higher chance to stop than start (short bursts)
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

	# scan: horizontal sweep line moving downward
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

	# corrupt: vertex displacement + color channel swap
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

# generate random horizontal slice definitions for glitch effect
func _generate_glitch_slices() -> void:
	_glitch_slices.clear()
	var num_slices: int = randi_range(1, 4)
	for _i in num_slices:
		var y_start: float = randf_range(0.0, 360.0)
		var y_end: float = y_start + randf_range(glitch_band_height, glitch_band_height * 4.0)
		var x_off: float = randf_range(-glitch_intensity, glitch_intensity)
		_glitch_slices.append({"y_start": y_start, "y_end": y_end, "x_offset": x_off})

# generate random particle positions for static effect
func _generate_static_particles() -> void:
	_static_particles.clear()
	var count: int = int(static_density * 500.0)
	for _i in count:
		_static_particles.append({
			"x": randf_range(0.0, 640.0),
			"y": randf_range(0.0, 360.0)
		})

# return horizontal offset for a given y position during glitch
func _get_glitch_offset(y: float) -> float:
	if not _glitch_active:
		return 0.0
	for slice in _glitch_slices:
		if y >= slice.y_start and y <= slice.y_end:
			return slice.x_offset
	return 0.0

func _on_entity_deactivating() -> void:
	for sig in trigger_glitch:
		entity.bus_disconnect(sig, _force_glitch)
	for sig in trigger_corrupt:
		entity.bus_disconnect(sig, _force_corrupt)
	for sig in trigger_static:
		entity.bus_disconnect(sig, _force_static)
	super._on_entity_deactivating()

# displace a point using seeded pseudo-random corruption
func _corrupt_point(p: Vector2) -> Vector2:
	if not _corrupt_active:
		return p
	var seed_val := _corrupt_seed
	var px := p.x + _seeded_rand(seed_val, int(p.x) * 7 + int(p.y) * 13) * corrupt_displacement
	var py := p.y + _seeded_rand(seed_val + 1, int(p.x) * 11 + int(p.y) * 3) * corrupt_displacement
	return Vector2(px, py)

# deterministic hash-based random for consistent corrupt displacement
func _seeded_rand(s: int, index: int) -> float:
	var v := s ^ (index * 1664525 + 1013904223)
	v = (v >> 16) ^ v
	v = v * 0x45d9f3b
	v = (v >> 16) ^ v
	return (float(v & 0x7FFFFFFF) / float(0x7FFFFFFF)) * 2.0 - 1.0

### drawing

# draw the base shape with menace modifications: glitch offset, corrupt displacement, glow, static, scan
func _draw() -> void:
	if _current_points.size() < 2:
		return

	# apply glitch and corrupt to all shape points
	var modified := PackedVector2Array()
	for p in _current_points:
		var pt := p
		if _glitch_active and glitch_enabled:
			pt.x += _get_glitch_offset(pt.y)
			
		if _corrupt_active and corrupt_enabled:
			pt = _corrupt_point(pt)
		modified.append(pt)

	# swap color channels during corruption
	var draw_color := color
	if _corrupt_active and corrupt_enabled:
		draw_color = Color(color.g, color.r, color.b * 0.5, color.a)

	# compute glow pulse oscillation
	var pulse: float = 0.0
	if glow_enabled:
		pulse = sin(_elapsed * glow_pulse_speed) * glow_pulse_amount

	# draw glow passes (progressively wider, semi-transparent)
	if glow_enabled and glow_passes > 0:
		for i in glow_passes:
			var extra_w: float = glow_base_width * float(i + 1)
			var alpha: float = clampf((glow_intensity + pulse) / float(i + 1), 0.0, 1.0)
			var glow_col := Color(draw_color.r, draw_color.g, draw_color.b, alpha)
			_draw_polyline(modified, glow_col, width + extra_w)

	# draw the main shape on top of glow
	_draw_polyline(modified, draw_color, width)

	# draw static noise particles
	if _static_active and static_enabled:
		var static_col := Color(draw_color.r, draw_color.g, draw_color.b, 0.6)
		for p in _static_particles:
			draw_rect(Rect2(p.x, p.y, static_size, static_size), static_col)

	# draw scan sweep line with a trailing faint line
	if _scan_active and scan_enabled:
		var scan_col := Color(draw_color.r, draw_color.g, draw_color.b, scan_brightness)
		draw_rect(Rect2(0.0, _scan_y, 640.0, scan_thickness), scan_col)
		# trailing faint line behind the scan
		var trail_col := Color(draw_color.r, draw_color.g, draw_color.b, scan_brightness * 0.3)
		draw_rect(Rect2(0.0, _scan_y - scan_thickness * 2.0, 640.0, scan_thickness * 0.5), trail_col)

# draw a polyline, optionally closing the loop
func _draw_polyline(points: PackedVector2Array, draw_color: Color, draw_width: float) -> void:
	if points.size() < 2:
		return
	if _current_closed:
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		draw_polyline(closed, draw_color, draw_width, true)
	else:
		draw_polyline(points, draw_color, draw_width, true)
