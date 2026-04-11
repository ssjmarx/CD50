# spawn multiple nodes when the parent dies.  checks for a size enum and makes the new splits smaller if one exists on both the parent and the fragments.

extends Node

@export var fragment_path: String = ""
@export var spawn_count: int = 2
@export var fragment_speed: float = 100.0
@export var offset_amount: int = 20

var base_angle := randf() * TAU

@onready var parent = get_parent()

func _ready() -> void:
	parent.get_node("Health").zero_health.connect(_on_parent_died)

func _on_parent_died(_parent: Node) -> void:
	if fragment_path == "":
		return
	var fragment_scene: PackedScene = load(fragment_path)
	if fragment_scene == null:
		return
	if "initial_size" in parent:
		if parent.initial_size <= 0:
			return
	
	for i in spawn_count:
		var angle := base_angle + (i * TAU / spawn_count) + randf_range(-0.3, 0.3)
		var direction := Vector2.from_angle(angle)
		var fragment = fragment_scene.instantiate()
		
		if "initial_size" in fragment and "initial_size" in parent:
			if parent.initial_size > 0:
				fragment.initial_size = parent.initial_size - 1
		
		fragment.velocity = direction * fragment_speed
		fragment.global_position = parent.global_position + direction * offset_amount
		parent.get_parent().add_child(fragment)
