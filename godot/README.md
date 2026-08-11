# EVOLUTION — Multiplayer Vertical Slice 0.1

Godot 4.3 project. Two biomes (Forest, Wetlands), one shared ecosystem per
world, 1-4 players, server-authoritative.

## Running it

Open the project in Godot 4.3+ and hit Play, or:

```
godot --path godot
```

Pick a biome next to **Host**, then have a second player **Join** at your
LAN/localhost address and pick a lineage. Controls: WASD move, mouse aim,
Shift sprint, Space hold-to-charge-pounce/tap-to-bite, E eat/interact.

## Content

- **Biomes:** Forest (baseline), Wetlands (much more water, more predators,
  fewer/smaller land resources), and Highlands (rock and scarcity - one
  small lake, few berries, more rocks) - see `WorldGenerator`.
- **Mutation families:** Claws, Legs, Hide (now including Fur, a 5th
  cold-hardy tier-2 branch alongside Insulation), Venom, Jaws, Fins
  (aquatic), plus the Carnivore/Herbivore/Scavenger diet trio.
- **Lineages have distinct attack/movement identities, not just stats.**
  Stalker's hold-to-charge is a fast, long, precise Ambush Lunge; Grazer's
  is a slow, sustained Shoulder Charge that barely hits harder than a
  normal bite but has huge knockback; Titan's Ground Slam barely travels
  at all but roughly doubles bite damage at full charge with massive
  knockback. Movement also has real per-lineage momentum now (`LineageData.
  handling`) instead of instant velocity snapping - Stalker turns on a
  dime, Titan carries weight into turns. See `LineageData`'s `pounce_*`/
  `handling` fields and `Creature._process_player_movement()`.
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
