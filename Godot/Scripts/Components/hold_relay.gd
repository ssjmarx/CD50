# Hold relay component. Forwards the body's action signal to the game's
# hold_requested signal. Pure signal relay — no game logic.

extends UniversalComponent

func _ready() -> void:
	call_deferred("_connect")

func _connect() -> void:
	if parent.has_signal("action"):
		parent.action.connect(_on_action)

func _on_action(event: InputEvent = null) -> void:
	if event and event.is_action("button_1"):
		game.hold_requested.emit()
