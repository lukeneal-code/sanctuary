class_name Door
extends StaticBody3D
## The room's exit. Optionally gated on holding an item; opening writes a GameState
## flag (progression never lives on the node itself). The gate decision (can_open)
## is pure so it is unit-testable on a bare Door.new(); the visual half (collision
## off, panel slides up) is a no-op when those child nodes are absent.
##
## A "threshold" door (target_room set) emits transition_requested on open instead
## of changing scenes itself — the room_builder owns the actual scene swap, so the
## door stays free of SceneManager coupling and testable on a bare instance.

## Emitted when a threshold door opens. The room_builder performs the scene swap.
signal transition_requested(target_room: String, target_spawn: String)

## Empty requires_item means no item is needed — the door is always openable.
@export var requires_item: String = "rusted_key"
@export var opened_flag: String = "exit_unlocked"
@export var open_tension: float = 0.3
@export var open_rise: float = 2.2
## If set, opening this door requests a transition to target_room at target_spawn.
@export var target_room: String = ""
@export var target_spawn: String = "default"
## Shown instead of the default locked line when the door cannot open (flavor).
@export var locked_prompt: String = ""

var _opened: bool = false


func _ready() -> void:
	add_to_group("interactable")
	# A loaded save may have already opened this door.
	if GameState.get_flag(opened_flag):
		_opened = true
		_apply_open_visuals()


## Pure gate decision, no side effects. Safe on a bare instance (autoloads only).
## An empty requires_item means the door has no requirement and always opens.
func can_open() -> bool:
	if requires_item == "":
		return true
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
	if can_open():
		return "Press E to open"
	return locked_prompt if locked_prompt != "" else "Locked — needs a key"


## Opens the door, then (for a threshold door) asks the level host to swap rooms.
## The door does not change scenes itself, so this stays safe on a bare instance.
func interact(_player: Node) -> void:
	if try_open() and target_room != "":
		transition_requested.emit(target_room, target_spawn)


func _apply_open_visuals() -> void:
	# Guarded with get_node_or_null so try_open() works on a bare Door.new() in a
	# unit test; the scaffolded door.tscn supplies CollisionShape3D + Mesh.
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.position.y += open_rise
