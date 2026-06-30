class_name DialogueRunner
extends RefCounted
## Crude, custom dialogue walker for Phase 1. Reads a JSON conversation graph and
## walks it, reading/writing GameState flags. Pure logic — no Node, no UI — so the
## branching is unit-testable headless; dialogue_ui.gd is the thin presentation
## layer on top. This is TEMPORARY: Phase 2 replaces it with the Dialogue Manager
## addon (see CLAUDE.md). Do not invent that addon's files here.
##
## JSON schema (data/dialogue/<id>.json):
##   { "id", "start": "<node_id>", "nodes": { "<node_id>": {
##       "speaker", "text",
##       "set_flags":  { flag: value, ... },   # applied when the node is entered
##       "choices": [ {
##           "text",
##           "goto": "<node_id>",              # "" ends the conversation
##           "set_flags":     { ... },         # applied when this choice is picked
##           "require_flags": { ... } } ] } } } # all must match to offer the choice

const DIALOGUE_DIR := "res://data/dialogue/"

var _nodes: Dictionary = {}
var _start: String = ""
var _current: String = ""


## Builds a runner from data/dialogue/<id>.json. Returns null if missing/malformed.
static func from_id(id: String) -> DialogueRunner:
	var path := DIALOGUE_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("DialogueRunner: missing %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueRunner: %s is not a JSON object" % path)
		return null
	return from_dict(parsed)


## Builds a runner directly from an already-parsed conversation dict (for tests).
static func from_dict(data: Dictionary) -> DialogueRunner:
	var runner := DialogueRunner.new()
	runner._nodes = data.get("nodes", {})
	runner._start = data.get("start", "")
	return runner


## Enters the start node (applying its on-entry flag effects); returns self so
## callers can chain `DialogueRunner.from_id(id).start()`.
func start() -> DialogueRunner:
	_goto(_start)
	return self


func is_finished() -> bool:
	return _current == "" or not _nodes.has(_current)


func current_speaker() -> String:
	return _node().get("speaker", "")


func current_text() -> String:
	return _node().get("text", "")


## The choices offered at the current node, filtered by their require_flags. Each
## entry is the raw choice dict; index into it with choose() using this ordering.
func available_choices() -> Array:
	var out: Array = []
	for choice: Dictionary in _node().get("choices", []):
		if _flags_satisfied(choice.get("require_flags", {})):
			out.append(choice)
	return out


## Picks the index-th *available* choice: applies its flag effects and advances.
func choose(index: int) -> void:
	var choices := available_choices()
	if index < 0 or index >= choices.size():
		push_warning("DialogueRunner.choose: index %d out of range" % index)
		return
	var choice: Dictionary = choices[index]
	_apply_flags(choice.get("set_flags", {}))
	_goto(choice.get("goto", ""))


# --- internals ---------------------------------------------------------------


func _node() -> Dictionary:
	return _nodes.get(_current, {})


## Makes a node current, then applies its on-entry flag effects.
func _goto(node_id: String) -> void:
	_current = node_id
	if not is_finished():
		_apply_flags(_node().get("set_flags", {}))


func _apply_flags(flags: Dictionary) -> void:
	for key: String in flags:
		GameState.set_flag(key, flags[key])


func _flags_satisfied(required: Dictionary) -> bool:
	for key: String in required:
		if GameState.get_flag(key) != required[key]:
			return false
	return true
