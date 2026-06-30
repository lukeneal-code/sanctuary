extends CanvasLayer
## Shows the interaction prompt for whatever the player is currently looking at.
## Bound to a live Interactor by the room builder, because the interactor lives
## inside the spawned player rather than in this scene file.

@onready var _label: Label = $Label


func bind_interactor(interactor: Node) -> void:
	if interactor and interactor.has_signal("focus_changed"):
		interactor.focus_changed.connect(_on_focus_changed)


func _on_focus_changed(node: Node) -> void:
	if node and node.has_method("get_prompt"):
		_label.text = node.get_prompt()
	else:
		_label.text = ""
