class_name WildlifeAI

## Server-only AI for non-player creatures. Dispatches on species_data flags
## rather than per-species branches, so a new species is (ideally) just a
## new SpeciesData entry, not new code here.

const NIGHT_LENGTH := 60.0

static func process(c: Creature, world: Node, delta: float) -> void:
	if c.dead or c.species_data == null:
		return
	match c.species_data.creature_type:
		"prey":
			_process_prey(c, world, delta)
		"predator":
			_process_predator(c, world, delta)
		"apex":
			_process_apex(c, world, delta)
	_finish_move(c, delta)

# --- shared helpers ---

static func _finish_move(c: Creature, delta: float) -> void:
	var before := c.global_position
	c.move_and_slide()
	var moved: Vector2 = c.global_position - before
	if moved.length() > 0.5:
		c.facing = moved.angle()

static func _nearest(c: Creature, list: Array, max_range: float) -> Node:
	var best: Node = null
	var best_d := max_range
	for o in list:
		if o == c:
			continue
		var d: float = c.global_position.distance_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best

static func _nearest_water(c: Creature, world: Node) -> WorldObject:
	var best: WorldObject = null
	var best_d := INF
	for o in world.objects_by_id.values():
		if o.kind != "water":
			continue
		var d: float = c.global_position.distance_to(o.global_position) - o.radius
		if d < best_d:
			best_d = d
			best = o
	return best

static func _in_water(c: Creature, world: Node) -> bool:
	for o in world.objects_by_id.values():
		if o.kind == "water" and c.global_position.distance_to(o.global_position) < o.radius:
			return true
	return false

# --- prey ---

static func _process_prey(c: Creature, world: Node, delta: float) -> void:
	var players: Array = world.get_player_creatures()
	var nearest_player: Creature = _nearest(c, players, 999999.0) as Creature
	var dplayer := nearest_player.global_position.distance_to(c.global_position) if nearest_player else 999999.0
	var sp: float = c.stats.speed

	if nearest_player and (dplayer < 150.0 or c.status.fear_time > 0.0):
		var away := (c.global_position - nearest_player.global_position).normalized()
		c.velocity = away * sp
		return

	var berry: FoodItem = _nearest_food(c, world, "berry", c.stats.sense_range)
	if berry:
		var d := c.global_position.distance_to(berry.global_position)
		if d > c.stats.radius + berry.radius + 4.0:
			c.velocity = (berry.global_position - c.global_position).normalized() * sp * 0.7
		else:
			world.consume_food_by_creature(berry, c)
			c.velocity = Vector2.ZERO
		return

	# wander, with herd clustering for niblet-like species
	var dir := _wander_dir(c, delta, world)
	if c.species_data.herd:
		var packmate := _nearest(c, world.get_prey_creatures(), 120.0)
		if packmate:
			dir = (dir + (packmate.global_position - c.global_position).normalized() * 0.6).normalized()
	c.velocity = dir * sp * 0.4

static func _nearest_food(c: Creature, world: Node, kind: String, max_range: float) -> FoodItem:
	var best: FoodItem = null
	var best_d := max_range
	for f in world.food_by_id.values():
		if f.kind != kind:
			continue
		var d: float = c.global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best

static var _wander_dirs: Dictionary = {}

## Idle wandering isn't pure random walk - it drifts toward the nearest
## water hole (a "hotspot"), which is what actually makes water dangerous
## rather than decorative: prey linger near it out of the same pull, and
## predators camping near it get fed. This is the whole "ecological
## hotspots"/"dynamic migration" idea in one small, honest change rather
## than a separate hotspot data structure to maintain.
static func _wander_dir(c: Creature, delta: float, world: Node = null) -> Vector2:
	if not _wander_dirs.has(c.entity_id) or randf() < 0.02:
		_wander_dirs[c.entity_id] = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var dir: Vector2 = _wander_dirs.get(c.entity_id, Vector2.ZERO)
	if world:
		var water := _nearest_water(c, world)
		if water and c.global_position.distance_to(water.global_position) > water.radius + 50.0:
			var toward: Vector2 = (water.global_position - c.global_position).normalized()
			dir = (dir * 0.65 + toward * 0.35).normalized()
	return dir

# --- predators ---

static func _process_predator(c: Creature, world: Node, delta: float) -> void:
	if c.telegraph > 0.0:
		c.telegraph -= delta
		if c.telegraph <= 0.0:
			_resolve_telegraphed_attack(c, world)
		c.velocity = Vector2.ZERO
		return

	if c.species_data.water_tether and not _in_water(c, world):
		var water := _nearest_water(c, world)
		if water and c.global_position.distance_to(water.global_position) - water.radius > 120.0:
			c.velocity = (water.global_position - c.global_position).normalized() * c.stats.speed * 1.1
			return

	if c.species_data.scavenger:
		var carcass := _nearest_food(c, world, "carcass", c.stats.sense_range)
		if carcass:
			var d := c.global_position.distance_to(carcass.global_position)
			if d > c.stats.radius + carcass.radius + 4.0:
				c.velocity = (carcass.global_position - c.global_position).normalized() * c.stats.speed
			else:
				world.consume_food_by_creature(carcass, c)
				c.velocity = Vector2.ZERO
			return

	var prey_list: Array = world.get_prey_creatures()
	var target: Creature = _nearest(c, prey_list, c.stats.sense_range) as Creature
	if target and not c.species_data.aquatic and world._creature_in_water(target):
		target = null # dove into water - not this predator's problem unless it's aquatic too
	var players: Array = world.get_player_creatures()
	var nearest_player: Creature = _nearest(c, players, 999999.0) as Creature
	if nearest_player and not c.species_data.aquatic and world._creature_in_water(nearest_player):
		nearest_player = null
	var dplayer := nearest_player.global_position.distance_to(c.global_position) if nearest_player else 999999.0

	# During a Predator Surge, hunters press attacks against much bigger prey
	# than they normally would and give up the chase far less readily.
	var surge: bool = world.predator_surge_active
	var mass_threat_mult: float = 2.6 if surge else 1.8
	var threat := false
	if nearest_player:
		threat = nearest_player.stats.mass > c.stats.mass * mass_threat_mult or c.stats.hp < c.stats.max_hp * 0.35 or c.status.fear_time > 0.0
	var night_mult: float = 1.25 if world.is_night() else 1.0
	if c.species_data.nocturnal:
		night_mult = 1.4 if world.is_night() else 0.35
	var sp: float = c.stats.speed * night_mult * (1.15 if surge else 1.0)

	var cornered := threat and nearest_player and dplayer < c.stats.radius + nearest_player.stats.radius + 4.0 and c.bite_cooldown <= 0.0
	if cornered:
		c.attack_target = nearest_player
		c.telegraph = 0.75 if c.species_id == "razorcat" else 0.35
		c.velocity = Vector2.ZERO
		return

	if target and not threat:
		c.velocity = (target.global_position - c.global_position).normalized() * sp
		if c.global_position.distance_to(target.global_position) < c.stats.radius + target.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
			c.attack_target = target
			c.telegraph = 0.75 if c.species_id == "razorcat" else 0.35
		return

	var chase_range: float = 380.0 if surge else 260.0
	if nearest_player and dplayer < chase_range and not threat:
		c.velocity = (nearest_player.global_position - c.global_position).normalized() * sp
		if dplayer < c.stats.radius + nearest_player.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
			c.attack_target = nearest_player
			c.telegraph = 0.75 if c.species_id == "razorcat" else 0.35
		return

	if nearest_player and dplayer < 320.0 and threat:
		c.velocity = (c.global_position - nearest_player.global_position).normalized() * sp * 1.2
		return

	c.velocity = _wander_dir(c, delta, world) * sp * 0.35

static func _resolve_telegraphed_attack(c: Creature, world: Node) -> void:
	var t: Creature = c.attack_target
	c.attack_target = null
	c.bite_cooldown = 0.7 if c.species_data.creature_type == "predator" else 1.2
	if t == null or t.dead:
		return
	var d := c.global_position.distance_to(t.global_position)
	var lunge_range: float = 45.0 if c.species_data.creature_type == "predator" else 60.0
	if d >= c.stats.radius + t.stats.radius + lunge_range:
		return
	if d > c.stats.radius + t.stats.radius + 3.0:
		var close: float = minf(d - (c.stats.radius + t.stats.radius + 3.0), lunge_range * 0.65)
		c.global_position += (t.global_position - c.global_position).normalized() * close
	world.server_resolve_bite(c, t)

# --- apex ---

static func _process_apex(c: Creature, world: Node, delta: float) -> void:
	if c.telegraph > 0.0:
		c.telegraph -= delta
		if c.telegraph <= 0.0:
			_resolve_telegraphed_attack(c, world)
		c.velocity = Vector2.ZERO
		return

	var home: Vector2 = c.get_meta("home_position", c.global_position)
	var d_home := c.global_position.distance_to(home)
	var candidates: Array = world.get_all_creatures() + world.get_player_creatures()
	var intruder: Node = null
	var best := 240.0
	for o in candidates:
		if o == c:
			continue
		if home.distance_to(o.global_position) < 160.0:
			var d: float = c.global_position.distance_to(o.global_position)
			if d < best:
				best = d
				intruder = o

	if d_home > 220.0:
		c.velocity = (home - c.global_position).normalized() * c.stats.speed * 1.3
		return
	if intruder:
		c.velocity = (intruder.global_position - c.global_position).normalized() * c.stats.speed
		if best < c.stats.radius + intruder.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
			c.attack_target = intruder
			c.telegraph = 0.5
		return
	var players: Array = world.get_player_creatures()
	var nearest_player: Creature = _nearest(c, players, 999999.0) as Creature
	if nearest_player and c.global_position.distance_to(nearest_player.global_position) < 220.0:
		c.velocity = (nearest_player.global_position - c.global_position).normalized() * c.stats.speed
		if c.global_position.distance_to(nearest_player.global_position) < c.stats.radius + nearest_player.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
			c.attack_target = nearest_player
			c.telegraph = 0.5
		return
	c.velocity = _wander_dir(c, delta, world) * c.stats.speed * 0.3
