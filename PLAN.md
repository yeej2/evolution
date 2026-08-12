# EVOLUTION — First Playable Plan

This is the distilled plan for the **EVOLUTION** roguelike survival game. It begins with a fast web prototype to validate the fun, then lists the first Godot vertical slice.

---

## 1. Core Pillars

1. **Ecosystem Simulation:** creatures forage, flee, hunt, and compete even without player input.
2. **Mutation ↔ Environment Interaction:** mutations unlock traversal, food, and combat options rather than just stats.
3. **Visible Procedural Evolution:** the player's body visibly changes with every major mutation.

---

## 2. First-Playable Goals (Minimum Viable Loop)

- Launch straight into a playable forest.
- Choose a lineage (for MVP: **Stalker**, **Grazer**, **Titan**).
- Move, sprint, and use energy.
- Manage hunger and health.
- Eat at least two food categories (plants / meat).
- Encounter prey and predators with simple AI.
- Fight or flee in real-time combat.
- Kill a creature and leave a carcass.
- Earn Evolution Points.
- Choose a mutation that changes stats and/or interactions.
- See a visible body change.
- Use a mutation to interact with an environmental object.
- Die and restart quickly.

---

## 3. Prototype Scope (Web / HTML5)

A 10-minute throwaway prototype to test the feel.

### Mechanics
- **WASD** move, **Shift** sprint (drains Energy), **Space** bite, **E** eat / interact.
- **Health**, **Energy**, **Hunger** bars.
- Hunger slowly rises; sprint and attacks cost Energy.
- Biting costs 5 Energy and has a short cooldown.
- Prey drops carcasses; berries are static plants.

### Starting Lineages (prototype)
- **Stalker**: faster while still, bonus first bite from hiding (simplified: standing still for 1.5s makes the next bite do +50% damage).
- **Grazer**: plants restore extra hunger; starts with more health.
- **Titan**: larger, stronger, slower, needs more food.

### Content
- 1 small forest map.
- 8 berry bushes.
- 6 small prey (yellow). Flee from player.
- 3 predators (red). Hunt player unless player is bigger/stronger.
- 1 apex predator (purple). Slow and lethal early.
- 4 trees, 2 rocks.
- 1 shallow water pool.

### Mutation Options (prototype pool)
1. **Sharp Claws** — bite +3 damage, can climb trees (E near tree).
2. **Long Legs** — +20% speed, can cross shallow water faster.
3. **Thick Hide** — +30 max HP, +mass, -10% speed, looks larger.
4. **Venom Fangs** — bite applies poison (5 dmg over 3s), visual green tint.
5. **Strong Jaws** — can break rocks (E near rock), +5 bite damage, head grows.

### AI Archetypes
- **Prey:** wander, flee if player is close.
- **Predator:** patrol, chase weaker/smaller target, flee if low HP or out-massed.
- **Apex:** slow chase of player, ignores smaller creatures.

### Win / Loss
- **Loss:** Health reaches 0.
- **Win (prototype):** reach 100 Evolution Points and choose at least one mutation.

---

## 4. Godot Vertical Slice (Phase 1)

After the prototype, build the same scope in Godot 4.x / GDScript.

### Folder Sketch
```
/scenes
    world.tscn
    player_creature.tscn
    npc_creature.tscn
    food.tscn
    env_tree.tscn
    env_rock.tscn
/scripts
    core/game_manager.gd
    creatures/creature.gd
    creatures/player_creature.gd
    creatures/npc_creature.gd
    components/health_component.gd
    components/needs_component.gd
    components/movement_component.gd
    components/combat_component.gd
    components/mutation_component.gd
    components/ai_component.gd
    systems/evolution_system.gd
    systems/interaction_system.gd
    ui/hud.gd
    ui/evolution_screen.gd
```

### Implementation Order
1. Movement, camera, collision, Health/Energy/Hunger.
2. Simple procedural forest map + food.
3. Prey, predator, and carcass AI.
4. Bite, sprint, Energy costs, knockback, mass.
5. Evolution Points and mutation screen.
6. Capability/tag interaction system (climb, break, swim).
7. Lineage selection and passives.
8. Visual genome (scale, color, horns/claws/Spines).
9. Death, restart, run summary.

---

## 5. Mutation Short List (Vertical Slice)

| Mutation | Category | Gameplay Effect | Environment Unlock | Tradeoff | Visual |
|----------|----------|-----------------|--------------------|----------|--------|
| Sharp Claws | Offense | +3 bite, causes bleeding | Climb trees, scratch bark | slightly less mass | claw marks |
| Long Legs | Movement | +25% speed | Cross shallow water | -5 max HP | longer legs |
| Thick Hide | Defense | +30 HP, +mass | — | -15% speed, larger hitbox | larger, darker body |
| Venom Fangs | Offense | Bite applies venom | Poison carcass deterrence | higher hunger cost | green jaw tint |
| Strong Jaws | Offense | +5 bite, breaks shells/bones | Break rocks, tear carcasses | slower acceleration | bigger head |
| Climbing Claws | Movement | Climb cliffs/trees | Access nests | — | hooked claws |
| Enhanced Smell | Senses | Show nearby food/carcass scent | Detect hidden prey | — | larger nose |
| Fat Storage | Metabolism | Hunger rises slower | Survive food shortages | -5% speed | rounder body |

---

## 6. Content Status (for Godot build)

- **Lineages:** Stalker, Grazer, Titan first; others later.
- **Mutations:** implement the 8 above before expanding.
- **Creatures:** Berry bush, insect swarm, rabbit (prey), fox (predator), bear (apex).
- **Biomes:** Forest only for the vertical slice.
- **Environment objects:** tree, rock, berry bush, carcass, water, nest.
- **Status effects:** Bleeding, Venom, Stagger.

---

## 7. Prototype Learning

The HTML5 prototype validated that the loop is fun. The core is now:

> **Lineage → forage/hunt → evolve → unlock interactions → choose a migration strategy → face a harder ecosystem.**

The prototype also confirmed that the strongest hook is *“what did my creature become?”*, not the combat meters.

---

## 8. Next Pass — Deepening Single-Player

### 8.1 Core Design Rule

**Advanced mutations are directions, not upgrades.** Every base mutation must branch into 2–4 advanced mutations that change *what kind of creature* the player becomes.

### 8.2 Branching Mutation Families (First Pass)

**Claws**
- **Rending Claws** — heavy bleed (combat).
- **Climbing Claws** — vertical traversal, nests.
- **Digging Claws** — burrow, roots/insects, underground passages.
- **Grasping Claws** — carry objects, grapple prey.

**Hide**
- **Bone Plate** — hard shell, +HP/mass.
- **Camouflage** — stillness hides player.
- **Thorns** — reflect damage.
- **Insulation** — ignore fire/cold events.

**Venom**
- **Toxic Spit** — ranged poison shot.
- **Numbing Venom** — poison slows target.
- **Parasitic Venom** — poisoned creatures heal player.

### 8.3 Signature Species Rules — Implemented

- **Niblet** — herds with nearby prey.
- **Mossback** — eating a berry consumes the whole nearby cluster (bush) and reseeds new berries elsewhere after 20s.
- **Shellback** — 70% frontal damage reduction; weak from behind.
- **Razorcat** — crouches 0.75s before pouncing (visible warning); more dangerous at night.
- **Riverjaw** — won't stray more than 120 units from water; retreats to water instead of chasing on land.
- **Carrion Beetle** — smells carcasses across the map and prioritizes them over hunting.
- **Great Horn** — owns territory, ignores threats outside it; 60% frontal armor with charge retaliation, +40% damage taken from behind.

### 8.4 Combat Body Geometry — Implemented

- Frontal attacks on Shellback/Great Horn are heavily penalized; Great Horn also retaliates for 5 HP if struck head-on.
- Great Horn takes +40% damage from behind.
- Razorcat gives a visible pounce warning (crouch arc + "!").
- All creatures track facing so front/rear matters.
- Predator "threat" flee threshold raised (mass > 2.2x, was 1.2x) so evolved/mass-heavy builds still get engaged; cornered predators will still bite even while wary.

### 8.5 Event Redesign — Implemented

Events rearrange the food chain, not just modify numbers.

- **Drought** — water shrinks 50%, berries stop respawning, prey actively migrate to remaining water, aquatic creatures (Riverjaw) take damage while stranded on land.
- **Bloom** — extra berries spawn; ~25% are poisonous (visibly purple, prey avoid them, player doesn't unless Insulated).
- **Wildfire** — 6s smoke warmup, then fire sweeps from a random edge over 32s. Nests/trees burn away, logs burn open, carcasses caught in the band get "cooked" (better food value, bypasses Ruminant Gut penalty). Anything in the fire band takes heavy damage and gets pushed ahead of the front unless in water or Insulated; moving fast (>140 speed) cuts the damage. Visualized with an advancing orange front line.
- **Predator Surge** — new hunters enter.

### 8.6 Biome-Specific Migration — Implemented

| Biome | Migration Options |
|-------|-------------------|
| Forest | Mass ≥ 2.5 / kill apex / travel 4000+ units |
| Wetlands | Aquatic adaptation (Fins/Gills + touched water) / kill apex / survive a Drought |
| Highlands | Fur or Insulation / survive a Wildfire / kill apex / Mass ≥ 3.0 |

The HUD and exit both show the live checklist for the current biome; migrating requires only one condition.

### 8.7 Diet & Reproduction — Implemented

- **Carnivore Gut / Herbivore Gut / Scavenger Gut** are mutually-exclusive Diet mutations affecting hunger restore rates from meat vs. plants, with Herbivore causing sickness from meat and Scavenger rewarding aged/cooked carcasses over fresh kills.
- At the exit, once migration is unlocked, the player can choose **Migrate Onward** or **Reproduce (Gen 2)**.
- Reproducing lets the player pick one owned mutation to pass on, resets the character to a fresh juvenile (+10% of the parent's final mass), keeps the same biome, and escalates ecosystem difficulty (`genFactor`) for future generations. The run continues rather than ending.
- Multiplayer (future): reproduction draws from a shared species gene pool instead of a single parent.

---

## 9. Multiplayer Foundation

The game should be treated as **one shared simulation** supporting three modes.

### 9.1 Design North Star

> Multiplayer does not replace the survival/evolution game. It amplifies it.

Roles (tank, scout, scavenger, support) must emerge from biology, never a class menu.

### 9.2 Three Modes

1. **Survival** — 1–4 player co-op. Main experience. Same species, divergent individuals.
2. **Wild Ecosystem** — 8–20 player PvPvE. Other players are just another species in the ecosystem.
3. **Survival of the Fittest** — 12–24 player ecological battle royale. Environmental collapse replaces the magic shrinking circle.

### 9.3 Multiplayer Constraints for Current Systems

- **No local-only state.** Creature AI, physics, hits, and death must eventually be authoritatively server-owned.
- **Scarce, non-instanced resources.** One carcass, one cave, one river crossing. This creates social decisions.
- **Information is gameplay.** Enemy builds are not inspectable; you read their body.
- **Environmental collapse as endgame.** Drought → wildfire → cold → apex migration.
- **Death is not instant respawn.** Spectate or play as a juvenile; return when the group reproduces.
- **Shared gene pool.** Reproduction draws from the group’s discovered adaptations.

### 9.4 First Multiplayer Test

Before any larger modes, answer one question:

> Is surviving with one other person more fun than surviving alone?

Build the smallest possible test: **2 players, 1 Forest, shared food, shared predators, no server.**

### 9.5 Vertical Slice 0.1 — Built

The Godot project in `/godot` is this test. All three biomes from the
exit-criteria table (Forest, Wetlands, Highlands), Stalker/Grazer/Titan
lineages, Claws/Hide(+Fur)/Legs/Venom/Jaws/Fins branching mutations, the
diet trio, Niblet/Mossback/Shellback/Razorcat/Carrion Beetle/Great Horn,
Drought/Wildfire/Predator Surge, per-biome migration checklists, and
reproduce-to-Generation-2 all ported over data-driven and
server-authoritative (see `/godot/README.md` for the architecture notes and
how to run it). Verified end-to-end with real networked Godot processes
(host + join, movement/eat/death/spectate/catch-up/events all replicate
correctly, snapshot bandwidth fixed and chunked to stay under the ENet
MTU). A real 2-player playtest confirmed the loop is fun, though the
answer to the question above deserves more sessions before calling it
settled. Stress-tested at 4 concurrent players (the current `MAX_PLAYERS`)
with zero errors or dropped-packet warnings; real interest management
(culling far-away creatures per peer) is still needed before pushing past
that toward Wild Ecosystem / Survival of the Fittest player counts.

Lineages now have real roles (Stalker glass cannon, Grazer support, Titan
tank) instead of just flat stat differences, and a first real instance of
"the environment forces evolution choices, not just rewards them" exists:
rocks permanently block a path unless something with Strong Jaws bites
through, fallen logs block everyone except Climbing Claws. First-playtest
feedback (a real remote session over playit.gg) directly drove this -
several mutations had claimed an environmental interaction in their
flavor text for a while without one actually existing in code.

### 9.6 Environmental systems pass — Built

Six systems, from a design-review pass after the first real remote
playtest:

1. **Escape interactions** - climb a tree (Climbing Claws), burrow
   anywhere (Digging Claws) or at a placed Burrow object (anyone), dive
   into water (safe from non-aquatic predators). Sheltered = immobile but
   genuinely imperceptible to wildlife and other players, not just
   "stealth-hidden."
2. **Ecological hotspots** + 3. **Dynamic migration** - implemented as one
   change rather than two systems: idle wildlife wander now drifts toward
   the nearest water hole instead of pure random walk, for both prey and
   predators. Water becomes dangerous because predators camp near it, not
   because of a separate hotspot data structure.
4. **Multi-purpose environment objects** - Nest gained a real
   non-destructive use (passive regen) instead of only being fire fuel;
   Burrow is a new object type usable by anyone. Water/Tree/Log/Rock were
   already multi-purpose from the rock/log pass (9.5).
5. **Sensory Evolution** - Keen Smell, Keen Hearing, Night Vision. These
   reveal real information (a direction, a warning) rather than a flat
   detection-range number, and Night Vision only matters because players
   now have a real at-night sense-range penalty to counter.
6. **Seed-based Forest profiles** - Lush/Dry/Flooded/Ancient, same
   creatures/mutations/checklist rules as Forest, different resource
   density and (new) per-biome event-weighting.

**The design-validation test to actually run now** (this is the
requirement, not a nice-to-have): take the same starting lineage into a
few of these profiles. Does it end up evolving differently because the
world made different traits valuable? Or do players converge on the same
"optimal" mutations regardless of which world they're in? If the latter,
the environment doesn't matter enough yet, and that's the next thing to
fix - not "add more content."

### 9.7 Generation depth pass — Built

A follow-up code review of 9.6 correctly identified the real bottleneck:
the four Forest profiles were still "different ingredient ratios inside
the same procedural soup" - different counts of independently-scattered
objects, not actual situations. Four things fixed:

1. **Structured generation, not scattering.** Each Forest archetype now
   builds named landmarks that cluster a resource kind's whole spawn
   budget around an anchor (`WorldGenerator._gen_dry_forest()` /
   `_gen_flooded_forest()` / `_gen_ancient_forest()` / `_gen_lush_forest()`).
   Flooded Forest specifically builds a literal connected river (a chain
   of overlapping water circles) with a deliberate Fallen Giant bridge and
   an Island Nest reward - the exact "generate situations" example from
   the review, not five independent ponds.
2. **Need-driven movement, two more concrete cases** on top of 9.6's
   hotspot wander-bias: apex abandons territory and flees during
   Wildfire; fleeing prey bias toward a nearby Burrow instead of running
   directly away from nothing in particular.
3. **Terrain-dependent digging.** Soil is derived from what's already
   there (unbroken rocks = rocky ground = no burrowing; Ancient Forest's
   Dense Canopy Zone = root-dense) rather than Digging Claws working
   everywhere unconditionally, which had made the ground stop mattering
   for anyone who took it.
4. **World-state telemetry** (`user://telemetry.jsonl`) - biome, seed,
   lineage, final mutation list, nearest landmark, per run. This is the
   actual instrument for 9.6's divergent-evolution test, not just a
   description of it.

Also fixed along the way: a real bug, not a design gap - `WORLD_SIZE` had
never actually been enforced as a movement boundary, only a spawn
boundary. Both wildlife and players could walk straight out of the map.
Now hard-clamped, server- and client-side.

**Explicitly deferred, per the review's own prioritization:** visual
sensory presentation (scent wisps, directional audio cues instead of
text hints), and any further biome/mutation-family expansion - the
project has enough content to run the divergent-evolution test now; the
next thing to actually do is run it.

### 9.8 Panic, packs, and combat archetypes — Built

Feedback from an actual play session: the apex had a learnable fixed
leash radius and wasn't especially fast, so it stopped being a monster
and became a circle to route around; small predators posed no threat
1-on-1 and had no reason to; and evolution changed numbers, never how
combat actually felt to play.

- **Great Horn panic FSM**: Guard -> Threaten -> Charge -> Pursue ->
  Search -> Guard. Provoked (attacked, or lingered too close) commits it
  to a temporarily-much-faster charge; it smashes logs/rocks directly in
  its path while charging/pursuing (the payoff for every escape
  interaction built in 9.6 - water/burrow/tree refuge, obstacles - is
  that they're real, not just decoration); losing it starts an ~11s
  Search around the last place it saw you rather than an instant "safe
  now." See `wildlife_ai.gd`'s `_process_apex()`.
- **Razorcat pack behavior**: courage (willingness to engage a
  much-bigger player) scales with nearby packmates; pack members spread
  around a shared target instead of stacking one approach line; a
  packmate under 40% HP triggers others to converge on its attacker
  regardless of their own detection range; a Razorcat under 30% HP
  disengages toward its pack instead of dying alone. New `SpeciesData.
  pack` flag, so this is reusable for future pack species, not
  Razorcat-specific code.
- **Three combat archetypes**, evolved independently of starting lineage
  (any Stalker/Grazer/Titan can pick one up) - and each one changes what
  the mouse buttons do, not just your numbers:
  - **Spitter** (gun fantasy): `venom_gland` -> `projectile_gland`. RMB
    aims, Space fires an actual simulated projectile (`Projectile.gd`)
    that travels and poisons on hit.
  - **Ravager** (sword fantasy): `rending_claws` -> `predatory_talons`.
    Chained bites stack up to +45% damage; hitting any target's back adds
    bleed. The "lunge" ask is just the existing pounce/charge mechanic.
  - **Behemoth** (grappler fantasy - deliberately the "weird" third
    option, not another weapon): `grasping_claws` -> `crushing_grip`.
    Space grabs (mass-capped), Space again crushes, RMB throws with real
    knockback + damage. Grabbed = fully immobilized and dragged along.

**Explicitly scoped down from the original ask**, per its own stated
priority order (fix these three systems before adding hybrids/more
branches): each archetype has one real mutation path (2 mutations), not
the full branching trees (Quill Volley, Great Scythe, Impale/Drag) or
mutation hybrids (Canopy Hunter, Ambush Assassin, Juggernaut, River
Spitter, Pouncing Blade). The core fantasy and controls are real and
complete for all three; branches/hybrids are the natural next step once
these are actually playtested - premature to build before knowing if the
core three feel right.

**Also explicitly deferred**: the standalone Ambush Predator enemy
concept, and pack cutoff-escape-route roles (flanking-by-angle is built;
"wait outside a burrow entrance" is not).

### 9.9 Still not built

A terrain feature (e.g. a ditch/chasm) only crossable with an aerial
mutation ("wings"), with brute-force alternatives for everyone else
(route around, or spend time knocking down a tree to bridge it). Bigger
than everything in 9.6/9.7/9.8 - implies a new terrain kind and movement
mode (flight), not just a new bypass rule on an existing solid object.

### 9.10 FEEL + INTERACTION update — Built

The previous pass gave the three archetypes different *controls*. This
pass made the same enemies and the same world feel different depending
on which archetype you actually became, and finished the multiplayer
lifecycle death->reproduce bug that was blocking real runs.

- **Death -> Reproduction actually works.** The dead creature was
  despawned before the reproduce RPC could read its state. Now
  `_on_creature_died()` stashes `{lineage_id, mass, mutations,
  generation}` keyed by peer id, and `rpc_request_reproduce()` uses that
  stashed state when no live creature exists. So "I died" is no longer
  game-over - it's "keep the species alive so I can come back."
- **Spitter: Venom Reserve.** Ranged shots now drain 25 stored venom;
  venom passively regenerates slowly (4/s); eating poisonous food gives
  a large refill (40). `projectile_gland` adds +50 capacity. Poisonous
  berry spawn chance is biome-specific (Dry 3%, Lush 15%, Flooded 45%,
  Ancient 25%), so Spitter really isn't equally optimal everywhere.
- **Ravager: commitment and flanking pressure.** Combo chains now reset
  the instant the Ravager takes a hit from anything - not just on a
  timeout. A frontal bite on a Shellback with hardshell retaliation will
  zero the combo; you have to flank to keep stacking.
- **Behemoth: enemy-specific interactions.**
  - *Shellback*: a grabbed hardshell target is flipped (`is_flipped`)
    while held; the grabber's own bites bypass the frontal armor and
    deal +50% damage while the target is upended.
  - *Great Horn*: you can't grab something that heavy, but if it is
    currently charging and you press Space in its path, the Behemoth
    braces and redirects the charge - the Horn takes a shove, gets
    stunned for 2s, and its AI state resets to an 8-second Search.
  - *Razorcat pack*: a throw resolves a bowling splash in a forward
    cone; if it overlaps another cat, that cat takes damage and a stun.
- **Behemoth: mass-tiered environment shove.** Pressing Space with no
  creature to grab now shoves the nearest solid object: logs at mass
  1.0+, rocks at 2.0+, trees at 3.0+. Bigger Behemoths physically
  reshape more of the world.
- **Apex presentation.** The charging apex now has a snapshot flag
  (`FLAG_APEX_CHARGING`) replicated to all clients. Clients use it for
  a proximity-based camera shake and a brief "DANGER" HUD cue. The
  wildlife AI also checks `_flee_from_apex()` for all prey/predators,
  so when a Great Horn charges, the whole food web scatters - not just
  its direct target.
- **Telemetry is running.** Every death/migration/reproduction already
  logs `biome, world_seed, lineage, generation, outcome, mutations,
  mass, distance_traveled, apex_killed, near_landmark`. After ~20-30
  real runs the `user://telemetry.jsonl` file can answer whether Dry
  Forest players evolve differently from Flooded Forest players, which
  mutations dominate, and whether Great Horn kills are disproportionate.

**Honest limitations / scope notes:**
- Apex audio (music drop, heavy footsteps, heartbeat, impact sounds)
  is not built - there are no sound assets yet.
- Apex "environmental dust kick-up" and "birds/prey flee" are the same
  system: wildlife flee. No dedicated dust/leaf particles.
- Spitter venom is shown in the hint text, not a dedicated bar - the
  bar can come once the feel is confirmed.
- Behemoth object shove uses `burned` on trees to make them passable,
  since "felled" doesn't exist. It's functionally correct but the
  terminology/visual is a placeholder.
- The three archetypes still each have one mutation path, not the full
  branching trees or hybrids described in the original ask.

### 9.11 v0.3 — Ancestral Memory (narrative + hidden evolution)

This pass tests whether adding a narrative layer and lineage progression
makes the player want to continue exploring across runs.

- **The Dead Giant** is a generated Firstborn landmark in every Forest
  biome. It offers five clues, each requiring a different adaptation:
  `examine` (none), `smell_giant` (Keen Smell), `excavate_giant`
  (Digging Claws), `break_bone` (Strong Jaws / Jaws), and `reach_skull`
  (Climbing Claws). Discoveries persist in `user://narrative.json` and
  sync to joining clients.
- **Ancestral Insights and hidden mutations.** The `break_bone` clue
  grants the Ancestral Insight **Hollow Skeleton**. Once the lineage
  knows it, compatible creatures (Long Jumper or Climbing Claws) can
  see **Hollow Bones** in their mutation draft. This proves the
  knowledge → biology → evolution loop.
- **Ancestral Memory UI** in the main menu shows the Dead Giant
  progress (X / 5), unlocked insights, and the last 15 lineage memories.
- **Lineage memories** record first mutation, first reproduction,
  migration, first apex kill, death-by-apex/predator, and surviving
  major Drought/Wildfire events.
- **The Hungry Pack** ecological Chapter spawns extra Razorcats plus a
  toughened alpha at the start of the event; they despawn when it ends.

**Honest limitations / scope notes:**
- Only one mystery (the Dead Giant), one insight (Hollow Skeleton), and
  one hidden mutation (Hollow Bones) are built. The architecture
  (`NarrativeDB`, `CLUES`, `INSIGHTS`, `CHAPTERS`) is generic enough to
  add more.
- No dedicated art for the Dead Giant: it is drawn as a cluster of
  large pale circles. It still reads as a landmark on the map.
- The named rival/alpha system is minimal: the alpha gets +HP, +mass,
  and +bite damage, but it does not yet carry a persistent name or scar.
- Biome-specific event weights are simple multipliers; future Chapters
  may deserve their own `chapter_director.gd` files once we have more.
- Ecological Chapters are currently implemented through the existing
  WorldEvent system. A dedicated Chapter Director may be worthwhile if
  more Chapters are added.

### 9.12 v0.3.1 — Ancestral Memory polish

A short follow-up pass to make the v0.3 systems feel like one coherent
narrative loop before deciding whether the idea works.

- **Independent Dead Giant clue access.** After `examine_giant`, the
  remaining four clues are no longer blocked by whichever happens to be
  next in a linear list. The creature can discover any clue its body is
  actually capable of performing.
- **Physical Dead Giant.** The skeleton is now a cluster of distinct
  interactive objects (`giant_tissue`, `giant_excavation`, `giant_femur`,
  `giant_skull`) plus a central `dead_giant` anchor. Each clue must be
  reached at the right bone, so the player is moving through a place
  rather than standing beside a single lore object.
- **Authoritative UI pipeline for mutation and migration.** `main.gd`
  no longer directly mutates `my_creature` for host/single-player.
  `mutation_chosen` and `migrate_pressed` always route through
  `World.rpc_choose_mutation` and `World.rpc_request_migrate`, so the
  same validation, telemetry, and narrative memory logic runs for all
  peers.
- **Distinctive Ancestral draft reveal.** The first time a hidden
  mutation becomes biologically possible, it is guaranteed as a fourth
  draft option with a gold "ANCESTRAL —" label. After it has been
  offered once, it can compete with normal mutations.
- **Hungry Pack Chapter polish.** The event now desawns some prey and
  spawns carcasses at the start, so the ecosystem tells the story.
  Killing the chapter alpha records a `broke_chapter` lineage memory.
- **Lineage memories are location-aware.** All memory creation now
  records the current `biome_id`, `world_seed`, and nearest landmark.
  The Ancestral Memory UI displays "Gen X — biome near landmark".
- **README stale note fixed.** The death→reproduction note no longer
  lists it as a not-yet-fixed follow-up.

### 9.13 v0.3.2 — Egg respawn and species continuity

A short pass that makes player death part of the species survival loop
rather than an immediate run end.

- **Death leaves an egg.** The server spawns a `WorldObject` of kind
  `egg` at the player's death position. It stores the owner's `peer_id`,
  `lineage_id`, `species_id`, `generation`, full mutation list, and a
  decay timer.
- **Incubation / hatch.** A living creature can press E near an egg to
  increment its `egg_incubation`. At the threshold, `_hatch_egg()` spawns
  a new player creature for the egg's owner at the next generation. The
  hatched creature keeps a random subset of up to 3 stored mutations;
  everything else is lost.
- **Multiplayer rescue.** Dead players cannot self-incubate while other
  peers are connected. A packmate must find and warm the egg. This turns
  death into a clutch moment: "hold the egg while I fight."
- **Lone-player fallback.** In true single-player (no network peer, or a
  host with no joined clients) the dead player can still incubate their
  own egg. If the egg rots, the UI falls back to `show_respawn_class_`
  `select()` and the player rejoins as a fresh class with no mutations.
- **Catch-up replication.** Dynamic eggs are sent to late-joining clients
  via `rpc_spawn_egg` in `send_full_state_to_peer`.

