# Classically-styled UFO. Scales speed and accuracy for the SMALL variant. Draws a three-layer saucer shape.

extends UniversalBody

# Appearance and variant
@export var color: Color = Color.WHITE
@export var size: Size = Size.LARGE

enum Size {
	LARGE,
	SMALL
}

# Scale child components for the small variant (faster, more accurate, higher pitch)
func _ready() -> void:
	if size == Size.SMALL:
		self.width = width / 2
		self.height = height / 2
		var direct_movement = get_node_or_null("DirectMovement")
		if direct_movement:
			direct_movement.speed = direct_movement.speed * 2
		var aim_ai = get_node_or_null("AimAi")
		if aim_ai:
			aim_ai.aim_inaccuracy = aim_ai.aim_inaccuracy / 2
		var shoot_ai = get_node_or_null("ShootAi")
		if shoot_ai:
			shoot_ai.fire_rate = shoot_ai.fire_rate / 2.0
		var sound_synth = get_node_or_null("SoundSynth")
		if sound_synth:
			sound_synth.note = 72
		var shoot_ai2 = get_node_or_null("ShootAi2")
		if shoot_ai2:
			shoot_ai2.fire_rate = shoot_ai2.fire_rate / 2.0
		var aim_ai2 = get_node_or_null("AimAi2")
		if aim_ai2:
			aim_ai2.aim_inaccuracy = aim_ai2.aim_inaccuracy / 2
		var score_on_death = get_node_or_null("ScoreOnDeath")
		if score_on_death:
			score_on_death.base_score = 30
	
	super._ready()

# Draw the saucer as three stacked polyline layers (bottom, middle, top)
func _draw() -> void:
	var w: float = width / 16.0
	var h: float = height / 16.0

	var bottom: Array = [
		Vector2(-20 * w, 2.5 * h),
		Vector2(-10 * w, 10.5 * h),
		Vector2(10 * w, 10.5 * h),
		Vector2(20 * w, 2.5 * h),
	]

	var middle: Array = [
		Vector2(-20 * w, 2.5 * h),
		Vector2(-10 * w, -5.5 * h),
		Vector2(10 * w, -5.5 * h),
		Vector2(20 * w, 2.5 * h),
	]

	var top: Array = [
		Vector2(-10 * w, -5.5 * h),
		Vector2(-3 * w, -10.5 * h),
		Vector2(4 * w, -10.5 * h),
		Vector2(10 * w, -5.5 * h),
	]
	
	draw_polyline(bottom, color, 2.0)
	draw_polyline(middle, color, 2.0)
	draw_polyline(top, color, 2.0)
