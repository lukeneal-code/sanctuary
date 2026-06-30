class_name Interactor
extends RayCast3D
## Camera-forward ray that highlights the interactable under the crosshair and
## dispatches interact() to it on the `interact` action. Focus is recomputed each
## physics frame; the smoke test drives it deterministically via force_update() +
## get_focused() rather than synthesizing input. An interactable is any node in
## the "interactable" group exposing interact(player) (and optionally get_prompt()).

signal focus_changed(node: Node)

var _focused: Node = null


func _ready() -> void:
	collide_with_areas = true
	collide_with_bodies = true
	enabled = true


func _physics_process(_delta: float) -> void:
	_recompute_focus()
	if Input.is_action_just_pressed("interact"):
		try_interact()


## Forces an immediate raycast + focus refresh (used by the smoke test).
func force_update() -> void:
	force_raycast_update()
	_recompute_focus()


func get_focused() -> Node:
	return _focused


func try_interact() -> void:
	if _focused and _focused.has_method("interact"):
		_focused.interact(owner)  # owner is the Player root of the instanced scene


func _recompute_focus() -> void:
	var hit: Node = null
	if is_colliding():
		var collider := get_collider()
		if collider is Node and (collider as Node).is_in_group("interactable"):
			hit = collider
	if hit != _focused:
		_focused = hit
		focus_changed.emit(_focused)
