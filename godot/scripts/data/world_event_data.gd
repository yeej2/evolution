class_name WorldEventData
extends Resource

## Data-driven description of an ecosystem event. The actual simulation
## logic lives in scripts/systems/events/*.gd (one script per id), this
## resource only carries the tunable parameters + presentation info so the
## server can broadcast a compact "event started" message that clients can
## render without simulating the event themselves.

@export var id: String = ""
@export var display_name: String = ""
@export var duration: float = 25.0
@export var warmup: float = 0.0
@export var color: Color = Color(1, 1, 1, 0.2)
@export var params: Dictionary = {} ## event-specific tunables (band width, etc.)

func _to_string() -> String:
	return "WorldEvent(%s)" % id
