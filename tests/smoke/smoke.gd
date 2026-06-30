extends Node
## Smoke test: boots the engine, verifies the core singletons interoperate
## (Phase 0), then drives the Phase 1 greybox slice end to end — look at the
## locked door, pick up the key, open the door, hold a branch of the conversation,
## and get spotted by the guard. Method-driven (no synthesized input) so it is
## deterministic and runs under --headless.
## Run via:  godot --headless --path . res://tests/smoke/smoke.tscn


func _ready() -> void:
	var failures: Array[String] = []

	_check_core(failures)
	await _check_greybox_slice(failures)

	if failures.is_empty():
		print("SMOKE: PASS — core loop + greybox slice work end to end.")
		get_tree().quit(0)
	else:
		for f: String in failures:
			printerr("SMOKE FAIL: %s" % f)
		get_tree().quit(1)


# --- Phase 0: core singletons ------------------------------------------------


func _check_core(failures: Array[String]) -> void:
	for singleton: String in [
		"GameState", "Inventory", "SaveSystem", "SceneManager", "AudioDirector"
	]:
		if get_node_or_null("/root/" + singleton) == null:
			failures.append("missing autoload: %s" % singleton)

	GameState.clear()
	GameState.set_flag("smoke_flag", true)
	if not GameState.get_flag("smoke_flag"):
		failures.append("flag set/get failed")

	Inventory.items.clear()
	Inventory.add("rusted_key")
	if not Inventory.has("rusted_key"):
		failures.append("inventory add failed")

	if not SaveSystem.save_game(98):
		failures.append("save failed")
	GameState.clear()
	Inventory.items.clear()
	if not SaveSystem.load_game(98):
		failures.append("load failed")
	if not GameState.get_flag("smoke_flag"):
		failures.append("flag not restored after load")
	if not Inventory.has("rusted_key"):
		failures.append("inventory not restored after load")


# --- Phase 1: the greybox vertical slice -------------------------------------


func _check_greybox_slice(failures: Array[String]) -> void:
	GameState.clear()
	Inventory.items.clear()

	# Input map is wired (player movement reads these silently — a typo would not
	# error, so assert it here).
	for action: String in [
		"move_forward", "move_back", "move_left", "move_right", "interact", "crouch"
	]:
		if not InputMap.has_action(action):
			failures.append("missing input action: %s" % action)

	var room := (load("res://scenes/levels/greybox.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player: Player = room.get_player()
	var door: Door = room.get_door()
	var pickup: Pickup = room.get_pickup()
	var npc: NpcTalker = room.get_npc()
	var guard: Guard = room.get_guard()

	if player == null or door == null or pickup == null or npc == null or guard == null:
		failures.append("greybox did not build all entities (player/door/pickup/npc/guard)")
		room.queue_free()
		return

	# 1. Walk up to the locked door and look at it.
	player.teleport(Vector3(0, 0.1, -4), 0.0)  # in front of the door, facing -Z
	await get_tree().physics_frame
	var interactor := player.get_interactor()
	interactor.force_update()
	if interactor.get_focused() != door:
		failures.append("interactor did not focus the locked door")
	if door.can_open():
		failures.append("door is openable before the key is picked up")
	if GameState.get_flag("exit_unlocked"):
		failures.append("exit flag set before the door is opened")

	# 2. Find the key.
	pickup.interact(player)
	if not Inventory.has("rusted_key"):
		failures.append("key pickup did not add to inventory")

	# 3. Use the key — the door opens and writes its flag.
	if not door.try_open():
		failures.append("door did not open with the key")
	if not GameState.get_flag("exit_unlocked"):
		failures.append("exit flag not set after opening the door")

	# 4. Hold one branch of the conversation.
	var convo := DialogueRunner.from_id(npc.dialogue_id)
	if convo == null:
		failures.append("npc dialogue '%s' failed to load" % npc.dialogue_id)
	else:
		convo.start()
		convo.choose(0)  # "I have clearance." -> sets chose_bluff
		if not GameState.get_flag("chose_bluff"):
			failures.append("dialogue branch did not set its flag")

	# 5. Stealth: a guard with clear line of sight, facing the player, spots it.
	guard.patrol_points = []  # hold still for a deterministic check
	GameState.set_flag("player_spotted", false)
	guard.global_position = Vector3(0, 0, -2)
	guard.look_at(Vector3(0, 0, -4), Vector3.UP)  # face the player (horizontal, like patrol)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not GameState.get_flag("player_spotted"):
		failures.append("guard did not spot the player with a clear line of sight")

	# ...and looking away, it does not.
	GameState.set_flag("player_spotted", false)
	guard.look_at(Vector3(0, 0, 2), Vector3.UP)  # face away from the player (horizontal)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if GameState.get_flag("player_spotted"):
		failures.append("guard spotted the player while facing away")

	room.queue_free()
