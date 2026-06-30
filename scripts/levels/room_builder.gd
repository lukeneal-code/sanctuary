extends Node3D
## Builds the greybox room from data/rooms/<id>.json: a primitive CSG shell, then
## entity scenes (pickup / door / npc / guard) and the player placed at the spawn
## named by GameState.player_spawn. Data-driven, so adding room content means
## editing JSON, not this script. Exposes getters so the smoke test can drive the
## slice. The HUD + DialogueUI are authored as children of greybox.tscn.
##
## Entity scenes are loaded at runtime (not preloaded) so this script compiles
## before the scaffold has generated those .tscn files.

const ROOMS_DIR := "res://data/rooms/"
const PLAYER_SCENE := "res://scenes/entities/player.tscn"
const DOOR_SCENE := "res://scenes/entities/door.tscn"
const PICKUP_SCENE := "res://scenes/entities/pickup.tscn"
const NPC_SCENE := "res://scenes/entities/npc.tscn"
const GUARD_SCENE := "res://scenes/entities/guard.tscn"

@export var room_id: String = "greybox"

var _player: Player = null
var _door: Door = null
var _pickup: Pickup = null
var _npc: NpcTalker = null
var _guard: Guard = null
var _textures: Dictionary = {}


func _ready() -> void:
	var data := _load_room(room_id)
	if data.is_empty():
		return
	_textures = TextureCatalog.load_all()
	_build_shell(data.get("size", [12, 4, 12]), data.get("surfaces", {}))
	_build_lighting(data.get("light", {}))
	_spawn_player(data.get("spawns", {}))
	_spawn_entities(data.get("entities", []))
	_wire_ui()
	AudioDirector.play_ambient(data.get("ambient", ""))


func get_player() -> Player:
	return _player


func get_door() -> Door:
	return _door


func get_pickup() -> Pickup:
	return _pickup


func get_npc() -> NpcTalker:
	return _npc


func get_guard() -> Guard:
	return _guard


# --- build -------------------------------------------------------------------


func _load_room(id: String) -> Dictionary:
	var path := ROOMS_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("room_builder: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("room_builder: %s is not a JSON object" % path)
		return {}
	return parsed


## Surfaces are optional: an absent role leaves that CSG box untextured (the grey
## greybox default), so rooms without a "surfaces" block render exactly as before.
func _build_shell(size_arr: Array, surfaces: Dictionary) -> void:
	var w: float = size_arr[0]
	var h: float = size_arr[1]
	var d: float = size_arr[2]
	var floor_tex: String = surfaces.get("floor", "")
	var ceiling_tex: String = surfaces.get("ceiling", "")
	var wall_tex: String = surfaces.get("walls", "")
	_add_box(Vector3(w, 0.2, d), Vector3(0, -0.1, 0), "Floor", floor_tex)
	_add_box(Vector3(w, 0.2, d), Vector3(0, h, 0), "Ceiling", ceiling_tex)
	_add_box(Vector3(0.2, h, d), Vector3(w / 2.0, h / 2.0, 0), "WallEast", wall_tex)
	_add_box(Vector3(0.2, h, d), Vector3(-w / 2.0, h / 2.0, 0), "WallWest", wall_tex)
	_add_box(Vector3(w, h, 0.2), Vector3(0, h / 2.0, d / 2.0), "WallSouth", wall_tex)
	# North wall (-Z) has a doorway gap centered on x=0 where the exit door sits.
	var gap := 1.8
	var seg := (w - gap) / 2.0
	_add_box(
		Vector3(seg, h, 0.2),
		Vector3(-(gap / 2.0 + seg / 2.0), h / 2.0, -d / 2.0),
		"WallNorthL",
		wall_tex,
	)
	_add_box(
		Vector3(seg, h, 0.2),
		Vector3(gap / 2.0 + seg / 2.0, h / 2.0, -d / 2.0),
		"WallNorthR",
		wall_tex,
	)


## Ambient environment + a single directional "sun" so the greybox is readable.
## All values come from the room JSON's optional "light" block (tune them there;
## no scene regeneration needed). Dark-but-visible by default, per the PSX look.
func _build_lighting(cfg: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _to_color(cfg.get("bg_color", [0.05, 0.05, 0.07]))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _to_color(cfg.get("ambient_color", [0.62, 0.64, 0.72]))
	env.ambient_light_energy = float(cfg.get("ambient_energy", 0.8))
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = float(cfg.get("sun_energy", 1.1))
	var ang := cfg.get("sun_angle", [-55, -130]) as Array
	sun.rotation = Vector3(deg_to_rad(float(ang[0])), deg_to_rad(float(ang[1])), 0.0)
	add_child(sun)


func _add_box(box_size: Vector3, pos: Vector3, node_name: String, tex_id: String = "") -> void:
	var box := CSGBox3D.new()
	box.size = box_size
	box.position = pos
	box.use_collision = true  # CSG collision lands on layer 1 (world) by default
	box.name = node_name
	if tex_id != "":
		box.material = TextureCatalog.make_material(tex_id, _textures)
	add_child(box)


func _spawn_player(spawns: Dictionary) -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(_player)
	var spawn: Dictionary = spawns.get(GameState.player_spawn, spawns.get("default", {}))
	_player.teleport(_to_vec3(spawn.get("pos", [0, 0.1, 0])), spawn.get("yaw", 0.0))


func _spawn_entities(entities: Array) -> void:
	for e: Dictionary in entities:
		match e.get("type", ""):
			"pickup":
				_spawn_pickup(e)
			"door":
				_spawn_door(e)
			"npc":
				_spawn_npc(e)
			"guard":
				_spawn_guard(e)
			_:
				push_warning("room_builder: unknown entity type '%s'" % e.get("type", ""))


func _spawn_pickup(e: Dictionary) -> void:
	_pickup = (load(PICKUP_SCENE) as PackedScene).instantiate() as Pickup
	_pickup.item_id = e.get("item", "")
	add_child(_pickup)
	_pickup.global_position = _to_vec3(e.get("pos", [0, 0.5, 0]))


func _spawn_door(e: Dictionary) -> void:
	_door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	_door.requires_item = e.get("requires_item", "rusted_key")
	_door.opened_flag = e.get("opened_flag", "exit_unlocked")
	add_child(_door)
	_door.global_position = _to_vec3(e.get("pos", [0, 1.1, 0]))


func _spawn_npc(e: Dictionary) -> void:
	_npc = (load(NPC_SCENE) as PackedScene).instantiate() as NpcTalker
	_npc.dialogue_id = e.get("dialogue", "")
	_npc.npc_name = e.get("name", "")
	add_child(_npc)
	_npc.global_position = _to_vec3(e.get("pos", [0, 0, 0]))
	_npc.rotation.y = deg_to_rad(e.get("yaw", 0.0))


func _spawn_guard(e: Dictionary) -> void:
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate() as Guard
	_guard.fov_deg = e.get("fov", 70.0)
	_guard.sight_range = e.get("range", 8.0)
	_guard.move_speed = e.get("speed", 1.5)
	var pts: Array[Vector3] = []
	for p: Variant in e.get("patrol", []):
		pts.append(_to_vec3(p))
	_guard.patrol_points = pts
	add_child(_guard)
	_guard.global_position = _to_vec3(e.get("pos", [0, 0, 0]))


## Wires the HUD prompt to the (dynamically spawned) interactor and hands the
## DialogueUI to the NPC. HUD + DialogueUI are authored children of greybox.tscn.
func _wire_ui() -> void:
	var hud := get_node_or_null("HUD")
	if hud and _player:
		hud.bind_interactor(_player.get_interactor())
	var dui := get_node_or_null("DialogueUI")
	if dui and _npc:
		_npc.dialogue_ui = dui


func _to_vec3(arr: Variant) -> Vector3:
	var a := arr as Array
	if a == null or a.size() < 3:
		return Vector3.ZERO
	return Vector3(a[0], a[1], a[2])


func _to_color(arr: Variant) -> Color:
	var a := arr as Array
	if a == null or a.size() < 3:
		return Color.WHITE
	return Color(a[0], a[1], a[2])
