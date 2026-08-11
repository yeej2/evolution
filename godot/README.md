# EVOLUTION — Multiplayer Vertical Slice 0.1

Godot 4.3 project. Two biomes (Forest, Wetlands), one shared ecosystem per
world, 1-4 players, server-authoritative.

## Running it

Open the project in Godot 4.3+ and hit Play, or:

```
godot --path godot
```

Pick a biome next to **Host**, then have a second player **Join** at your
LAN/localhost address (or `host:port` for a tunnel like playit.gg) and pick
a lineage. Controls: WASD move, mouse aim, Shift sprint, Space
hold-to-charge-pounce/tap-to-bite, E eat/interact, Q lineage special
(currently only Grazer's Share Sustenance). RMB changes meaning if you've
evolved a combat archetype - see below.

## Content

- **Biomes:** Forest (baseline), Wetlands (much more water, more predators,
  fewer/smaller land resources), and Highlands (rock and scarcity - one
  small lake, few berries, more rocks) - see `WorldGenerator`.
- **Mutation families:** Claws, Legs, Hide (now including Fur, a 5th
  cold-hardy tier-2 branch alongside Insulation), Venom, Jaws, Fins
  (aquatic), plus the Carnivore/Herbivore/Scavenger diet trio.
- **Lineages have distinct roles, not just stats.** Stalker is a glass
  cannon: fast, fragile (55 HP), and its hold-to-charge is Flurry Strike - a
  rapid multi-hit combo that plants it in place rather than a dash, so
  committing to it is genuinely risky. Grazer is support: a mediocre
  fighter (Shoulder Charge barely out-damages a normal bite, though the
  knockback is huge) whose real value is Q - Share Sustenance, feeding a
  nearby ally out of its own hunger reserve at a loss. Titan is a tank:
  Ground Slam roughly doubles bite damage at full charge, and Brace gives
  it a flat 20% damage reduction on everything it takes, all the time.
  Movement also has real per-lineage momentum (`LineageData.handling`)
  instead of instant velocity snapping - Stalker turns on a dime, Titan
  carries weight into turns. See `LineageData` and
  `Creature._process_player_movement()`.
- **The environment now actually gates evolution, not just flavor text.**
  Several mutations always *claimed* an environmental interaction they
  didn't mechanically have - Strong Jaws said "break rocks," Climbing Claws
  said "climb faster," and neither did anything. Now: rocks are permanent
  obstacles unless something with Strong Jaws bites through one (several
  hits, not instant - see `World._try_break_rock()`), and fallen logs block
  everyone except a Climbing Claws creature, which ignores them entirely
  (`WorldObject.LAYER_LOG`, `Creature._update_collision_shape()`). Both are
  permanent, server-authoritative, and replicated the same way burning a
  tree or opening a log in a wildfire already was. This is the intended
  general pattern going forward: a real obstacle with more than one honest
  way through it (route around it, or invest in the mutation that clears
  it), not a stat check.
- **The HUD now actually surfaces the mechanics above.** A charge bar shows
  while holding the attack (previously zero feedback on how charged a
  lunge/charge/slam was); the special-ability line shows Q's name and
  ready/cooldown state for lineages that have one; a contextual hint line
  shows up when standing next to a rock or log, saying whether you can
  break/climb it and how. A persistent one-line control reminder is always
  visible too. See `game_ui.gd`'s `update_charge_bar()`/`_environment_hint()`.
- **Migration checklist shows real progress bars, not a flat x/OK.**
  `Creature.can_migrate()`/the migrate button were always "any ONE item
  done," but a bare x/OK next to 3 items reads like "you need all 3" -
  each item now has a 0..1 `progress` value and a real bar. The server
  also now re-validates `can_migrate()` in `rpc_request_migrate()` instead
  of just trusting that the client's button was only ever shown when
  eligible. Added an EP/evolution progress bar too (previously zero
  visibility into how close the next mutation draft was).
- **Escape interactions.** E doubles as a refuge action when there's no
  food in reach: Climbing Claws lets you climb a nearby tree, Digging
  Claws lets you burrow *anywhere*, and anyone can use a placed **Burrow**
  object regardless of mutations. Sheltered (`Creature.refuge_time > 0`)
  means immobile but genuinely imperceptible to wildlife AND other
  players' bites - not just "hidden" in the stealth-mechanic sense. Water
  is a passive refuge too: non-aquatic predators won't chase prey/players
  into it. Auto-exits after `REFUGE_DURATION` (6s) with a cooldown after.
- **Nests are no longer just fire fuel.** Standing at an unburned one
  slowly heals you - the first non-destructive multi-purpose use for an
  object that previously only existed to burn down in Wildfire.
- **Wildlife wanders toward water instead of pure random walk when idle**
  (`WildlifeAI._wander_dir`) - this is deliberately the entire "ecological
  hotspots"/"dynamic migration" implementation: water becomes dangerous
  because predators drift toward it too, not because of a separate
  hotspot data structure to maintain.
- **Sensory Evolution**: Keen Smell/Keen Hearing/Night Vision, a new
  independent (non-branching, stackable) mutation family. These reveal
  *information*, not a flat detection-range bonus - Keen Smell tells you
  "a carcass is to the northeast," Keen Hearing tells you something's
  actively hunting nearby, Night Vision negates a real sense-range penalty
  players now have at night without it. See `game_ui.gd`'s
  `_sensory_hint()`.
- **Seed-based Forest profiles**: Lush/Dry/Flooded/Ancient, selectable
  alongside Forest/Wetlands/Highlands. Same creature roster, same
  migration checklist rules (they're all still "forest" underneath), same
  mutation pool - what differs is resource/obstacle density and, for the
  first time, *per-biome event weighting* (`WorldGenerator.
  biome_event_weights()` - Dry Forest is ~4x more likely to roll a
  Drought, Flooded Forest almost never does). This is the actual
  design-validation surface for PLAN.md's test: **does the same starting
  lineage evolve differently across these, or do players converge on the
  same "optimal" picks regardless of world?** If the latter, the
  environment isn't mattering enough yet and that's a real signal, not a
  content gap to paper over with more biomes.
- **Real bug fix: world bounds were never actually enforced.** `WORLD_SIZE`
  only ever controlled where things *spawned* - nothing clamped where a
  creature could actually go, so both wildlife and players could walk
  straight out of the 1600x1200 world (confirmed via a debug log showing
  x positions in the thousands). Now hard-clamped every tick, both
  server-side (`World._clamp_to_world()`, all creatures) and client-side
  (a joined client's *own* creature is locally predicted specifically so
  server corrections don't fight it - same clamp had to be applied there
  too, or it could walk past the edge with nothing ever pulling it back).
  A real edge treatment (dense forest/cliffs/water explaining the
  boundary visually, instead of an invisible wall) is a follow-up.
- **Structured world generation ("generate situations, not objects") for
  the four Forest archetypes.** These used to just be different ratios of
  independently-scattered objects. Now each has named landmarks that
  cluster a resource kind's *entire* spawn budget around an anchor point
  instead of scattering it map-wide - Dry Forest's Rocky Pass, Ancient
  Forest's Dense Canopy Zone, Lush Forest's Berry Groves, etc. Flooded
  Forest is the flagship case: `WorldGenerator._gen_flooded_forest()`
  builds an actual connected river (a chain of overlapping water circles
  in a wandering line across the map, not independent ponds) with one
  deliberately-placed Fallen Giant log bridging it and an Island Nest as
  the reward for crossing. Landmarks aren't labeled on-screen by design
  (see PLAN.md 9.6) except one exception: the HUD shows "Near: <name>"
  when you're inside one, and it's recorded in telemetry (below) - the
  idea is for players to nickname them ("meet at the Fallen Giant"), not
  for the UI to.
- **Terrain-dependent digging.** Digging Claws letting you burrow
  literally anywhere made the ground stop mattering. Soil is derived from
  what's already there rather than a separate authored system: standing
  within ~55 units of an *unbroken* rock is "rocky" ground and blocks
  burrowing (break the rock with Strong Jaws and the rubble becomes
  diggable - an emergent interaction between two mutations, not something
  deliberately paired); Ancient Forest's Dense Canopy Zone is marked
  "root_dense" and blocks digging entirely, forcing routing through it on
  the surface or via the separate Cave Mouth (Burrow object, which is
  already-dug and works regardless of soil). See `World._soil_at()`.
- **Need-driven movement, two concrete additions** (on top of the
  hotspot/water-bias wander from the previous pass): a territorial apex
  now abandons its territory and flees during Wildfire instead of holding
  ground and cooking; fleeing prey bias their escape toward a nearby
  Burrow object instead of just running directly away from the threat
  with no destination in mind.
- **World-state telemetry.** Every death/migration/reproduction now
  appends a JSON line to `user://telemetry.jsonl` (biome, seed, lineage,
  final mutation list, generation, mass, distance traveled, nearest
  landmark). This is the actual measurement for the divergent-evolution
  test PLAN.md records as a requirement - run a batch of same-lineage
  games across different Forest profiles and diff the mutation lists
  afterward instead of hand-tracking it.
- **Great Horn has a real panic state machine**: Guard -> Threaten -> Charge
  -> Pursue -> Search -> (back to Guard). Casually skirting its territory
  gets a warning (it faces you, doesn't move); actually provoking it
  (attacking it, or lingering too close) commits it to a charge that's
  temporarily much faster than an unevolved player, and it'll smash
  through logs/rocks directly in its path while pursuing. Losing it
  doesn't mean you're instantly safe - it Searches the last place it saw
  you for ~11s before giving up. See `wildlife_ai.gd`'s `_process_apex()`.
- **Razorcat is a real pack hunter now.** Courage scales with nearby
  packmates (a lone Razorcat won't engage a much bigger player; a pack of
  five will), pack members spread around a shared target by index instead
  of stacking on one approach line, and a wounded packmate under 40% HP
  triggers nearby allies to converge on its attacker regardless of their
  own normal detection range - "you wounded one, now three come back."
  A Razorcat under 30% HP disengages toward its pack instead of fighting
  on alone. See `SpeciesData.pack` / `wildlife_ai.gd`'s `_pack_mates()`.
- **Three combat archetypes**, evolved independently of starting lineage -
  any Stalker/Grazer/Titan can pick these up, and the mutation changes
  what your mouse buttons actually do:
  - **Spitter** (`venom_gland` -> `projectile_gland`): RMB aims, Space
    fires a real projectile (`Projectile.gd`) that travels, poisons, and
    despawns on hit - not a raycast, an actual simulated object every
    peer sees move identically.
  - **Ravager** (`rending_claws` -> `predatory_talons`): chaining bites
    within 1.5s stacks up to +45% damage (x3), and hitting a target's
    back (any target, not just wildlife with a rear-bonus stat) adds a
    bleed stack. The "lunge" ask is just the existing pounce/charge
    mechanic - no separate system needed.
  - **Behemoth** (`grasping_claws` -> `crushing_grip`): Space grabs a
    nearby target (mass-capped so you can't grab something way bigger),
    Space again crushes it, RMB throws it in your aim direction with real
    knockback + damage. A held target is dragged along behind you every
    tick and is fully immobilized - can't act, can't be independently
    targeted by anything else while held.
  - **Honest scope note**: each archetype shipped with one real mutation
    path (2 mutations: a base + the one that unlocks the actual mechanic),
    not the full branching trees or hybrids described in the original
    ask. The core fantasy and controls are real and complete; more
    branches (Quill Volley, Great Scythe, Impale/Drag, hybrids like
    Canopy Hunter) are a natural follow-up once these are playtested.
- **Snapshot format changed again** (added `ep`/`ep_next`/`special_cooldown`
  replication) - as always, both host and joiners need to be on the same
  build or `rpc_snapshot` will throw an index-out-of-bounds trying to read
  fields the other side's version doesn't send.
- **Server-side validation, from an actual code review pass.** Several
  request_* RPCs trusted the client more than they should have for
  anything beyond friendly co-op:
  - `rpc_request_eat` only found the *nearest* food in a 999-unit search
	radius with no actual proximity check - a client could eat from
	almost anywhere. Now validated against `radius + radius +
	EAT_INTERACT_RANGE`.
  - `rpc_choose_mutation` only rejected duplicate ids via
	`MutationComponent.add()` - it never checked the id was one of the
	three actually offered. The server now tracks `pending_mutation_
	choices` per creature and only accepts an id from that exact set,
	clearing it immediately after (success or not).
  - `rpc_request_reproduce` never checked `can_migrate()` or that the
	parent actually owned the mutation it claimed to pass on. Both are
	now validated. (Found while fixing this: reproduce was already
	unreachable after a normal death, since the creature is despawned -
	removed from `creatures_by_id` - before the reproduce screen even
	appears, so it silently only ever worked after a migration win. This
	contradicts PLAN.md's "death becomes reproduction" design and is a
	separate, not-yet-fixed follow-up.)
  - `rpc_request_join` never checked that `lineage_id` was real.
  - Grazer's Share Sustenance capped its own cost at 100 hunger but still
	gave the ally the full fixed benefit - a Grazer already near-starving
	could pay almost nothing while still handing out the full amount. The
	ally's benefit now scales with what was actually paid.
- **Object radius and food cook-state are now actually replicated.** Both
  were previously mutated only on the server's own copy with zero network
  sync at all - not just "already-connected clients don't see it," late
  joiners didn't either. Drought's water-shrink and Wildfire's carcass-
  cooking now go through `_broadcast_object_radius()`/
  `_broadcast_update_food_state()` respectively, matching the existing
  burned/open/broken pattern.
- **Events:** Drought, Wildfire, Predator Surge (extra hunters spawn in and
  every predator presses attacks harder/further for the duration).
- **Migration checklist is per-biome** (`Creature.migration_checklist()`):
  Forest asks for mass/apex-kill/distance, Wetlands asks for aquatic
  adaptation + touched water/apex-kill/surviving a Drought, Highlands asks
  for Fur-or-Insulation/surviving a Wildfire/apex-kill/mass.

## Architecture (see PLAN.md section 8/9 for the design rationale)

- **Data, not booleans.** `scripts/data/*.gd` defines `MutationData`,
  `SpeciesData`, `LineageData`, `WorldEventData` as Resources. The actual
  tables live in `scripts/autoload/*_db.gd` (autoloaded singletons). A
  creature's entire genome is `MutationComponent.owned: Array[String]` -
  never a pile of per-mutation flags.
- **Components, not a god-object.** `scripts/components/` holds
  `StatsComponent`, `MutationComponent`, `StatusEffectComponent`,
  `HungerComponent`. `scripts/entities/creature.gd` composes them.
- **Server authority.** `scripts/World.gd` is the only place that mutates
  simulation state. Clients call `rpc_request_*` / `rpc_submit_move`; the
  server validates and broadcasts results. See `_apply_*` vs `_broadcast_*`
  vs `rpc_*` naming: `_apply_*` mutates local state only, `_broadcast_*`
  applies locally AND tells every remote peer, and the bare `rpc_*` methods
  are the network entry points themselves (never call them directly except
  through the two wrappers above, or you'll skip either the local or the
  remote half of the update).
- **Shared-seed terrain, explicit entity replication.** The map layout
  (`scripts/systems/world_generator.gd`) is generated identically on every
  peer from one broadcast integer. Creatures and food are individually
  replicated by id since they're dynamic (spawned/eaten/killed constantly).
- **Late join catch-up.** `World.send_full_state_to_peer()` regenerates the
  terrain from the seed, replays every burn/open mutation, and spawns every
  currently-alive creature/food item for a newly-connected peer.
- **AI is data-dispatched.** `scripts/ai/wildlife_ai.gd` reads `SpeciesData`
  flags (`herd`, `water_tether`, `scavenger`, `territorial`, `bush_eater`,
  `nocturnal`) rather than branching on species id.
- **Events are authoritative state machines.** `scripts/systems/
  world_event_manager.gd` (Drought, Wildfire, Predator Surge) runs
  server-side only; clients only ever see its effects (object burns, food
  changes, hp changes, extra creatures spawning/despawning) via the normal
  replication RPCs.
- **Snapshots are positional, not keyed, and chunked.** `Creature.
  to_snapshot_core/_extended()` return plain arrays, not Dictionaries -
  repeating 11 key name strings per creature per packet was what pushed a
  ~13-creature snapshot past the ENet MTU. Status flags (hidden/stunned/
  poisoned/bleeding) are a single bitmask. `World._broadcast_snapshot()`
  also splits the per-tick creature list into `SNAPSHOT_CHUNK_SIZE`-sized
  RPCs, since even the compact format starts exceeding one packet again
  somewhere around a dozen creatures (trivially reached at 3-4 players plus
  their local wildlife).
- **Client-side prediction + interpolation.** `main.gd` simulates the local
  player's own movement immediately instead of waiting for a snapshot round
  trip; the server's snapshot then gently reconciles it. Every other
  creature interpolates toward its latest known snapshot position
  (`Creature.net_target_pos`) instead of snapping to it.
- **player_died is explicitly announced, not just despawned.**
  `World._announce_player_died()` emits it locally on the server and
  replicates it via a dedicated reliable RPC (`rpc_notify_player_died`) - a
  despawn RPC alone doesn't tell a joined client anything happened to their
  own creature.

## Known follow-ups (not yet done)

- Player death drops a spectate-camera player into free-look mode
  (`main.gd`'s `_spectating`), but there's still no "watch your pack" state
  beyond that - no spectating a specific other player, no
  respawn-on-reproduction handoff (see PLAN.md section 8, "Death becomes
  reproduction").
- Mutation drafts aren't biome-gated - Fins/Fur can be offered/picked in the
  "wrong" biome even though they're mostly wasted there. Low priority;
  matches how every other family is always available regardless of biome.
- No interest management (every peer gets every creature in the world every
  snapshot, chunked or not). Verified clean at 4 players/16 creatures on
  localhost; would need real distance-based culling before Wild Ecosystem /
  Survival of the Fittest player counts (8-24).
