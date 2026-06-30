extends Node3D
## Boot scene. Hands off to the Phase 1 greybox vertical slice via SceneManager so
## its scene-change bookkeeping (current_scene_path, scene_changed) runs.

const FIRST_SCENE := "res://scenes/levels/greybox.tscn"


func _ready() -> void:
	SceneManager.change_scene(FIRST_SCENE)
