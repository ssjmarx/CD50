# StateDirector
# Transitions entities between groups (group-as-state) using CDTransition resources
# Queues transitions via CDUpdater to avoid group mutation during iteration

class_name StateDirector extends CDGameComponent

# --- exports ---

# transition rules defining from/to groups, triggers, selectors, and cooldowns
@export var transitions: Array[CDTransition] = []

# --- state ---

# per-frame guard: each entity can only transition once per frame
var _transitioned: Dictionary = {}
# reference to the game's CDUpdater for deferred transitions
var _update: CDUpdater

# --- lifecycle ---

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	if game:
		_update = game.update

# initialize all valid transitions
func initialize() -> void:
	for t in transitions:
		if t.is_valid():
			t.initialize(game)
		else:
			push_warning("StateDirector: skipping invalid transition (empty group names).")

# --- processing ---

# evaluate transitions each frame, advance cooldowns, queue matching transitions
func _physics_process(delta: float) -> void:
	_transitioned.clear()
	
	# advance cooldowns for all transitions
	for t in transitions:
		t.advance_cooldown(delta)
	
	# evaluate triggers and queue transitions
	for t in transitions:
		if not t.is_valid() or t.is_on_cooldown():
			continue
		if t.trigger and t.trigger.evaluate(delta):
			_process_trigger(t)

# --- transition logic ---

# gather candidates, filter, select, and queue transitions via CDUpdater
func _process_trigger(t: CDTransition) -> void:
	# build candidates from trigger type
	var candidates: Array[CDEntity]
	if t.trigger is CDSignalTrigger:
		candidates = t.trigger.consume_pending()
	else:
		candidates = game.group_registry.get_group(t.from_group)
	
	# filter: valid, active, not already transitioned, still in from_group
	var filtered: Array[CDEntity] = []
	for entity in candidates:
		if not is_instance_valid(entity):
			continue
		if entity.state != CDEnums.EntityState.ACTIVE:
			continue
		if _transitioned.has(entity):
			continue
		if not entity.is_in_group(t.from_group):
			continue
		filtered.append(entity)
	
	# selector narrows the pool
	var selected: Array[CDEntity]
	if t.selector:
		selected = t.selector.select(filtered)
	else:
		selected = filtered
	
	# queue transitions via CDUpdater (deferred to avoid mutation during iteration)
	for entity in selected:
		_transitioned[entity] = true
		_update.queue_transition(entity, t.from_group, t.to_group, t.exit_signal_name, t.emit_signal_name)
		t.start_cooldown()

# --- reset ---

# clear all transition state for game restart
func reset() -> void:
	_transitioned.clear()
	for t in transitions:
		t.reset()