# Spawns smaller fragments when parent dies. Reduces size enum if present (e.g., LARGE -> MEDIUM).

extends UniversalComponent

@export var fragment_path: String = "" 
@export var spawn_count: int = 2
@export var fragment_speed: float = 100.0
@export var offset_amount: int = 20
@export var score_adjustment: int = 1
@export var score_adjustment_mode: CommonEnums.AdjustmentMode = CommonEnums.AdjustmentMode.ADD

var base_angle: float = randf() * TAU

# Connect to parent's death signal
func _ready() -> void:
	parent.get_node("Health").zero_health.connect(_on_parent_died)

# Spawn fragments when parent dies
func _on_parent_died(_parent: Node) -> void:
	if fragment_path == "":
		return
	var fragment_scene: PackedScene = load(fragment_path)
	if fragment_scene == null:
		return
	# Don't spawn if parent is at minimum size
	if "size" in parent:
		if parent.size <= 0:
			return
	
	var score_on_death = parent.get_node("ScoreOnDeath")
	var new_score = null

	if score_on_death:
		match score_adjustment_mode:
			CommonEnums.AdjustmentMode.ADD:
				new_score = score_on_death.base_score + score_adjustment
			CommonEnums.AdjustmentMode.MULTIPLY:
				new_score = score_on_death.base_score * score_adjustment
			CommonEnums.AdjustmentMode.SET:
				new_score = score_adjustment

	# Spawn fragments in spread pattern
	for i in spawn_count:
		var angle: float = base_angle + (i * TAU / spawn_count) + randf_range(-0.3, 0.3)
		var direction: Vector2 = Vector2.from_angle(angle)
		var fragment = fragment_scene.instantiate()
		
		# Reduce fragment size if both parent and fragment have size enum
		if "size" in fragment and "size" in parent:
			if parent.size > 0:
				fragment.size = parent.size - 1
		
		if "color" in parent and "color" in parent:
			fragment.color = parent.color
		
		fragment.velocity = direction * fragment_speed
		fragment.global_position = parent.global_position + direction * offset_amount

		if new_score != null:
			var fragment_score = fragment.get_node("ScoreOnDeath")
			if fragment_score:
				fragment_score.base_score = new_score

		parent.get_parent().add_child(fragment)
