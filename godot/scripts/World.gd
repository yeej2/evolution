class_name World
extends Node2D

## The shared simulation. The server (or the local peer, if there is no
## network peer at all - useful for quick offline testing) owns every piece
## of state here; clients only ever call the request_* RPCs and read back
## whatever the authority broadcasts.

signal mutation_draft_offered(choices: Array)
signal player_died(entity_id: int)
signal event_state_changed(event_id: String, phase: String)
signal hud_refresh
signal local_player_ready(c: Creature)

const CreatureScene: PackedScene = preload("res://scenes/Creature.tscn")
const DAY_LENGTH := 60.0
const BERRY_RESPAWN_CHANCE := 0.03
const MIGRATION_TRAVEL_GOAL := 4000.0

var creatures_by_id: Dictionary = {} ## int -> Creature
var objects_by_id: Dictionary = {} ## int -> WorldObject
var food_by_id: Dictionary = {} ## int -> FoodItem
var peer_to_entity: Dictionary = {} ## int peer_id -> int entity_id

var world_seed: int = 0
var biome_id: String = "forest"
var root_dense_zones: Array = [] ## Array of {center: Vector2, radius: float} - see _soil_at()
var landmarks: Array = [] ## Array of {name: String, pos: Vector2, radius: float} - see WorldGenerator's structured Forest generators

## Not labeled on-screen by design (per PLAN.md 9.6/9.7's "you don't
## necessarily label them, they're spatial structures players nickname")
## except this one HUD nicety - lets you say "meet at the Fallen Giant" and
## have it mean something concrete.
func nearest_landmark_name(pos: Vector2) -> String:
	for l in landmarks:
		if pos.distance_to(l["pos"]) < float(l["radius"]):
			return l["name"]
	return ""
var day_time: float = 0.0
var gen_factor: float = 1.0
var generation: int = 1

var current_event_id: String = ""
var event_timer: float = 0.0
var pending_event_id: String = ""
var pending_timer: float = 0.0
var wildfire_direction: String = "left"
var wildfire_progress: float = 0.0
var wildfire_burned_objects: Dictionary = {}
var event_data: Dictionary = {}
var predator_surge_active: bool = false

var _next_food_id: int = 1000
var _seen_initial_food_ids: Array = []
var rng := RandomNumberGenerator.new()

@onready var creatures_root: Node2D = $Creatures
@onready var objects_root: Node2D = $Objects
@onready var food_root: Node2D = $Food

func _ready() -> void:
	GameState.register_world(self)
	rng.randomize()
	NetworkManager.player_connected.connect(_on_peer_connected_send_catchup)

func _on_peer_connected_send_catchup(peer_id: int) -> void:
	if not _is_authority() or world_seed == 0:
		return
	send_full_state_to_peer(peer_id)

## Brings a freshly-connected peer up to date with everything that already
## happened: terrain layout (via the shared seed), any burns/opens applied
## to it, which of the original berries are already gone, any food spawned
## since, and every creature currently alive.
func send_full_state_to_peer(peer_id: int) -> void:
	rpc_setup_world.rpc_id(peer_id, world_seed, biome_id)
	for o in objects_by_id.values():
		if o.burned:
			rpc_update_object.rpc_id(peer_id, o.object_id, "burned", true)
		if o.open:
			rpc_update_object.rpc_id(peer_id, o.object_id, "open", true)
		if o.broken:
			rpc_update_object.rpc_id(peer_id, o.object_id, "broken", true)
		if o.kind == "water" and current_event_id == "drought":
			rpc_update_object_radius.rpc_id(peer_id, o.object_id, o.radius)
	var original_food_ids: Array = []
	for id in food_by_id.keys():
		if id < 1000:
			original_food_ids.append(id)
	for id in range(0, 1000):
		if not food_by_id.has(id) and id in _seen_initial_food_ids:
			rpc_remove_food.rpc_id(peer_id, id)
	for f in food_by_id.values():
		if f.entity_id >= 1000:
			rpc_spawn_food.rpc_id(peer_id, f.entity_id, f.kind, f.global_position.x, f.global_position.y, f.amount, f.radius, f.color, f.cooked, f.fresh_kill, f.poisonous)
	for c in creatures_by_id.values():
		var kind_id: String = c.lineage_id if c.is_player else c.species_id
		rpc_spawn_creature.rpc_id(peer_id, c.entity_id, c.is_player, kind_id, c.owner_peer_id, c.generation)

func _is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()

func is_night() -> bool:
	return fmod(day_time, DAY_LENGTH) / DAY_LENGTH > 0.6

# ------------------------------------------------------------------
# World bootstrap (authority calls this once, replicated to everyone)
# ------------------------------------------------------------------

func host_start(seed_val: int = -1, biome: String = "forest") -> void:
	if seed_val < 0:
		seed_val = rng.randi()
	_apply_world_setup(seed_val, biome)
	if multiplayer.multiplayer_peer:
		rpc_setup_world.rpc(seed_val, biome)
	if _is_authority():
		var counts: Dictionary = WorldGenerator._spawn_and_colors(biome)[0]
		for i in range(int(counts["prey"])):
			_spawn_wildlife("prey")
		for i in range(int(counts["predator"])):
			_spawn_wildlife("predator")
		for i in range(int(counts["apex"])):
			_spawn_wildlife("apex")

## Regenerates the deterministic terrain/food layout locally. Never spawns
## wildlife itself - the server does that once via host_start(), then
## replicates each creature explicitly so ids stay authoritative.
func _apply_world_setup(seed_val: int, biome: String = "forest") -> void:
	world_seed = seed_val
	biome_id = biome
	var data := WorldGenerator.generate(seed_val, biome)
	root_dense_zones = data.get("root_dense_zones", [])
	landmarks = data.get("landmarks", [])
	for od in data["objects"]:
		_spawn_object_local(od["id"], od["kind"], od["x"], od["y"], od["radius"], od["color"])
	for fd in data["food"]:
		_spawn_food_local(fd["id"], fd["kind"], fd["x"], fd["y"], fd["amount"], fd["radius"], fd["color"], false, false, false)
		if not _seen_initial_food_ids.has(fd["id"]):
			_seen_initial_food_ids.append(fd["id"])
	_next_food_id = int(data["next_food_id"]) + 1000

@rpc("authority", "call_remote", "reliable")
func rpc_setup_world(seed_val: int, biome: String) -> void:
	_apply_world_setup(seed_val, biome)

func _spawn_object_local(id: int, kind: String, x: float, y: float, radius: float, color: Color) -> void:
	var o := WorldObject.new()
	objects_root.add_child(o)
	o.configure(id, kind, radius, color)
	o.global_position = Vector2(x, y)
	objects_by_id[id] = o

func _spawn_food_local(id: int, kind: String, x: float, y: float, amount: float, radius: float, color: Color, cooked: bool, fresh_kill: bool, poisonous: bool) -> void:
	var f := FoodItem.new()
	food_root.add_child(f)
	f.configure(id, kind, amount, radius, color)
	f.cooked = cooked
	f.fresh_kill = fresh_kill
	f.poisonous = poisonous
	f.global_position = Vector2(x, y)
	food_by_id[id] = f

# ------------------------------------------------------------------
# Player join / creature spawn
# ------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_join(lineage_id: String) -> void:
	if not _is_authority():
		return
	if LineageDB.get_lineage(lineage_id) == null:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_server_spawn_player(peer_id, lineage_id)

func local_join(lineage_id: String) -> void:
	# Offline / host-local shortcut (no RPC round trip needed for peer 1's own creature).
	_server_spawn_player(multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1, lineage_id)

func _server_spawn_player(peer_id: int, lineage_id: String) -> void:
	var id := NetworkManager.allocate_entity_id()
	peer_to_entity[peer_id] = id
	_broadcast_spawn_creature(id, true, lineage_id, peer_id, generation)
	var c: Creature = creatures_by_id.get(id)
	if c:
		c.global_position = WorldGenerator.WORLD_SIZE / 2.0

## Instantiates locally AND tells every remote peer to do the same. Use this
## (never the bare RPC) whenever the authority creates a brand-new creature.
func _broadcast_spawn_creature(id: int, is_player: bool, kind_id: String, owner_peer: int, gen: int) -> void:
	_apply_spawn_creature(id, is_player, kind_id, owner_peer, gen)
	if multiplayer.multiplayer_peer:
		rpc_spawn_creature.rpc(id, is_player, kind_id, owner_peer, gen)

func _apply_spawn_creature(id: int, is_player: bool, kind_id: String, owner_peer: int, gen: int) -> void:
	var c: Creature = CreatureScene.instantiate()
	creatures_root.add_child(c)
	if is_player:
		c.setup_as_player(id, owner_peer, kind_id)
	else:
		c.setup_as_species(id, kind_id)
		c.stats.base_hp *= gen_factor
		c.stats.base_bite_damage *= gen_factor
		c.recompute_stats()
		c.stats.hp = c.stats.max_hp
		if kind_id == "great_horn":
			c.global_position = Vector2(rng.randf_range(200, WorldGenerator.WORLD_SIZE.x - 200), rng.randf_range(200, WorldGenerator.WORLD_SIZE.y - 200))
			c.set_meta("home_position", c.global_position)
	c.generation = gen
	c.died.connect(_on_creature_died)
	creatures_by_id[id] = c
	if not is_player:
		c.global_position = Vector2(rng.randf_range(60, WorldGenerator.WORLD_SIZE.x - 60), rng.randf_range(60, WorldGenerator.WORLD_SIZE.y - 60))
	elif owner_peer == multiplayer.get_unique_id() or multiplayer.multiplayer_peer == null:
		local_player_ready.emit(c)

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_creature(id: int, is_player: bool, kind_id: String, owner_peer: int, gen: int) -> void:
	_apply_spawn_creature(id, is_player, kind_id, owner_peer, gen)

func _spawn_wildlife(creature_type: String) -> void:
	var species_id: String = SpeciesDB.random_id_of_type(creature_type, rng)
	if species_id == "":
		return
	var id := NetworkManager.allocate_entity_id()
	_broadcast_spawn_creature(id, false, species_id, 0, 1)

func _broadcast_despawn_creature(id: int) -> void:
	_apply_despawn_creature(id)
	if multiplayer.multiplayer_peer:
		rpc_despawn_creature.rpc(id)

func _apply_despawn_creature(id: int) -> void:
	var c: Creature = creatures_by_id.get(id)
	if c:
		creatures_by_id.erase(id)
		c.queue_free()

## player_died was previously only ever emitted on the server (from
## _on_creature_died, guarded by _is_authority()), so a joined client whose
## own creature died - or who won by migrating - never heard about it; their
## creature node just got freed out from under them with nothing telling
## main.gd to stop using it or show the end screen. This announces it on the
## server locally and replicates it (reliably, and therefore in order with
## the despawn RPC that follows it) to every client.
func _announce_player_died(entity_id: int) -> void:
	player_died.emit(entity_id)
	if multiplayer.multiplayer_peer:
		rpc_notify_player_died.rpc(entity_id)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_player_died(entity_id: int) -> void:
	player_died.emit(entity_id)

@rpc("authority", "call_remote", "reliable")
func rpc_despawn_creature(id: int) -> void:
	_apply_despawn_creature(id)

## The actual measurement for the design question PLAN.md now records as a
## requirement (9.6): does the same starting lineage evolve differently
## across seeds/profiles, or do players converge on the same mutations
## regardless of world? One JSON-line per finished run, appended to
## user://telemetry.jsonl, so a batch of test runs can just be grepped/
## diffed afterward instead of hand-tracked.
func _log_telemetry(c: Creature, outcome: String) -> void:
	if not c.is_player or not _is_authority():
		return
	var entry := {
		"time": Time.get_datetime_string_from_system(),
		"biome": biome_id,
		"world_seed": world_seed,
		"lineage": c.lineage_id,
		"generation": c.generation,
		"outcome": outcome,
		"mutations": c.mutation.owned.duplicate(),
		"mass": c.stats.mass,
		"distance_traveled": c.distance_traveled,
		"apex_killed": c.apex_killed,
		"near_landmark": nearest_landmark_name(c.global_position),
	}
	var path := "user://telemetry.jsonl"
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_line(JSON.stringify(entry))
		f.close()

func _on_creature_died(c: Creature) -> void:
	if not _is_authority():
		return
	var carcass_id := _next_food_id
	_next_food_id += 1
	var attacker: Creature = _find_creature(c.last_attacker_id)
	var fresh: bool = attacker != null and attacker.is_player
	var carcass_amount: float = 60.0 if c.is_player else 45.0
	# Your carcass remains and can be eaten - death is not an instant wipe.
	_broadcast_spawn_food(carcass_id, "carcass", c.global_position.x, c.global_position.y, carcass_amount, 12.0, Color("8b5a2b"), false, fresh, false)
	if c.is_player:
		_log_telemetry(c, "died")
		_announce_player_died(c.entity_id)
		_broadcast_despawn_creature(c.entity_id)
	else:
		if fresh and c.species_data.creature_type == "apex":
			attacker.apex_killed = true
		_broadcast_despawn_creature(c.entity_id)
		_spawn_wildlife(c.species_data.creature_type)

func _find_creature(id: int) -> Creature:
	return creatures_by_id.get(id, null)

# ------------------------------------------------------------------
# Player input (client -> server)
# ------------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_submit_move(move: Vector2, aim: float, sprint: bool) -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null:
		return
	c.move_input = move
	c.aim_angle = aim
	c.sprint_held = sprint

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_bite() -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null or c.bite_cooldown > 0.0:
		return
	var target := _nearest_bite_target(c)
	if target:
		server_resolve_bite(c, target)
	elif not _try_break_rock(c):
		pass # bit at nothing - no cooldown waste beyond the normal one below
	c.bite_cooldown = 0.4

## Strong Jaws' whole point is a real, permanent way through an obstacle
## that isn't available to everyone - a rock only cracks under a bite from
## something with EffectKeys.BREAK_ROCKS, and it takes several hits, so it's
## a genuine choice to invest in Jaws rather than a free pass.
func _try_break_rock(c: Creature) -> bool:
	if not c.mutation.has_flag(EffectKeys.BREAK_ROCKS):
		return false
	var reach := c.stats.radius + 40.0
	for o in objects_by_id.values():
		if o.kind != "rock" or o.broken:
			continue
		if c.global_position.distance_to(o.global_position) < reach + o.radius:
			o.rock_hp -= c.stats.bite_damage
			o.queue_redraw()
			if o.rock_hp <= 0.0:
				_broadcast_update_object(o.object_id, "broken", true)
			return true
	return false

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_pounce(charge: float) -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null:
		return
	c.start_pounce(clampf(charge, 0.0, 1.0))

const EAT_INTERACT_RANGE := 14.0
const REFUGE_TREE_RANGE := 20.0
const REFUGE_BURROW_OBJECT_RANGE := 15.0

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_eat() -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null:
		return
	if c.refuge_time > 0.0:
		# Toggle off early - E is also how you come back out.
		c.refuge_time = 0.0
		c.refuge_type = ""
		c.refuge_cooldown = Creature.REFUGE_COOLDOWN
		return
	# _nearest_food_to's 999.0 is just a search radius for "what's the
	# closest food anywhere nearby" - it was never a proximity check by
	# itself, so a client could request-eat food from almost anywhere on
	# the map. Actual reach has to be validated here, server-side.
	var f := _nearest_food_to(c, 999.0)
	if f and c.global_position.distance_to(f.global_position) <= c.stats.radius + f.radius + EAT_INTERACT_RANGE:
		consume_food_by_creature(f, c)
		return
	_try_enter_refuge(c)

## Escape interactions (PLAN.md): a Razorcat is chasing you, so you climb a
## tree, dive underwater (handled passively in wildlife_ai.gd - predators
## won't follow non-aquatic prey into water), or burrow. Climbing needs a
## specific mutation because it needs a specific object (a tree) to climb;
## burrowing has two doors in, matching the "multi-purpose environment
## object" idea - Digging Claws lets you do it anywhere, or anyone can use
## a placed Burrow object instead.
func _try_enter_refuge(c: Creature) -> void:
	if c.dead or c.refuge_cooldown > 0.0:
		return
	if c.mutation.has_flag(EffectKeys.CLIMB_OVER_LOGS):
		for o in objects_by_id.values():
			if o.kind == "tree" and o.is_solid() and c.global_position.distance_to(o.global_position) < c.stats.radius + o.radius + REFUGE_TREE_RANGE:
				c.refuge_type = "tree"
				c.refuge_time = Creature.REFUGE_DURATION
				return
	if c.mutation.has_flag(EffectKeys.BURROW) and _soil_at(c.global_position) == "soft":
		c.refuge_type = "burrow"
		c.refuge_time = Creature.REFUGE_DURATION
		return
	for o in objects_by_id.values():
		if o.kind == "burrow" and c.global_position.distance_to(o.global_position) < c.stats.radius + o.radius + REFUGE_BURROW_OBJECT_RANGE:
			# A placed Burrow is already dug - usable regardless of the
			# ground under it, unlike digging fresh with Digging Claws.
			c.refuge_type = "burrow"
			c.refuge_time = Creature.REFUGE_DURATION
			return

## Digging Claws letting you burrow literally anywhere made the ground
## itself stop mattering - "I don't need to care where safe ground is."
## Soil is derived from what's already there rather than a separate
## authored zone system: rocky ground forms around unbroken rocks (break
## one with Jaws and the rubble becomes diggable again - a nice
## consequence of two mutations interacting rather than something
## deliberately designed in), and biome-specific dense terrain (e.g.
## Ancient Forest's canopy) can mark itself root-dense via root_dense_zones.
func _soil_at(pos: Vector2) -> String:
	for o in objects_by_id.values():
		if o.kind == "rock" and not o.broken and pos.distance_to(o.global_position) < o.radius + 55.0:
			return "rocky"
	for z in root_dense_zones:
		if pos.distance_to(z["center"]) < float(z["radius"]):
			return "root_dense"
	return "soft"

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_special() -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null or c.dead or c.special_cooldown > 0.0 or c.lineage_data == null:
		return
	match c.lineage_data.special_name:
		"share_sustenance":
			_try_share_sustenance(c)

## Grazer's support identity: feed a nearby ally out of your own hunger
## reserve. Deliberately lossy (spends more than it gives) so it's a real
## sacrifice, not a free group-wide hunger reset - the point is "bring a
## Grazer along and it can bail someone out," not "hunger stops mattering."
func _try_share_sustenance(c: Creature) -> void:
	var ally: Creature = null
	var best_d := 90.0
	for other in creatures_by_id.values():
		if other == c or other.dead or not other.is_player:
			continue
		var d: float = c.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			ally = other
	if ally == null:
		return
	const COST := 15.0
	const GIVE := 20.0
	# hunger caps at 100, so a Grazer already near-starving (e.g. 98) would
	# only actually pay 2 of the intended 15 cost while still handing out
	# the full 20 - scale what the ally receives by what was actually
	# spent, so there's no way to get the full benefit at a discount.
	var actual_cost: float = minf(COST, 100.0 - c.hunger.hunger)
	if actual_cost <= 0.0:
		return
	c.hunger.hunger += actual_cost
	ally.hunger.hunger = maxf(0.0, ally.hunger.hunger - GIVE * (actual_cost / COST))
	c.special_cooldown = c.lineage_data.special_cooldown

@rpc("any_peer", "call_remote", "reliable")
func rpc_choose_mutation(mutation_id: String) -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null:
		return
	# add_mutation()/MutationComponent.add() only reject duplicate ids - they
	# don't know or care whether this id was ever actually offered, so
	# without this check a client could request any mutation id at all,
	# bypassing prerequisites/exclusions/weights entirely. Only accept an id
	# from the specific draft the server itself most recently offered this
	# creature, and clear it immediately either way so it can't be replayed.
	var choices := c.pending_mutation_choices
	c.pending_mutation_choices = []
	if mutation_id in choices:
		c.add_mutation(mutation_id)

func _offer_mutation_draft(c: Creature) -> void:
	var weights: Dictionary = c.lineage_data.mutation_weights if c.lineage_data else {}
	var choices: Array = c.mutation.roll_choices(3, weights, GameState.rng)
	if choices.is_empty():
		return
	c.pending_mutation_choices = choices
	if c.owner_peer_id == multiplayer.get_unique_id() or multiplayer.multiplayer_peer == null:
		mutation_draft_offered.emit(choices)
	else:
		rpc_offer_mutation_draft.rpc_id(c.owner_peer_id, choices)

@rpc("authority", "call_remote", "reliable")
func rpc_offer_mutation_draft(choices: Array) -> void:
	mutation_draft_offered.emit(choices)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_migrate() -> void:
	if not _is_authority():
		return
	# "Migrating" just means "you win" for this vertical slice. Re-validate
	# server-side rather than trusting that the client's migrate button was
	# only ever shown when actually eligible - the button is just UI, not
	# an access control.
	var c := _creature_for_sender()
	if c and c.can_migrate():
		_log_telemetry(c, "migrated")
		_announce_player_died(c.entity_id) # reuse the end-of-run screen with a win flag read from hp>0

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_reproduce(inherit_mutation_id: String) -> void:
	if not _is_authority():
		return
	var c := _creature_for_sender()
	if c == null or not c.can_migrate():
		return
	# Without this, a client could hand back a mutation id it never
	# actually owned and have the offspring spawn with it anyway.
	if inherit_mutation_id != "" and not c.mutation.has(inherit_mutation_id):
		return
	_log_telemetry(c, "reproduced")
	var peer_id := multiplayer.get_remote_sender_id()
	var prior_mass := c.stats.mass
	var lineage_id := c.lineage_id
	var new_gen := c.generation + 1
	gen_factor += 0.15
	_broadcast_despawn_creature(c.entity_id)
	var id := NetworkManager.allocate_entity_id()
	peer_to_entity[peer_id] = id
	_broadcast_spawn_creature(id, true, lineage_id, peer_id, new_gen)
	var nc: Creature = creatures_by_id.get(id)
	if nc:
		nc.global_position = WorldGenerator.WORLD_SIZE / 2.0
		nc.stats.mass += prior_mass * 0.1
		if inherit_mutation_id != "":
			nc.add_mutation(inherit_mutation_id)

func _creature_for_sender() -> Creature:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	var id: int = peer_to_entity.get(peer_id, -1)
	return creatures_by_id.get(id, null)

func _nearest_bite_target(c: Creature, extra_reach: float = 50.0) -> Creature:
	var best: Creature = null
	var best_d := INF
	var reach := c.stats.radius + extra_reach
	for other in creatures_by_id.values():
		if other == c or other.dead or other.refuge_time > 0.0:
			continue
		var d: float = c.global_position.distance_to(other.global_position)
		if d < reach + other.stats.radius and d < best_d:
			best_d = d
			best = other
	return best

## A pounce is a moving hitbox for its whole duration, not a single instant
## check - without this, charging and releasing a pounce would move the
## player but never actually resolve a hit against anything.
func _check_pounce_hits(c: Creature, delta: float) -> void:
	if c.lineage_data and c.lineage_data.attack_style == "flurry":
		_check_flurry_hits(c, delta)
		return
	var hit_radius_bonus: float = c.lineage_data.pounce_hit_radius_bonus if c.lineage_data else 20.0
	for other in creatures_by_id.values():
		if other == c or other.dead or other.refuge_time > 0.0 or c.pounce_hit_ids.has(other.entity_id):
			continue
		var d: float = c.global_position.distance_to(other.global_position)
		if d < c.stats.radius + other.stats.radius + hit_radius_bonus:
			c.pounce_hit_ids.append(other.entity_id)
			CombatResolver.resolve_bite(c, other, _pounce_damage_mult(c), _pounce_knockback_mult(c))

## Flurry (Stalker) doesn't move and doesn't dedupe hits by target the way a
## single-pass lunge/charge/slam does - it's a tight, repeating attack: every
## flurry_interval seconds while held, hit whatever's closest in range again.
func _check_flurry_hits(c: Creature, delta: float) -> void:
	c.flurry_hit_timer -= delta
	if c.flurry_hit_timer > 0.0:
		return
	c.flurry_hit_timer = c.lineage_data.flurry_interval
	var target := _nearest_bite_target(c, c.lineage_data.pounce_hit_radius_bonus)
	if target:
		c.facing = c.global_position.direction_to(target.global_position).angle()
		# Standing perfectly still for the whole flurry read as static/dead
		# even though several hits were landing - a real flurry should look
		# like a burst of quick jabs, so nudge visibly toward the target on
		# every landed hit instead of one silent stationary tick.
		c.global_position += c.global_position.direction_to(target.global_position) * 9.0
		CombatResolver.resolve_bite(c, target, _pounce_damage_mult(c), _pounce_knockback_mult(c))

func _pounce_damage_mult(c: Creature) -> float:
	var base: float = c.lineage_data.pounce_damage_base if c.lineage_data else 1.2
	var charge_mult: float = c.lineage_data.pounce_damage_charge_mult if c.lineage_data else 1.2
	return base + c.pounce_power * charge_mult

func _pounce_knockback_mult(c: Creature) -> float:
	return c.lineage_data.pounce_knockback_mult if c.lineage_data else 1.0

func server_resolve_bite(attacker: Creature, target: Creature) -> void:
	var mult := 1.0
	var knockback_mult := 1.0
	if attacker.pounce_time > 0.0:
		mult = _pounce_damage_mult(attacker)
		knockback_mult = _pounce_knockback_mult(attacker)
	CombatResolver.resolve_bite(attacker, target, mult, knockback_mult)

# ------------------------------------------------------------------
# Food
# ------------------------------------------------------------------

func consume_food_by_creature(f: FoodItem, c: Creature) -> void:
	if not _is_authority():
		return
	if c.is_player:
		var result: Dictionary = c.hunger.eat(f.kind, f.amount, f.cooked, f.fresh_kill, c.mutation)
		c.stats.hp = minf(c.stats.max_hp, c.stats.hp + float(result["hp_gain"]))
		if f.poisonous and not c.mutation.has_flag(EffectKeys.POISON_IMMUNE):
			c.status.apply_poison(4.0, -1)
		if float(result["self_poison"]) > 0.0 and not c.mutation.has_flag(EffectKeys.POISON_IMMUNE):
			c.status.apply_poison(float(result["self_poison"]), -1)
		c.ep += 5.0 if f.kind == "berry" else 12.0
		if c.ep >= c.ep_next:
			c.ep = 0.0
			c.ep_next += 60.0
			_offer_mutation_draft(c)
	else:
		c.stats.hp = minf(c.stats.max_hp, c.stats.hp + 5.0)
		if c.species_data and c.species_data.bush_eater and f.kind == "berry":
			_eat_bush_cluster(f, c)
	_broadcast_remove_food(f.entity_id)

func _eat_bush_cluster(origin: FoodItem, c: Creature) -> void:
	for f in food_by_id.values():
		if f == origin or f.kind != "berry":
			continue
		if f.global_position.distance_to(origin.global_position) < 40.0:
			_broadcast_remove_food(f.entity_id)
	var seed_pos: Vector2 = origin.global_position + Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150))
	get_tree().create_timer(20.0).timeout.connect(func():
		if _is_authority():
			_spawn_berry(seed_pos.x, seed_pos.y)
	)

func _spawn_berry(x: float, y: float) -> void:
	var id := _next_food_id
	_next_food_id += 1
	_broadcast_spawn_food(id, "berry", x, y, 22.0, 6.0, Color("4abf4a"), false, false, false)

func _broadcast_spawn_food(id: int, kind: String, x: float, y: float, amount: float, radius: float, color: Color, cooked: bool, fresh_kill: bool, poisonous: bool) -> void:
	_spawn_food_local(id, kind, x, y, amount, radius, color, cooked, fresh_kill, poisonous)
	if multiplayer.multiplayer_peer:
		rpc_spawn_food.rpc(id, kind, x, y, amount, radius, color, cooked, fresh_kill, poisonous)

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_food(id: int, kind: String, x: float, y: float, amount: float, radius: float, color: Color, cooked: bool, fresh_kill: bool, poisonous: bool) -> void:
	_spawn_food_local(id, kind, x, y, amount, radius, color, cooked, fresh_kill, poisonous)

func _broadcast_remove_food(id: int) -> void:
	_apply_remove_food(id)
	if multiplayer.multiplayer_peer:
		rpc_remove_food.rpc(id)

func _apply_remove_food(id: int) -> void:
	var f: FoodItem = food_by_id.get(id)
	if f:
		food_by_id.erase(id)
		f.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_remove_food(id: int) -> void:
	_apply_remove_food(id)

func _broadcast_update_object(id: int, prop: String, value: bool) -> void:
	_apply_update_object(id, prop, value)
	if multiplayer.multiplayer_peer:
		rpc_update_object.rpc(id, prop, value)

## Radius is mutable too (Drought shrinks water), but it's a float, not a
## bool, so it needs its own small replication path rather than reusing
## _apply_update_object/rpc_update_object's bool-only signature. Previously
## this was mutated directly on the server's own WorldObject with no
## network sync at all - not just already-connected clients but even late
## joiners never learned about it.
func _broadcast_object_radius(id: int, radius: float) -> void:
	_apply_object_radius(id, radius)
	if multiplayer.multiplayer_peer:
		rpc_update_object_radius.rpc(id, radius)

func _apply_object_radius(id: int, radius: float) -> void:
	var o: WorldObject = objects_by_id.get(id)
	if o:
		o.radius = radius
		o.queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_update_object_radius(id: int, radius: float) -> void:
	_apply_object_radius(id, radius)

## Same story as object radius, but for food - Wildfire cooking a carcass
## (cooked=true, amount*=1.3) was only ever applied to the server's own
## FoodItem with no network sync, so already-connected clients kept seeing
## the raw carcass and its old value. Late joiners did get it (food is
## fully re-sent on join), just not anyone already in the game.
func _broadcast_update_food_state(id: int, cooked: bool, amount: float) -> void:
	_apply_update_food_state(id, cooked, amount)
	if multiplayer.multiplayer_peer:
		rpc_update_food_state.rpc(id, cooked, amount)

func _apply_update_food_state(id: int, cooked: bool, amount: float) -> void:
	var f: FoodItem = food_by_id.get(id)
	if f:
		f.cooked = cooked
		f.amount = amount
		f.queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_update_food_state(id: int, cooked: bool, amount: float) -> void:
	_apply_update_food_state(id, cooked, amount)

func _apply_update_object(id: int, prop: String, value: bool) -> void:
	var o: WorldObject = objects_by_id.get(id)
	if o == null:
		return
	if prop == "burned":
		o.set_burned(value)
	elif prop == "open":
		o.set_open(value)
	elif prop == "broken":
		o.set_broken(value)

@rpc("authority", "call_remote", "reliable")
func rpc_update_object(id: int, prop: String, value: bool) -> void:
	_apply_update_object(id, prop, value)

func _nearest_food_to(c: Creature, max_range: float) -> FoodItem:
	var best: FoodItem = null
	var best_d := max_range
	for f in food_by_id.values():
		var d: float = c.global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best

# ------------------------------------------------------------------
# Queries used by WildlifeAI
# ------------------------------------------------------------------

func get_all_creatures() -> Array:
	return creatures_by_id.values()

func get_player_creatures() -> Array:
	var out: Array = []
	for c in creatures_by_id.values():
		# Sheltered players (climbing/burrowed - see Creature.refuge_time)
		# are meant to be genuinely imperceptible to wildlife, not just
		# "hidden" in the stealth sense - this is the one place every AI
		# perception check ultimately reads from, so filtering here covers
		# fleeing prey, hunting predators, and territorial apex all at once.
		if c.is_player and not c.dead and c.refuge_time <= 0.0:
			out.append(c)
	return out

const NEST_REGEN_PER_SEC := 3.0

## Nests were previously fire fuel and nothing else - a "multi-purpose
## environment object" needs at least one non-destructive use too: resting
## at one slowly heals, making them worth contesting as safe-ish territory
## (unburned; a burned nest stops working, same logic as everything else
## that fire permanently changes).
func _creature_near_nest(c: Creature) -> bool:
	for o in objects_by_id.values():
		if o.kind == "nest" and not o.burned and c.global_position.distance_to(o.global_position) < c.stats.radius + o.radius:
			return true
	return false

func get_prey_creatures() -> Array:
	var out: Array = []
	for c in creatures_by_id.values():
		if not c.is_player and c.species_data and c.species_data.creature_type == "prey":
			out.append(c)
	return out

# ------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _is_authority():
		return
	day_time += delta
	for c in creatures_by_id.values():
		c.in_water = _creature_in_water(c)
		if c.is_player and c.in_water:
			c.touched_water = true # Wetlands migration checklist
		if c.is_player and not c.dead and _creature_near_nest(c):
			c.stats.hp = minf(c.stats.max_hp, c.stats.hp + NEST_REGEN_PER_SEC * delta)
		c.process_server_tick(delta)
		if c.is_player and c.pounce_time > 0.0 and not c.dead:
			_check_pounce_hits(c, delta)
		if not c.is_player and not c.dead:
			WildlifeAI.process(c, self, delta)
		_clamp_to_world(c)
	if not _is_authority():
		return
	_tick_events(delta)
	if current_event_id != "drought" and rng.randf() < BERRY_RESPAWN_CHANCE * delta:
		_spawn_berry(rng.randf_range(40, WorldGenerator.WORLD_SIZE.x - 40), rng.randf_range(40, WorldGenerator.WORLD_SIZE.y - 40))
	_broadcast_snapshot()

const WORLD_MARGIN := 24.0

## Real bug, caught from a debug log: WORLD_SIZE only ever controlled where
## things spawned, not where a creature could actually go - nothing has
## ever clamped movement to it, so wildlife/players (confirmed via
## auto-wander test logs showing x positions in the thousands against a
## declared 1600-wide world) could just walk straight out of the
## ecosystem. Hard-clamped for now; a real edge treatment (dense
## impassable forest / cliffs / water, so the boundary explains itself
## visually) is a follow-up, not a substitute for this actually working.
func _clamp_to_world(c: Creature) -> void:
	var pos := c.global_position
	var clamped := Vector2(
		clampf(pos.x, WORLD_MARGIN, WorldGenerator.WORLD_SIZE.x - WORLD_MARGIN),
		clampf(pos.y, WORLD_MARGIN, WorldGenerator.WORLD_SIZE.y - WORLD_MARGIN)
	)
	if clamped != pos:
		c.global_position = clamped

func _creature_in_water(c: Creature) -> bool:
	for o in objects_by_id.values():
		if o.kind == "water" and c.global_position.distance_to(o.global_position) < o.radius:
			return true
	return false

var _snapshot_tick: int = 0
const SNAPSHOT_CHUNK_SIZE := 10

func _broadcast_snapshot() -> void:
	if not multiplayer.multiplayer_peer:
		return
	_snapshot_tick += 1
	if _snapshot_tick % 2 != 0:
		return # ~15Hz core snapshot is plenty for a 2-4 player forest map
	var include_extended: bool = _snapshot_tick % 10 == 0 # ~3Hz for slow-changing player fields
	var core: Array = []
	var extended: Array = []
	for c in creatures_by_id.values():
		core.append(c.to_snapshot_core())
		if include_extended and c.is_player:
			extended.append(c.to_snapshot_extended())
	# One entry is ~100 bytes once Variant array overhead is counted, so a
	# single-packet snapshot starts exceeding the ENet MTU (1392 bytes)
	# somewhere around a dozen creatures - trivially reachable at 3-4 players
	# plus their local wildlife. Splitting into several smaller unreliable
	# RPCs keeps every individual packet well under that, at the cost of the
	# chunks technically landing across a couple of frames of jitter (which
	# the client-side interpolation already smooths over) instead of losing
	# packets outright.
	var i := 0
	while i < core.size():
		var chunk: Array = core.slice(i, i + SNAPSHOT_CHUNK_SIZE)
		rpc_snapshot.rpc(chunk, extended if i == 0 else [])
		i += SNAPSHOT_CHUNK_SIZE
	if core.is_empty() and not extended.is_empty():
		rpc_snapshot.rpc([], extended)

@rpc("authority", "call_remote", "unreliable")
func rpc_snapshot(core: Array, extended: Array) -> void:
	var local_peer := multiplayer.get_unique_id()
	for entry in core:
		var c: Creature = creatures_by_id.get(int(entry[0]))
		if c == null:
			continue
		var server_pos := Vector2(entry[1], entry[2])
		if c.is_player and c.owner_peer_id == local_peer:
			# This client is predicting its own creature's movement locally
			# (see main.gd); just nudge gently toward the server's truth
			# instead of overriding the prediction outright.
			c.net_interp_active = false
			c.global_position = c.global_position.lerp(server_pos, 0.2)
		else:
			c.net_target_pos = server_pos
			c.net_interp_active = true
		c.facing = entry[3]
		c.stats.hp = entry[4]
		c.stats.max_hp = entry[5]
		var flags: int = entry[6]
		c.status.hidden = (flags & Creature.FLAG_HIDDEN) != 0
		# These are only ever read as booleans (>0.0) client-side for visuals
		# (creature_visual.gd) - a sentinel of 1.0 is enough to reflect the
		# server's current flag state each snapshot without needing to
		# replicate exact remaining durations.
		c.status.stun_time = 1.0 if (flags & Creature.FLAG_STUNNED) != 0 else 0.0
		c.status.poison_time = 1.0 if (flags & Creature.FLAG_POISONED) != 0 else 0.0
		c.status.bleed_time = 1.0 if (flags & Creature.FLAG_BLEEDING) != 0 else 0.0
		c.telegraph = entry[7]
	for entry in extended:
		var c: Creature = creatures_by_id.get(int(entry[0]))
		if c == null:
			continue
		c.stats.mass = entry[1]
		c.stats.speed = entry[2]
		c.mutation.owned = entry[3]
		c.generation = entry[4]
		c.hunger.hunger = entry[5]
		c.hunger.energy = entry[6]
		c.apex_killed = entry[7]
		c.distance_traveled = entry[8]
		c.touched_water = entry[9]
		c.survived_drought = entry[10]
		c.survived_wildfire = entry[11]
		c.special_cooldown = entry[12]
		c.ep = entry[13]
		c.ep_next = entry[14]
		c.refuge_time = entry[15]
		c.refuge_type = entry[16]
	if not extended.is_empty():
		hud_refresh.emit()

# ------------------------------------------------------------------
# Events (authoritative; see scripts/systems/world_event_manager.gd for the
# actual per-id simulation logic)
# ------------------------------------------------------------------

func _tick_events(delta: float) -> void:
	if current_event_id != "":
		event_timer -= delta
		WorldEventManager.tick(self, current_event_id, delta)
		if event_timer <= 0.0:
			WorldEventManager.end_event(self, current_event_id)
			current_event_id = ""
	elif pending_event_id != "":
		pending_timer -= delta
		if pending_timer <= 0.0:
			current_event_id = pending_event_id
			pending_event_id = ""
			var ed: WorldEventData = EventDB.get_event(current_event_id)
			event_timer = ed.duration
			WorldEventManager.start_event(self, current_event_id)
			event_state_changed.emit(current_event_id, "active")
	elif rng.randf() < 0.003 * delta:
		var candidate := EventDB.weighted_random_id(rng, WorldGenerator.biome_event_weights(biome_id))
		var ed: WorldEventData = EventDB.get_event(candidate)
		if ed.warmup > 0.0:
			pending_event_id = candidate
			pending_timer = ed.warmup
			event_state_changed.emit(candidate, "pending")
		else:
			current_event_id = candidate
			event_timer = ed.duration
			WorldEventManager.start_event(self, candidate)
			event_state_changed.emit(candidate, "active")
