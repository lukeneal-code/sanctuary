class_name Pickup
extends Area3D
## A world item the player can take. Adds its item id to Inventory and removes
## itself. Possession is the state (it lives in Inventory), so no flag is needed.

@export var item_id: String = ""


func _ready() -> void:
	add_to_group("interactable")
	if Inventory.definition(item_id).is_empty():
		push_warning("Pickup: unknown item id '%s'" % item_id)


func get_prompt() -> String:
	var display: String = Inventory.definition(item_id).get("display_name", item_id)
	return "Press E to pick up %s" % display


func interact(_player: Node) -> void:
	if Inventory.add(item_id):
		queue_free()
