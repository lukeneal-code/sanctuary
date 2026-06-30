class_name Guard
extends CharacterBody3D
## A crude patrolling guard. Ping-pongs between waypoints and, each physics frame,
## checks whether it can see the player: the vision cone (pure GuardVision) AND an
## unobstructed line of sight (raycast — walls block it). On a sighting it raises
## the 'player_spotted' flag and tension, and tints red so detection is visible in
## the greybox (the agent can't see the game; this is the human's feedback channel).
## Detection is exposed as can_see()/sees_player() so the smoke test can query it.

@export var patrol_points: Array[Vector3] = []
@export var fov_deg: float = 70.0
@export var sight_range: float = 8.0
@export var move_speed: float = 1.5
@export var eye_height: float = 1.6
@export var spotted_flag: String = "player_spotted"
@export var calm_color: Color = Color(0.55, 0.55, 0.6)
@export var alert_color: Color = Color(0.9, 0.15, 0.15)

var _target_index: int = 0
var _sees_player: bool = false

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group("guard")
	_apply_alert_tint(false)


func _physics_process(delta: float) -> void:
	_patrol(delta)
	var player := _find_player()
	var sees: bool = player != null and can_see(player.global_position + Vector3.UP)
	# Latch the flag/tension every frame it sees the player (set_flag is a no-op
	# when unchanged); only flip the visible tint + log on the rising/falling edge.
	if sees:
		GameState.set_flag(spotted_flag, true)
		AudioDirector.set_tension(1.0)
	if sees != _sees_player:
		_sees_player = sees
		_apply_alert_tint(sees)
		if sees:
			print("Guard: spotted the player")


## Whether the guard can currently see the player (live, not the latched flag).
func sees_player() -> bool:
	return _sees_player


## True when `target` is inside the vision cone AND not occluded by world geometry.
func can_see(target: Vector3) -> bool:
	if not GuardVision.in_view_cone(_eye_pos(), _forward(), fov_deg, sight_range, target):
		return false
	return _has_line_of_sight(target)


func _patrol(_delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target: Vector3 = patrol_points[_target_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.2:
		_target_index = (_target_index + 1) % patrol_points.size()
		return
	var dir := to_target.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	look_at(global_position + dir, Vector3.UP)
	move_and_slide()


func _eye_pos() -> Vector3:
	return global_position + Vector3.UP * eye_height


func _forward() -> Vector3:
	return -global_transform.basis.z


func _has_line_of_sight(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_eye_pos(), target)
	query.collision_mask = 1  # world geometry only
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()  # nothing between eye and target -> clear view


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node3D if players.size() > 0 else null


## Crude alert feedback: tint the guard mesh red while it can see the player.
func _apply_alert_tint(alert: bool) -> void:
	if not is_instance_valid(_mesh):
		return
	var mat := _mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		_mesh.material_override = mat
	mat.albedo_color = alert_color if alert else calm_color
