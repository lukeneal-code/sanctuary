class_name NpcTalker
extends Area3D
## An NPC you can talk to. On interact it loads its conversation into the scene's
## DialogueUI (injected by the room builder). The NPC holds no dialogue state —
## the DialogueRunner writes everything to GameState flags.

@export var dialogue_id: String = ""
@export var npc_name: String = ""

var dialogue_ui: Node = null  ## Injected by room_builder._wire_ui().


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	var who := npc_name if npc_name != "" else "them"
	return "Press E to talk to %s" % who


func interact(player: Node) -> void:
	if dialogue_id == "" or dialogue_ui == null:
		push_warning("NpcTalker: no dialogue_id or dialogue_ui bound")
		return
	var runner := DialogueRunner.from_id(dialogue_id)
	if runner == null:
		return
	dialogue_ui.begin(runner, player)
