# Kills all members of a target group when a game signal is received.
# Optionally filters by signal group name (e.g. only trigger when "enemies" group is cleared).

extends UniversalComponent

@export var listen_signal: String = "group_cleared"
@export var trigger_group: String = ""  # if non-empty, only trigger when signal group matches this
@export var target_group: String = "settled_pieces"
@export var use_health_kill: bool = true  # if true, try Health component for death effects; if false, queue_free directly
@export var kill_delay: float = 0.01      # delay between sequential health kills (allows death effects to play)

func _ready() -> void:
	if listen_signal != "" and game and game.has_signal(listen_signal):
		game.connect(listen_signal, _on_signal)

func _on_signal(group_name: String) -> void:
	if trigger_group != "" and group_name != trigger_group:
		return
	_kill_group()

func _kill_group() -> void:
	for member in get_tree().get_nodes_in_group(target_group):
		if is_instance_valid(member) and not member.is_queued_for_deletion():
			if use_health_kill:
				var health = _find_health_component(member)
				if health:
					health.reduce_health(health.current_health)
				else:
					member.queue_free()
				await get_tree().create_timer(kill_delay).timeout
			else:
				member.queue_free()

func _find_health_component(node: Node) -> Node:
	for child in node.get_children():
		if child.has_signal("zero_health"):
			return child
	return null