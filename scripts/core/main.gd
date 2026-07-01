extends Node3D
## Boot scene. Hands off to the generic level host via SceneManager (so its
## scene-change bookkeeping — current_scene_path, scene_changed — runs) and selects
## the starting room. Stage 1 opens in the booking cell.

const FIRST_SCENE := "res://scenes/levels/level.tscn"
const FIRST_ROOM := "booking_cell"


func _ready() -> void:
	GameState.current_room = FIRST_ROOM
	GameState.player_spawn = "default"
	SceneManager.change_scene(FIRST_SCENE)
