class_name Player
extends CharacterBody3D
## First-person player: WASD move, mouse look, crude hold-to-crouch. Holds NO
## progression state. The room builder places it via teleport() using
## GameState.player_spawn; it is frozen while a conversation is open. Feel is all
## @export so it can be tuned in-editor (the agent cannot see the running game).

@export var move_speed: float = 3.5
@export var crouch_speed: float = 1.6
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 18.0
@export var stand_height: float = 1.7
@export var crouch_height: float = 0.9
@export var eye_height: float = 1.5

var is_crouching: bool = false
var frozen: bool = false  ## Set true during dialogue / cutscenes.

@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_head.rotate_x(-motion.relative.y * mouse_sensitivity)
		_head.rotation.x = clampf(_head.rotation.x, -1.55, 1.55)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_update_crouch(delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := crouch_speed if is_crouching else move_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


func _update_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	var target_h := crouch_height if is_crouching else stand_height
	var capsule := _collision.shape as CapsuleShape3D
	if capsule:
		capsule.height = lerpf(capsule.height, target_h, delta * 12.0)
	var target_eye := eye_height * (crouch_height / stand_height) if is_crouching else eye_height
	_head.position.y = lerpf(_head.position.y, target_eye, delta * 12.0)


## Places the player at a world position with a yaw (degrees). Used by the room
## builder's spawn points and by the smoke test. yaw 0 faces -Z.
func teleport(pos: Vector3, yaw_deg: float = 0.0) -> void:
	global_position = pos
	rotation.y = deg_to_rad(yaw_deg)
	velocity = Vector3.ZERO


func get_interactor() -> Node:
	return $Head/Camera3D/Interactor
