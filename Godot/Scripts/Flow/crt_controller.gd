# CRT Controller. Manages the lightweight CRT post-processing pipeline for the Arcade Orchestrator.
# Self-building: creates its own ColorRect (shader) + TextureRects (overlays) + persistence SubViewport.
# Uses Node2D with z_index instead of CanvasLayer — CanvasLayer + SCREEN_TEXTURE doesn't work
# in GL Compatibility mode because the shader reads the layer's own empty canvas, not the game.
# Phosphor persistence is always enabled for authentic CRT glow. Single mode, no switching.

extends Node2D

# z_index for rendering on top of all game content
const OVERLAY_Z: int = 4096

# --- CRT shader parameters ---
@export_group("CRT Effects")

@export_range(0.0, 0.3) var warp: float = 0.1:
	set(v): warp = v; _params_dirty = true
@export_range(0.0, 10.0) var aberration: float = 0.75:
	set(v): aberration = v; _params_dirty = true
@export_range(0.0, 4.0) var vignette: float = 0.15:
	set(v): vignette = v; _params_dirty = true
@export_range(0.0, 2.0) var bloom_amount: float = 0.2:
	set(v): bloom_amount = v; _params_dirty = true
@export_range(0.0, 2.0) var bloom_threshold: float = 0.5:
	set(v): bloom_threshold = v; _params_dirty = true
@export_range(0.0, 0.5) var roll_brightness: float = 0.05:
	set(v): roll_brightness = v; _params_dirty = true
@export_range(0.0, 0.1) var flicker: float = 0.0025:
	set(v): flicker = v; _params_dirty = true
@export_range(0.5, 2.0) var brightness: float = 1.0:
	set(v): brightness = v; _params_dirty = true
@export_range(0.5, 3.0) var gamma: float = 1.2:
	set(v): gamma = v; _params_dirty = true

# --- Persistence (phosphor decay, always on) ---
@export_group("Persistence (Phosphor Decay)")

@export_range(0.0, 0.98) var persistence_decay: float = 0.66:
	set(v): persistence_decay = v; _params_dirty = true
@export_range(0.0, 1.0) var persistence_blend: float = 0.22:
	set(v): persistence_blend = v; _params_dirty = true

# --- Overlay controls ---
@export_group("Overlay Opacity")

@export_range(0.0, 1.0) var scanline_overlay_opacity: float = 0.3:
	set(v): scanline_overlay_opacity = v; _params_dirty = true
@export_range(0.0, 1.0) var noise_overlay_opacity: float = 0.1:
	set(v): noise_overlay_opacity = v; _params_dirty = true

# --- Animation ---
@export_group("Animation")

@export var roll_speed: float = 0.02:
	set(v): roll_speed = v; _params_dirty = true

# --- Internal state ---
var _color_rect: ColorRect
var _scanlines_rect: TextureRect
var _noise_rect: TextureRect
var _material: ShaderMaterial
var _persistence_vp: SubViewport
var _persistence_rect: ColorRect
var _persistence_mat: ShaderMaterial
var _params_dirty: bool = true

func _ready() -> void:
	# Render on top of everything (z_index 4096 is the max)
	z_index = OVERLAY_Z
	z_as_relative = false
	
	_build_nodes()
	_material = _color_rect.material as ShaderMaterial
	_persistence_mat = _persistence_rect.material as ShaderMaterial
	
	print("CRT controller ready (Node2D mode, z=", z_index, ")")

func _build_nodes() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	
	# 0. BackBufferCopy — captures game content so SCREEN_TEXTURE has data.
	#    Required in GL Compatibility mode; must be added BEFORE the shader rect.
	#    COPY_MODE_VIEWPORT captures the entire viewport regardless of resolution or
	#    scale factor — avoids the "right half missing" bug when framebuffer size
	#    differs from canvas size (integer scaling, fullscreen, web export).
	var bbc := BackBufferCopy.new()
	bbc.name = "BackBufferCopy"
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc)
	
	# 1. Persistence SubViewport — accumulates previous frames for phosphor trails.
	#    CLEAR_MODE_NEVER retains previous content. Always active.
	_persistence_vp = SubViewport.new()
	_persistence_vp.name = "PersistenceVP"
	_persistence_vp.size = vp_size
	_persistence_vp.transparent_bg = false
	_persistence_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_persistence_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_persistence_vp)
	
	# Persistence ColorRect with accumulation shader, fills the SubViewport
	_persistence_rect = ColorRect.new()
	_persistence_rect.name = "PersistenceAccumulator"
	_persistence_rect.position = Vector2.ZERO
	_persistence_rect.size = vp_size
	_persistence_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_persistence_mat = ShaderMaterial.new()
	_persistence_mat.shader = load("res://Shaders/persistence.gdshader")
	_persistence_mat.set_shader_parameter("decay", persistence_decay)
	_persistence_mat.set_shader_parameter("game_frame", get_viewport().get_texture())
	_persistence_rect.material = _persistence_mat
	_persistence_vp.add_child(_persistence_rect)
	
	# 2. CRT Shader ColorRect — full-screen post-processing
	_color_rect = ColorRect.new()
	_color_rect.name = "CRTShader"
	_color_rect.position = Vector2.ZERO
	_color_rect.size = vp_size
	_color_rect.z_index = OVERLAY_Z
	_color_rect.z_as_relative = false
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://Shaders/crt_light.gdshader")
	shader_mat.set_shader_parameter("resolution", vp_size)
	shader_mat.set_shader_parameter("persistence_blend", persistence_blend)
	shader_mat.set_shader_parameter("persistence_tex", _persistence_vp.get_texture())
	_color_rect.material = shader_mat
	add_child(_color_rect)
	
	# 3. Scanlines overlay (always on)
	_scanlines_rect = _create_overlay("ScanlinesOverlay", "res://Assets/CRT/scanlines.png", vp_size)
	_scanlines_rect.stretch_mode = TextureRect.STRETCH_TILE
	_scanlines_rect.modulate.a = scanline_overlay_opacity
	add_child(_scanlines_rect)
	
	# 4. Noise overlay (always on)
	_noise_rect = _create_overlay("NoiseOverlay", "res://Assets/CRT/noise.png", vp_size)
	_noise_rect.stretch_mode = TextureRect.STRETCH_TILE
	_noise_rect.size = Vector2(704, 424)  # Larger than viewport for seamless scroll
	_noise_rect.modulate.a = noise_overlay_opacity
	add_child(_noise_rect)

func _create_overlay(name: String, texture_path: String, vp_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = name
	rect.texture = load(texture_path)
	rect.position = Vector2.ZERO
	rect.size = vp_size
	rect.z_index = OVERLAY_Z
	rect.z_as_relative = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect

func _process(delta: float) -> void:
	if not _material:
		return
	
	# Only push shader params when dirty (inspector tweak).
	# Eliminates ~20+ set_shader_parameter WASM bridge calls per frame in production.
	if _params_dirty:
		_push_params()
		_params_dirty = false
	
	# Always animate: hum bar scroll
	var current_y: float = _material.get_shader_parameter("roll_y") if _material.get_shader_parameter("roll_y") != null else 0.0
	_material.set_shader_parameter("roll_y", fmod(current_y + roll_speed * delta, 1.0))
	
	# Always animate: scroll noise texture for animated static
	if _noise_rect and _noise_rect.visible:
		_noise_rect.position.x = fmod(_noise_rect.position.x + delta * 30.0, 64.0)
		_noise_rect.position.y = fmod(_noise_rect.position.y + delta * 15.0, 64.0)

# Push all shader parameters and overlay settings to GPU.
# Called only when _params_dirty is true (inspector tweak, not every frame).
func _push_params() -> void:
	_material.set_shader_parameter("warp_amount", warp)
	_material.set_shader_parameter("aberration_amount", aberration)
	_material.set_shader_parameter("vignette_intensity", vignette)
	_material.set_shader_parameter("bloom_amount", bloom_amount)
	_material.set_shader_parameter("bloom_threshold", bloom_threshold)
	_material.set_shader_parameter("roll_brightness", roll_brightness)
	_material.set_shader_parameter("flicker_amount", flicker)
	_material.set_shader_parameter("brightness", brightness)
	_material.set_shader_parameter("gamma", gamma)
	
	# Persistence (always on)
	_material.set_shader_parameter("persistence_blend", persistence_blend)
	if _persistence_mat:
		_persistence_mat.set_shader_parameter("decay", persistence_decay)
		_persistence_mat.set_shader_parameter("game_frame", get_viewport().get_texture())
	
	# Feed persistence SubViewport texture to main CRT shader
	if _persistence_vp:
		_material.set_shader_parameter("persistence_tex", _persistence_vp.get_texture())
	
	# Update overlay opacity
	if _scanlines_rect:
		_scanlines_rect.modulate.a = scanline_overlay_opacity
	if _noise_rect:
		_noise_rect.modulate.a = noise_overlay_opacity