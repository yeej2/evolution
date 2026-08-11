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
# pool, completely different evolutionary pressure" test). These generate
# actual situations - landmark clusters and, for Flooded Forest, a real
# connected river crossing - rather than independently-scattered objects
# in different ratios. See _structured_forest() below.
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
	"forest_lush": 80.0, "forest_dry": 45.0, "forest_flooded": 95.0, "forest_ancient": 55.0,
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

const _STRUCTURED_BIOMES := ["forest_lush", "forest_dry", "forest_flooded", "forest_ancient"]

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
	var landmarks: Array = []
	var root_dense_zones: Array = []

	var sc := _spawn_and_colors(biome_id)
	var s: Dictionary = sc[0]
	var colors: Dictionary = sc[1]
	var water_radius: float = _WATER_RADIUS.get(biome_id, 70.0)

	if biome_id in _STRUCTURED_BIOMES:
		var built := _structured_forest(rng, biome_id, s, colors, water_radius)
		for spec in built["placements"]:
			objects.append(_obj(next_id, spec["kind"], spec["pos"].x, spec["pos"].y, spec["radius"], spec["color"]))
			next_id += 1
		for i in range(int(s["berries"])):
			var p: Vector2 = built["berry_positions"][i]
			food.append(_food(i, "berry", p.x, p.y, 22.0, 6.0, colors["berry"]))
		landmarks = built["landmarks"]
		root_dense_zones = built["root_dense_zones"]
	else:
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
		for i in range(s["berries"]):
			food.append(_food(i, "berry", rng.randf_range(50, WORLD_SIZE.x - 50), rng.randf_range(50, WORLD_SIZE.y - 50), 22.0, 6.0, colors["berry"]))

	# guaranteed gate log + exit near the far corner, mirrors the HTML prototype
	objects.append(_obj(next_id, "log", WORLD_SIZE.x - 320, WORLD_SIZE.y - 320, 32.0, Color("6b5a3b")))
	next_id += 1
	objects.append(_obj(next_id, "exit", WORLD_SIZE.x - 120, WORLD_SIZE.y - 120, 35.0, colors["exit"]))
	next_id += 1

	return {
		"objects": objects,
		"food": food,
		"next_object_id": next_id,
		"next_food_id": s["berries"],
		"spawn_counts": s,
		"landmarks": landmarks,
		"root_dense_zones": root_dense_zones,
	}

static func _obj(id: int, kind: String, x: float, y: float, radius: float, color: Color) -> Dictionary:
	return {"id": id, "kind": kind, "x": x, "y": y, "radius": radius, "color": color}

static func _food(id: int, kind: String, x: float, y: float, amount: float, radius: float, color: Color) -> Dictionary:
	return {"id": id, "kind": kind, "x": x, "y": y, "amount": amount, "radius": radius, "color": color}

# ------------------------------------------------------------------
# Structured generation - "generate situations, not objects." Every
# resource kind's full spawn budget clusters around a named landmark
# instead of scattering independently across the whole map. Landmarks
# aren't labeled on screen (see game_ui.gd's nearest-landmark HUD line for
# the one exception) - they're meant to become the thing players nickname
# ("meet at the Fallen Giant") rather than a UI feature.
# ------------------------------------------------------------------

static func _cluster(rng: RandomNumberGenerator, center: Vector2, count: int, spread: float) -> Array:
	var pts: Array = []
	for i in range(count):
		var ang := rng.randf() * TAU
		var dist := rng.randf() * spread
		var p := center + Vector2(cos(ang), sin(ang)) * dist
		p.x = clampf(p.x, 60.0, WORLD_SIZE.x - 60.0)
		p.y = clampf(p.y, 60.0, WORLD_SIZE.y - 60.0)
		pts.append(p)
	return pts

## Anchor points with enough separation that clusters don't collide into
## one mush - each is a distinct "situation" on the map.
static func _anchors(rng: RandomNumberGenerator, count: int, min_sep: float, margin: float = 220.0) -> Array:
	var pts: Array = []
	for i in range(count):
		var best := Vector2.ZERO
		var best_score := -1.0
		for _try in range(24):
			var cand := Vector2(rng.randf_range(margin, WORLD_SIZE.x - margin), rng.randf_range(margin, WORLD_SIZE.y - margin))
			var min_d := INF
			for p in pts:
				min_d = minf(min_d, cand.distance_to(p))
			if pts.is_empty():
				min_d = 999999.0
			if min_d > best_score:
				best_score = min_d
				best = cand
			if min_d > min_sep:
				break
		pts.append(best)
	return pts

static func _structured_forest(rng: RandomNumberGenerator, biome_id: String, s: Dictionary, colors: Dictionary, water_radius: float) -> Dictionary:
	match biome_id:
		"forest_dry":
			return _gen_dry_forest(rng, s, colors, water_radius)
		"forest_flooded":
			return _gen_flooded_forest(rng, s, colors, water_radius)
		"forest_ancient":
			return _gen_ancient_forest(rng, s, colors, water_radius)
		_:
			return _gen_lush_forest(rng, s, colors, water_radius)

## Dry Forest: scarcity forces you toward a handful of known, contested
## places rather than "water slows me down more often" - one waterhole,
## one rock pass, one dead grove, one burrow colony.
static func _gen_dry_forest(rng: RandomNumberGenerator, s: Dictionary, colors: Dictionary, water_radius: float) -> Dictionary:
	var placements: Array = []
	var landmarks: Array = []
	var anchors: Array = _anchors(rng, 4, 380.0)

	var water_pos: Vector2 = anchors[0]
	placements.append({"kind": "water", "pos": water_pos, "radius": water_radius, "color": colors["water"]})
	landmarks.append({"name": "Last Waterhole", "pos": water_pos, "radius": water_radius + 40.0})

	var rock_center: Vector2 = anchors[1]
	for p in _cluster(rng, rock_center, int(s["rocks"]), 90.0):
		placements.append({"kind": "rock", "pos": p, "radius": 28.0, "color": colors["rock"]})
	landmarks.append({"name": "Rocky Pass", "pos": rock_center, "radius": 130.0})

	var grove_center: Vector2 = anchors[2]
	for p in _cluster(rng, grove_center, int(s["trees"]), 110.0):
		placements.append({"kind": "tree", "pos": p, "radius": 22.0, "color": colors["tree_leaf"]})
	landmarks.append({"name": "Dead Grove", "pos": grove_center, "radius": 130.0})

	var burrow_center: Vector2 = anchors[3]
	for p in _cluster(rng, burrow_center, int(s.get("burrows", 0)), 70.0):
		placements.append({"kind": "burrow", "pos": p, "radius": 18.0, "color": Color("2b2018")})
	landmarks.append({"name": "Burrow Colony", "pos": burrow_center, "radius": 90.0})

	for i in range(int(s["logs"])):
		placements.append({"kind": "log", "pos": Vector2(rng.randf_range(200, WORLD_SIZE.x - 200), rng.randf_range(200, WORLD_SIZE.y - 200)), "radius": 32.0, "color": Color("6b5a3b")})
	for i in range(int(s["nests"])):
		placements.append({"kind": "nest", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 22.0, "color": Color("8b6a4b")})

	var berry_positions: Array = []
	for i in range(int(s["berries"])):
		berry_positions.append(Vector2(rng.randf_range(50, WORLD_SIZE.x - 50), rng.randf_range(50, WORLD_SIZE.y - 50)))

	return {"placements": placements, "berry_positions": berry_positions, "landmarks": landmarks, "root_dense_zones": []}

## Flooded Forest: a literal connected river you have to actually deal
## with, not five independent ponds. A chain of overlapping water circles
## forms a crossing band; one deliberately-placed long log bridges it
## (Climbing Claws); everything without an adaptation goes around or gets
## wet. An Island Nest sits just off the river as the "worth the risk"
## payoff.
static func _gen_flooded_forest(rng: RandomNumberGenerator, s: Dictionary, colors: Dictionary, water_radius: float) -> Dictionary:
	var placements: Array = []
	var landmarks: Array = []

	var horizontal: bool = rng.randf() < 0.5
	var river_start: Vector2
	var river_dir: Vector2
	if horizontal:
		river_start = Vector2(140.0, rng.randf_range(300.0, WORLD_SIZE.y - 300.0))
		river_dir = Vector2(1, 0)
	else:
		river_start = Vector2(rng.randf_range(300.0, WORLD_SIZE.x - 300.0), 140.0)
		river_dir = Vector2(0, 1)
	var span: float = (WORLD_SIZE.x - 280.0) if horizontal else (WORLD_SIZE.y - 280.0)
	var count: int = int(s["waters"])
	var step: float = span / maxf(1.0, float(count - 1))
	var perp := river_dir.rotated(PI / 2.0)
	var river_points: Array = []
	for i in range(count):
		var wobble := rng.randf_range(-70.0, 70.0)
		var pos: Vector2 = river_start + river_dir * (step * i) + perp * wobble
		river_points.append(pos)
		placements.append({"kind": "water", "pos": pos, "radius": water_radius, "color": colors["water"]})
	landmarks.append({"name": "Central River", "pos": river_points[int(count / 2)], "radius": water_radius + 60.0})

	# Fallen Giant: a real bridge, deliberately placed across the river's
	# midpoint rather than dropped anywhere - Climbing Claws crosses free,
	# everyone else swims/wades or detours.
	var mid: Vector2 = river_points[int(count / 2)]
	placements.append({"kind": "log", "pos": mid, "radius": 34.0, "color": Color("6b5a3b")})
	landmarks.append({"name": "Fallen Giant", "pos": mid, "radius": 60.0})

	# Island Nest: the payoff for crossing, sitting just off the river line.
	var island: Vector2 = mid + perp * (water_radius + 50.0)
	island.x = clampf(island.x, 60.0, WORLD_SIZE.x - 60.0)
	island.y = clampf(island.y, 60.0, WORLD_SIZE.y - 60.0)
	placements.append({"kind": "nest", "pos": island, "radius": 22.0, "color": Color("8b6a4b")})
	landmarks.append({"name": "Island Nest", "pos": island, "radius": 70.0})
	for i in range(int(s["nests"]) - 1):
		placements.append({"kind": "nest", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 22.0, "color": Color("8b6a4b")})

	# Drowned Grove: what's left of the trees, clustered on one bank.
	var grove_center: Vector2 = river_start - perp * 220.0
	grove_center.x = clampf(grove_center.x, 100.0, WORLD_SIZE.x - 100.0)
	grove_center.y = clampf(grove_center.y, 100.0, WORLD_SIZE.y - 100.0)
	for p in _cluster(rng, grove_center, int(s["trees"]), 100.0):
		placements.append({"kind": "tree", "pos": p, "radius": 22.0, "color": colors["tree_leaf"]})
	landmarks.append({"name": "Drowned Grove", "pos": grove_center, "radius": 110.0})

	for i in range(int(s["rocks"])):
		placements.append({"kind": "rock", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 28.0, "color": colors["rock"]})
	for i in range(int(s["logs"]) - 1):
		placements.append({"kind": "log", "pos": Vector2(rng.randf_range(200, WORLD_SIZE.x - 200), rng.randf_range(200, WORLD_SIZE.y - 200)), "radius": 32.0, "color": Color("6b5a3b")})
	for i in range(int(s.get("burrows", 0))):
		placements.append({"kind": "burrow", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 18.0, "color": Color("2b2018")})

	var berry_positions: Array = []
	for i in range(int(s["berries"])):
		berry_positions.append(Vector2(rng.randf_range(50, WORLD_SIZE.x - 50), rng.randf_range(50, WORLD_SIZE.y - 50)))

	return {"placements": placements, "berry_positions": berry_positions, "landmarks": landmarks, "root_dense_zones": []}

## Ancient Forest: a Dense Canopy Zone thick enough with trees that it's a
## real ground-level obstacle (and root-dense - Digging Claws can't burrow
## inside it, see World._soil_at()), a Rock Formation choke, a Nest
## Colony, and a Cave Mouth (Burrow object) as the below-ground option.
static func _gen_ancient_forest(rng: RandomNumberGenerator, s: Dictionary, colors: Dictionary, water_radius: float) -> Dictionary:
	var placements: Array = []
	var landmarks: Array = []
	var root_dense_zones: Array = []
	var anchors: Array = _anchors(rng, 4, 340.0)

	var canopy_center: Vector2 = anchors[0]
	for p in _cluster(rng, canopy_center, int(s["trees"]), 130.0):
		placements.append({"kind": "tree", "pos": p, "radius": 22.0, "color": colors["tree_leaf"]})
	landmarks.append({"name": "Dense Canopy Zone", "pos": canopy_center, "radius": 160.0})
	root_dense_zones.append({"center": canopy_center, "radius": 160.0})

	var rock_center: Vector2 = anchors[1]
	for p in _cluster(rng, rock_center, int(s["rocks"]), 85.0):
		placements.append({"kind": "rock", "pos": p, "radius": 28.0, "color": colors["rock"]})
	landmarks.append({"name": "Rock Formation", "pos": rock_center, "radius": 120.0})

	var nest_center: Vector2 = anchors[2]
	for p in _cluster(rng, nest_center, int(s["nests"]), 90.0):
		placements.append({"kind": "nest", "pos": p, "radius": 22.0, "color": Color("8b6a4b")})
	landmarks.append({"name": "Nest Colony", "pos": nest_center, "radius": 110.0})

	var cave_center: Vector2 = anchors[3]
	for p in _cluster(rng, cave_center, int(s.get("burrows", 0)), 60.0):
		placements.append({"kind": "burrow", "pos": p, "radius": 18.0, "color": Color("2b2018")})
	landmarks.append({"name": "Cave Mouth", "pos": cave_center, "radius": 80.0})

	placements.append({"kind": "water", "pos": Vector2(rng.randf_range(300, WORLD_SIZE.x - 300), rng.randf_range(300, WORLD_SIZE.y - 300)), "radius": water_radius, "color": colors["water"]})

	# Fallen Giant: one deliberately prominent bridge log near the canopy
	# edge, separate from the ordinary scattered logs.
	var giant_pos: Vector2 = canopy_center + (rock_center - canopy_center).normalized() * 140.0
	placements.append({"kind": "log", "pos": giant_pos, "radius": 34.0, "color": Color("6b5a3b")})
	landmarks.append({"name": "Fallen Giant", "pos": giant_pos, "radius": 60.0})
	for i in range(int(s["logs"]) - 1):
		placements.append({"kind": "log", "pos": Vector2(rng.randf_range(200, WORLD_SIZE.x - 200), rng.randf_range(200, WORLD_SIZE.y - 200)), "radius": 32.0, "color": Color("6b5a3b")})

	var berry_positions: Array = []
	for i in range(int(s["berries"])):
		berry_positions.append(Vector2(rng.randf_range(50, WORLD_SIZE.x - 50), rng.randf_range(50, WORLD_SIZE.y - 50)))

	return {"placements": placements, "berry_positions": berry_positions, "landmarks": landmarks, "root_dense_zones": root_dense_zones}

## Lush Forest: abundance, not obstacles - the "situations" here are food
## clusters worth camping (and therefore worth fighting over), not
## traversal puzzles.
static func _gen_lush_forest(rng: RandomNumberGenerator, s: Dictionary, colors: Dictionary, water_radius: float) -> Dictionary:
	var placements: Array = []
	var landmarks: Array = []
	var anchors: Array = _anchors(rng, 2, 400.0)

	var berry_positions: Array = []
	var per_grove: int = int(s["berries"]) / 2
	for i in range(anchors.size()):
		var grove_pts := _cluster(rng, anchors[i], per_grove if i == 0 else int(s["berries"]) - per_grove, 130.0)
		berry_positions.append_array(grove_pts)
		landmarks.append({"name": "Berry Grove", "pos": anchors[i], "radius": 150.0})

	for i in range(int(s["waters"])):
		var near: Vector2 = anchors[i % anchors.size()] + Vector2(rng.randf_range(-160, 160), rng.randf_range(-160, 160))
		near.x = clampf(near.x, 300.0, WORLD_SIZE.x - 300.0)
		near.y = clampf(near.y, 300.0, WORLD_SIZE.y - 300.0)
		placements.append({"kind": "water", "pos": near, "radius": water_radius, "color": colors["water"]})
	landmarks.append({"name": "Watering Hole", "pos": anchors[0], "radius": water_radius + 60.0})

	for i in range(int(s["trees"])):
		placements.append({"kind": "tree", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 22.0, "color": colors["tree_leaf"]})
	for i in range(int(s["rocks"])):
		placements.append({"kind": "rock", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 28.0, "color": colors["rock"]})
	for i in range(int(s["logs"])):
		placements.append({"kind": "log", "pos": Vector2(rng.randf_range(200, WORLD_SIZE.x - 200), rng.randf_range(200, WORLD_SIZE.y - 200)), "radius": 32.0, "color": Color("6b5a3b")})
	for i in range(int(s["nests"])):
		placements.append({"kind": "nest", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 22.0, "color": Color("8b6a4b")})
	for i in range(int(s.get("burrows", 0))):
		placements.append({"kind": "burrow", "pos": Vector2(rng.randf_range(100, WORLD_SIZE.x - 100), rng.randf_range(100, WORLD_SIZE.y - 100)), "radius": 18.0, "color": Color("2b2018")})

	return {"placements": placements, "berry_positions": berry_positions, "landmarks": landmarks, "root_dense_zones": []}
