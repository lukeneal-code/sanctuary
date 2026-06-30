extends Node
## The player's inventory. Holds item ids only; definitions come from ItemCatalog.

signal item_added(id: String)
signal item_removed(id: String)

var items: Array[String] = []
var _catalog: Dictionary = {}


func _ready() -> void:
	_catalog = ItemCatalog.load_all()


func has(id: String) -> bool:
	return items.has(id)


func add(id: String) -> bool:
	if not _catalog.has(id):
		push_warning("Inventory.add: unknown item id '%s'" % id)
	if has(id):
		return false
	items.append(id)
	item_added.emit(id)
	return true


func remove(id: String) -> bool:
	if not has(id):
		return false
	items.erase(id)
	item_removed.emit(id)
	return true


func definition(id: String) -> Dictionary:
	return _catalog.get(id, {})


## Returns the id two items would produce, or "" if they don't combine.
## Combination is treated as symmetric.
func combines_into(a: String, b: String) -> String:
	if (definition(a).get("combines_with", []) as Array).has(b):
		return definition(a).get("combines_into", "")
	if (definition(b).get("combines_with", []) as Array).has(a):
		return definition(b).get("combines_into", "")
	return ""


## Performs the combination if both items are held; returns the result id or "".
func combine(a: String, b: String) -> String:
	var result: String = combines_into(a, b)
	if result == "" or not has(a) or not has(b):
		return ""
	remove(a)
	remove(b)
	add(result)
	return result


func to_array() -> Array[String]:
	return items.duplicate()


func from_array(saved: Array) -> void:
	items.clear()
	for id: Variant in saved:
		items.append(str(id))
