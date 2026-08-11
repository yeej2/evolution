extends Node
## Autoload. Single source of truth for every SpeciesData in the game.

var by_id: Dictionary = {} ## String id -> SpeciesData

func _ready() -> void:
	_build()

func get_species(id: String) -> SpeciesData:
	return by_id.get(id, null)

func ids_of_type(creature_type: String) -> Array:
	var out: Array = []
	for id in by_id.keys():
		if by_id[id].creature_type == creature_type:
			out.append(id)
	return out

func random_id_of_type(creature_type: String, rng: RandomNumberGenerator) -> String:
	var ids := ids_of_type(creature_type)
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]

func _def(id: String, name: String, creature_type: String, radius: float, hp: float,
		speed: float, mass: float, bite: float, sense: float, color: Color,
		flags: Dictionary = {}) -> void:
	var s := SpeciesData.new()
	s.id = id
	s.display_name = name
	s.creature_type = creature_type
	s.radius = radius
	s.base_hp = hp
	s.base_speed = speed
	s.mass = mass
	s.bite_damage = bite
	s.sense_range = sense
	s.color = color
	s.frontal_armor = flags.get("armor", 0.0)
	s.frontal_retaliation = flags.get("frontal_retaliation", false)
	s.rear_damage_bonus = flags.get("rear_bonus", 0.0)
	s.herd = flags.get("herd", false)
	s.territorial = flags.get("territorial", false)
	s.aquatic = flags.get("aquatic", false)
	s.water_tether = flags.get("water_tether", false)
	s.nocturnal = flags.get("nocturnal", false)
	s.scavenger = flags.get("scavenger", false)
	s.bush_eater = flags.get("bush_eater", false)
	s.pack = flags.get("pack", false)
	by_id[id] = s

func _build() -> void:
	_def("niblet", "Niblet", "prey", 8.0, 18.0, 115.0, 0.25, 0.0, 160.0, Color("9ec85a"),
		{"herd": true})
	_def("mossback", "Mossback", "prey", 15.0, 50.0, 70.0, 0.9, 0.0, 120.0, Color("5a8a4a"),
		{"bush_eater": true})
	_def("shellback", "Shellback", "prey", 17.0, 70.0, 65.0, 1.3, 0.0, 100.0, Color("7a9a6a"),
		{"armor": 0.7})
	_def("razorcat", "Razorcat", "predator", 13.0, 55.0, 115.0, 0.85, 10.0, 240.0, Color("a05050"),
		{"nocturnal": true, "pack": true})
	_def("riverjaw", "Riverjaw", "predator", 15.0, 70.0, 90.0, 1.0, 12.0, 220.0, Color("4a7a9a"),
		{"aquatic": true, "water_tether": true})
	_def("carrion_beetle", "Carrion Beetle", "predator", 12.0, 40.0, 85.0, 0.6, 5.0, 260.0, Color("6a5a4a"),
		{"scavenger": true})
	_def("great_horn", "Great Horn", "apex", 32.0, 240.0, 55.0, 4.0, 22.0, 260.0, Color("6a3a8a"),
		{"territorial": true, "armor": 0.6, "frontal_retaliation": true, "rear_bonus": 0.4})
