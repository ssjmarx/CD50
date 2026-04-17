extends UniversalComponent

@export var source_node: Node
@export var source_signal: String
@export var target_property: String
@export var adjustment_amount: float
@export var adjustment_mode: CommonEnums.AdjustmentMode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	source_node.connect(source_signal, _on_signal_recieved)

func _on_signal_recieved(_ignore) -> void:
	match adjustment_mode:
		CommonEnums.AdjustmentMode.ADD:
			parent[target_property] += adjustment_amount
		CommonEnums.AdjustmentMode.MULTIPLY:
			parent[target_property] *= adjustment_amount
		CommonEnums.AdjustmentMode.SET:
			parent[target_property] = adjustment_amount
