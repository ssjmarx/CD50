extends UniversalComponent

@export var source_node: Node
@export var source_signal: String
@export var filter_value: String = ""
@export var target_property: String
@export var adjustment_amount: float
@export var adjustment_mode: CommonEnums.AdjustmentMode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	source_node.connect(source_signal, _on_signal_recieved)

func _on_signal_recieved(arg) -> void:
	if filter_value != "" and arg != filter_value:
		return
	match adjustment_mode:
		CommonEnums.AdjustmentMode.ADD:
			parent[target_property] += adjustment_amount
		CommonEnums.AdjustmentMode.MULTIPLY:
			parent[target_property] *= adjustment_amount
		CommonEnums.AdjustmentMode.SET:
			parent[target_property] = adjustment_amount
