class_name TextureCatalog
extends RefCounted
## Loads PSX texture definitions from data/textures/textures.json into a Dictionary
## keyed by semantic id, and builds materials from them. Kept as JSON (not .tres)
## so a session can author and reference textures by id without the editor — the
## same shape as ItemCatalog. A texture is chosen by its id (and its tags /
## description, which exist purely so the harness can pick one without seeing it);
## the file path is bound in exactly one place, the catalog entry.

const CATALOG_PATH := "res://data/textures/textures.json"


static func load_all() -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("TextureCatalog: missing %s" % CATALOG_PATH)
		return result
	var text: String = FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TextureCatalog: %s is not a JSON object" % CATALOG_PATH)
		return result
	for id: String in parsed:
		result[id] = parsed[id]
	return result


## Builds a StandardMaterial3D for a texture id. The PSX crunch lives here:
## nearest-neighbour filtering, no smoothing. An unknown id or a missing file
## yields a plain, untextured material rather than crashing, so callers can stay
## terse (this mirrors the build-material-in-code idiom in guard.gd).
static func make_material(id: String, catalog: Dictionary) -> StandardMaterial3D:
	var def: Dictionary = catalog.get(id, {})
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PSX: no bilinear
	mat.roughness = float(def.get("roughness", 0.9))
	var tiling: Array = def.get("tiling", [1.0, 1.0])
	mat.uv1_scale = Vector3(float(tiling[0]), float(tiling[1]), 1.0)
	var tex_path: String = def.get("path", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path) as Texture2D
	return mat
