# CRT Controller. Manages the lightweight CRT post-processing pipeline for the Arcade Orchestrator.
# Self-building: creates its own ColorRect (shader) + TextureRects (overlays) + persistence SubViewport.
# Uses Node2D with z_index instead of CanvasLayer — CanvasLayer + SCREEN_TEXTURE doesn't work
# in GL Compatibility mode because the shader reads the layer's own empty canvas, not the game.
# All shader parameters are exported as inspector-tunable presets for raster and vector modes.

extends Node2D

# z_index for rendering on top of all game content
const OVERLAY_Z: int = 4096

# --- Raster mode preset (scanlines on, phosphor off) ---
@export_group("Raster Mode (Standard CRT)")

@export_range(0.0, 0.3) var raster_warp: float = 0.1
@export_range(0.0, 10.0) var raster_aberration: float = 0.75
@export_range(0.0, 4.0) var raster_vignette: float = 0.15
@export_range(0.0, 2.0) var raster_bloom_amount: float = 0.2
@export_range(0.0, 2.0) var raster_bloom_threshold: float = 0.5
@export_range(0.0, 0.5) var raster_roll_brightness: float = 0.025
@export_range(0.0, 0.1) var raster_flicker: float = 0.0025
@export_range(0.5, 2.0) var raster_brightness: float = 1.0
@export_range(0.5, 3.0) var raster_contrast: float = 1.2

# --- Vector mode preset (phosphor on, scanlines off, persistence on) ---
@export_group("Vector Mode (Vector Monitor)")

@export_range(0.0, 0.3) var vector_warp: float = 0.1
@export_range(0.0, 10.0) var vector_aberration: float = 1.0
@export_range(0.0, 4.0) var vector_vignette: float = 0.15
@export_range(0.0, 2.0) var vector_bloom_amount: float = 0.5
@export_range(0.0, 2.0) var vector_bloom_threshold: float = 0.3
@export_range(0.0, 0.5) var vector_roll_brightness: float = 0.025
@export_range(0.0, 0.1) var vector_flicker: float = 0.01
@export_range(0.5, 2.0) var vector_brightness: float = 1.2
@export_range(0.5, 3.0) var vector_contrast: float = 1.4

# --- Persistence (phosphor decay, vector mode only) ---
@export_group("Persistence (Phosphor Decay)")

@export_range(0.0, 0.98) var vector_decay: float = 0.44
@export_range(0.0, 1.0) var vector_persistence_blend: float = 0.15

# --- Overlay controls ---
@export_group("Overlay Opacity")

@export_range(0.0, 1.0) var scanline_overlay_opacity: float = 0.3
@export_range(0.0, 1.0) var phosphor_overlay_opacity: float = 0.25
@export_range(0.0, 1.0) var noise_overlay_opacity: float = 0.1

# --- Animation ---
@export_group("Animation")

@export var roll_speed: float = 0.02

# --- Internal state ---
var _color_rect: ColorRect
var _scanlines_rect: TextureRect
var _phosphor_rect: TextureRect
var _noise_rect: TextureRect
var _material: ShaderMaterial
var _persistence_vp: SubViewport
var _persistence_rect: ColorRect
var _persistence_mat: ShaderMaterial
var _vector_mode: bool = false

func _ready() -> void:
	# Render on top of everything (z_index 4096 is the max)
	z_index = OVERLAY_Z
	z_as_relative = false
	
	_build_nodes()
	_material = _color_rect.material as ShaderMaterial
	_persistence_mat = _persistence_rect.material as ShaderMaterial
	_vector_mode = false
	
	print("CRT controller ready (Node2D mode, z=", z_index, ")")

func _build_nodes() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	
	# 0. BackBufferCopy — captures game content so SCREEN_TEXTURE has data.
	#    Required in GL Compatibility mode; must be added BEFORE the shader rect.
	var bbc := BackBufferCopy.new()
	bbc.name = "BackBufferCopy"
	bbc.rect = Rect2(0, 0, vp_size.x, vp_size.y)
	add_child(bbc)
	
	# 1. Persistence SubViewport — accumulates previous frames for phosphor trails.
	#    CLEAR_MODE_NEVER retains previous content.
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
	_persistence_mat.set_shader_parameter("decay", vector_decay)
	_persistence_mat.set_shader_parameter("enabled", 0.0)
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
	shader_mat.set_shader_parameter("persistence_blend", 0.0)
	_color_rect.material = shader_mat
	add_child(_color_rect)
	
	# 3. Scanlines overlay (raster mode)
	_scanlines_rect = _create_overlay("ScanlinesOverlay", "res://Assets/CRT/scanlines.png", vp_size)
	_scanlines_rect.stretch_mode = TextureRect.STRETCH_TILE
	_scanlines_rect.modulate.a = scanline_overlay_opacity
	add_child(_scanlines_rect)
	
	# 4. Phosphor grid overlay (vector mode)
	_phosphor_rect = _create_overlay("PhosphorOverlay", "res://Assets/CRT/phosphor_grid.png", vp_size)
	_phosphor_rect.stretch_mode = TextureRect.STRETCH_TILE
	_phosphor_rect.modulate.a = phosphor_overlay_opacity
	add_child(_phosphor_rect)
	
	# 5. Noise overlay (always on)
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
	
	# Push exported values to shader every frame so inspector changes are live
	if _vector_mode:
		_material.set_shader_parameter("warp_amount", vector_warp)
		_material.set_shader_parameter("aberration_amount", vector_aberration)
		_material.set_shader_parameter("vignette_intensity", vector_vignette)
		_material.set_shader_parameter("bloom_amount", vector_bloom_amount)
		_material.set_shader_parameter("bloom_threshold", vector_bloom_threshold)
		_material.set_shader_parameter("roll_brightness", vector_roll_brightness)
		_material.set_shader_parameter("flicker_amount", vector_flicker)
		_material.set_shader_parameter("brightness", vector_brightness)
		_material.set_shader_parameter("contrast", vector_contrast)
		# Persistence (vector only)
		_material.set_shader_parameter("persistence_blend", vector_persistence_blend)
		if _persistence_mat:
			_persistence_mat.set_shader_parameter("enabled", 1.0)
			_persistence_mat.set_shader_parameter("decay", vector_decay)
			_persistence_mat.set_shader_parameter("game_frame", get_viewport().get_texture())
	else:
		_material.set_shader_parameter("warp_amount", raster_warp)
		_material.set_shader_parameter("aberration_amount", raster_aberration)
		_material.set_shader_parameter("vignette_intensity", raster_vignette)
		_material.set_shader_parameter("bloom_amount", raster_bloom_amount)
		_material.set_shader_parameter("bloom_threshold", raster_bloom_threshold)
		_material.set_shader_parameter("roll_brightness", raster_roll_brightness)
		_material.set_shader_parameter("flicker_amount", raster_flicker)
		_material.set_shader_parameter("brightness", raster_brightness)
		_material.set_shader_parameter("contrast", raster_contrast)
		# No persistence in raster mode
		_material.set_shader_parameter("persistence_blend", 0.0)
		if _persistence_mat:
			_persistence_mat.set_shader_parameter("enabled", 0.0)
	
	# Feed persistence SubViewport texture to main CRT shader
	if _persistence_vp:
		_material.set_shader_parameter("persistence_tex", _persistence_vp.get_texture())
	
	# Scroll the hum bar
	var current_y: float = _material.get_shader_parameter("roll_y") if _material.get_shader_parameter("roll_y") != null else 0.0
	_material.set_shader_parameter("roll_y", fmod(current_y + roll_speed * delta, 1.0))
	
	# Update overlay opacities live
	if _scanlines_rect:
		_scanlines_rect.visible = not _vector_mode
		_scanlines_rect.modulate.a = scanline_overlay_opacity
	if _phosphor_rect:
		_phosphor_rect.visible = _vector_mode
		_phosphor_rect.modulate.a = phosphor_overlay_opacity
	if _noise_rect:
		_noise_rect.modulate.a = noise_overlay_opacity
	
	# Scroll noise texture for animated static
	if _noise_rect and _noise_rect.visible:
		_noise_rect.position.x = fmod(_noise_rect.position.x + delta * 30.0, 64.0)
		_noise_rect.position.y = fmod(_noise_rect.position.y + delta * 15.0, 64.0)

# Configure for vector monitor vs raster mode
func set_vector_mode(enabled: bool) -> void:
	_vector_mode = enabled
