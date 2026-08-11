class_name EffectKeys

## Vocabulary of generic effect keys understood by the components.
## A mutation's `effects` dictionary is made of these keys. Adding a new
## mutation almost never requires new engine code - only a new dictionary
## entry using keys already understood by a component, or (rarely) a new
## key + a couple of lines in the component that reads it.

# StatsComponent (flat additive unless noted _mult)
const BITE_DAMAGE_ADD := "bite_damage_add"
const MAX_HP_ADD := "max_hp_add"
const MASS_ADD := "mass_add"
const SPEED_MULT := "speed_mult"
const RADIUS_ADD := "radius_add"
const SENSE_RANGE_ADD := "sense_range_add"

# CombatComponent
const BLEED_ON_HIT := "bleed_on_hit" ## seconds of bleed applied to bitten target
const POISON_ON_HIT := "poison_on_hit" ## seconds of poison applied to bitten target
const HIDDEN_DAMAGE_MULT := "hidden_damage_mult" ## bonus multiplier on first bite after being hidden
const KNOCKBACK_MULT := "knockback_mult"
const STUN_ON_HIT := "stun_on_hit" ## seconds of stun applied to bitten target
const STUN_ON_POUNCE := "stun_on_pounce" ## seconds of stun applied only while pouncing
const STUN_SMALL_PREY_ON_POUNCE := "stun_small_prey_on_pounce"
const RETALIATE_ON_FRONTAL_HIT := "retaliate_on_frontal_hit" ## damage reflected to attacker
const REFLECT_DAMAGE_PCT := "reflect_damage_pct" ## fraction of incoming damage reflected to attacker
const POISON_REFLECT_IN_WATER := "poison_reflect_in_water"
const AQUATIC_DAMAGE_MULT := "aquatic_damage_mult"
const AQUATIC_ADAPTED := "aquatic_adapted" ## gates the Wetlands migration checklist
const COLD_ADAPTED := "cold_adapted" ## gates the Highlands migration checklist (Fur or Insulation)

# MovementComponent
const IGNORE_WATER_SLOW := "ignore_water_slow"
const WATER_SPEED_MULT := "water_speed_mult"
const POUNCE_DISTANCE_MULT := "pounce_distance_mult"
const CLIMB_SPEED_MULT := "climb_speed_mult"
const CLIMB_OVER_LOGS := "climb_over_logs" ## ignore log collision entirely (WorldObject/Creature)
const BREAK_ROCKS := "break_rocks" ## can bite through rocks to permanently clear them (World.gd)
const BURROW := "burrow" ## can enter a refuge state anywhere, not just at a Burrow object (World.gd)

# Sensory Evolution
const KEEN_SMELL := "keen_smell" ## reveals carcass/prey direction beyond normal sense range
const KEEN_HEARING := "keen_hearing" ## reveals nearby aggressive predators beyond normal sense range
const NIGHT_VISION := "night_vision" ## negates the at-night sense_range penalty

# StatusEffectComponent
const POISON_IMMUNE := "poison_immune"
const NUMBING_POISON := "numbing_poison" ## poison inflicted by this creature also slows target
const PARASITIC_POISON := "parasitic_poison" ## poison ticks on target heal this creature

# HungerComponent / diet
const STEALTH_HIDE_TIME_MULT := "stealth_hide_time_mult"
const PLANT_RESTORE_MULT := "plant_restore_mult"
const MEAT_RESTORE_MULT := "meat_restore_mult"
const CARCASS_RESTORE_MULT := "carcass_restore_mult"
const MEAT_CAUSES_SICKNESS := "meat_causes_sickness"
const FRESH_KILL_RESTORE_MULT := "fresh_kill_restore_mult"
const COOKED_CARCASS_RESTORE_MULT := "cooked_carcass_restore_mult"

# Fire / environment resistance
const FIRE_IMMUNE := "fire_immune"

# Combat archetypes (World.gd/main.gd) - these gate entirely different
# control schemes, not stat tweaks. Evolving into one changes what your
# mouse buttons actually do; see main.gd's _unhandled_input and
# World.gd's rpc_request_fire/rpc_request_grab/rpc_request_throw.
const RANGED_ATTACK := "ranged_attack" ## Spitter: RMB aim, fire a projectile
const COMBO_ATTACK := "combo_attack" ## Ravager: chaining bites within COMBO_WINDOW stacks bonus damage
const GRAB_ATTACK := "grab_attack" ## Behemoth: hold Space near a target to grab, Space to crush, RMB to throw
