class_name CombatResolver

## All bite resolution lives here so there is exactly one place that decides
## "did this hit land, and what happened" - this is the function the server
## calls; clients never run it, they only render the results the server
## broadcasts (hp changes, particles, status effects) via Creature RPCs.

static func resolve_bite(attacker: Creature, target: Creature, mult: float = 1.0, knockback_mult: float = 1.0) -> Dictionary:
	if target.status.iframe_time > 0.0:
		return {}

	var dmg: float = attacker.stats.bite_damage * mult

	if attacker.status.hidden:
		dmg *= attacker.mutation.max_value(EffectKeys.HIDDEN_DAMAGE_MULT, 1.5)
		attacker.status.hidden = false

	var poison_dur := attacker.mutation.max_value(EffectKeys.POISON_ON_HIT, 0.0)
	if poison_dur > 0.0:
		target.status.apply_poison(poison_dur, attacker.entity_id)
		target.status.poison_source_id = attacker.entity_id

	var bleed_dur := attacker.mutation.max_value(EffectKeys.BLEED_ON_HIT, 0.0)
	if bleed_dur > 0.0:
		target.status.apply_bleed(bleed_dur)

	if attacker.in_water and attacker.mutation.has_flag(EffectKeys.AQUATIC_DAMAGE_MULT):
		dmg *= attacker.mutation.mult_value(EffectKeys.AQUATIC_DAMAGE_MULT, 1.0)

	if attacker.pounce_time > 0.0:
		var stun_pounce := attacker.mutation.max_value(EffectKeys.STUN_ON_POUNCE, 0.0)
		if stun_pounce > 0.0:
			target.status.apply_stun(stun_pounce)
		if attacker.mutation.has_flag(EffectKeys.STUN_SMALL_PREY_ON_POUNCE) and target.stats.mass < attacker.stats.mass * 0.5:
			target.status.apply_stun(0.6)

	var stun_hit := attacker.mutation.max_value(EffectKeys.STUN_ON_HIT, 0.0)
	if stun_hit > 0.0:
		target.status.apply_stun(stun_hit)

	if target.mutation.has_flag(EffectKeys.POISON_REFLECT_IN_WATER) and target.in_water:
		attacker.status.apply_poison(5.0, target.entity_id)

	# --- Directional body geometry (species armor / retaliation) ---
	var retaliation_dmg := 0.0
	if target.species_data:
		var facing := target.facing
		var to_attacker := (attacker.global_position - target.global_position).normalized()
		var facing_vec := Vector2.RIGHT.rotated(facing)
		var dot := facing_vec.dot(to_attacker)
		if dot > 0.0 and target.species_data.frontal_armor > 0.0:
			dmg *= (1.0 - target.species_data.frontal_armor)
			if target.species_data.frontal_retaliation:
				retaliation_dmg = 5.0
		elif dot < -0.4 and target.species_data.rear_damage_bonus > 0.0:
			dmg *= (1.0 + target.species_data.rear_damage_bonus)

	if target.mutation.has_flag(EffectKeys.REFLECT_DAMAGE_PCT):
		retaliation_dmg += dmg * target.mutation.mult_value(EffectKeys.REFLECT_DAMAGE_PCT, 0.0)

	target.stats.hp -= dmg
	target.last_attacker_id = attacker.entity_id
	if retaliation_dmg > 0.0:
		attacker.stats.hp -= retaliation_dmg

	# knockback
	var away: Vector2 = (target.global_position - attacker.global_position)
	if away.length() < 0.001:
		away = Vector2.RIGHT
	away = away.normalized()
	var kb: float = (dmg / maxf(target.stats.mass, 0.1)) * 0.6
	kb *= attacker.mutation.mult_value(EffectKeys.KNOCKBACK_MULT, 1.0)
	kb *= knockback_mult
	target.knockback_impulse += away * kb

	return {
		"damage": dmg,
		"retaliation": retaliation_dmg,
		"target_id": target.entity_id,
		"attacker_id": attacker.entity_id,
	}
