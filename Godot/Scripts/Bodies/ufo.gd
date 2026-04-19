# Entity based on Asteroids UFO

extends UniversalBody

@export var color: Color = Color.WHITE
@export var size: Size = Size.LARGE

enum Size {
	LARGE,
	SMALL
}

func _ready() -> void:
	if size == Size.SMALL:
		self.width = width / 2
		self.height = height / 2
		$DirectMovement.speed = $DirectMovement.speed * 2
		$AimAi.aim_inaccuracy = $AimAi.aim_inaccuracy / 2
		$ShootAi.fire_rate = $ShootAi.fire_rate / 2.0
		$SoundSynth.note = 72
	
	super._ready()
	
	#print("ufo ready")

# Draw triangle ship
func _draw() -> void:
	var w: float = width / 16.0
	var h: float = height / 16.0

	var bottom = [
		Vector2(-20 * w, 2.5 * h),
		Vector2(-10 * w, 10.5 * h),
		Vector2(10 * w, 10.5 * h),
		Vector2(20 * w, 2.5 * h),
	]

	var middle = [
		Vector2(-20 * w, 2.5 * h),
		Vector2(-10 * w, -5.5 * h),
		Vector2(10 * w, -5.5 * h),
		Vector2(20 * w, 2.5 * h),
	]

	var top = [
		Vector2(-10 * w, -5.5 * h),
		Vector2(-3 * w, -10.5 * h),
		Vector2(4 * w, -10.5 * h),
		Vector2(10 * w, -5.5 * h),
	]
	
	draw_polyline(bottom, color, 2.0)
	draw_polyline(middle, color, 2.0)
	draw_polyline(top, color, 2.0)
 
