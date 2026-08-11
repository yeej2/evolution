class_name Creature
extends CharacterBody2D

## A single creature - player-controlled or wildlife. All "what kind of
## creature is this" data lives in StatsComponent/MutationComponent/etc,
## never as ad-hoc booleans on this script. The server is the only peer
## that ever calls process_server_tick(); clients just read the fields
## that World.gd's snapshot system writes into them each frame.

signal died(creature: Creature)

var entity_id: int = -1
var owner_peer_id: int = 0 ## 0 = AI-controlled, otherwise the controlling player's peer id
var is_player: bool = false
var generation: int = 1

var lineage_id: String = ""
var species_id: String = ""
var lineage_data: LineageData = null
var species_data: SpeciesData = null

var stats: StatsComponent = StatsComponent.new()
var mutation: MutationComponent = MutationComponent.new()
var status: StatusEffectComponent = StatusEffectComponent.new()
var hunger: HungerComponent = HungerComponent.new()

var facing: float = 0.0
var in_water: bool = false
var hidden_ready_time: float = 1.5

var pounce_time: float = 0.0
var pounce_dir: float = 0.0
var pounce_power: float = 0.0
var pounce_hit_ids: Array = []

var bite_cooldown: float = 0.0
var telegraph: float = 0.0
var attack_target: Creature = null
var last_attacker_id: int = -1
var knockback_impulse: Vector2 = Vector2.ZERO

var move_input: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0
var sprint_held: bool = false
var dead: bool = false

# --- Client-side smoothing ---
# On a client (not the server), creatures other than the local player's own
# never get position updates except from rpc_snapshot, which only arrives at
# ~15-30Hz. Snapping straight to each new value looks like stutter, so those
# creatures interpolate toward the latest received position instead. The
# local player's own creature is driven by client-side prediction (see
# main.gd) and only gets gently reconciled toward the server's value.
var net_target_pos: Vector2 = Vector2.ZERO
var net_interp_active: bool = false

func _process(delta: float) -> void:
	if net_interp_active:
		global_position = global_position.lerp(net_target_pos, clampf(delta * 12.0, 0.0, 1.0))

# Migration / progress tracking, replicated via to_snapshot_extended() since
# migration_checklist() runs on clients too (HUD, game-over screen).
var apex_killed: bool = false
var distance_traveled: float = 0.0
var touched_water: bool = false
var survived_drought: bool = false
var survived_wildfire: bool = false

# Evolution points -> mutation draft trigger
var ep: float = 0.0
var ep_next: float = 60.0

# --- Setup ---

func setup_as_player(id: int, peer_id: int, lineage: String) -> void:
	entity_id = id
	is_player = true
	owner_peer_id = peer_id
	lineage_id = lineage
	lineage_data = LineageDB.get_lineage(lineage)
	stats.base_hp = lineage_data.base_hp
	stats.base_speed = lineage_data.base_speed
	stats.base_mass = lineage_data.mass
	stats.base_radius = lineage_data.radius
	stats.base_bite_damage = 6.0
	stats.base_sense_range = 0.0
	recompute_stats()
	stats.hp = stats.max_hp
	name = "Player_%d" % id

func setup_as_species(id: int, species: String) -> void:
	entity_id = id
	is_player = false
	species_id = species
	species_data = SpeciesDB.get_species(species)
	stats.base_hp = species_data.base_hp
	stats.base_speed = species_data.base_speed
	stats.base_mass = species_data.mass
	stats.base_radius = species_data.radius
	stats.base_bite_damage = species_data.bite_damage
	stats.base_sense_range = species_data.sense_range
	recompute_stats()
	stats.hp = stats.max_hp
	name = "%s_%d" % [species_data.display_name, id]

func recompute_stats() -> void:
	stats.recompute(mutation.effects_list())
	_update_collision_shape()

func _ready() -> void:
	if has_node("Collision") and $Collision.shape:
		$Collision.shape = $Collision.shape.duplicate()

func _update_collision_shape() -> void:
	if has_node("Collision") and $Collision.shape is CircleShape2D:
		$Collision.shape.radius = stats.radius
	if has_node("Visual"):
		$Visual.queue_redraw()

func add_mutation(id: String) -> bool:
	var added := mutation.add(id)
	if added:
		recompute_stats()
	return added

# --- Server-side simulation ---

func process_server_tick(delta: float) -> void:
	if dead:
		return
	var hp_delta := status.process(delta, self)
	stats.hp += hp_delta
	if bite_cooldown > 0.0:
		bite_cooldown -= delta

	if is_player:
		hidden_check(delta)
		_process_player_movement(delta)
		var starve_delta := hunger.process(delta, lineage_data.hunger_rate)
		stats.hp += starve_delta

	if stats.hp <= 0.0 and not dead:
		dead = true
		died.emit(self)

func hidden_check(delta: float) -> bool:
	var moving := move_input.length() > 0.05
	if moving:
		hidden_ready_time = 0.0
		status.hidden = false
	else:
		hidden_ready_time += delta
		var threshold: float = 1.5 * mutation.mult_value(EffectKeys.STEALTH_HIDE_TIME_MULT, 1.0)
		if hidden_ready_time > threshold:
			status.hidden = true
	return status.hidden

func _process_player_movement(delta: float) -> void:
	var v := Vector2.ZERO
	if pounce_time > 0.0:
		pounce_time -= delta
		var pounce_speed: float = (340.0 + pounce_power * 180.0) * mutation.mult_value(EffectKeys.POUNCE_DISTANCE_MULT, 1.0)
		v = Vector2.RIGHT.rotated(pounce_dir) * pounce_speed
	elif not status.is_stunned():
		var water_mult := 1.0
		if in_water:
			# WATER_SPEED_MULT defaults to the water-logged penalty (0.55) if
			# nothing ignores it, but once something does (e.g. Fins), it
			# becomes a bonus multiplier on top of full speed instead - so a
			# swim-speed mutation like Deep Diver still does something for a
			# creature that already ignores the slowdown.
			water_mult = mutation.mult_value(EffectKeys.WATER_SPEED_MULT, 1.0) if mutation.has_flag(EffectKeys.IGNORE_WATER_SLOW) else mutation.mult_value(EffectKeys.WATER_SPEED_MULT, 0.55)
		var sp := stats.speed * water_mult
		var mag: float = clamp(move_input.length(), 0.0, 1.0)
		if sprint_held and hunger.energy > 0.0 and mag > 0.05:
			sp *= 1.6
			hunger.energy -= 8.0 * delta
		v = move_input.normalized() * sp * mag if mag > 0.05 else Vector2.ZERO
		if mag > 0.05:
			facing = move_input.angle()
	velocity = v + knockback_impulse
	var before := global_position
	move_and_slide()
	distance_traveled += global_position.distance_to(before)
	knockback_impulse = knockback_impulse.lerp(Vector2.ZERO, clamp(delta * 8.0, 0.0, 1.0))
	if knockback_impulse.length() < 0.5:
		knockback_impulse = Vector2.ZERO

func start_bite() -> void:
	pass # resolved directly by World.gd calling CombatResolver against a nearby target

func start_pounce(charge: float) -> void:
	pounce_time = 0.35
	pounce_dir = aim_angle
	pounce_power = charge
	pounce_hit_ids.clear()

const MIGRATION_MASS_GOAL := 2.5
const MIGRATION_DISTANCE_GOAL := 4000.0

## Per-biome checklist (PLAN.md 8.6) - any one condition unlocks the exit.
## Reads the biome off GameState.world rather than taking a parameter, since
## this is called from several places (HUD, game-over screen, migrate
## button) that don't all have a World reference handy.
const HIGHLANDS_MASS_GOAL := 3.0

func migration_checklist() -> Array:
	var biome: String = GameState.world.biome_id if GameState.world else "forest"
	match biome:
		"wetlands":
			return [
				{"label": "Aquatic adaptation + touched water", "done": mutation.has_flag(EffectKeys.AQUATIC_ADAPTED) and touched_water},
				{"label": "Kill the apex", "done": apex_killed},
				{"label": "Survive a Drought", "done": survived_drought},
			]
		"highlands":
			return [
				{"label": "Fur or Insulation", "done": mutation.has_flag(EffectKeys.COLD_ADAPTED)},
				{"label": "Survive a Wildfire", "done": survived_wildfire},
				{"label": "Kill the apex", "done": apex_killed},
				{"label": "Mass >= %.1f" % HIGHLANDS_MASS_GOAL, "done": stats.mass >= HIGHLANDS_MASS_GOAL},
			]
		_:
			return [
				{"label": "Mass >= %.1f" % MIGRATION_MASS_GOAL, "done": stats.mass >= MIGRATION_MASS_GOAL},
				{"label": "Kill the apex", "done": apex_killed},
				{"label": "Travel far and wide", "done": distance_traveled >= MIGRATION_DISTANCE_GOAL},
			]

func can_migrate() -> bool:
	for item in migration_checklist():
		if item["done"]:
			return true
	return false

## Bitmask flags for the compact core snapshot (see to_snapshot_core).
const FLAG_HIDDEN := 1
const FLAG_STUNNED := 2
const FLAG_POISONED := 4
const FLAG_BLEEDING := 8

## Positional (not Dictionary) snapshot format - avoids repeating key name
## strings for every creature on every packet, which was the main reason a
## ~13-creature snapshot was blowing past the ENet MTU and getting dropped.
## [id, x, y, facing, hp, max_hp, flags, telegraph]
func to_snapshot_core() -> Array:
	var flags := 0
	if status.hidden:
		flags |= FLAG_HIDDEN
	if status.is_stunned():
		flags |= FLAG_STUNNED
	if status.poison_time > 0.0:
		flags |= FLAG_POISONED
	if status.bleed_time > 0.0:
		flags |= FLAG_BLEEDING
	return [entity_id, global_position.x, global_position.y, facing, stats.hp, stats.max_hp, flags, telegraph]

## Slow-changing player-only fields, broadcast at a much lower rate.
## [id, mass, speed, mutations, generation, hunger, energy, apex_killed, distance_traveled, touched_water, survived_drought, survived_wildfire]
func to_snapshot_extended() -> Array:
	return [entity_id, stats.mass, stats.speed, mutation.owned.duplicate(), generation, hunger.hunger, hunger.energy, apex_killed, distance_traveled, touched_water, survived_drought, survived_wildfire]
