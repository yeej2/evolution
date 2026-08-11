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

