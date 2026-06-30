class_name ItemCatalog
extends RefCounted
## Loads item definitions from data/items/items.json into a Dictionary keyed by id.
## Kept as JSON (not .tres) so Claude can author items freely without the editor.

const CATALOG_PATH := "res://data/items/items.json"


static func load_all() -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("ItemCatalog: missing %s" % CATALOG_PATH)
		return result
	var text: String = FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ItemCatalog: %s is not a JSON object" % CATALOG_PATH)
		return result
	for id: String in parsed:
		result[id] = parsed[id]
	return result
