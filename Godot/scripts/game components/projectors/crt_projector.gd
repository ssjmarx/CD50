## CRTProjector
## Full-screen CRT post-processing pipeline with phosphor persistence, warp, and overlays
## Builds a node hierarchy at runtime: BackBufferCopy → Persistence VP → CRT shader → scanlines → noise

class_name CRTProjector extends CDGameComponent

## --- constants ---

## z-index for overlay rendering (renders on top of everything)
const OVERLAY_Z: int = 4096

## --- exports: CRT effects ---

## barrel distortion amount
@export_group("CRT Effects")
@export_range(0.0, 0.3) var warp: float = 0.1:
	set(v): warp = v; _params_dirty = true
## chromatic aberration offset
@export_range(0.0, 10.0) var aberration: float = 0.75:
	set(v): aberration = v; _params_dirty = true
## edge darkening intensity
@export_range(0.0, 4.0) var vignette: float = 0.15:
	set(v): vignette = v; _params_dirty = true
## bloom spread amount
@export_range(0.0, 2.0) var bloom_amount: float = 0.2:
	set(v): bloom_amount = v; _params_dirty = true
## brightness threshold for bloom activation
@export_range(0.0, 2.0) var bloom_threshold: float = 0.5:
	set(v): bloom_threshold = v; _params_dirty = true
## rolling hum bar brightness
@export_range(0.0, 0.5) var roll_brightness: float = 0.05:
	set(v): roll_brightness = v; _params_dirty = true
## random brightness flicker amount
@export_range(0.0, 0.1) var flicker: float = 0.0025:
	set(v): flicker = v; _params_dirty = true
## overall brightness multiplier
@export_range(0.5, 2.0) var brightness: float = 1.0:
	set(v): brightness = v; _params_dirty = true
## gamma correction curve
@export_range(0.5, 3.0) var gamma: float = 1.2:
	set(v): gamma = v; _params_dirty = true

## --- exports: persistence ---

## phosphor trail fade rate (higher = longer trails)
@export_group("Persistence (Phosphor Decay)")
@export_range(0.0, 0.98) var persistence_decay: float = 0.66:
	set(v): persistence_decay = v; _params_dirty = true
## how much phosphor blends into the main image
@export_range(0.0, 1.0) var persistence_blend: float = 0.22:
	set(v): persistence_blend = v; _params_dirty = true

## --- exports: overlay opacity ---

## scanline texture transparency
@export_group("Overlay Opacity")
@export_range(0.0, 1.0) var scanline_overlay_opacity: float = 0.3:
	set(v): scanline_overlay_opacity = v; _params_dirty = true
## noise texture transparency
@export_range(0.0, 1.0) var noise_overlay_opacity: float = 0.1:
	set(v): noise_overlay_opacity = v; _params_dirty = true

## --- exports: animation ---

## speed of the rolling hum bar
@export_group("Animation")
@export var roll_speed: float = 0.02:
	set(v): roll_speed = v; _params_dirty = true

## --- exports: listen signals ---

## game bus signals to show/hide the CRT effect
@export_group("Listen Signals")
@export var on_crt_on: Array[StringName] = [&"crt_on"]
@export var on_crt_off: Array[StringName] = [&"crt_off"]

## --- state ---

## full-screen ColorRect with CRT shader
var _color_rect: ColorRect
## scanline texture overlay
var _scanlines_rect: TextureRect
## noise texture overlay
var _noise_rect: TextureRect
## main CRT shader material
var _material: ShaderMaterial
## SubViewport for phosphor persistence accumulation
var _persistence_vp: SubViewport
## ColorRect inside persistence VP with accumulation shader
var _persistence_rect: ColorRect
## persistence accumulation shader material
var _persistence_mat: ShaderMaterial
## flag to push shader params on next frame
var _params_dirty: bool = true

## --- lifecycle ---

## build node hierarchy, cache materials, connect bus signals
func _on_initialize() -> void:
	z_index = OVERLAY_Z
	z_as_relative = false
	
	_build_nodes()
	_material = _color_rect.material as ShaderMaterial
	_persistence_mat = _persistence_rect.material as ShaderMaterial
	
	## connect visibility toggle signals
	for sig in on_crt_on:
		game.bus_connect(sig, _on_crt_on)
	for sig in on_crt_off:
		game.bus_connect(sig, _on_crt_off)

## disconnect bus signals on removal
func _exit_tree() -> void:
	if game:
		for sig in on_crt_on:
			game.bus_disconnect(sig, _on_crt_on)
		for sig in on_crt_off:
			game.bus_disconnect(sig, _on_crt_off)

## --- visibility ---

## show the CRT overlay
func _on_crt_on() -> void:
	visible = true

## hide the CRT overlay
func _on_crt_off() -> void:
	visible = false

## --- node construction ---

## build the full rendering pipeline as child nodes
func _build_nodes() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	
	## BackBufferCopy captures game content for SCREEN_TEXTURE
	var bbc := BackBufferCopy.new()
	bbc.name = "BackBufferCopy"
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc)
	
	## persistence SubViewport accumulates previous frames for phosphor trails
	_persistence_vp = SubViewport.new()
	_persistence_vp.name = "PersistenceVP"
	_persistence_vp.size = vp_size
	_persistence_vp.transparent_bg = false
	_persistence_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_persistence_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_persistence_vp)
	
	## persistence ColorRect with decay shader fills the SubViewport
	_persistence_rect = ColorRect.new()
	_persistence_rect.name = "PersistenceAccumulator"
	_persistence_rect.position = Vector2.ZERO
	_persistence_rect.size = vp_size
	_persistence_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_persistence_mat = ShaderMaterial.new()
	_persistence_mat.shader = load("res://shaders/persistence.gdshader")
	_persistence_mat.set_shader_parameter("decay", persistence_decay)
	_persistence_mat.set_shader_parameter("game_frame", get_viewport().get_texture())
	_persistence_rect.material = _persistence_mat
	_persistence_vp.add_child(_persistence_rect)
	
	## CRT shader ColorRect applies all post-processing effects
	_color_rect = ColorRect.new()
	_color_rect.name = "CRTShader"
	_color_rect.position = Vector2.ZERO
	_color_rect.size = vp_size
	_color_rect.z_index = OVERLAY_Z
	_color_rect.z_as_relative = false
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/crt_light.gdshader")
	shader_mat.set_shader_parameter("resolution", vp_size)
	shader_mat.set_shader_parameter("persistence_blend", persistence_blend)
	shader_mat.set_shader_parameter("persistence_tex", _persistence_vp.get_texture())
	_color_rect.material = shader_mat
	add_child(_color_rect)
	
	## scanline texture overlay (tiled)
	_scanlines_rect = _create_overlay("ScanlinesOverlay", "res://assets/crt/scanlines.png", vp_size)
	_scanlines_rect.stretch_mode = TextureRect.STRETCH_TILE
	_scanlines_rect.modulate.a = scanline_overlay_opacity
	add_child(_scanlines_rect)
	
	## noise texture overlay (scrolling for animated static)
	_noise_rect = _create_overlay("NoiseOverlay", "res://assets/crt/noise.png", vp_size)
	_noise_rect.stretch_mode = TextureRect.STRETCH_TILE
	_noise_rect.size = Vector2(704, 424)
	_noise_rect.modulate.a = noise_overlay_opacity
	add_child(_noise_rect)

## create a fullscreen TextureRect overlay with standard settings
func _create_overlay(overlay_name: String, texture_path: String, vp_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = overlay_name
	rect.texture = load(texture_path)
	rect.position = Vector2.ZERO
	rect.size = vp_size
	rect.z_index = OVERLAY_Z
	rect.z_as_relative = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect

## --- processing ---

## push dirty params, animate hum bar and noise scroll
func _process(delta: float) -> void:
	if not _material:
		return
	
	if _params_dirty:
		_push_params()
		_params_dirty = false
	
	var current_y: float = _material.get_shader_parameter("roll_y") if _material.get_shader_parameter("roll_y") != null else 0.0
	_material.set_shader_parameter("roll_y", fmod(current_y + roll_speed * delta, 1.0))
	
	if _noise_rect and _noise_rect.visible:
		_noise_rect.position.x = fmod(_noise_rect.position.x + delta * 30.0, 64.0)
		_noise_rect.position.y = fmod(_noise_rect.position.y + delta * 15.0, 64.0)

## --- shader params ---

## push all shader parameters and overlay settings to GPU
func _push_params() -> void:
	## main CRT shader params
	_material.set_shader_parameter("warp_amount", warp)
	_material.set_shader_parameter("aberration_amount", aberration)
	_material.set_shader_parameter("vignette_intensity", vignette)
	_material.set_shader_parameter("bloom_amount", bloom_amount)
	_material.set_shader_parameter("bloom_threshold", bloom_threshold)
	_material.set_shader_parameter("roll_brightness", roll_brightness)
	_material.set_shader_parameter("flicker_amount", flicker)
	_material.set_shader_parameter("brightness", brightness)
	_material.set_shader_parameter("gamma", gamma)
	
	## persistence params
	_material.set_shader_parameter("persistence_blend", persistence_blend)
	if _persistence_mat:
		_persistence_mat.set_shader_parameter("decay", persistence_decay)
		_persistence_mat.set_shader_parameter("game_frame", get_viewport().get_texture())
	
	if _persistence_vp:
		_material.set_shader_parameter("persistence_tex", _persistence_vp.get_texture())
	
	## update overlay opacity
	if _scanlines_rect:
		_scanlines_rect.modulate.a = scanline_overlay_opacity
	if _noise_rect:
		_noise_rect.modulate.a = noise_overlay_opacity
