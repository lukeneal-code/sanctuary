extends Node
## Global, authoritative world state. ALL progression lives here as flags —
## never on individual nodes. Persisted by SaveSystem.

signal flag_changed(key: String, value: Variant)

var flags: Dictionary = {}
var current_objective: String = ""
## Named spawn point the next loaded scene should use ("default", "cell", ...).
var player_spawn: String = "default"
## Room id the level host should build. Empty = use the scene's @export default.
## A "threshold" door sets this (+ player_spawn) before reloading the level scene.
var current_room: String = ""
## Day/cycle counter. The compound runs on a loop reused across the game; this is
## the scaffolding for it (advanced on a return-to-booking that lands later).
var day: int = 1


func set_flag(key: String, value: Variant = true) -> void:
	var changed: bool = flags.get(key) != value
	flags[key] = value
	if changed:
		flag_changed.emit(key, value)


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func has_flag(key: String) -> bool:
	return flags.has(key)


## Advances the day/cycle. Hook for the return-to-booking loop.
func advance_day() -> void:
	day += 1


func clear() -> void:
	flags.clear()
	current_objective = ""
	player_spawn = "default"
	current_room = ""
	day = 1


## Snapshot used by SaveSystem.
func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"current_objective": current_objective,
		"player_spawn": player_spawn,
		"current_room": current_room,
		"day": day,
	}


func from_dict(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	current_objective = data.get("current_objective", "")
	player_spawn = data.get("player_spawn", "default")
	current_room = data.get("current_room", "")
	day = int(data.get("day", 1))
