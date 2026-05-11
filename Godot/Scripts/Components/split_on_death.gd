# Spawns smaller fragments when parent dies. Reduces size enum if present (e.g., LARGE -> MEDIUM).

extends UniversalComponent

@export var fragment_scene: PackedScene
@export var fragment_path: String = ""
@export var spawn_count: int = 2
@export var fragment_speed: float = 100.0
@export var offset_amount: int = 20
@export var score_adjustment: int = 1
@export var score_adjustment_mode: CommonEnums.AdjustmentMode = CommonEnums.AdjustmentMode.ADD

var base_angle: float = randf() * TAU

# Preload fragment scene once at ready time (avoids circular dep in .tscn for self-referencing scenes)
func _ready() -> void:
	parent.get_node("Health").zero_health.connect(_on_parent_died)
	if fragment_scene == null and fragment_path != "":
		fragment_scene = load(fragment_path)

# Spawn fragments when parent dies (deferred to spread instantiation cost).
func _on_parent_died(_parent: Node) -> void:
	if fragment_scene == null:
		return
	# Don't spawn if parent is at minimum size
	if "size" in parent:
		if parent.size <= 0:
			return
	
	# Capture parent state before it's freed
	var parent_pos: Vector2 = parent.global_position
	var parent_size = parent.get("size") if "size" in parent else null
	var parent_color = parent.get("color") if "color" in parent else null
	var spawn_parent: Node = parent.get_parent()
	
	var new_score = null
	if parent.has_node("ScoreOnDeath"):
		var score_on_death = parent.get_node("ScoreOnDeath")
		match score_adjustment_mode:
			CommonEnums.AdjustmentMode.ADD:
				new_score = score_on_death.base_score + score_adjustment
			CommonEnums.AdjustmentMode.MULTIPLY:
				new_score = score_on_death.base_score * score_adjustment
			CommonEnums.AdjustmentMode.SET:
				new_score = score_adjustment
	
	# Capture fragment angles now, defer instantiation to end of frame
	var angles: Array[float] = []
	for i in spawn_count:
		angles.append(base_angle + (i * TAU / spawn_count) + randf_range(-0.3, 0.3))
	
	_deferred_spawn.bind(angles, parent_pos, parent_size, parent_color, new_score, spawn_parent).call_deferred()

# Deferred fragment spawning — runs at end of frame to spread cost across multiple deaths
func _deferred_spawn(angles: Array[float], parent_pos: Vector2, parent_size: Variant, parent_color: Variant, new_score: Variant, spawn_parent: Node) -> void:
	if not is_instance_valid(spawn_parent):
		return
	for angle in angles:
		var direction: Vector2 = Vector2.from_angle(angle)
		var fragment = fragment_scene.instantiate()
		
		if parent_size != null and "size" in fragment:
			if parent_size > 0:
				fragment.size = parent_size - 1
		
		if parent_color != null and "color" in fragment:
			fragment.color = parent_color
		
		fragment.velocity = direction * fragment_speed
		fragment.global_position = parent_pos + direction * offset_amount

		if new_score != null:
			var fragment_score = fragment.get_node("ScoreOnDeath")
			if fragment_score:
				fragment_score.base_score = new_score

		spawn_parent.add_child(fragment)
