# Adjusts a property on the parent entity when a signal is received from a source node.
# Supports add, multiply, and set modes with optional signal argument filtering.

extends UniversalComponent

# Signal source configuration
@export var source_node: Node
@export var source_signal: String
@export var filter_value: String = ""

# Target property and adjustment
@export var target_property: String
@export var adjustment_amount: float
@export var adjustment_mode: CommonEnums.AdjustmentMode

# Connect to the source signal
func _ready() -> void:
	source_node.connect(source_signal, _on_signal_recieved)

# Apply adjustment to parent property when signal fires, filtered by optional value
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
