# Hold relay component. Forwards the body's action signal to the game's
# hold_requested signal. Pure signal relay — no game logic.

extends UniversalComponent

func _ready() -> void:
	call_deferred("_connect")

func _connect() -> void:
	if parent.has_signal("button_1"):
		parent.button_1.connect(_on_button_1)

func _on_button_1() -> void:
	game.hold_requested.emit()
