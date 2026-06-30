extends Node
## Serializes GameState + Inventory + player transform to user:// as JSON.
## JSON keeps saves human-readable and diff-able during development.

const SAVE_DIR := "user://saves"


func _save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func save_game(slot: int = 0, player_transform: Transform3D = Transform3D.IDENTITY) -> bool:
	_ensure_dir()
	var payload: Dictionary = {
		"version": 1,
		"state": GameState.to_dict(),
		"inventory": Inventory.to_array(),
		"player_transform": _transform_to_array(player_transform),
	}
	var file := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open save file for writing")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: corrupt save in slot %d" % slot)
		return false
	var data: Dictionary = parsed
	GameState.from_dict(data.get("state", {}))
	Inventory.from_array(data.get("inventory", []))
	return true


func get_player_transform(slot: int = 0) -> Transform3D:
	if not has_save(slot):
		return Transform3D.IDENTITY
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return Transform3D.IDENTITY
	return _array_to_transform((parsed as Dictionary).get("player_transform", []))


func _transform_to_array(t: Transform3D) -> Array:
	return [
		t.basis.x.x,
		t.basis.x.y,
		t.basis.x.z,
		t.basis.y.x,
		t.basis.y.y,
		t.basis.y.z,
		t.basis.z.x,
		t.basis.z.y,
		t.basis.z.z,
		t.origin.x,
		t.origin.y,
		t.origin.z,
	]


func _array_to_transform(a: Array) -> Transform3D:
	if a.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(
		Basis(
			Vector3(a[0], a[1], a[2]),
			Vector3(a[3], a[4], a[5]),
			Vector3(a[6], a[7], a[8]),
		),
		Vector3(a[9], a[10], a[11]),
	)
