## cd_body.gd
## Produces: group sleep/wake of child CDEntityComponents on an entity.
## Consumes: entity bus control signals; child component bus connections.
class_name CDBody extends CDEntityComponent

@export_group("Control Signals")
## Start already sleeping — children are disabled before they process a single frame
@export var start_asleep: bool = false
## Entity bus signals that trigger sleep (e.g., "path_finished", "patrol_complete")
@export var sleep_on: Array[StringName] = []
## Entity bus signals that trigger wake (e.g., "receive_powerup", "status_began")
@export var wake_on: Array[StringName] = []

## current sleep state of this body
var is_sleeping: bool = false

## cached child components (collected in _on_initialize)
var _children: Array[CDEntityComponent] = []

## Run at UPDATE priority so this processes after all children.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.UPDATE
	super._ready()

## Collect children, apply start_asleep, and wire control signals.
func _on_initialize() -> void:
	_collect_children()

	## if start_asleep, immediately disable physics on all children,
	## then defer bus disconnection until after children have populated _bus_connections
	if start_asleep:
		is_sleeping = true
		for child in _children:
			if is_instance_valid(child):
				CDEntity.set_subtree_collisions(child, false)
				child._on_sleep()
		call_deferred("_apply_start_asleep_disconnect")

	## connect control signals on the entity bus (auto-creates signals if needed)
	for sig in sleep_on:
		if sig != &"":
			self.bus_connect(sig, _on_sleep_signal)
	for sig in wake_on:
		if sig != &"":
			self.bus_connect(sig, _on_wake_signal)

## Sleep this body: queue disable of children's bus connections, collisions, and _on_sleep.
func sleep() -> void:
	if is_sleeping:
		return
	is_sleeping = true
	game.update.queue_sleep(self)

## Wake this body: queue re-enable of children's bus connections, collisions, and _on_wake.
func wake() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	game.update.queue_wake(self)

func _on_sleep_signal() -> void:
	sleep()

func _on_wake_signal() -> void:
	wake()

## Execute sleep on all children — called by CDUpdater.
func _flush_sleep() -> void:
	for child in _children:
		if not is_instance_valid(child):
			continue
		_disconnect_child(child)
		CDEntity.set_subtree_collisions(child, false)
		child._on_sleep()

## Execute wake on all children — called by CDUpdater.
func _flush_wake() -> void:
	for child in _children:
		if not is_instance_valid(child):
			continue
		_reconnect_child(child)
		CDEntity.set_subtree_collisions(child, true)
		child._on_wake()

## --- Internal ---

## Deferred bus disconnection for start_asleep — runs after children populate _bus_connections.
func _apply_start_asleep_disconnect() -> void:
	for child in _children:
		if is_instance_valid(child):
			_disconnect_child(child)

## Recursively collect all CDEntityComponent children (including nested CDBodies).
func _collect_children() -> void:
	_children.clear()
	var found = find_children("*", "CDEntityComponent")
	for node in found:
		if node == self:
			continue
		if node is CDEntityComponent:
			_children.append(node)

## Disconnect all tracked bus connections for a child component.
func _disconnect_child(child: CDEntityComponent) -> void:
	for entry in child._bus_connections:
		var sig_name: StringName = entry["signal_name"]
		var callable: Callable = entry["callable"]
		if entity.has_signal(sig_name) and entity.is_connected(sig_name, callable):
			entity.disconnect(sig_name, callable)

## Reconnect all tracked bus connections for a child component.
func _reconnect_child(child: CDEntityComponent) -> void:
	for entry in child._bus_connections:
		var sig_name: StringName = entry["signal_name"]
		var callable: Callable = entry["callable"]
		if not entity.has_signal(sig_name):
			entity.add_user_signal(sig_name)
		if not entity.is_connected(sig_name, callable):
			entity.connect(sig_name, callable)