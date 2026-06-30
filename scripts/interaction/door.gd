class_name Door
extends StaticBody3D
## The room's locked exit. Gated on holding an item; opening writes a GameState
## flag (progression never lives on the node itself). The gate decision (can_open)
## is pure so it is unit-testable on a bare Door.new(); the visual half (collision
## off, panel slides up) is a no-op when those child nodes are absent.

@export var requires_item: String = "rusted_key"
@export var opened_flag: String = "exit_unlocked"
@export var open_tension: float = 0.3
@export var open_rise: float = 2.2

var _opened: bool = false


func _ready() -> void:
	add_to_group("interactable")
	# A loaded save may have already opened this door.
	if GameState.get_flag(opened_flag):
		_opened = true
		_apply_open_visuals()


## Pure gate decision, no side effects. Safe on a bare instance (autoloads only).
func can_open() -> bool:
	return Inventory.has(requires_item)


## Opens if the gate passes: sets the flag, bumps tension, plays open visuals.
## Returns whether the door is now open. Idempotent.
func try_open() -> bool:
	if _opened:
		return true
	if not can_open():
		return false
	_opened = true
	GameState.set_flag(opened_flag, true)
	AudioDirector.set_tension(open_tension)
	_apply_open_visuals()
	return true


func is_open() -> bool:
	return _opened


func get_prompt() -> String:
	if _opened:
		return ""
	return "Press E to open" if can_open() else "Locked — needs a key"


func interact(_player: Node) -> void:
	try_open()


func _apply_open_visuals() -> void:
	# Guarded with get_node_or_null so try_open() works on a bare Door.new() in a
	# unit test; the scaffolded door.tscn supplies CollisionShape3D + Mesh.
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.position.y += open_rise
