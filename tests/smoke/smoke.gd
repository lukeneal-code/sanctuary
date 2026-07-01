extends Node
## Smoke test: boots the engine, verifies the core singletons interoperate
## (Phase 0), then drives the Phase 1 greybox slice end to end — look at the
## locked door, pick up the key, open the door, hold a branch of the conversation,
## and get spotted by the guard. Method-driven (no synthesized input) so it is
## deterministic and runs under --headless.
## Run via:  godot --headless --path . res://tests/smoke/smoke.tscn

const LEVEL_SCENE := preload("res://scenes/levels/level.tscn")


func _ready() -> void:
	var failures: Array[String] = []

	_check_core(failures)
	await _check_greybox_slice(failures)
	await _check_ceremony_opening(failures)

	if failures.is_empty():
		print("SMOKE: PASS — core loop + greybox slice + ceremony opening work end to end.")
		get_tree().quit(0)
	else:
		for f: String in failures:
			printerr("SMOKE FAIL: %s" % f)
		get_tree().quit(1)


# --- Phase 0: core singletons ------------------------------------------------


func _check_core(failures: Array[String]) -> void:
	for singleton: String in [
		"GameState", "Inventory", "SaveSystem", "SceneManager", "AudioDirector", "GlobalInput"
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

	# GameState was cleared above, so current_room is "" and the level host falls
	# back to its @export room_id ("greybox") — this drives the Phase 1 room.
	var room := LEVEL_SCENE.instantiate()
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

	# 2. Find the key — look at it through the real interactor + HUD so the prompt
	#    that appears must also clear when the pickup frees itself on pickup. Place
	#    the player at room centre facing the key with nothing interactable behind
	#    it (like looking down at the floor), so taking it must leave an empty prompt.
	var prompt_label: Label = null
	var hud := room.get_node_or_null("HUD")
	if hud:
		prompt_label = hud.get_node_or_null("Label")
	player.teleport(Vector3(0, 0.1, 0), 0.0)
	pickup.global_position = Vector3(0, 1.6, -1.5)  # on the forward ray, open space behind
	await get_tree().physics_frame
	interactor.force_update()
	if interactor.get_focused() != pickup:
		failures.append("interactor did not focus the key pickup")
	if prompt_label != null and prompt_label.text == "":
		failures.append("HUD prompt did not show for the focused pickup")
	interactor.try_interact()  # picks it up -> the pickup frees itself
	if not Inventory.has("rusted_key"):
		failures.append("key pickup did not add to inventory")
	await get_tree().physics_frame
	await get_tree().process_frame  # let queue_free actually delete the pickup
	interactor.force_update()
	if prompt_label != null and prompt_label.text != "":
		failures.append("HUD prompt lingered after the pickup was taken")

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
	player.teleport(Vector3(0, 0.1, 0), 0.0)
	guard.patrol_points = []  # hold still for a deterministic check
	guard.global_position = Vector3(0, 0, -3)
	GameState.set_flag("player_spotted", false)
	guard.look_at(Vector3(0, 0, 0), Vector3.UP)  # face the player at the origin
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not GameState.get_flag("player_spotted"):
		failures.append("guard did not spot the player with a clear line of sight")
	if not guard.sees_player():
		failures.append("guard sees_player() false despite a clear line of sight")

	# ...and looking away, it does not.
	GameState.set_flag("player_spotted", false)
	guard.look_at(Vector3(0, 0, -6), Vector3.UP)  # face away from the player
	await get_tree().physics_frame
	await get_tree().physics_frame
	if GameState.get_flag("player_spotted"):
		failures.append("guard spotted the player while facing away")
	if guard.sees_player():
		failures.append("guard still sees_player() while facing away")

	room.queue_free()


# --- Phase 2: the Ceremony opening beat --------------------------------------


## Drives the opening: wake in the booking cell, don the robe to unlock the exit,
## then (the transition) load the corridor where Coll waits and the Ceremony doors
## are sealed. The same generic level.tscn hosts both rooms; which it builds comes
## from GameState.current_room. The smoke instantiates the host as its own child
## (not via get_tree().change_scene), so it reproduces a transition by setting
## current_room + re-instantiating — the room_builder handler's real scene swap is
## a thin SceneManager call exercised in the running game.
func _check_ceremony_opening(failures: Array[String]) -> void:
	# --- Room 1: booking cell ---
	GameState.clear()
	Inventory.items.clear()
	GameState.current_room = "booking_cell"
	var booking := LEVEL_SCENE.instantiate()
	add_child(booking)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player: Player = booking.get_player()
	var robe: Pickup = booking.get_pickup()
	var exit_door: Door = booking.get_door()
	if player == null or robe == null or exit_door == null:
		failures.append("booking_cell did not build player/robe pickup/exit door")
		booking.queue_free()
		return

	# The exit is robe-gated: you can't leave until you're dressed.
	if exit_door.can_open():
		failures.append("booking exit openable before the robe is taken")
	if exit_door.target_room != "ceremony_corridor":
		failures.append("booking exit does not target the ceremony corridor")

	# Take the robe through the real interactor (place it on the forward ray).
	var interactor := player.get_interactor()
	player.teleport(Vector3(0, 0.1, 0), 0.0)
	robe.global_position = Vector3(0, 1.6, -1.5)
	await get_tree().physics_frame
	interactor.force_update()
	if interactor.get_focused() != robe:
		failures.append("interactor did not focus the robe pickup")
	interactor.try_interact()
	if not Inventory.has("initiate_robe"):
		failures.append("robe pickup did not add to inventory")
	if not exit_door.can_open():
		failures.append("booking exit still locked after donning the robe")
	booking.queue_free()
	await get_tree().process_frame

	# --- The transition: corridor, entered from the booking side ---
	GameState.current_room = "ceremony_corridor"
	GameState.player_spawn = "from_booking"
	var corridor := LEVEL_SCENE.instantiate()
	add_child(corridor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var coll: NpcTalker = corridor.get_npc()
	var ceremony_door: Door = corridor.get_door()
	if coll == null or ceremony_door == null:
		failures.append("ceremony_corridor did not build Coll/the ceremony door")
		corridor.queue_free()
		return
	if coll.dialogue_id != "coll_intro":
		failures.append("corridor NPC is not wired to coll_intro")
	if coll.dialogue_ui == null:
		failures.append("corridor NPC did not get its DialogueUI wired")
	if ceremony_door.can_open():
		failures.append("ceremony doors should be sealed (no summons yet)")

	# Talk to Coll: holding the conversation sets its flag.
	var convo := DialogueRunner.from_id(coll.dialogue_id)
	if convo == null:
		failures.append("coll_intro dialogue failed to load")
	else:
		convo.start()
		if not GameState.get_flag("met_coll"):
			failures.append("talking to Coll did not set met_coll")

	corridor.queue_free()
