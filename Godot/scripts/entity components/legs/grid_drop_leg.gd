## drops entity by N grid cells. used for line clear settling
class_name GridDropLeg extends CDEntityComponent

@export var cell_size_y: float = 18.0

@export_group("Listen Signals")
@export var drop_signals: Array[StringName] = [&"grid_drop"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in drop_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_drop)

func _on_drop(drop_count: int) -> void:
	if drop_count <= 0:
		return
	entity.request_position_add(Vector2(0, drop_count * cell_size_y))

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in drop_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_drop):
			entity.disconnect(sig, _on_drop)
