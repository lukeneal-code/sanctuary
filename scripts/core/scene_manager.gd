extends Node
## Thin wrapper around scene changes. Records the current scene path so other
## systems (save, audio) can react. Fades/transitions are added in Phase 5.

signal scene_changed(path: String)

var current_scene_path: String = ""


func change_scene(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: failed to change to %s (err %d)" % [path, err])
		return
	current_scene_path = path
	scene_changed.emit(path)
