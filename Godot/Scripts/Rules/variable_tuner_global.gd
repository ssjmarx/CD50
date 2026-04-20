extends UniversalComponent

@export var source_node: Node
@export var source_signal: String
@export var filter_value: String = ""
@export var target_property: String
@export var adjustment_amount: float
@export var adjustment_mode: CommonEnums.AdjustmentMode
@export var target_group: String
@export var target_node: String

func _ready() -> void:
	source_node.connect(source_signal, _on_signal_recieved)

func _on_signal_recieved(arg) -> void:
	if filter_value != "" and arg != filter_value:
		return
	
	for target in get_tree().get_nodes_in_group(target_group):
		var node: Node = target
		if target_node != "":
			node = target.get_node(target_node)
		
		match adjustment_mode:
			CommonEnums.AdjustmentMode.ADD:
				node[target_property] += adjustment_amount
			CommonEnums.AdjustmentMode.MULTIPLY:
				node[target_property] *= adjustment_amount
			CommonEnums.AdjustmentMode.SET:
				node[target_property] = adjustment_amount
