extends SceneTree
## Ensures every texture flagged as a `normal` map in data/textures/textures.json
## is imported as a normal map (compress/normal_map = Enable -> linear data, correct
## unpacking) instead of an sRGB colour texture. Godot's auto-detect only fires for
## normals referenced by *saved* materials; ours are built at runtime by
## TextureCatalog, so we set the flag explicitly. Re-runnable and idempotent — it
## only rewrites the one import param and leaves Godot's UID untouched.
##
## Run after adding a normal-mapped texture, then do an import pass:
##   godot --headless --path . --script res://tools/godot/set_normalmap_imports.gd
##   godot --headless --path . --editor --quit

const CATALOG_PATH := "res://data/textures/textures.json"


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("set_normalmap_imports: %s is not a JSON object" % CATALOG_PATH)
		quit(1)
		return
	var catalog: Dictionary = parsed
	var changed := 0
	for id: String in catalog:
		var normal_path: String = catalog[id].get("normal", "")
		if normal_path == "":
			continue
		var import_path := normal_path + ".import"
		if not FileAccess.file_exists(import_path):
			push_warning(
				"set_normalmap_imports: no .import for %s — run an import pass first" % normal_path
			)
			continue
		var cfg := ConfigFile.new()
		if cfg.load(import_path) != OK:
			push_warning("set_normalmap_imports: cannot read %s" % import_path)
			continue
		if int(cfg.get_value("params", "compress/normal_map", 0)) != 1:
			cfg.set_value("params", "compress/normal_map", 1)
			cfg.save(import_path)
			changed += 1
			print("flagged as normal map: %s" % normal_path)
	print("set_normalmap_imports: %d file(s) updated" % changed)
	quit(0)
