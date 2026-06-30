extends Node
## App-level input that must outlive scene changes (autoloads persist, scenes
## don't). Esc quits the game. Phase 5's pause menu will hang off here instead
## of quitting outright. Uses _unhandled_input so future UI can consume Esc first.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
