class_name HungerComponent
extends RefCounted

var hunger: float = 0.0 ## 0 = full, 100 = starving
var energy: float = 100.0
var max_energy: float = 100.0

## Advances hunger and returns hp delta from starvation (0 or negative).
func process(delta: float, hunger_rate: float) -> float:
	hunger = min(100.0, hunger + hunger_rate * delta)
	energy = min(max_energy, energy + 6.0 * delta)
	if hunger >= 100.0:
		return -1.5 * delta
	return 0.0

## Resolves eating one food item. `kind` is "berry" or "carcass".
## Returns a dict: {hunger_restored, hp_gain, energy_gain, self_poison, self_poison_source}
func eat(kind: String, base_amount: float, cooked: bool, fresh_kill: bool, mutation: MutationComponent) -> Dictionary:
	var gain := base_amount
	if kind == "berry":
		gain *= mutation.mult_value(EffectKeys.PLANT_RESTORE_MULT, 1.0)
	elif kind == "carcass":
		gain *= mutation.mult_value(EffectKeys.MEAT_RESTORE_MULT, 1.0)
		gain *= mutation.mult_value(EffectKeys.CARCASS_RESTORE_MULT, 1.0)
		if cooked:
			gain *= mutation.mult_value(EffectKeys.COOKED_CARCASS_RESTORE_MULT, 1.0)
		elif fresh_kill:
			gain *= mutation.mult_value(EffectKeys.FRESH_KILL_RESTORE_MULT, 1.0)
	hunger = max(0.0, hunger - gain)
	var energy_gain: float = 12.0 if kind == "berry" else 25.0
	energy = min(max_energy, energy + energy_gain)
	var self_poison := 0.0
	if kind == "carcass" and mutation.has_flag(EffectKeys.MEAT_CAUSES_SICKNESS):
		self_poison = 4.0
	return {
		"hunger_restored": gain,
		"hp_gain": 15.0 if kind == "carcass" else 5.0,
		"energy_gain": energy_gain,
		"self_poison": self_poison,
	}
