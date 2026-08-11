extends Node
## Autoload. Single source of truth for every LineageData in the game.
## The vertical slice ships three lineages: Stalker, Grazer, Titan.

var by_id: Dictionary = {} ## String id -> LineageData

func _ready() -> void:
	_build()

func get_lineage(id: String) -> LineageData:
	return by_id.get(id, null)

func all_ids() -> Array:
	return by_id.keys()

func _def(id: String, name: String, radius: float, hp: float, speed: float, mass: float,
		hunger_rate: float, color: Color, bonus: String, weights: Dictionary = {}) -> void:
	var l := LineageData.new()
	l.id = id
	l.display_name = name
	l.radius = radius
	l.base_hp = hp
	l.base_speed = speed
	l.mass = mass
	l.hunger_rate = hunger_rate
	l.color = color
	l.bonus_description = bonus
	l.mutation_weights = weights
	by_id[id] = l

func _build() -> void:
	_def("stalker", "Stalker", 12.0, 80.0, 145.0, 0.8, 1.4, Color("8a8ab8"),
		"First bite after hiding does +50% damage",
		{"claws": 1.5, "legs": 1.3, "venom": 2.0, "camouflage": 2.0, "hide": 0.6, "jaws": 0.8})
	_def("grazer", "Grazer", 15.0, 120.0, 110.0, 1.0, 1.1, Color("6cb06c"),
		"Plants restore extra hunger",
		{"claws": 0.7, "legs": 0.8, "venom": 0.5, "hide": 1.5, "diet_herbivore": 2.0, "ruminant_gut": 1.8})
	_def("titan", "Titan", 22.0, 180.0, 82.0, 1.8, 2.1, Color("9e6e3e"),
		"Larger and tougher, but needs more food",
		{"claws": 0.6, "legs": 0.6, "hide": 1.5, "jaws": 1.5, "bone_plate": 1.8, "diet_carnivore": 1.5})
