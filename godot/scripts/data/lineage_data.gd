class_name LineageData
extends Resource

## Data-driven description of a player starting lineage.

@export var id: String = ""
@export var display_name: String = ""
@export var radius: float = 14.0
@export var base_hp: float = 100.0
@export var base_speed: float = 130.0
@export var mass: float = 1.0
@export var hunger_rate: float = 1.0
@export var color: Color = Color.WHITE
@export var bonus_description: String = ""

## mutation_id -> weight multiplier used when building the evolution draft pool.
@export var mutation_weights: Dictionary = {}

# --- Attack identity (hold-to-charge special) ---
# Purely descriptive - drives no logic itself, just lets the tunables below
# read as a coherent "why does this feel this way" rather than arbitrary
# numbers (see creature.gd/World.gd's pounce handling for how they're used).
@export var attack_style: String = "lunge"
@export var attack_name: String = "Lunge"
@export var pounce_speed_base: float = 340.0
@export var pounce_speed_charge_mult: float = 180.0
@export var pounce_duration: float = 0.35
@export var pounce_damage_base: float = 1.2
@export var pounce_damage_charge_mult: float = 1.2
@export var pounce_knockback_mult: float = 1.0
@export var pounce_hit_radius_bonus: float = 20.0
## Only meaningful when attack_style == "flurry": seconds between automatic
## hits while the attack is held, instead of a single dash-and-hit.
@export var flurry_interval: float = 0.15

## Bite damage differs by lineage too, not just the hold-to-charge special.
@export var base_bite_damage: float = 6.0

## Flat passive damage reduction from all incoming bites (Titan's "Brace" -
## a tank should just be harder to kill all the time, not on a button).
@export var damage_reduction_pct: float = 0.0

## Q ("dodge" input action - unused otherwise) triggers a lineage-specific
## support ability instead of a generic dodge roll, matching the "no
## universal dodge" design rule in PLAN.md. Currently only Grazer uses this.
@export var special_name: String = ""
@export var special_cooldown: float = 4.0

# --- Movement feel ---
# 1.0 = instantly snaps to target velocity (the old, one-size-fits-all
# behavior). Lower values give heavier creatures real momentum instead of
# turning on a dime - see Creature._process_player_movement().
@export var handling: float = 1.0

func _to_string() -> String:
	return "Lineage(%s)" % id
