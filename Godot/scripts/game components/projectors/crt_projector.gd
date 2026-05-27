## CRT post-processing pipeline for V2
class_name CRTProjector extends CDGameComponent

const OVERLAY_Z: int = 4096

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

@export_group("Persistence (Phosphor Decay)")

@export_range(0.0, 0.98) var persistence_decay: float = 0.66:
	set(v): persistence_decay = v; _params_dirty = true
@export_range(0.0, 1.0) var persistence_blend: float = 0.22:
	set(v): persistence_blend = v; _params_dirty = true

@export_group("Overlay Opacity")

@export_range(0.0, 1.0) var scanline_overlay_opacity: float = 0.3:
	set(v): scanline_overlay_opacity = v; _params_dirty = true
@export_range(0.0, 1.0) var noise_overlay_opacity: float = 0.1:
	set(v): noise_overlay_opacity = v; _params_dirty = true

@export_group("Animation")

@export var roll_speed: float = 0.02:
	set(v): roll_speed = v; _params_dirty = true

@export_group("Listen Signals")
@export var on_crt_on: Array[StringName] = [&"crt_on"]
@export var on_crt_off: Array[StringName] = [&"crt_off"]

var _color_rect: ColorRect
var _scanlines_rect: TextureRect
var _noise_rect: TextureRect
var _material: ShaderMaterial
var _persistence_vp: SubViewport
var _persistence_rect: ColorRect
var _persistence_mat: ShaderMaterial
var _params_dirty: bool = true

func _on_initialize() -> void:
	z_index = OVERLAY_Z
	z_as_relative = false
	
	_build_nodes()
	_material = _color_rect.material as ShaderMaterial
	_persistence_mat = _persistence_rect.material as ShaderMaterial
	
	for sig in on_crt_on:
		game.bus_connect(sig, _on_crt_on)
	for sig in on_crt_off:
		game.bus_connect(sig, _on_crt_off)


func _on_crt_on() -> void:
	visible = true

func _on_crt_off() -> void:
	visible = false

func _build_nodes() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	
	# 0. BackBufferCopy — captures game content so SCREEN_TEXTURE has data
	var bbc := BackBufferCopy.new()
	bbc.name = "BackBufferCopy"
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc)
	
	# 1. persistence SubViewport — accumulates previous frames for phosphor trails
	_persistence_vp = SubViewport.new()
	_persistence_vp.name = "PersistenceVP"
	_persistence_vp.size = vp_size
	_persistence_vp.transparent_bg = false
	_persistence_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_persistence_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_persistence_vp)
	
	# persistence ColorRect with accumulation shader, fills the SubViewport
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
	
	# 2. CRT Shader ColorRect — full-screen post-processing
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
	
	# 3. scanlines overlay (always on)
	_scanlines_rect = _create_overlay("ScanlinesOverlay", "res://assets/crt/scanlines.png", vp_size)
	_scanlines_rect.stretch_mode = TextureRect.STRETCH_TILE
	_scanlines_rect.modulate.a = scanline_overlay_opacity
	add_child(_scanlines_rect)
	
	# 4. noise overlay (always on)
	_noise_rect = _create_overlay("NoiseOverlay", "res://assets/crt/noise.png", vp_size)
	_noise_rect.stretch_mode = TextureRect.STRETCH_TILE
	_noise_rect.size = Vector2(704, 424)  # larger than viewport for seamless scroll
	_noise_rect.modulate.a = noise_overlay_opacity
	add_child(_noise_rect)

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

## visual element, uses _process, NOT _physics_process
func _process(delta: float) -> void:
	if not _material:
		return
	
	# dirty flag params update
	if _params_dirty:
		_push_params()
		_params_dirty = false
	
	# always animate: hum bar scroll
	var current_y: float = _material.get_shader_parameter("roll_y") if _material.get_shader_parameter("roll_y") != null else 0.0
	_material.set_shader_parameter("roll_y", fmod(current_y + roll_speed * delta, 1.0))
	
	# always animate: scroll noise texture for animated static
	if _noise_rect and _noise_rect.visible:
		_noise_rect.position.x = fmod(_noise_rect.position.x + delta * 30.0, 64.0)
		_noise_rect.position.y = fmod(_noise_rect.position.y + delta * 15.0, 64.0)

# push all shader parameters and overlay settings to GPU
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
	
	# persistence (always on)
	_material.set_shader_parameter("persistence_blend", persistence_blend)
	if _persistence_mat:
		_persistence_mat.set_shader_parameter("decay", persistence_decay)
		_persistence_mat.set_shader_parameter("game_frame", get_viewport().get_texture())
	
	# feed persistence SubViewport texture to main CRT shader
	if _persistence_vp:
		_material.set_shader_parameter("persistence_tex", _persistence_vp.get_texture())
	
	# update overlay opacity
	if _scanlines_rect:
		_scanlines_rect.modulate.a = scanline_overlay_opacity
	if _noise_rect:
		_noise_rect.modulate.a = noise_overlay_opacity

## self cleanup
func _exit_tree() -> void:
	if game:
		for sig in on_crt_on:
			game.bus_disconnect(sig, _on_crt_on)
		for sig in on_crt_off:
			game.bus_disconnect(sig, _on_crt_off)
