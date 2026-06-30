extends CanvasLayer
## Thin presentation layer over DialogueRunner: shows the speaker + line, lists the
## available choices as buttons, advances the runner on selection, and freezes the
## player while the conversation is open. All branching logic lives in the
## (headless-tested) DialogueRunner; this node only renders it.

signal dialogue_finished

var _runner: DialogueRunner = null
var _player: Node = null

@onready var _panel: Control = $Panel
@onready var _speaker: Label = $Panel/VBox/Speaker
@onready var _text: Label = $Panel/VBox/Text
@onready var _choices: VBoxContainer = $Panel/VBox/Choices


func _ready() -> void:
	_panel.visible = false


func is_active() -> bool:
	return _runner != null


## Starts presenting a conversation. `player` (optional) is frozen until it ends.
func begin(runner: DialogueRunner, player: Node = null) -> void:
	_runner = runner
	_player = player
	if _player and "frozen" in _player:
		_player.frozen = true
	_runner.start()
	_refresh()


func _refresh() -> void:
	if _runner.is_finished():
		_end()
		return
	_panel.visible = true
	_speaker.text = _runner.current_speaker()
	_text.text = _runner.current_text()
	for child in _choices.get_children():
		child.queue_free()
	var choices := _runner.available_choices()
	for i in choices.size():
		var btn := Button.new()
		btn.text = (choices[i] as Dictionary).get("text", "...")
		btn.pressed.connect(_on_choice.bind(i))
		_choices.add_child(btn)
	if not choices.is_empty():
		(_choices.get_child(0) as Button).grab_focus()


func _on_choice(index: int) -> void:
	_runner.choose(index)
	_refresh()


func _end() -> void:
	_panel.visible = false
	_runner = null
	if _player and "frozen" in _player:
		_player.frozen = false
	_player = null
	dialogue_finished.emit()
