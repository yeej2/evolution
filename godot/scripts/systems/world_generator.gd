class_name WorldGenerator

## Deterministic map layout. Every peer calls generate() with the same seed
## and gets byte-identical results, so the server only needs to broadcast a
## single integer to put everyone on the same map - no object list ever
## needs to cross the network.

const WORLD_SIZE := Vector2(1600, 1200)

const FOREST_SPAWN := {
	"trees": 5, "rocks": 3, "waters": 2, "berries": 10, "logs": 2, "nests": 2,
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
	"trees": 2, "rocks": 2, "waters": 6, "berries": 8, "logs": 3, "nests": 1,
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
	"trees": 2, "rocks": 7, "waters": 1, "berries": 6, "logs": 1, "nests": 2,
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

const _WATER_RADIUS := {"forest": 70.0, "wetlands": 110.0, "highlands": 50.0}

static func _spawn_and_colors(biome_id: String) -> Array:
	match biome_id:
		"wetlands":
			return [WETLANDS_SPAWN, WETLANDS_COLORS]
		"highlands":
			return [HIGHLANDS_SPAWN, HIGHLANDS_COLORS]
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
