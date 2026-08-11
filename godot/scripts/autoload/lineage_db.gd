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
		hunger_rate: float, color: Color, bonus: String, weights: Dictionary = {},
		attack: Dictionary = {}, handling: float = 1.0) -> void:
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
	l.handling = handling
	if attack.has("style"): l.attack_style = attack["style"]
	if attack.has("name"): l.attack_name = attack["name"]
	if attack.has("speed_base"): l.pounce_speed_base = attack["speed_base"]
	if attack.has("speed_charge_mult"): l.pounce_speed_charge_mult = attack["speed_charge_mult"]
	if attack.has("duration"): l.pounce_duration = attack["duration"]
	if attack.has("damage_base"): l.pounce_damage_base = attack["damage_base"]
	if attack.has("damage_charge_mult"): l.pounce_damage_charge_mult = attack["damage_charge_mult"]
	if attack.has("knockback_mult"): l.pounce_knockback_mult = attack["knockback_mult"]
	if attack.has("hit_radius_bonus"): l.pounce_hit_radius_bonus = attack["hit_radius_bonus"]
	by_id[id] = l

func _build() -> void:
	# Stalker: nimble ambush skirmisher. Quick, long, precise lunge; snappy
	# handling to match a creature built around repositioning constantly.
	_def("stalker", "Stalker", 12.0, 80.0, 145.0, 0.8, 1.4, Color("8a8ab8"),
		"First bite after hiding does +50% damage. Fast, long ambush lunge.",
		{"claws": 1.5, "legs": 1.3, "venom": 2.0, "camouflage": 2.0, "hide": 0.6, "jaws": 0.8},
		{"style": "lunge", "name": "Ambush Lunge", "speed_base": 400.0, "speed_charge_mult": 220.0,
			"duration": 0.28, "damage_base": 1.3, "damage_charge_mult": 1.3,
			"knockback_mult": 0.75, "hit_radius_bonus": 14.0},
		1.35)
	# Grazer: bulk shove, not a hunter's strike. Barely more damage than a
	# normal bite, but a long sustained charge with huge knockback - good for
	# clearing space or shoving something into water/off a ledge, not
	# winning a fight outright. Heavier, less responsive turning than Stalker.
	_def("grazer", "Grazer", 15.0, 120.0, 110.0, 1.0, 1.1, Color("6cb06c"),
		"Plants restore extra hunger. Sustained shoulder charge, huge shove.",
		{"claws": 0.7, "legs": 0.8, "venom": 0.5, "hide": 1.5, "diet_herbivore": 2.0, "ruminant_gut": 1.8},
		{"style": "charge", "name": "Shoulder Charge", "speed_base": 260.0, "speed_charge_mult": 90.0,
			"duration": 0.55, "damage_base": 1.0, "damage_charge_mult": 0.5,
			"knockback_mult": 2.2, "hit_radius_bonus": 26.0},
		0.85)
	# Titan: barely moves at all when it commits - this isn't a gap-closer,
	# it's a stationary slam that punishes anything that gets close. Full
	# charge roughly doubles the damage of a normal bite. Sluggish turning.
	_def("titan", "Titan", 22.0, 180.0, 82.0, 1.8, 2.1, Color("9e6e3e"),
		"Larger and tougher, but needs more food. Slow, devastating ground slam.",
		{"claws": 0.6, "legs": 0.6, "hide": 1.5, "jaws": 1.5, "bone_plate": 1.8, "diet_carnivore": 1.5},
		{"style": "slam", "name": "Ground Slam", "speed_base": 90.0, "speed_charge_mult": 30.0,
			"duration": 0.5, "damage_base": 1.4, "damage_charge_mult": 1.8,
			"knockback_mult": 2.6, "hit_radius_bonus": 34.0},
		0.55)
