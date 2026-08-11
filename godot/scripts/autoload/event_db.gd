extends Node
## Autoload. Single source of truth for every WorldEventData in the game.
## The simulation logic for each event lives in scripts/systems/events/*.gd,
## keyed by the same id.

var by_id: Dictionary = {} ## String id -> WorldEventData

func _ready() -> void:
	_build()

func get_event(id: String) -> WorldEventData:
	return by_id.get(id, null)

func all_ids() -> Array:
	return by_id.keys()

func random_id(rng: RandomNumberGenerator) -> String:
	var ids := all_ids()
	return ids[rng.randi_range(0, ids.size() - 1)]

func _def(id: String, name: String, duration: float, warmup: float, color: Color, params: Dictionary = {}) -> void:
	var e := WorldEventData.new()
	e.id = id
	e.display_name = name
	e.duration = duration
	e.warmup = warmup
	e.color = color
	e.params = params
	by_id[id] = e

func _build() -> void:
	_def("drought", "Drought", 30.0, 0.0, Color(0.63, 0.47, 0.16, 0.3), {"water_shrink": 0.5})
	_def("wildfire", "Wildfire", 32.0, 6.0, Color(0.82, 0.35, 0.08, 0.28), {"band_width": 160.0})
	_def("predator_surge", "Predator Surge", 28.0, 4.0, Color(0.55, 0.08, 0.08, 0.25), {"extra_predators": 3, "extra_apex": 1})
