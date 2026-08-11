class_name WorldGenerator

## Deterministic map layout. Every peer calls generate() with the same seed
## and gets byte-identical results, so the server only needs to broadcast a
## single integer to put everyone on the same map - no object list ever
## needs to cross the network.

const WORLD_SIZE := Vector2(1600, 1200)

const FOREST_SPAWN := {
	"trees": 5, "rocks": 3, "waters": 2, "berries": 10, "logs": 2, "nests": 2, "burrows": 2,
	"prey": 8, "predator": 3, "apex": 1,
}

const FOREST_COLORS := {
	"tree_leaf": Color("5a9a3a"),
	"rock": Color("555555"),
	"water": Color("3a5a8a"),
	"berry": Color("4abf4a"),
	"carcass": Color("8b5a2b"),
	"exit": Color("ffffff"),
}

## Wetlands trades trees/rocks for far more (and bigger) water, so aquatic
## adaptation actually matters for traversal, not just combat - and Riverjaw
## has much more habitat to threaten you from.
const WETLANDS_SPAWN := {
	"trees": 2, "rocks": 2, "waters": 6, "berries": 8, "logs": 3, "nests": 1, "burrows": 1,
	"prey": 7, "predator": 4, "apex": 1,
}

const WETLANDS_COLORS := {
	"tree_leaf": Color("4a7a4a"),
	"rock": Color("4a5550"),
	"water": Color("2f5548"),
	"berry": Color("6aac4a"),
	"carcass": Color("6b5a3b"),
	"exit": Color("d8f0e8"),
}

## Highlands is rock and scarcity, not water - sparse food and a single small
## lake force the Fur/Insulation-or-tough-it-out choice the checklist tests.
const HIGHLANDS_SPAWN := {
	"trees": 2, "rocks": 7, "waters": 1, "berries": 6, "logs": 1, "nests": 2, "burrows": 3,
	"prey": 6, "predator": 3, "apex": 1,
}

const HIGHLANDS_COLORS := {
	"tree_leaf": Color("5a7a6a"),
	"rock": Color("8a8f95"),
	"water": Color("6a94ac"),
	"berry": Color("c76a6a"),
	"carcass": Color("7a6a5a"),
	"exit": Color("eef4fa"),
}

# ------------------------------------------------------------------
# Seed-based Forest archetypes (PLAN.md's "same creatures, same mutation
# pool, completely different evolutionary pressure" test). These are all
# still the "forest" migration checklist/rules family - what differs is
# purely how much of what exists and how often which event shows up, which
# is deliberately the whole point: the pressure comes from the world, not
# from a different ruleset bolted on per variant.
# ------------------------------------------------------------------

const LUSH_FOREST_SPAWN := {
	"trees": 4, "rocks": 2, "waters": 3, "berries": 16, "logs": 2, "nests": 3, "burrows": 2,
	"prey": 12, "predator": 5, "apex": 1,
}
const LUSH_FOREST_COLORS := {
	"tree_leaf": Color("4fae3a"), "rock": Color("5a6a55"), "water": Color("2f6a9a"),
	"berry": Color("5fef5a"), "carcass": Color("8b5a2b"), "exit": Color("d8ffd8"),
}

const DRY_FOREST_SPAWN := {
	"trees": 6, "rocks": 5, "waters": 1, "berries": 5, "logs": 2, "nests": 1, "burrows": 3,
	"prey": 6, "predator": 3, "apex": 1,
}
const DRY_FOREST_COLORS := {
	"tree_leaf": Color("8a9a4a"), "rock": Color("8a7a5a"), "water": Color("6a8aa0"),
	"berry": Color("c2b23a"), "carcass": Color("9a6a3b"), "exit": Color("fff0d8"),
}

const FLOODED_FOREST_SPAWN := {
	"trees": 2, "rocks": 1, "waters": 5, "berries": 8, "logs": 4, "nests": 1, "burrows": 1,
	"prey": 7, "predator": 4, "apex": 1,
}
const FLOODED_FOREST_COLORS := {
	"tree_leaf": Color("3a7a5a"), "rock": Color("46564f"), "water": Color("245a72"),
	"berry": Color("4acf9a"), "carcass": Color("5a6b3b"), "exit": Color("d8f4ff"),
}

const ANCIENT_FOREST_SPAWN := {
	"trees": 10, "rocks": 6, "waters": 1, "berries": 7, "logs": 6, "nests": 4, "burrows": 2,
	"prey": 7, "predator": 4, "apex": 1,
}
const ANCIENT_FOREST_COLORS := {
	"tree_leaf": Color("2f5a2a"), "rock": Color("4a4a45"), "water": Color("2a4a55"),
	"berry": Color("3a8a4a"), "carcass": Color("6b5a3b"), "exit": Color("e8e8d8"),
}

const _WATER_RADIUS := {
	"forest": 70.0, "wetlands": 110.0, "highlands": 50.0,
	"forest_lush": 80.0, "forest_dry": 45.0, "forest_flooded": 120.0, "forest_ancient": 55.0,
}

## Event weight multipliers per biome (missing event id = 1.0, i.e.
## unaffected). This is how Dry Forest becomes "the drought one" and
## Flooded Forest becomes "the wildfire almost never matters here, water's
## the story" one without either needing its own event list.
const _EVENT_WEIGHTS := {
	"forest_dry": {"drought": 4.0, "wildfire": 1.5},
	"forest_flooded": {"drought": 0.2, "wildfire": 0.5},
	"forest_lush": {"predator_surge": 1.5},
	"forest_ancient": {"predator_surge": 1.3, "wildfire": 1.4},
}

static func biome_event_weights(biome_id: String) -> Dictionary:
	return _EVENT_WEIGHTS.get(biome_id, {})

static func _spawn_and_colors(biome_id: String) -> Array:
	match biome_id:
		"wetlands":
			return [WETLANDS_SPAWN, WETLANDS_COLORS]
		"highlands":
			return [HIGHLANDS_SPAWN, HIGHLANDS_COLORS]
		"forest_lush":
			return [LUSH_FOREST_SPAWN, LUSH_FOREST_COLORS]
		"forest_dry":
			return [DRY_FOREST_SPAWN, DRY_FOREST_COLORS]
		"forest_flooded":
			return [FLOODED_FOREST_SPAWN, FLOODED_FOREST_COLORS]
		"forest_ancient":
			return [ANCIENT_FOREST_SPAWN, ANCIENT_FOREST_COLORS]
		_:
			return [FOREST_SPAWN, FOREST_COLORS]

static func generate(seed_val: int, biome_id: String = "forest") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var objects: Array = []
	var food: Array = []
	var next_id := 0

	var sc := _spawn_and_colors(biome_id)
	var s: Dictionary = sc[0]
	var colors: Dictionary = sc[1]
	var water_radius: float = _WATER_RADIUS.get(biome_id, 70.0)
	for i in range(s["trees"]):
		objects.append(_obj(next_id, "tree", rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100), 22.0, colors["tree_leaf"]))
		next_id += 1
	for i in range(s["rocks"]):
		objects.append(_obj(next_id, "rock", rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100), 28.0, colors["rock"]))
		next_id += 1
	for i in range(s["waters"]):
		objects.append(_obj(next_id, "water", rng.randf_range(300, WORLD_SIZE.x - 300), rng.randf_range(300, WORLD_SIZE.y - 300), water_radius, colors["water"]))
		next_id += 1
	for i in range(s["logs"]):
		objects.append(_obj(next_id, "log", rng.randf_range(200, WORLD_SIZE.x - 200), rng.randf_range(200, WORLD_SIZE.y - 200), 32.0, Color("6b5a3b")))
		next_id += 1
	for i in range(s["nests"]):
		objects.append(_obj(next_id, "nest", rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100), 22.0, Color("8b6a4b")))
		next_id += 1
	for i in range(int(s.get("burrows", 0))):
		objects.append(_obj(next_id, "burrow", rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100), 18.0, Color("2b2018")))
		next_id += 1
	# guaranteed gate log + exit near the far corner, mirrors the HTML prototype
	objects.append(_obj(next_id, "log", WORLD_SIZE.x - 320, WORLD_SIZE.y - 320, 32.0, Color("6b5a3b")))
	next_id += 1
	objects.append(_obj(next_id, "exit", WORLD_SIZE.x - 120, WORLD_SIZE.y - 120, 35.0, colors["exit"]))
	next_id += 1

	for i in range(s["berries"]):
		food.append(_food(i, "berry", rng.randf_range(50, WORLD_SIZE.x - 50), rng.randf_range(50, WORLD_SIZE.y - 50), 22.0, 6.0, colors["berry"]))

	return {
		"objects": objects,
		"food": food,
		"next_object_id": next_id,
		"next_food_id": s["berries"],
		"spawn_counts": s,
	}

static func _obj(id: int, kind: String, x: float, y: float, radius: float, color: Color) -> Dictionary:
	return {"id": id, "kind": kind, "x": x, "y": y, "radius": radius, "color": color}

static func _food(id: int, kind: String, x: float, y: float, amount: float, radius: float, color: Color) -> Dictionary:
	return {"id": id, "kind": kind, "x": x, "y": y, "amount": amount, "radius": radius, "color": color}
