extends UniversalBody

@export var color = Color.WHITE
@export var type = Type.NAUTILUS

enum Type {
	NAUTILUS,
	CRAB,
	SQUID
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	
	match type:
		Type.NAUTILUS:
			$nautilus.show()
		Type.CRAB:
			$crab.show()
		Type.SQUID:
			$squid.show()
			$ScoreOnDeath.score_type = CommonEnums.ScoreType.MULTIPLIER
	
	_play_with_offset()

func _play_with_offset() -> void:
	await get_tree().create_timer(randf_range(0.0, 0.5)).timeout 
	
	match type:
		Type.NAUTILUS:
			$nautilus.play()
		Type.CRAB:
			$crab.play()
		Type.SQUID:
			$squid.play()
