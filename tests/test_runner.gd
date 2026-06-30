extends Node
## Minimal, dependency-free test runner so the harness works out of the box.
## Run via:  godot --headless --path . res://tests/test_runner.tscn
## Exits 0 if all tests pass, 1 otherwise. Swap for GUT later (see CLAUDE.md).
##
## Any method named test_* is discovered and run automatically. Shared singleton
## state is reset before each test.

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _ready() -> void:
	print("== Sanctuary unit tests ==")
	for method: Dictionary in get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			_run(method_name)
	print("\n== %d passed, %d failed ==" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run(method_name: String) -> void:
	_current = method_name
	GameState.clear()
	Inventory.items.clear()
	call(method_name)


func _ok(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, msg])


func _eq(a: Variant, b: Variant, msg: String) -> void:
	_ok(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


# --- GameState ---------------------------------------------------------------


func test_flag_set_and_get() -> void:
	GameState.set_flag("met_overseer")
	_ok(GameState.get_flag("met_overseer"), "flag should be true after set")
	_ok(not GameState.get_flag("unset_flag"), "unset flag should default to false")


func test_flag_change_signal_fires_once() -> void:
	var seen: Array = []
	var cb: Callable = func(key: String, _value: Variant) -> void: seen.append(key)
	GameState.flag_changed.connect(cb)
	GameState.set_flag("ceremony_done", true)
	GameState.set_flag("ceremony_done", true)  # no change -> no second emit
	GameState.flag_changed.disconnect(cb)
	_eq(seen.size(), 1, "flag_changed should fire once for a real change")


# --- Inventory ---------------------------------------------------------------


func test_inventory_add_remove() -> void:
	_ok(Inventory.add("rusted_key"), "add returns true for a new item")
	_ok(Inventory.has("rusted_key"), "inventory has the added item")
	_ok(not Inventory.add("rusted_key"), "add returns false for a duplicate")
	_ok(Inventory.remove("rusted_key"), "remove returns true")
	_ok(not Inventory.has("rusted_key"), "item is gone after remove")


func test_inventory_combine() -> void:
	Inventory.add("wire")
	Inventory.add("battery")
	var result: String = Inventory.combine("wire", "battery")
	_eq(result, "shiv_light", "wire + battery should combine into shiv_light")
	_ok(Inventory.has("shiv_light"), "combined item is in inventory")
	_ok(not Inventory.has("wire"), "component is consumed by combine")


# --- SaveSystem round-trip ---------------------------------------------------


func test_save_load_roundtrip() -> void:
	GameState.set_flag("met_overseer", true)
	GameState.set_flag("sector", "amber")
	GameState.current_objective = "Attend the Ceremony"
	Inventory.add("rusted_key")
	_ok(SaveSystem.save_game(99), "save_game succeeds")

	GameState.clear()
	Inventory.items.clear()
	_ok(not GameState.get_flag("met_overseer"), "state cleared before load")

	_ok(SaveSystem.load_game(99), "load_game succeeds")
	_ok(GameState.get_flag("met_overseer"), "bool flag restored")
	_eq(GameState.get_flag("sector"), "amber", "string flag restored")
	_eq(GameState.current_objective, "Attend the Ceremony", "objective restored")
	_ok(Inventory.has("rusted_key"), "inventory restored")


# --- DialogueRunner (Phase 1) ------------------------------------------------


func test_dialogue_real_file_parses() -> void:
	var dr := DialogueRunner.from_id("guard_intro")
	_ok(dr != null, "guard_intro.json loads")
	if dr == null:
		return
	dr.start()
	_ok(not dr.is_finished(), "start node is valid")
	_eq(dr.current_speaker(), "Overseer", "start speaker is Overseer")


func test_dialogue_branch_sets_flags() -> void:
	var dr := DialogueRunner.from_id("guard_intro")
	dr.start()
	_ok(GameState.get_flag("met_overseer"), "node entry flags applied on start")
	_eq(dr.available_choices().size(), 2, "start offers two choices")
	dr.choose(0)  # "I have clearance." -> n_bluff
	_ok(GameState.get_flag("chose_bluff"), "choice set_flags applied")
	_ok(GameState.get_flag("overseer_suspicious"), "destination entry flags applied")
	dr.choose(0)  # "(Step back.)" -> "" ends
	_ok(dr.is_finished(), "conversation ends on empty goto")


func test_dialogue_choice_requires_flag() -> void:
	var data := {
		"start": "n",
		"nodes":
		{
			"n":
			{
				"speaker": "X",
				"text": "...",
				"choices":
				[
					{"text": "gated", "goto": "", "require_flags": {"has_pass": true}},
					{"text": "always", "goto": ""},
				],
			},
		},
	}
	var dr := DialogueRunner.from_dict(data)
	dr.start()
	_eq(dr.available_choices().size(), 1, "gated choice hidden until its flag is set")
	GameState.set_flag("has_pass", true)
	_eq(dr.available_choices().size(), 2, "gated choice appears once flag is set")


# --- GuardVision (Phase 1) ---------------------------------------------------


func test_guard_vision_cone() -> void:
	var eye := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)  # facing -Z
	_ok(
		GuardVision.in_view_cone(eye, fwd, 70.0, 8.0, Vector3(0, 0, -5)),
		"sees target ahead in range"
	)
	_ok(
		not GuardVision.in_view_cone(eye, fwd, 70.0, 8.0, Vector3(0, 0, 5)),
		"does not see target behind",
	)
	_ok(
		not GuardVision.in_view_cone(eye, fwd, 70.0, 8.0, Vector3(0, 0, -12)),
		"does not see target beyond range",
	)
	_ok(
		not GuardVision.in_view_cone(eye, fwd, 70.0, 8.0, Vector3(5, 0, 0)),
		"does not see target outside the fov cone",
	)


# --- Door gating + Pickup (Phase 1) ------------------------------------------


func test_door_gating() -> void:
	var d := Door.new()
	d.requires_item = "rusted_key"
	d.opened_flag = "exit_unlocked"
	add_child(d)
	_ok(not d.can_open(), "door is locked without the key")
	_ok(not d.try_open(), "try_open fails without the key")
	_ok(not GameState.get_flag("exit_unlocked"), "opened flag stays unset while locked")
	Inventory.add("rusted_key")
	_ok(d.can_open(), "door is openable with the key")
	_ok(d.try_open(), "try_open succeeds with the key")
	_ok(GameState.get_flag("exit_unlocked"), "opened flag is set after opening")
	d.queue_free()


func test_pickup_adds_item() -> void:
	var p := Pickup.new()
	p.item_id = "rusted_key"
	add_child(p)
	p.interact(null)
	_ok(Inventory.has("rusted_key"), "pickup adds its item to the inventory")
