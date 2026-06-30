extends SceneTree
## Run-once scaffold for the Phase 1 greybox slice. Builds each entity/UI/level
## node tree in code, packs it, and saves a .tscn so Godot assigns real UIDs
## (CLAUDE.md forbids hand-authoring .tscn with fabricated UIDs). Re-runnable: it
## overwrites its outputs. The generated scenes are committed and become the
## human's in-editor tuning surface (@export sliders, transforms).
##
## Run:  godot --headless --path . --script res://tools/godot/scaffold_phase1.gd
##
## Collision layers: 1=world, 2=interactable, 3=player, 4=guard.

const L_WORLD := 1
const L_INTERACTABLE := 2
const L_PLAYER := 4
const L_GUARD := 8


func _initialize() -> void:
	# Entities first — the level scene preloads them.
	_build_player()
	_build_door()
	_build_pickup()
	_build_npc()
	_build_guard()
	# UI next — the level scene instances these.
	_build_hud()
	_build_dialogue_ui()
	# Level last.
	_build_greybox()
	print("scaffold: done")
	quit()


# --- entities ----------------------------------------------------------------


func _build_player() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	root.set_script(load("res://scripts/player/player.gd"))
	root.collision_layer = L_PLAYER
	root.collision_mask = L_WORLD

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.height = 1.7
	cap.radius = 0.3
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	_attach(root, col)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.5, 0)
	_attach(root, head)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_attach(root, cam, head)

	var inter := RayCast3D.new()
	inter.name = "Interactor"
	inter.set_script(load("res://scripts/player/interactor.gd"))
	inter.target_position = Vector3(0, 0, -2.5)
	inter.collision_mask = L_WORLD | L_INTERACTABLE
	_attach(root, inter, cam)

	_save(root, "res://scenes/entities/player.tscn")


func _build_door() -> void:
	var root := StaticBody3D.new()
	root.name = "Door"
	root.set_script(load("res://scripts/interaction/door.gd"))
	# On both world + interactable: blocks the player AND is detectable by the ray.
	root.collision_layer = L_WORLD | L_INTERACTABLE
	root.collision_mask = 0
	_attach(root, _box_mesh("Mesh", Vector3(1.4, 2.2, 0.3)))
	_attach(root, _box_collision("CollisionShape3D", Vector3(1.4, 2.2, 0.3)))
	_save(root, "res://scenes/entities/door.tscn")


func _build_pickup() -> void:
	var root := Area3D.new()
	root.name = "Pickup"
	root.set_script(load("res://scripts/interaction/pickup.gd"))
	root.collision_layer = L_INTERACTABLE
	root.collision_mask = 0
	_attach(root, _box_mesh("Mesh", Vector3(0.25, 0.25, 0.25)))
	# Slightly larger collider so the interaction ray catches it easily.
	_attach(root, _box_collision("CollisionShape3D", Vector3(0.4, 0.4, 0.4)))
	_save(root, "res://scenes/entities/pickup.tscn")


func _build_npc() -> void:
	var root := Area3D.new()
	root.name = "Npc"
	root.set_script(load("res://scripts/interaction/npc_talker.gd"))
	root.collision_layer = L_INTERACTABLE
	root.collision_mask = 0
	_attach(root, _capsule_mesh("Mesh", 1.8, 0.3))
	_attach(root, _capsule_collision("CollisionShape3D", 1.8, 0.4))
	_save(root, "res://scenes/entities/npc.tscn")


func _build_guard() -> void:
	var root := CharacterBody3D.new()
	root.name = "Guard"
	root.set_script(load("res://scripts/stealth/guard.gd"))
	root.collision_layer = L_GUARD  # kept out of the world mask so LOS rays ignore it
	root.collision_mask = L_WORLD
	_attach(root, _capsule_mesh("Mesh", 1.8, 0.3))
	_attach(root, _capsule_collision("CollisionShape3D", 1.8, 0.3))
	_save(root, "res://scenes/entities/guard.tscn")


# --- ui ----------------------------------------------------------------------


func _build_hud() -> void:
	var root := CanvasLayer.new()
	root.name = "HUD"
	root.set_script(load("res://scripts/ui/interaction_prompt.gd"))
	var label := Label.new()
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -90
	label.offset_bottom = -50
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_attach(root, label)
	_save(root, "res://scenes/ui/hud.tscn")


func _build_dialogue_ui() -> void:
	var root := CanvasLayer.new()
	root.name = "DialogueUI"
	root.set_script(load("res://scripts/dialogue/dialogue_ui.gd"))

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = -260
	panel.offset_bottom = -40
	_attach(root, panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	_attach(root, vbox, panel)

	var speaker := Label.new()
	speaker.name = "Speaker"
	_attach(root, speaker, vbox)

	var text := Label.new()
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attach(root, text, vbox)

	var choices := VBoxContainer.new()
	choices.name = "Choices"
	_attach(root, choices, vbox)

	_save(root, "res://scenes/ui/dialogue_ui.tscn")


# --- level -------------------------------------------------------------------


func _build_greybox() -> void:
	var root := Node3D.new()
	root.name = "Greybox"
	root.set_script(load("res://scripts/levels/room_builder.gd"))
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	_attach(root, hud)
	var dui := (load("res://scenes/ui/dialogue_ui.tscn") as PackedScene).instantiate()
	_attach(root, dui)
	_save(root, "res://scenes/levels/greybox.tscn")


# --- helpers -----------------------------------------------------------------


## Adds `child` under `parent` (default root) and sets its owner to `root` so
## pack() records it. Owner is always the scene root being built.
func _attach(root: Node, child: Node, parent: Node = null) -> void:
	(parent if parent != null else root).add_child(child)
	child.owner = root


func _box_mesh(node_name: String, box_size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := BoxMesh.new()
	m.size = box_size
	mi.mesh = m
	return mi


func _box_collision(node_name: String, box_size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = node_name
	var s := BoxShape3D.new()
	s.size = box_size
	cs.shape = s
	return cs


func _capsule_mesh(node_name: String, height: float, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := CapsuleMesh.new()
	m.height = height
	m.radius = radius
	mi.mesh = m
	mi.position = Vector3(0, height / 2.0, 0)
	return mi


func _capsule_collision(node_name: String, height: float, radius: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = node_name
	var s := CapsuleShape3D.new()
	s.height = height
	s.radius = radius
	cs.shape = s
	cs.position = Vector3(0, height / 2.0, 0)
	return cs


func _save(root: Node, path: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("scaffold: pack failed for %s (err %d)" % [path, err])
		root.free()
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("scaffold: save failed for %s (err %d)" % [path, err])
	else:
		print("scaffold: wrote ", path)
	root.free()
