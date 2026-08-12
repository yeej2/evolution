class_name WildlifeAI

## Server-only AI for non-player creatures. Dispatches on species_data flags
## rather than per-species branches, so a new species is (ideally) just a
## new SpeciesData entry, not new code here.

const NIGHT_LENGTH := 60.0

static func process(c: Creature, world: Node, delta: float) -> void:
	if c.dead or c.species_data == null:
		return
	if c.grabbed_by_id != -1:
		# Position is driven by the grabber (World.gd) - a grabbed animal
		# doesn't get to keep fleeing/hunting while held.
		c.velocity = Vector2.ZERO
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

static func _nearest_burrow_object(c: Creature, world: Node, max_range: float) -> WorldObject:
	var best: WorldObject = null
	var best_d := max_range
	for o in world.objects_by_id.values():
		if o.kind != "burrow":
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

const APEX_PANIC_RADIUS := 260.0

static func _flee_from_apex(c: Creature, world: Node) -> bool:
	for other in world.creatures_by_id.values():
		if other == c or other.dead or not other.species_data or other.species_data.creature_type != "apex":
			continue
		var st := _apex_state(other)
		if st["state"] in ["charge", "pursue"] and c.global_position.distance_to(other.global_position) < APEX_PANIC_RADIUS:
			c.velocity = (c.global_position - other.global_position).normalized() * c.stats.speed * 1.5
			return true
	return false

# --- prey ---

static func _process_prey(c: Creature, world: Node, delta: float) -> void:
	if _flee_from_apex(c, world):
		return
	var players: Array = world.get_player_creatures()
	var nearest_player: Creature = _nearest(c, players, 999999.0) as Creature
	var dplayer := nearest_player.global_position.distance_to(c.global_position) if nearest_player else 999999.0
	var sp: float = c.stats.speed

	if nearest_player and (dplayer < 150.0 or c.status.fear_time > 0.0):
		var away := (c.global_position - nearest_player.global_position).normalized()
		# Fleeing toward an actual burrow beats fleeing directly away from
		# nothing in particular - a real destination, not just "not here."
		var cover := _nearest_burrow_object(c, world, 260.0)
		if cover:
			away = (away * 0.5 + (cover.global_position - c.global_position).normalized() * 0.5).normalized()
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
	if _flee_from_apex(c, world):
		return
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

	# Pack alarm: a wounded packmate that was just hit by a player is worth
	# converging on even if it's outside this predator's own normal
	# detection range - "the wounded animal retreated toward its pack, and
	# now three come back" only works if uninjured members actually react
	# to an ally's injury, not just to their own senses.
	if c.species_data.pack:
		var mates := _pack_mates(c, world, 320.0)
		for mate in mates:
			if mate.last_hit_time > 1.5 and mate.last_attacker_id != -1:
				var alarm_target: Creature = world._find_creature(mate.last_attacker_id)
				if alarm_target and alarm_target.is_player and not alarm_target.dead:
					var d := c.global_position.distance_to(alarm_target.global_position)
					c.velocity = (alarm_target.global_position - c.global_position).normalized() * c.stats.speed * 1.25
					if d < c.stats.radius + alarm_target.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
						c.attack_target = alarm_target
						c.telegraph = 0.75
					return
		# A badly wounded pack member disengages toward its allies instead of
		# fighting on alone - "don't casually mess with pack animals" only
		# lands if losing a fight visibly costs the pack something.
		if c.stats.hp < c.stats.max_hp * 0.3 and not mates.is_empty():
			var centroid := Vector2.ZERO
			for m in mates:
				centroid += m.global_position
			centroid /= mates.size()
			c.velocity = (centroid - c.global_position).normalized() * c.stats.speed
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
	# Courage scales with numbers: one Razorcat alone treats a much bigger
	# player as too risky; a pack of five treats the same player as food.
	# This is what makes the exact same animal read as "manageable" or "RUN"
	# depending purely on context, not a different stat block.
	if c.species_data.pack:
		var pack_size: int = _pack_mates(c, world, 260.0).size() + 1
		mass_threat_mult *= 1.0 + minf(float(pack_size - 1), 4.0) * 0.4
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
		# Pack members spread around the target by index instead of all
		# stacking on the same approach line - the closest thing to
		# pursuer/flanker roles without a full role-assignment system.
		var chase_point := nearest_player.global_position
		if c.species_data.pack:
			chase_point += _flank_offset(c, world)
		c.velocity = (chase_point - c.global_position).normalized() * sp
		if dplayer < c.stats.radius + nearest_player.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
			c.attack_target = nearest_player
			c.telegraph = 0.75 if c.species_id == "razorcat" else 0.35
		return

	if nearest_player and dplayer < 320.0 and threat:
		c.velocity = (c.global_position - nearest_player.global_position).normalized() * sp * 1.2
		return

	c.velocity = _wander_dir(c, delta, world) * sp * 0.35

static func _pack_mates(c: Creature, world: Node, radius: float) -> Array:
	var mates: Array = []
	for other in world.creatures_by_id.values():
		if other == c or other.dead or other.is_player:
			continue
		if other.species_id != c.species_id:
			continue
		if c.global_position.distance_to(other.global_position) < radius:
			mates.append(other)
	return mates

static func _flank_offset(c: Creature, world: Node) -> Vector2:
	var pack := _pack_mates(c, world, 260.0)
	pack.append(c)
	if pack.size() <= 1:
		return Vector2.ZERO
	pack.sort_custom(func(a, b): return a.entity_id < b.entity_id)
	var idx := pack.find(c)
	var angle: float = (float(idx) / float(pack.size())) * TAU
	return Vector2(cos(angle), sin(angle)) * 55.0

static func _wildfire_flee_dir(world: Node) -> Vector2:
	match world.wildfire_direction:
		"left": return Vector2.RIGHT
		"right": return Vector2.LEFT
		"top": return Vector2.DOWN
		"bottom": return Vector2.UP
	return Vector2.ZERO

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

# --- apex: Alert -> Threaten -> Charge -> Pursue -> Search -> Return ---
#
# The old apex was a fixed-radius circle you learned to route around once
# you understood it wasn't especially fast and always stopped at the same
# invisible line. Real panic needs three things that circle never had:
# committing hard once provoked (faster than an unevolved player can
# outrun by holding W), not knowing the instant it's given up (Search
# roams the last-seen area for a while instead of snapping back), and a
# willingness to wreck the terrain you were hoping to hide behind.

const APEX_ALERT_RADIUS := 280.0
const APEX_THREATEN_TIME := 1.6 ## how long a threat has to linger before commitment, unless provoked
const APEX_CHARGE_TIME := 2.5 ## initial burst - faster than APEX_PURSUE_SPEED_MULT alone
const APEX_CHARGE_SPEED_MULT := 2.1
const APEX_PURSUE_SPEED_MULT := 1.55
const APEX_GIVE_UP_RANGE := 420.0 ## losing the target this far away starts Search
const APEX_SEARCH_TIME := 11.0
const APEX_SMASH_RANGE := 50.0

static var _apex_ai: Dictionary = {} ## entity_id -> {state, timer, target_id, last_seen}

static func _apex_state(c: Creature) -> Dictionary:
	if not _apex_ai.has(c.entity_id):
		_apex_ai[c.entity_id] = {"state": "guard", "timer": 0.0, "target_id": -1, "last_seen": c.global_position}
	return _apex_ai[c.entity_id]

static func _process_apex(c: Creature, world: Node, delta: float) -> void:
	if c.telegraph > 0.0:
		c.telegraph -= delta
		if c.telegraph <= 0.0:
			_resolve_telegraphed_attack(c, world)
		c.velocity = Vector2.ZERO
		return

	# A territory is only worth defending if the territory isn't currently
	# on fire - needs-based movement in miniature: the apex's top priority
	# flips from "hold ground" to "get away from the fire front" without
	# any Wildfire-specific code in this function at all. This overrides
	# panic entirely - fleeing a real fire matters more than a grudge.
	if world.current_event_id == "wildfire":
		var away_from_fire := _wildfire_flee_dir(world)
		if away_from_fire != Vector2.ZERO:
			c.velocity = away_from_fire * c.stats.speed * 1.2
			return

	var home: Vector2 = c.get_meta("home_position", c.global_position)
	var st := _apex_state(c)
	var players: Array = world.get_player_creatures()
	var nearest_player: Creature = _nearest(c, players, 999999.0) as Creature
	var dplayer := nearest_player.global_position.distance_to(c.global_position) if nearest_player else 999999.0
	var provoked: bool = nearest_player != null and c.last_hit_time > 0.0 and c.last_attacker_id == nearest_player.entity_id

	match st["state"]:
		"guard":
			if provoked or (nearest_player and dplayer < 140.0):
				st["state"] = "charge"
				st["timer"] = APEX_CHARGE_TIME
				st["target_id"] = nearest_player.entity_id
			elif nearest_player and dplayer < APEX_ALERT_RADIUS:
				st["state"] = "threaten"
				st["timer"] = APEX_THREATEN_TIME
				st["target_id"] = nearest_player.entity_id
			else:
				_apex_guard_territory(c, world, home, delta)
			return
		"threaten":
			var target := world._find_creature(int(st["target_id"])) as Creature
			if target == null or target.dead or target.global_position.distance_to(home) > APEX_ALERT_RADIUS + 120.0:
				st["state"] = "guard"
				return
			# Faces the threat, doesn't move yet - the warning before commitment.
			c.facing = c.global_position.direction_to(target.global_position).angle()
			c.velocity = Vector2.ZERO
			if provoked or c.global_position.distance_to(target.global_position) < 90.0:
				st["state"] = "charge"
				st["timer"] = APEX_CHARGE_TIME
				return
			st["timer"] -= delta
			if st["timer"] <= 0.0:
				st["state"] = "charge"
				st["timer"] = APEX_CHARGE_TIME
			return
		"charge", "pursue":
			var target: Creature = world._find_creature(int(st["target_id"]))
			if target == null or target.dead:
				st["state"] = "search"
				st["timer"] = APEX_SEARCH_TIME
				return
			var d := c.global_position.distance_to(target.global_position)
			if d > APEX_GIVE_UP_RANGE:
				st["state"] = "search"
				st["timer"] = APEX_SEARCH_TIME
				st["last_seen"] = target.global_position
				return
			st["last_seen"] = target.global_position
			var mult: float = APEX_CHARGE_SPEED_MULT
			if st["state"] == "charge":
				st["timer"] -= delta
				if st["timer"] <= 0.0:
					st["state"] = "pursue"
			else:
				mult = APEX_PURSUE_SPEED_MULT
			c.velocity = (target.global_position - c.global_position).normalized() * c.stats.speed * mult
			_apex_smash_path(c, world, target.global_position)
			if d < c.stats.radius + target.stats.radius + 4.0 and c.bite_cooldown <= 0.0:
				c.attack_target = target
				c.telegraph = 0.5
			return
		"search":
			# Not knowing it's given up is the point - roam the last place it
			# saw you rather than snapping back to guard duty immediately.
			if nearest_player and dplayer < 150.0:
				st["state"] = "charge"
				st["timer"] = APEX_CHARGE_TIME
				st["target_id"] = nearest_player.entity_id
				return
			var to_last: Vector2 = Vector2(st["last_seen"]) - c.global_position
			if to_last.length() > 40.0:
				c.velocity = to_last.normalized() * c.stats.speed * 0.85
			else:
				c.velocity = _wander_dir(c, delta, world) * c.stats.speed * 0.5
			st["timer"] -= delta
			if st["timer"] <= 0.0:
				st["state"] = "guard"
			return

static func _apex_guard_territory(c: Creature, world: Node, home: Vector2, delta: float) -> void:
	var d_home := c.global_position.distance_to(home)
	if d_home > 220.0:
		c.velocity = (home - c.global_position).normalized() * c.stats.speed * 1.3
		return
	c.velocity = _wander_dir(c, delta, world) * c.stats.speed * 0.3

## The payoff for all the escape-interaction work: thinking a fallen log
## or rock will save you, then the apex smashes straight through it. Only
## while actively charging/pursuing (a guarding apex doesn't casually
## flatten the forest) and only things directly in its path to the target.
static func _apex_smash_path(c: Creature, world: Node, target_pos: Vector2) -> void:
	var dir := c.global_position.direction_to(target_pos)
	for o in world.objects_by_id.values():
		if o.kind not in ["log", "rock"] or not o.is_solid():
			continue
		var to_obj: Vector2 = o.global_position - c.global_position
		if to_obj.length() > APEX_SMASH_RANGE + o.radius:
			continue
		if dir.dot(to_obj.normalized()) < 0.5:
			continue
		if o.kind == "log":
			world._broadcast_update_object(o.object_id, "open", true)
		else:
			world._broadcast_update_object(o.object_id, "broken", true)
