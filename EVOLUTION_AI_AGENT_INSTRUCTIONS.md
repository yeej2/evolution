# EVOLUTION — AI Agent Instruction File

## Mission
Build **EVOLUTION** end-to-end as a playable 2D top-down roguelike survival game in **Godot 4.x using GDScript**.

Do not stop at scaffolding, architecture notes, empty scenes, or TODOs. Continue until there is a playable vertical slice. Use placeholder art/audio whenever needed. Prioritize gameplay, systemic interactions, modularity, readability, and fast iteration.

## Core Vision
The player begins as a weak organism and survives by exploring, eating, avoiding predators, hunting, interacting with the environment, collecting DNA, mutating, reproducing, and progressing through harder ecosystems.

The core rule is:

> **Evolution changes how you interact with the world.**

Mutations must affect more than stats. They should change movement, combat, diet, detection, traversal, environmental interaction, hazard resistance, and future mutation possibilities.

The player should begin feeling like prey, find an ecological niche, become dominant, and eventually face ecosystems that adapt to them.

---

## Engine
Use:
- Godot 4.x
- GDScript
- 2D top-down
- CharacterBody2D for moving organisms
- Area2D for sensing/interactions
- NavigationAgent2D where useful
- Resource-based data for mutations, lineages, creatures, biomes, and environment objects
- signals for loose coupling

Desktop first. Web export can come later.

---

## Main Gameplay Loop
Explore → find food/resources → avoid/hunt/intimidate creatures → interact with environment → earn Evolution Points / DNA → choose mutation → visually transform → unlock new interactions → survive stronger ecosystem pressure → reproduce → continue as offspring → enter harder biome.

---

## Starting Lineages
Starting classes are evolutionary lineages, not fantasy RPG classes.

Each lineage must have:
1. Mutation-category biases.
2. An innate passive.
3. A persistent evolution rule.

Mutation weighting should guide, not lock, the run.

Suggested lineages:

### Scavenger
Favored: metabolism, senses, disease resistance.
Passive: carcasses/spoiled food restore extra Energy.
Evolution rule: new food categories increase metabolism/sense weighting.

### Stalker
Favored: stealth, senses, venom, ambush offense.
Passive: remaining still in concealment builds Hidden; first attack from Hidden gains bonus damage.
Evolution rule: killing a stronger creature guarantees offense/sense representation in the next mutation offer.

### Grazer
Favored: defense, digestion, body size, endurance.
Passive: plants restore extra hunger and minor health.
Evolution rule: prolonged plant-heavy survival increases defense/metabolism weighting.

### Burrower
Favored: digging, echolocation, defense.
Passive: can create a shallow emergency burrow in soft ground.
Evolution rule: underground discovery increases subterranean mutation weighting.

### Climber
Favored: claws, mobility, gliding.
Passive: starts able to climb basic trees and has reduced fall damage.
Evolution rule: elevated exploration increases climbing/aerial weighting.

### Aquatic
Favored: fins, gills, electricity, aquatic senses.
Passive: improved swimming and underwater endurance.
Evolution rule: time underwater increases aquatic weighting.

### Broodkeeper
Favored: social, regeneration, defense.
Passive: gains bonuses near offspring/allies.
Evolution rule: reproduction provides one extra inheritance choice.

### Mutagen
Favored: rare, unstable, hybrid, synergy mutations.
Passive: evolution screens show 4 choices instead of 3.
Evolution rule: every third mutation may trigger a bonus mutation with a drawback.

### Titan
Favored: size, armor, horns, strength.
Passive: begins larger and stronger, but requires more food.
Evolution rule: successful mass-based combat increases large-body weighting.

### Opportunist
Balanced weighting.
Passive: one free reroll per evolution screen.
Evolution rule: bonus Evolution Points for discovering new interaction types.

Future meta-progression: unlock lineages through behavior rather than permanent raw stat upgrades.

---

## Survival Systems
Use three main resources:

### Health
0 HP = individual dies.

### Energy
Used for sprinting, special attacks, flight, digging, regeneration, electricity, pouncing, etc.

### Hunger
Gradually rises. High hunger reduces Energy recovery and eventually damages Health.

Avoid adding excessive meters early.

---

## Combat
Combat is real-time, readable, positional, and body-driven.

Base organism starts with:
- move
- sprint
- bite
- evade/reposition

Evolution creates the rest.

Use a small number of active biological actions:
- Primary Attack
- Secondary Attack
- Mobility Ability
- Special Ability

Examples:
- Stalker: Bite / Claw / Pounce / Camouflage
- Titan: Horn Jab / Stomp / Charge / Intimidate
- Electric aquatic creature: Bite / Tail Strike / Swim Dash / Electric Pulse

Do not create ability-bar bloat.

### Energy
Use Energy rather than heavy cooldown systems.

Example costs:
- Bite: 5
- Sprint: 8/sec
- Claw: 10
- Pounce: 20
- Horn Charge: 25
- Electric Pulse: 35
- Flight: 7/sec
- Regeneration: 40

Expected rhythm:
engage → spend Energy → disengage/reposition → recover → engage again.

### Body Parts as Weapons
Mutations should modify attacks and movement.

Examples:
- Claws → Swipe / Bleeding / Latch
- Horns → Charge / Knockback
- Strong Jaws → stronger Bite / break shells/bones
- Tail Club → rear/side sweep
- Venomous Fangs → Bite applies Venom
- Electric Organ → Electric Pulse

Prefer modifying existing actions over endlessly adding buttons.

### Mass
Every creature has Mass.

Mass affects:
- knockback
- charge collisions
- grappling
- carrying
- stagger resistance
- intimidation
- sprite scale
- footstep intensity

Small creatures should solve large enemies differently than large creatures.

### Status Effects
Keep it simple:
- Bleeding
- Venom
- Stagger
- Cripple
- Stun
- Fear
- Wounded

### Hunting vs Fighting
Hunting should often be:
detect → approach → concealment → ambush → chase → kill/fail/disengage.

Predators and prey should not behave like RPG mobs.

### Grappling / Latching
Large attacker: grab/shake/drag/throw.
Similar mass: brief grapple contest.
Small attacker: cannot normal-grab, but Climbing Claws may unlock Latch.

### Intimidation
AI should estimate threat from:
- mass
- teeth
- horns
- armor
- spines
- roar
- pack size
- health

Weak creatures may flee or abandon territory/food.

A major progression signal should be that former predators begin avoiding the player.

---

## Environment Interaction
The environment must be systemic, not decorative.

Environmental objects expose tags and interactions. Player mutations grant capabilities. The Interaction System matches capabilities to requirements.

Do not hardcode every object-mutation pair.

Example object data:

```gdscript
{
    "id": "fallen_log",
    "tags": ["climbable", "breakable", "contains_food"],
    "interactions": {
        "climb": {"requires": ["climb"], "result": "cross"},
        "break": {"requires": ["break_wood"], "result": "destroy"},
        "forage": {"requires": ["enhanced_smell"], "result": "spawn_insects"}
    }
}
```

Example capabilities:
- climb
- dig
- break_wood
- break_stone
- swim
- glide
- fly
- poison
- electrify
- push
- burn
- latch

---

## Mutation ↔ Environment Examples

### Claws
- climb trees/cliffs
- open nests
- scratch bark for insects
- shallow digging
- latch onto larger prey

### Strong Jaws
- crack bones
- crack shells
- tear carcasses
- break branches
- access armored prey

### Horns
- charge
- knock down small trees
- break fragile rocks
- push heavy objects
- smash nests

### Digging Claws
- burrow
- create shelter
- uncover roots/insects
- access underground shortcuts
- make nests

### Wings
- glide/fly
- cross gaps
- reach high nests
- bypass rivers
- escape terrestrial predators

### Web Glands
- create bridges
- set traps
- anchor climbing points
- immobilize prey
- reinforce nests

### Venom
- poison prey
- poison carcasses
- deter scavengers
- contaminate small pools

### Electric Organs
- stun creatures
- stun fish
- electrify shallow water
- frighten some predators

### Fire/Chemical Glands
Late-game:
- burn vegetation
- expose hidden prey
- destroy nests
- create fire barriers

### Prehensile Tail
- grab fruit
- swing
- pull objects
- carry extra item
- grab small prey

### Camouflage
Effectiveness depends on terrain and coloration.

### Echolocation
- cave navigation
- sense creatures through thin obstacles
- locate hidden/underground prey

### Gills
- deep-water access
- underwater caves
- aquatic hunting

### Fur / Heat Resistance
Allow entry into extreme climates with opposing tradeoffs.

### Photosynthesis
Generate some Energy in sunlight, but requires exposure.

### Bioluminescence
Helps in darkness and attracts insects/mates, but may attract predators.

---

## Environmental Chain Reactions
Build systems that combine.

Examples:
- knock down tree → tree forms bridge → cross river → rare DNA
- burn grass → prey flee → predators follow → territory clears → raid nest
- poison carcass → larger predator eats → weakens → becomes killable
- dig trench → rain fills it → aquatic insects spawn → new food source

Emergent stories are a core success metric.

---

## Exploration Gating
Avoid locked doors. Biology gates access.

Examples:
- cliff → climb / flight / jump
- deep water → gills / lung capacity
- rock wall → digging / strength
- dark cave → possible normally, easier with night vision/echolocation/bioluminescence
- poison swamp → toxin resistance/regeneration
- cold mountain → fur/cold resistance

This creates a biological Metroidvania layer.

---

## Mutation System
Earn Evolution Points through:
- eating
- exploration
- dangerous survival
- hunting
- rare DNA
- reproduction
- first-time interactions
- lineage-relevant behavior

At thresholds, pause and offer mutations.

Default: 3 options.
Mutagen: 4.

Each mutation card shows:
- name
- gameplay ability
- environmental unlocks
- tradeoff
- visual change
- known synergy hints

### Categories
Movement:
- Long Legs
- Climbing Claws
- Digging Claws
- Fins
- Gliding Membrane
- Wings
- Prehensile Tail

Defense:
- Thick Hide
- Shell
- Spines
- Camouflage
- Regeneration

Offense:
- Horns
- Sharp Claws
- Venom
- Strong Jaws
- Electric Organs
- Tail Club

Senses:
- Night Vision
- Echolocation
- Enhanced Smell
- Heat Detection
- Improved Hearing

Metabolism:
- Herbivore Digestion
- Carnivore Digestion
- Scavenger Stomach
- Photosynthesis
- Fat Storage

Social:
- Pack Instinct
- Warning Call
- Parental Care
- Herd Coordination

Intelligence:
- Enhanced Brain
- Memory
- Tool Use
- Primitive Communication
- Social Coordination

### Synergies
Examples:
- Wings + Light Bones → True Flight
- Claws + Strong Arms → Cliff Climber
- Venom + Fangs → Venomous Bite
- Camouflage + Ambush Instinct → Predator's Patience
- Thick Hide + Massive Body → Living Tank
- Web Glands + Climbing Claws → Arboreal Web Hunter
- Electric Organ + Gills → Electric Hunter
- Digging + Echolocation → Subterranean Predator

Automatically detect synergies.

### Tradeoffs
Powerful mutations must have meaningful costs.

Examples:
- Large Body → more health/strength/mass, but more food and slower acceleration
- Wings → flight, but high Energy and poor heavy-armor compatibility
- Armor → defense, but lower speed/Energy efficiency
- Venom → powerful hunting tool, but metabolic cost
- Regeneration → recovery, but major food consumption

Avoid obvious best builds.

---

## Ecosystem AI
NPC archetypes:

### Prey
forage, hide, flee.

### Territorial
defend territory/nest, otherwise avoid needless combat.

### Predator
hunt weaker targets, avoid dangerous ones.

### Scavenger
follow kills, eat carcasses, avoid direct fights.

### Herd
stay together, flee together, protect young.

### Apex Predator
dominates a region and is initially meant to be avoided.

Creatures must interact with each other even when the player does nothing.

The world should feel alive while the player stands still.

---

## Adaptive Ecosystem
Track:
- prey killed
- plants consumed
- time flying
- time underwater
- predators killed
- preferred food
- stealth usage
- combat style
- burrowing
- environmental manipulation

At generation/biome transitions, softly adapt the world.

Examples:
- overhunted prey declines
- dependent predators decline
- plants increase
- camouflage-heavy player causes better-smelling hunters to appear
- flying player encounters more aerial competition / anti-air pressure

Adaptation should create pressure, not punish success.

---

## Generations
The player eventually reproduces and continues as offspring.

Reproduction can:
- checkpoint progress
- increase generation
- apply ecosystem changes
- offer inheritance choices
- create cosmetic/genetic variation

Offspring inherit most major traits but may receive:
- strengthened trait
- altered trait
- spontaneous mutation
- inherited visual variation

MVP may end the run on death; deeper lineage checkpointing can come later.

---

## DNA Families
Examples:

Avian DNA:
- feathers
- light bones
- gliding
- wings
- talons

Arachnid DNA:
- webs
- extra limbs
- venom
- wall climbing

Reptilian DNA:
- scales
- heat detection
- venom
- regrowth

Aquatic DNA:
- gills
- fins
- pressure resistance
- electroreception

DNA opens future mutation branches rather than granting abilities immediately.

---

## Biomes
Initial planned biomes:

### Wetlands
Shallow water, mud, reeds, insects, berries, logs, small predators.

### Forest
Trees, bushes, caves, rivers, cliffs, fruit, nests, larger predators.

### Highlands
Cliffs, wind, cold, sparse food, large predators.

First polished vertical slice should use Forest only.

---

## Environmental Events
Examples:
- Rainstorm
- Drought
- Wildfire
- Migration
- Nightfall
- Cold Snap

Events should alter resources, creature movement, hazards, and opportunities.

---

## Procedural Creature Art
Do not depend on complete hand-made creature sprites.

Build creatures from modular parts:

```text
CreatureVisual
├── Body
├── Head
│   ├── Eyes
│   ├── Jaw
│   └── Horns
├── FrontLimbs
├── RearLimbs
├── Wings
├── Tail
├── Armor
├── Pattern
└── Effects
```

Potential component groups:
- bodies
- heads
- eyes
- limbs
- wings
- tails
- horns
- shells
- spines
- fins
- claws
- jaws
- markings
- fur
- glow organs

Gameplay mutations update the creature's visual genome immediately.

---

## Visual Genome
Example:

```gdscript
{
    "body_type": "compact_03",
    "body_scale": 1.15,
    "head_type": "predator_02",
    "leg_type": "runner_04",
    "tail_type": "prehensile_02",
    "wing_type": null,
    "horn_type": "curved_01",
    "shell_type": null,
    "pattern_type": "stripe_07",
    "palette": "forest_dark",
    "eye_count": 2,
    "glow": false
}
```

Mutation changes gameplay and genome together.

---

## Visual Mutation Stages
Where appropriate, mutations grow through visual stages.

Horns:
No Horns → Horn Buds → Small → Large → Curved → Branching

Wings:
None → Membrane → Glider → Primitive Wings → True Flight

Armor:
Soft Skin → Thick Hide → Scales → Armor Plates → Heavy Shell

The player should visually read evolutionary history from the creature.

---

## Art Pipeline

### Stage 1 — Programmer Art
Use shapes, silhouettes, simple colors, placeholder sprites, basic particles.

### Stage 2 — Modular Stylized Art
Move toward a biologically inspired, readable top-down style with exaggerated silhouettes and modular components.

### Stage 3 — Production Pass
Finalize palette, parts, environment art, effects, UI, sound, and lighting.

Never choose an art solution that prevents future mutation combinations.

---

## AI-Assisted Asset Creation
AI-generated concepts/source assets may be used in batches.

Generate categories such as:
- horns
- heads
- bodies
- wings
- tails
- claws
- plants
- rocks

Normalize everything for:
- perspective
- scale
- transparent backgrounds
- attachment alignment
- outline/shading consistency
- resolution

Do not import random inconsistent one-off images as final production art.

---

## Procedural Animation
Avoid unique animation sets for every creature combination.

Use:
- body bob
- limb oscillation
- head sway
- tail follow-through
- wing flap
- charge lean
- hit recoil
- eating lean
- burrowing sink
- swimming oscillation

Use standardized attachment points:
- head_socket
- left_front_leg
- right_front_leg
- left_back_leg
- right_back_leg
- tail_socket
- wing_left_socket
- wing_right_socket
- horn_left_socket
- horn_right_socket
- armor_socket

---

## Environment Art
Environment should also be modular.

Example tree:
trunk + canopy + roots + optional fruit + optional nest.

Support visual damage states:
- Tree: Healthy → Damaged → Fallen
- Grass: Normal → Burning → Burned
- Rock: Whole → Cracked → Destroyed
- Nest: Intact → Disturbed → Destroyed

---

## Audio
Start with placeholders.

Eventually include:
- footsteps
- water
- leaves
- bites
- claws
- impacts
- roars
- warning calls
- insects
- wind
- rain
- feeding
- breathing
- mutation effects

Creature sounds can vary by pitch, speed, intensity, and layering.

Use adaptive music states:
- Exploration
- Suspicion
- Chase
- Combat
- Apex Encounter
- Safe Area

---

## UI
Minimal HUD:
- Health
- Energy
- Hunger
- Evolution progress
- compact mutation icons

Contextual interactions only.

Creature inspection screen:
- large current creature visual
- lineage
- generation
- diet
- mass
- speed
- armor
- Energy efficiency
- mutations
- environmental capabilities

Run summary:
- Species Name
- Starting Lineage
- Generation
- Biomes Reached
- Mutations
- Creatures Eaten
- Predators Defeated
- Offspring
- Environmental Discoveries
- Inferred Ecological Niche
- Final Creature Visual

---

## Niche Inference
Infer rather than ask the player.

Possible labels:
- Apex Predator
- Ambush Hunter
- Scavenger
- Burrower
- Flying Hunter
- Aquatic Predator
- Armored Grazer
- Omnivore
- Opportunist
- Ecological Generalist
- Pack Hunter
- Nocturnal Hunter

---

## Suggested Project Architecture

```text
/scenes/
    game/
    world/
    creatures/
    ui/

/scripts/
    core/
        game_manager.gd
        run_manager.gd
        save_manager.gd

    creatures/
        creature.gd
        player_creature.gd
        npc_creature.gd

    components/
        health_component.gd
        needs_component.gd
        movement_component.gd
        combat_component.gd
        senses_component.gd
        interaction_component.gd
        mutation_component.gd
        visual_genome_component.gd
        ai_component.gd

    systems/
        evolution_system.gd
        ecosystem_system.gd
        interaction_system.gd
        combat_system.gd
        survival_system.gd
        generation_system.gd
        procedural_world_system.gd
        lineage_system.gd
        niche_system.gd

    ai/
        state_machine.gd
        states/

    rendering/
        creature_renderer.gd
        creature_animator.gd
        effects_manager.gd

    ui/
        hud.gd
        evolution_screen.gd
        lineage_select.gd
        creature_screen.gd
        run_summary.gd

/data/
    mutations/
    lineages/
    creatures/
    biomes/
    environment/
    dna/

/assets/
    creatures/
        bodies/
        heads/
        legs/
        tails/
        wings/
        horns/
        armor/
        eyes/
        patterns/
    environment/
    effects/
    ui/
    audio/
```

---

## System-First Rule
Do not solve interactions with one-off conditionals if a reusable capability/tag system can handle them.

Bad:

```gdscript
if player.has_claws and object.type == "tree":
    climb_tree()
```

Better:

```gdscript
InteractionSystem.get_available_interactions(
    player.capabilities,
    object.interactions
)
```

---

## First Vertical Slice
Build one polished Forest run containing:
- 3 starting lineages
- 1 procedural map
- 6 NPC species
- ~12 mutations
- ~12 environmental objects
- 1 apex predator
- 1 reproduction event
- 1 biome exit

Target length: 15–25 minutes.

The slice is successful if two players can tell very different stories based on adaptation.

Example:
> I began as a Stalker, evolved climbing claws to raid nests, then camouflage and venom turned me into an arboreal ambush predator.

Example:
> I began as a Titan, evolved horns and thick skin, knocked down a tree to cross the river, became an armored herbivore, and eventually challenged the apex predator.

---

## Development Order

### Phase 1 — Movement Sandbox
Implement movement, camera, collision, Health, Energy, Hunger, food, simple procedural map.

### Phase 2 — Living Ecosystem
Implement prey, predators, foraging, hunting, fleeing, carcasses, territories.

### Phase 3 — Combat
Implement Bite, Sprint, enemy attacks, mass, knockback, Energy costs, status framework, flee behavior.

### Phase 4 — Evolution
Implement Evolution Points, mutation screen, weighting, mutation application, visual changes, tradeoffs.

### Phase 5 — Environment Interaction
Implement capability/tag system and initial climb/dig/break/swim/glide/poison/push/electric interactions.

### Phase 6 — Starting Lineages
Implement selection, passives, mutation weighting, evolution rules.

### Phase 7 — Procedural Creature Visuals
Implement modular body, sockets, visual genome, mutation-driven body changes, simple procedural animation.

### Phase 8 — Biomes
Implement Wetlands, Forest, Highlands, transitions, mutation-gated optional areas.

### Phase 9 — Generations
Implement reproduction, inheritance, offspring, generation counter, adaptive ecosystem response.

### Phase 10 — Run Structure
Implement death, restart, victory, run summary, persistent discoveries.

---

## First Required Playable Build
Before expanding, the game must allow the player to:

1. Launch directly into a working main menu.
2. Choose from at least 3 lineages.
3. Start a Forest run.
4. Move and sprint.
5. Manage Energy and Hunger.
6. Eat at least 2 food categories.
7. Encounter autonomous prey and predators.
8. Be detected and hunted.
9. Fight or flee.
10. Kill a creature and create a carcass.
11. Earn Evolution Points.
12. Choose mutations.
13. See mutations visibly alter the creature.
14. Use mutations on environmental objects.
15. Reach at least one mutation-gated area.
16. Encounter one apex predator.
17. Reach reproduction or biome transition.
18. Die and restart.
19. See a run summary.

Do not expand feature count until this loop works and is fun.

---

## Agent Execution Rules
1. Build working gameplay before polishing.
2. Do not stop at scaffolding.
3. Use placeholders whenever assets are missing.
4. Prefer reusable systems.
5. Keep content data-driven.
6. Test after each major system.
7. Fix game-breaking bugs before adding features.
8. Avoid premature over-engineering.
9. Keep the project launchable without manual setup.
10. Maintain `DEV_NOTES.md` with controls, implemented systems, known bugs, and next priorities.
11. Maintain `CONTENT_STATUS.md` with implemented mutations, lineages, creatures, biomes, and interactions.
12. Do not leave required gameplay as TODOs.
13. Prioritize a complete end-to-end loop over quantity of content.

---

## Core Design Test
For every major encounter, ask:

> Would different evolutionary builds solve this encounter in meaningfully different ways?

Example armored grazer:

Stalker:
climb → hide → glide/pounce → latch → venom → escape → track.

Titan:
charge → mass collision → slam into tree → stomp.

Aquatic:
bait toward water → attack from water → electric discharge.

If all builds solve encounters by repeatedly using the same basic attack, redesign the system.

---

## Main Design Principles
Whenever adding a mutation, answer:

1. How does it help survival?
2. What does it cost?
3. What environmental interaction does it unlock?
4. How does it change combat or movement?
5. How does it visibly change the creature?
6. What does it synergize with?
7. What biome/predator can pressure it?

Avoid mutations that are only small percentage increases.

Bad:
`Strong Legs: +10% speed`

Better:
`Spring Legs: leap over logs, small creatures, narrow rivers, and low hazards.`

---

## Three Core Pillars

### 1. Ecosystem Simulation
The world feels alive even when the player does nothing.

### 2. Mutation ↔ Environment Interaction
Biology changes what the world allows the player to do.

### 3. Visible Procedural Evolution
The creature's body becomes a physical record of the run.

Everything else should reinforce these pillars.

---

## Creative North Star

EVOLUTION is not mainly about unlocking upgrades.

It is about encountering problems, adapting, and discovering that those adaptations create new ways to survive.

The player should not simply become a stronger version of the starting organism.

They should become something different.

Something shaped by:
- where they lived;
- what hunted them;
- what they ate;
- how they fought;
- what environments they explored;
- which risks they took;
- what survived long enough to reproduce.

At the end of a successful run, the final organism should mechanically and visually bear little resemblance to its ancestor.

The player should look at it and think:

> **That species exists because of everything that happened to me.**
