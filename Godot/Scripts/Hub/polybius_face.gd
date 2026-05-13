@tool
# Polybius vector CRT face. Draws expression from two independent channels:
#   - Eyes channel (outline, eyes, pupils, eyebrows) — controls expression
#   - Mouth channel (mouth shape) — controls lip sync
# Both combine freely: any eye frame + any mouth frame.
# All frame data is defined in PolybiusEyes and PolybiusMouth resources,
# editable directly in the Godot inspector with live viewport preview.

extends Control

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# Draw the face from current eye + mouth frame
func _draw() -> void:
	if reference_image and show_reference:
		var offset: Vector2 = reference_offset if reference_offset else Vector2.ZERO
		draw_texture(reference_image, offset)

	# Draw eye/expression channel
	if eye_frames.size() > 0 and current_eye_frame >= 0 and current_eye_frame < eye_frames.size():
		var eyes: PolybiusEyes = eye_frames[current_eye_frame]
		_draw_polyline_if_set(eyes.outline)
		_draw_polyline_if_set(eyes.left_eye)
		_draw_polyline_if_set(eyes.right_eye)
		_draw_polyline_if_set(eyes.left_pupil)
		_draw_polyline_if_set(eyes.right_pupil)
		_draw_polyline_if_set(eyes.left_eyebrow)
		_draw_polyline_if_set(eyes.right_eyebrow)
	
	if nose_frames.size() > 0 and current_nose_frame >= 0 and current_nose_frame < nose_frames.size():
		var nose: PolybiusNose = nose_frames[current_nose_frame]
		_draw_polyline_if_set(nose.left_nostril)
		_draw_polyline_if_set(nose.right_nostril)
	
	# Draw mouth channel
	if mouth_frames.size() > 0 and current_mouth_frame >= 0 and current_mouth_frame < mouth_frames.size():
		var mouth_res: PolybiusMouth = mouth_frames[current_mouth_frame]
		_draw_polyline_if_set(mouth_res.mouth)
		_draw_polyline_if_set(mouth_res.lower_lip)

# Helper: draw a polyline only if it has enough points (2+)
func _draw_polyline_if_set(points: PackedVector2Array) -> void:
	if points.size() >= 2:
		draw_polyline(points, face_color, line_width, true)

func _do_mirror() -> void:
	if eye_frames.size() == 0:
		return
	var eyes: PolybiusEyes = eye_frames[current_eye_frame]
	print("\n--- Mirrored frame ", current_eye_frame, " (center_x = ", center_x, ") ---")
	print("right_eye:     ", _mirror_points(eyes.left_eye))
	print("right_pupil:   ", _mirror_points(eyes.left_pupil))
	print("right_eyebrow: ", _mirror_points(eyes.left_eyebrow))
	print("---")

func _mirror_points(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(Vector2(center_x * 2.0 - p.x, p.y))
	return result
