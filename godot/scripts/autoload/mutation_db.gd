extends Node
## Autoload. Single source of truth for every MutationData in the game.
## Adding mutation #100 means adding one entry to _DEFS below - nothing else
## in the codebase needs to change.

var by_id: Dictionary = {} ## String id -> MutationData

func _ready() -> void:
	_build()

func get_mutation(id: String) -> MutationData:
	return by_id.get(id, null)

func all_ids() -> Array:
	return by_id.keys()

## Returns the ids of every mutation whose prerequisites are met and whose
## exclusions are not violated by `owned` (an Array[String]).
func available_for(owned: Array, family_filter: String = "") -> Array:
	var out: Array = []
	for id in by_id.keys():
		if owned.has(id):
			continue
		var m: MutationData = by_id[id]
		if family_filter != "" and m.family != family_filter:
			continue
		var reqs_ok := true
		for req in m.requires:
			if not owned.has(req):
				reqs_ok = false
				break
		if not reqs_ok:
			continue
		var excluded := false
		for ex in m.excludes:
			if owned.has(ex):
				excluded = true
				break
		if excluded:
			continue
		out.append(id)
	return out

func _def(id: String, name: String, category: String, family: String, tier: int,
		desc: String, effect_txt: String, tradeoff_txt: String,
		requires: Array = [], excludes: Array = [], effects: Dictionary = {}) -> void:
	var m := MutationData.new()
	m.id = id
	m.display_name = name
	m.category = category
	m.family = family
	m.tier = tier
	m.description = desc
	m.effect_summary = effect_txt
	m.tradeoff_summary = tradeoff_txt
	var req_arr: Array[String] = []
	for r in requires:
		req_arr.append(r)
	m.requires = req_arr
	var ex_arr: Array[String] = []
	for e in excludes:
		ex_arr.append(e)
	m.excludes = ex_arr
	m.effects = effects
	by_id[id] = m

func _build() -> void:
	# ---- Tier 1 bases ----
	_def("claws", "Sharp Claws", "Offense", "claws", 1,
		"Scratch bark, raid nests, climb over obstacles.",
		"Bite +3, climb trees", "Slightly smaller",
		[], [], {EffectKeys.BITE_DAMAGE_ADD: 3.0, EffectKeys.RADIUS_ADD: -1.0})

	_def("legs", "Long Legs", "Movement", "legs", 1,
		"Sprint further and cross shallows with ease.",
		"Speed +25%, water faster", "-5 max HP",
		[], [], {EffectKeys.SPEED_MULT: 1.25, EffectKeys.MAX_HP_ADD: -5.0})

	_def("hide", "Thick Hide", "Defense", "hide", 1,
		"Take hits and intimidate smaller creatures.",
		"+30 HP, +mass", "-12% speed, bigger",
		[], [], {EffectKeys.MAX_HP_ADD: 30.0, EffectKeys.MASS_ADD: 0.5, EffectKeys.SPEED_MULT: 0.88, EffectKeys.RADIUS_ADD: 4.0})

	_def("venom", "Venom Fangs", "Offense", "venom", 1,
		"Wear prey down over time.",
		"Bite poisons target", "+2 bite energy cost",
		[], [], {EffectKeys.POISON_ON_HIT: 5.0})

	_def("jaws", "Strong Jaws", "Offense", "jaws", 1,
		"Crack bones and smash obstacles.",
		"Bite +5, bite through rocks to clear a path", "-8% speed",
		[], [], {EffectKeys.BITE_DAMAGE_ADD: 5.0, EffectKeys.MASS_ADD: 0.2, EffectKeys.SPEED_MULT: 0.92, EffectKeys.RADIUS_ADD: 2.0, EffectKeys.BREAK_ROCKS: true})

	# ---- Claws branch (Tier 2, mutually exclusive specializations) ----
	var claws_branch := ["rending_claws", "climbing_claws", "digging_claws", "grasping_claws"]
	_def("rending_claws", "Rending Claws", "Offense", "claws", 2,
		"Claws tear deep, bleeding wounds.",
		"Bite +2, 6s bleed", "Slower attack",
		["claws"], _others(claws_branch, "rending_claws"),
		{EffectKeys.BITE_DAMAGE_ADD: 2.0, EffectKeys.BLEED_ON_HIT: 6.0})
	_def("climbing_claws", "Climbing Claws", "Movement", "claws", 2,
		"Claws become climbing hooks.",
		"Climb over fallen logs freely, +8% speed", "More visible",
		["claws"], _others(claws_branch, "climbing_claws"),
		{EffectKeys.SPEED_MULT: 1.08, EffectKeys.CLIMB_SPEED_MULT: 1.5, EffectKeys.CLIMB_OVER_LOGS: true})
	_def("digging_claws", "Digging Claws", "Movement", "claws", 2,
		"Claws widen for burrowing through soft ground.",
		"Can burrow to hide (E) anywhere, not just at a Burrow", "Slower on open ground",
		["claws"], _others(claws_branch, "digging_claws"),
		{EffectKeys.SPEED_MULT: 0.95, EffectKeys.BURROW: true})
	_def("grasping_claws", "Grasping Claws", "Control", "claws", 2,
		"Claws gain dexterity for grappling prey.",
		"Pounce holds target briefly", "None",
		["claws"], _others(claws_branch, "grasping_claws"),
		{EffectKeys.STUN_ON_POUNCE: 0.4})

	# ---- Hide branch ----
	var hide_branch := ["bone_plate", "camouflage", "thorns", "insulation", "fur"]
	_def("bone_plate", "Bone Plate", "Defense", "hide", 2,
		"Hide hardens into bony plates.",
		"+20 HP, +mass", "Slightly slower",
		["hide"], _others(hide_branch, "bone_plate"),
		{EffectKeys.MAX_HP_ADD: 20.0, EffectKeys.MASS_ADD: 0.3, EffectKeys.SPEED_MULT: 0.97})
	_def("camouflage", "Camouflage", "Stealth", "hide", 2,
		"Hide hardens into mottled, blending skin.",
		"Hide in 0.6s, harder to spot while still", "No bonus while moving",
		["hide"], _others(hide_branch, "camouflage"),
		{EffectKeys.STEALTH_HIDE_TIME_MULT: 0.4})
	_def("thorns", "Thorns", "Defense", "hide", 2,
		"Hide sprouts sharp spines.",
		"Attackers take 20% reflect damage", "None",
		["hide"], _others(hide_branch, "thorns"),
		{EffectKeys.REFLECT_DAMAGE_PCT: 0.2})
	_def("insulation", "Insulation", "Survival", "hide", 2,
		"Hide grows a fatty, resistant layer.",
		"Immune to poison and fire, cold-hardy, +10 HP", "None",
		["hide"], _others(hide_branch, "insulation"),
		{EffectKeys.MAX_HP_ADD: 10.0, EffectKeys.POISON_IMMUNE: true, EffectKeys.FIRE_IMMUNE: true, EffectKeys.COLD_ADAPTED: true})
	_def("fur", "Thick Fur", "Survival", "hide", 2,
		"Hide grows a dense, cold-hardy coat.",
		"Cold-hardy, no stealth penalty in the open", "Easier to spot in warm biomes",
		["hide"], _others(hide_branch, "fur"),
		{EffectKeys.COLD_ADAPTED: true, EffectKeys.MAX_HP_ADD: 5.0})

	# ---- Legs branch ----
	var legs_branch := ["strider", "long_jumper", "mud_legs"]
	_def("strider", "Strider", "Movement", "legs", 2,
		"Legs lengthen for open ground.",
		"+15% land speed", "None",
		["legs"], _others(legs_branch, "strider"),
		{EffectKeys.SPEED_MULT: 1.15})
	_def("long_jumper", "Long Jumper", "Movement", "legs", 2,
		"Legs coil for huge leaps.",
		"Pounce distance +50%", "None",
		["legs"], _others(legs_branch, "long_jumper"),
		{EffectKeys.POUNCE_DISTANCE_MULT: 1.5})
	_def("mud_legs", "Mud Legs", "Movement", "legs", 2,
		"Wide legs never sink in mud or shallows.",
		"Ignore water slowdown", "None",
		["legs"], _others(legs_branch, "mud_legs"),
		{EffectKeys.IGNORE_WATER_SLOW: true})

	# ---- Venom branch ----
	var venom_branch := ["toxic_spit", "numbing_venom", "parasitic_venom"]
	_def("toxic_spit", "Toxic Spit", "Offense", "venom", 2,
		"Venom glands become weaponized.",
		"Venom lasts 8s", "+1 bite cost",
		["venom"], _others(venom_branch, "toxic_spit"),
		{EffectKeys.POISON_ON_HIT: 8.0})
	_def("numbing_venom", "Numbing Venom", "Control", "venom", 2,
		"Venom dulls muscle and nerve.",
		"Poison also slows target 30%", "None",
		["venom"], _others(venom_branch, "numbing_venom"),
		{EffectKeys.NUMBING_POISON: true})
	_def("parasitic_venom", "Parasitic Venom", "Survival", "venom", 2,
		"Venom feeds back into your own body.",
		"Poison damage heals you", "None",
		["venom"], _others(venom_branch, "parasitic_venom"),
		{EffectKeys.PARASITIC_POISON: true})

	# ---- Jaws branch ----
	var jaws_branch := ["crushing_jaws", "stunning_bite", "ruminant_gut"]
	_def("crushing_jaws", "Crushing Jaws", "Offense", "jaws", 2,
		"Jaws strong enough to shatter bone.",
		"Bite knockback +40%", "None",
		["jaws"], _others(jaws_branch, "crushing_jaws"),
		{EffectKeys.KNOCKBACK_MULT: 1.4})
	_def("stunning_bite", "Stunning Bite", "Control", "jaws", 2,
		"A crushing grip that rattles prey.",
		"Bite briefly stuns target", "None",
		["jaws"], _others(jaws_branch, "stunning_bite"),
		{EffectKeys.STUN_ON_HIT: 0.3})
	_def("ruminant_gut", "Ruminant Gut", "Diet", "jaws", 2,
		"Jaws adapt to grind tough plant fiber.",
		"Berries restore +80% more", "Meat restores less",
		["jaws"], _others(jaws_branch, "ruminant_gut"),
		{EffectKeys.PLANT_RESTORE_MULT: 1.8, EffectKeys.CARCASS_RESTORE_MULT: 0.6})

	# ---- Fins branch (Wetlands aquatic adaptation) ----
	_def("fins", "Fins", "Movement", "fins", 1,
		"Grow paddle-like fins built for swimming.",
		"No water slowdown", "Slightly slower on land",
		[], [], {EffectKeys.IGNORE_WATER_SLOW: true, EffectKeys.AQUATIC_ADAPTED: true, EffectKeys.SPEED_MULT: 0.95})

	var fins_branch := ["razor_fins", "gills", "deep_diver"]
	_def("razor_fins", "Razor Fins", "Offense", "fins", 2,
		"Fin edges sharpen into blades.",
		"Bite +40% while submerged", "None",
		["fins"], _others(fins_branch, "razor_fins"),
		{EffectKeys.AQUATIC_DAMAGE_MULT: 1.4})
	_def("gills", "Gills", "Survival", "fins", 2,
		"Fins grow gill slits alongside them.",
		"Attackers are poisoned while you're submerged", "None",
		["fins"], _others(fins_branch, "gills"),
		{EffectKeys.POISON_REFLECT_IN_WATER: true})
	_def("deep_diver", "Deep Diver", "Movement", "fins", 2,
		"Fins broaden for sustained deep water travel.",
		"+30% swim speed", "-5% land speed",
		["fins"], _others(fins_branch, "deep_diver"),
		{EffectKeys.WATER_SPEED_MULT: 1.3, EffectKeys.SPEED_MULT: 0.95})

	# ---- Sensory Evolution (independent, not mutually exclusive - each is
	# its own standalone tier-1 sense rather than a branching family, since
	# stacking multiple senses over generations is the point). These reveal
	# real information rather than a flat detection-range number: Keen
	# Smell/Hearing surface an environment hint pointing at something you
	# couldn't otherwise perceive; Night Vision removes a real penalty that
	# only exists because this mutation exists to counter it.
	_def("keen_smell", "Keen Smell", "Senses", "senses", 1,
		"Scent carries meaning - carcasses, wounds, water.",
		"Sense carcasses/hunted prey from much farther away", "None",
		[], [], {EffectKeys.KEEN_SMELL: true})
	_def("keen_hearing", "Keen Hearing", "Senses", "senses", 1,
		"Every rustle and footstep becomes information.",
		"Sense nearby aggressive predators before they're in range", "None",
		[], [], {EffectKeys.KEEN_HEARING: true})
	_def("night_vision", "Night Vision", "Senses", "senses", 1,
		"Low light stops being a handicap.",
		"No sense-range penalty at night", "None",
		[], [], {EffectKeys.NIGHT_VISION: true})

	# ---- Combat archetypes ----
	# Three biological equivalents of familiar weapon fantasies - gun, sword,
	# grappler - available to any lineage, independent of starting kit. The
	# tier-2 mutation in each is what actually changes your controls (see
	# main.gd's _unhandled_input), not just your numbers.
	_def("venom_gland", "Venom Gland", "Offense", "spitter", 1,
		"A gland swells with toxin - the precursor to something that can fire it.",
		"Bite applies poison", "None",
		[], [], {EffectKeys.POISON_ON_HIT: 2.0})
	_def("projectile_gland", "Projectile Gland", "Offense", "spitter", 2,
		"The gland grows a firing duct. You are now, functionally, a gun.",
		"RMB aim, Space fire: spit venom at range, poisons on hit; venom reserve +50", "Melee bite damage -20%",
		["venom_gland"], [], {EffectKeys.RANGED_ATTACK: true, EffectKeys.BITE_DAMAGE_ADD: -2.0, EffectKeys.VENOM_MAX_ADD: 50.0})

	_def("rending_claws", "Rending Claws", "Offense", "ravager", 1,
		"Claws sharpen into something built for tearing, not just gripping.",
		"Bite applies bleed", "None",
		[], [], {EffectKeys.BLEED_ON_HIT: 3.0})
	_def("predatory_talons", "Predatory Talons", "Offense", "ravager", 2,
		"Talons lengthen further - consecutive hits chain into real combos.",
		"Chained bites within 1.5s stack +15% damage (max x3); hitting from behind bonus bleed", "None",
		["rending_claws"], [], {EffectKeys.COMBO_ATTACK: true})

	_def("grasping_claws", "Grasping Claws", "Offense", "behemoth", 1,
		"Claws widen into something built for holding on.",
		"+50% knockback dealt", "None",
		[], [], {EffectKeys.KNOCKBACK_MULT: 1.5})
	_def("crushing_grip", "Crushing Grip", "Offense", "behemoth", 2,
		"The grip becomes strong enough to actually hold something down.",
		"Hold Space near a target to grab it, Space to crush, RMB to throw", "Can't bite while holding a grab",
		["grasping_claws"], [], {EffectKeys.GRAB_ATTACK: true})

	# ---- Diet trio (independent of family trees, mutually exclusive) ----
	var diet_branch := ["diet_carnivore", "diet_herbivore", "diet_scavenger"]
	_def("diet_carnivore", "Carnivore Gut", "Diet", "diet", 1,
		"Your gut specializes in flesh. You depend on prey populations.",
		"Meat restores +60% hunger", "Plants restore -40%",
		[], _others(diet_branch, "diet_carnivore"),
		{EffectKeys.MEAT_RESTORE_MULT: 1.6, EffectKeys.PLANT_RESTORE_MULT: 0.6})
	_def("diet_herbivore", "Herbivore Gut", "Diet", "diet", 1,
		"Your gut specializes in plant matter. Droughts and fires hurt you badly.",
		"Plants restore +60% hunger", "Meat makes you sick (poison)",
		[], _others(diet_branch, "diet_herbivore"),
		{EffectKeys.PLANT_RESTORE_MULT: 1.6, EffectKeys.MEAT_CAUSES_SICKNESS: true})
	_def("diet_scavenger", "Scavenger Gut", "Diet", "diet", 1,
		"Your gut thrives on decay. You do well when things are dying.",
		"Carcasses +40% restore, never spoil", "Fresh kills restore -30%",
		[], _others(diet_branch, "diet_scavenger"),
		{EffectKeys.CARCASS_RESTORE_MULT: 1.4, EffectKeys.COOKED_CARCASS_RESTORE_MULT: 1.7, EffectKeys.FRESH_KILL_RESTORE_MULT: 0.7})

	# ---- Hidden / Ancestral mutations ----
	# These are not offered in normal drafts until their Ancestral Insight is
	# discovered by the lineage. Each one is meant to expand the possibility
	# space, not just be a straight power increase.
	_def("hollow_bones", "Hollow Bones", "Hidden", "ancestral", 2,
		"Bones become light and hollow, like the Firstborn's.",
		"Pounce distance +30%, mass reduced", "Less HP, more knockback taken",
		[], [], {EffectKeys.POUNCE_DISTANCE_MULT: 1.3, EffectKeys.MASS_ADD: -0.3, EffectKeys.MAX_HP_ADD: -8.0, EffectKeys.KNOCKBACK_TAKEN_MULT: 1.25})

## Helper: every id in `group` except `keep`, used to build symmetric exclusion sets.
func _others(group: Array, keep: String) -> Array:
	var out: Array = []
	for id in group:
		if id != keep:
			out.append(id)
	return out
