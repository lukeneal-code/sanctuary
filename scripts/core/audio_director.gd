extends Node
## Stub. Real ambient-layer crossfading and tension stingers arrive in Phase 5.
## Kept node-free so it is safe to run under --headless.

var tension: float = 0.0
var current_ambient: String = ""


func play_ambient(track: String) -> void:
	current_ambient = track
	# TODO Phase 5: crossfade between ambient layers.


func set_tension(level: float) -> void:
	tension = clampf(level, 0.0, 1.0)
	# TODO Phase 5: drive stinger / layer intensity from this value.
