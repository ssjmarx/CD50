# Space Invader-style enemy with three different sprite-based forms.

extends UniversalBody

@export var color = Color.WHITE
@export var shape = Shape.NAUTILUS

enum Shape {
	NAUTILUS,
	CRAB,
	SQUID
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	
	match shape:
		Shape.NAUTILUS:
			$nautilus.show()
		Shape.CRAB:
			$crab.show()
		Shape.SQUID:
			$squid.show()
			$ScoreOnDeath.score_type = CommonEnums.ScoreType.MULTIPLIER
	
	_play_with_offset()

func _play_with_offset() -> void:
	await get_tree().create_timer(randf_range(0.0, 0.5)).timeout 
	
	match shape:
		Shape.NAUTILUS:
			$nautilus.play()
		Shape.CRAB:
			$crab.play()
		Shape.SQUID:
			$squid.play()
