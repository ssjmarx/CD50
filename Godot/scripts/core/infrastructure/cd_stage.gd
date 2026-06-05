## CDStage
## Game-level container that sleeps/wakes child CDGameComponents as a group.
## Used for multi-level game designs and dynamic remix content.

class_name CDStage extends CDGameComponent

## --- Exports ---

@export_group("Control")
## Start already sleeping — children are disabled before they process a single frame
@export var start_asleep: bool = false
## Game bus signal emitted after wake completes and children are reconnected
@export var on_wake_signal: StringName = &""

## --- State ---

## current sleep state of this stage
var is_sleeping: bool = false

## cached child components (collected in _on_initialize)
var _children: Array[CDGameComponent] = []

## --- Lifecycle ---

func _ready() -> void:
	## CDStage runs at UPDATE priority so it processes after all children
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

func _on_initialize() -> void:
	_collect_children()

	## if start_asleep, immediately disable physics on all children,
	## then defer bus disconnection until after children have populated _bus_connections
	if start_asleep:
		is_sleeping = true
		for child in _children:
			if is_instance_valid(child):
				child._on_sleep()
		call_deferred("_apply_start_asleep_disconnect")

## --- Public API ---

## Sleep this stage: disconnect children's bus connections, disable collisions, call _on_sleep
func sleep() -> void:
	if is_sleeping:
		return
	is_sleeping = true
	game.update.queue_sleep(self)

## Wake this stage: reconnect children's bus connections, enable collisions, call _on_wake
func wake() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	game.update.queue_wake(self)

## --- Flush (called by CDUpdater at end of frame) ---

## Execute sleep on all children — called by CDUpdater
func _flush_sleep() -> void:
	for child in _children:
		if not is_instance_valid(child):
			continue
		_disconnect_child(child)
		child._on_sleep()

## Execute wake on all children — called by CDUpdater
func _flush_wake() -> void:
	for child in _children:
		if not is_instance_valid(child):
			continue
		_reconnect_child(child)
		child._on_wake()
	if on_wake_signal != &"":
		game.bus_emit(on_wake_signal)

## --- Internal ---

## Deferred bus disconnection for start_asleep — runs after children have populated _bus_connections
func _apply_start_asleep_disconnect() -> void:
	for child in _children:
		if is_instance_valid(child):
			_disconnect_child(child)

## Recursively collect all CDGameComponent children (including nested CDStages)
func _collect_children() -> void:
	_children.clear()
	var found = find_children("*", "CDGameComponent")
	for node in found:
		if node == self:
			continue
		if node is CDGameComponent:
			_children.append(node)

## Disconnect all tracked bus connections for a child component
func _disconnect_child(child: CDGameComponent) -> void:
	for entry in child._bus_connections:
		var sig_name: StringName = entry["signal_name"]
		var callable: Callable = entry["callable"]
		if game.has_signal(sig_name) and game.is_connected(sig_name, callable):
			game.disconnect(sig_name, callable)

## Reconnect all tracked bus connections for a child component
func _reconnect_child(child: CDGameComponent) -> void:
	for entry in child._bus_connections:
		var sig_name: StringName = entry["signal_name"]
		var callable: Callable = entry["callable"]
		if not game.has_signal(sig_name):
			game.add_user_signal(sig_name)
		if not game.is_connected(sig_name, callable):
			game.connect(sig_name, callable)
