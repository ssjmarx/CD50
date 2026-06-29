## StageDirector
## Produces: entity swaps (deactivate + spawn replacement) driven by CDDirectorRule.
## Consumes: game bus trigger signals + CDDirectorRule resources.

class_name StageDirector extends CDGameComponent

## --- exports ---

## swap rules defining trigger signals, target group, swap scene, and selector
@export var rules: Array[CDDirectorRule] = []

## --- state ---

## reverse lookup: signal name → array of matching rules
var _signal_to_rules: Dictionary = {}

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

## build signal map and connect all trigger signals
func _on_initialize() -> void:
	_build_signal_map()
	
	for sig_name: StringName in _signal_to_rules:
		bus_connect(sig_name, _on_trigger.bind(sig_name))

## build reverse lookup from trigger signal → rules
func _build_signal_map() -> void:
	_signal_to_rules.clear()
	
	for rule: CDDirectorRule in rules:
		## validate rule has required fields
		if rule.swap_scene == null:
			push_warning("StageDirector '%s': rule has no swap_scene — skipping." % name)
			continue
		if rule.target_group == &"":
			push_warning("StageDirector '%s': rule has no target_group — skipping." % name)
			continue
		
		## map each trigger signal to this rule
		for sig_name: StringName in rule.trigger_signals:
			if not _signal_to_rules.has(sig_name):
				_signal_to_rules[sig_name] = []
			_signal_to_rules[sig_name].append(rule)

## dispatch triggered signal to all matching rules
func _on_trigger(signal_name: StringName = &"") -> void:
	var matched_rules: Array = _signal_to_rules.get(signal_name, [])
	for rule: CDDirectorRule in matched_rules:
		_process_rule(rule)

## gather candidates, select via selector, swap each entity
func _process_rule(rule: CDDirectorRule) -> void:
	var candidates := game.group_registry.get_group(rule.target_group)
	if candidates.is_empty():
		return
	
	## select entities for swap
	var to_swap: Array[CDEntity] = []
	if rule.selector != null:
		to_swap = rule.selector.select(candidates)
	else:
		to_swap.assign(candidates)
	
	for entity: CDEntity in to_swap:
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			continue
		
		var spawn_pos := entity.global_position
		
		if rule.deactivate_original:
			entity.request_deactivate()
		
		## spawn and activate replacement at recorded position
		var replacement: CDEntity = rule.swap_scene.instantiate()
		game.add_child(replacement)
		replacement.global_position = spawn_pos
		replacement.activate()