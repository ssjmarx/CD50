# Spawns smaller fragments when parent dies. Reduces size enum if present (e.g., LARGE -> MEDIUM).

extends UniversalComponent

@export var fragment_path: String = "" # Scene path to fragment PackedScene
@export var spawn_count: int = 2 # Number of fragments to spawn
@export var fragment_speed: float = 100.0 # Velocity of spawned fragments
@export var offset_amount: int = 20 # Distance from parent spawn point

var base_angle := randf() * TAU # Random base direction for fragment spread


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
	if "initial_size" in parent:
		if parent.initial_size <= 0:
			return
	
	# Spawn fragments in spread pattern
	for i in spawn_count:
		var angle := base_angle + (i * TAU / spawn_count) + randf_range(-0.3, 0.3)
		var direction := Vector2.from_angle(angle)
		var fragment = fragment_scene.instantiate()
		
		# Reduce fragment size if both parent and fragment have size enum
		if "initial_size" in fragment and "initial_size" in parent:
			if parent.initial_size > 0:
				fragment.initial_size = parent.initial_size - 1
		
		fragment.velocity = direction * fragment_speed
		fragment.global_position = parent.global_position + direction * offset_amount
		parent.get_parent().add_child(fragment)