## GridDropLeg
## Produces: a downward position request by N grid cells.
## Consumes: entity.blackboard["drop_count"] (edge-detected).

class_name GridDropLeg extends CDEntityComponent

## --- exports ---

## height of one grid cell in pixels
@export var cell_size_y: float = 18.0

@export_group("Blackboard Keys")
## key to read drop count from (int — number of cells to drop)
@export var drop_count_key: StringName = &"drop_count"

## --- state ---

## previous frame's drop count for edge detection
var _prev_drop_count: int = 0

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## on initialize
func _on_initialize() -> void:
	pass

## edge-detect drop_count changes, apply instant vertical drop
func _physics_process(_delta: float) -> void:
	if not entity:
		return
	
	var drop_count: int = entity.blackboard.get(drop_count_key, 0)
	
	if drop_count > 0 and drop_count != _prev_drop_count:
		entity.request_position_add(Vector2(0, drop_count * cell_size_y))
		## clear the key after consuming
		entity.blackboard.erase(drop_count_key)
		_prev_drop_count = 0
	else:
		_prev_drop_count = drop_count

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_prev_drop_count = 0