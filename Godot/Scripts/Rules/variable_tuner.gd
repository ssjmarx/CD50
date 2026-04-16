extends Node

@export var source_signal: String
@export var target_node: Node
@export var target_property: String
@export var adjustment_amount: float
@export var adjustment_mode: CommonEnums.AdjustmentMode

@onready var parent = get_parent()
@onready var game = UniversalGameScript.find_ancestor(self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game.source_signal.connect(_on_signal_recieved)


func _on_signal_recieved() -> void:
	match adjustment_mode:
		CommonEnums.AdjustmentMode.ADD:
			target_node.target_property += adjustment_amount
		CommonEnums.AdjustmentMode.MULTIPLY:
			target_node.target_property *= adjustment_amount
		CommonEnums.AdjustmentMode.SET:
			target_node.target_property = adjustment_amount