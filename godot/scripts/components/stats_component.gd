class_name StatsComponent
extends RefCounted

## Pure numeric state for a creature. Never stores mutation flags - only the
## final computed numbers that MutationComponent/StatsComponent recompute
## whenever the owned mutation set changes.

var base_hp: float = 100.0
var max_hp: float = 100.0
var hp: float = 100.0

var base_speed: float = 130.0
var speed: float = 130.0

var base_mass: float = 1.0
var mass: float = 1.0

var base_radius: float = 14.0
var radius: float = 14.0

var base_bite_damage: float = 6.0
var bite_damage: float = 6.0

var base_sense_range: float = 160.0
var sense_range: float = 160.0

func recompute(effects_list: Array) -> void:
	max_hp = base_hp
	speed = base_speed
	mass = base_mass
	radius = base_radius
	bite_damage = base_bite_damage
	sense_range = base_sense_range
	for effects in effects_list:
		if effects.has(EffectKeys.MAX_HP_ADD):
			max_hp += effects[EffectKeys.MAX_HP_ADD]
		if effects.has(EffectKeys.SPEED_MULT):
			speed *= effects[EffectKeys.SPEED_MULT]
		if effects.has(EffectKeys.MASS_ADD):
			mass += effects[EffectKeys.MASS_ADD]
		if effects.has(EffectKeys.RADIUS_ADD):
			radius += effects[EffectKeys.RADIUS_ADD]
		if effects.has(EffectKeys.BITE_DAMAGE_ADD):
			bite_damage += effects[EffectKeys.BITE_DAMAGE_ADD]
		if effects.has(EffectKeys.SENSE_RANGE_ADD):
			sense_range += effects[EffectKeys.SENSE_RANGE_ADD]
	hp = min(hp, max_hp)
