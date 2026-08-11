class_name WorldEventManager

## Authoritative simulation for each WorldEventData id. The server calls
## start/tick/end; clients never run this - they only see its *effects*
## (object burns, food spawns, hp changes) arrive through World.gd's normal
## replicated RPCs, plus a lightweight event_state_changed signal for HUD/
## screen-tint purposes.

static func start_event(world: World, id: String) -> void:
	match id:
		"drought":
			_drought_start(world)
		"wildfire":
			_wildfire_start(world)
		"predator_surge":
			_predator_surge_start(world)

static func tick(world: World, id: String, delta: float) -> void:
	match id:
		"drought":
			_drought_tick(world, delta)
		"wildfire":
			_wildfire_tick(world, delta)
		"predator_surge":
			pass # aggression/spawns are one-shot at start; see wildlife_ai.gd for the ongoing effect

static func end_event(world: World, id: String) -> void:
	match id:
		"drought":
			_drought_end(world)
		"wildfire":
			_wildfire_end(world)
		"predator_surge":
			_predator_surge_end(world)

# --- Drought ---

static func _drought_start(world: World) -> void:
	var original := {}
	for o in world.objects_by_id.values():
		if o.kind == "water":
			original[o.object_id] = o.radius
			world._broadcast_object_radius(o.object_id, o.radius * 0.5)
	world.event_data["drought_original_radii"] = original

static func _drought_end(world: World) -> void:
	var original: Dictionary = world.event_data.get("drought_original_radii", {})
	for id in original.keys():
		world._broadcast_object_radius(id, original[id])
	for c in world.creatures_by_id.values():
		if c.is_player and c.stats.hp > 0.0:
			c.survived_drought = true

static func _drought_tick(world: World, delta: float) -> void:
	var waters: Array = []
	for o in world.objects_by_id.values():
		if o.kind == "water":
			waters.append(o)
	if waters.is_empty():
		return
	for c in world.creatures_by_id.values():
		if c.dead:
			continue
		if not c.is_player and c.species_data and c.species_data.creature_type == "prey":
			var nearest: WorldObject = waters[0]
			var best: float = c.global_position.distance_to(nearest.global_position)
			for w in waters:
				var d: float = c.global_position.distance_to(w.global_position)
				if d < best:
					best = d
					nearest = w
			if best > nearest.radius + c.stats.radius + 8.0:
				c.velocity = (nearest.global_position - c.global_position).normalized() * c.stats.speed * 0.5
				c.move_and_slide()
		if c.species_data and c.species_data.aquatic and not world._creature_in_water(c):
			c.stats.hp -= 3.0 * delta

# --- Wildfire ---

static func _wildfire_start(world: World) -> void:
	var dirs := ["left", "right", "top", "bottom"]
	world.wildfire_direction = dirs[world.rng.randi_range(0, dirs.size() - 1)]
	world.wildfire_progress = 0.0
	world.wildfire_burned_objects.clear()

static func _wildfire_end(world: World) -> void:
	for c in world.creatures_by_id.values():
		if c.is_player and c.stats.hp > 0.0:
			c.survived_wildfire = true

static func _wildfire_coord(world: World, pos: Vector2) -> float:
	match world.wildfire_direction:
		"left":
			return pos.x
		"right":
			return WorldGenerator.WORLD_SIZE.x - pos.x
		"top":
			return pos.y
		_:
			return WorldGenerator.WORLD_SIZE.y - pos.y

static func _wildfire_tick(world: World, delta: float) -> void:
	var ed: WorldEventData = EventDB.get_event("wildfire")
	var band: float = ed.params.get("band_width", 160.0)
	var total: float = WorldGenerator.WORLD_SIZE.x if world.wildfire_direction in ["left", "right"] else WorldGenerator.WORLD_SIZE.y
	world.wildfire_progress = minf(total + band, world.wildfire_progress + (total / ed.duration) * delta)
	var front := world.wildfire_progress

	for o in world.objects_by_id.values():
		if world.wildfire_burned_objects.has(o.object_id):
			continue
		var c := _wildfire_coord(world, o.global_position)
		if c < front:
			world.wildfire_burned_objects[o.object_id] = true
			if o.kind == "tree" or o.kind == "nest":
				world._broadcast_update_object(o.object_id, "burned", true)
			elif o.kind == "log":
				world._broadcast_update_object(o.object_id, "open", true)

	for f in world.food_by_id.values():
		if f.kind == "carcass" and not f.cooked:
			var c := _wildfire_coord(world, f.global_position)
			if c < front and c > front - band:
				world._broadcast_update_food_state(f.entity_id, true, f.amount * 1.3)

	var push_dir := Vector2.ZERO
	match world.wildfire_direction:
		"left": push_dir = Vector2.RIGHT
		"right": push_dir = Vector2.LEFT
		"top": push_dir = Vector2.DOWN
		"bottom": push_dir = Vector2.UP

	for c in world.creatures_by_id.values():
		if c.dead:
			continue
		if c.mutation and c.mutation.has_flag(EffectKeys.FIRE_IMMUNE):
			continue
		if world._creature_in_water(c):
			continue
		var coord := _wildfire_coord(world, c.global_position)
		if coord >= front or coord <= front - band:
			continue
		var fast: bool = c.stats.speed > 140.0
		c.stats.hp -= (6.0 if fast else 20.0) * delta
		c.global_position += push_dir * 90.0 * delta

# --- Predator Surge ---
# "New hunters enter" (PLAN.md 8.5): a wave of extra predators/apex spawn in
# and every existing predator hunts more boldly for the duration (see the
# world.predator_surge_active check in wildlife_ai.gd). Surge-spawned
# creatures that are still alive when it ends leave with it, so the
# population settles back to normal rather than ratcheting up forever.

static func _predator_surge_start(world: World) -> void:
	var ed: WorldEventData = EventDB.get_event("predator_surge")
	world.predator_surge_active = true
	var spawned: Array = []
	for i in range(int(ed.params.get("extra_predators", 3))):
		var before: Array = world.creatures_by_id.keys()
		world._spawn_wildlife("predator")
		spawned.append_array(_new_ids(before, world.creatures_by_id.keys()))
	for i in range(int(ed.params.get("extra_apex", 0))):
		var before: Array = world.creatures_by_id.keys()
		world._spawn_wildlife("apex")
		spawned.append_array(_new_ids(before, world.creatures_by_id.keys()))
	world.event_data["surge_spawned_ids"] = spawned

static func _new_ids(before: Array, after: Array) -> Array:
	var out: Array = []
	for id in after:
		if not before.has(id):
			out.append(id)
	return out

static func _predator_surge_end(world: World) -> void:
	world.predator_surge_active = false
	var spawned: Array = world.event_data.get("surge_spawned_ids", [])
	for id in spawned:
		if world.creatures_by_id.has(id):
			world._broadcast_despawn_creature(id)
	world.event_data.erase("surge_spawned_ids")
