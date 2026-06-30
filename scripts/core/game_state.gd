extends Node
## Global, authoritative world state. ALL progression lives here as flags —
## never on individual nodes. Persisted by SaveSystem.

signal flag_changed(key: String, value: Variant)

var flags: Dictionary = {}
var current_objective: String = ""
## Named spawn point the next loaded scene should use ("default", "cell", ...).
var player_spawn: String = "default"


func set_flag(key: String, value: Variant = true) -> void:
	var changed: bool = flags.get(key) != value
	flags[key] = value
	if changed:
		flag_changed.emit(key, value)


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func has_flag(key: String) -> bool:
	return flags.has(key)


func clear() -> void:
	flags.clear()
	current_objective = ""
	player_spawn = "default"


## Snapshot used by SaveSystem.
func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"current_objective": current_objective,
		"player_spawn": player_spawn,
	}


func from_dict(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	current_objective = data.get("current_objective", "")
	player_spawn = data.get("player_spawn", "default")
