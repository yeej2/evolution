class_name MutationComponent
extends RefCounted

## The entire "genome" of a creature is this one array of ids. This is the
## thing that gets replicated over the network - never a pile of booleans.

var owned: Array[String] = []

func has(id: String) -> bool:
	return owned.has(id)

func add(id: String) -> bool:
	if owned.has(id) or id == "":
		return false
	owned.append(id)
	return true

## Returns up to `count` draftable mutation ids, weighted by `weights`
## (mutation_id -> multiplier, missing = 1.0), restricted to `family_filter`
## if given (used for the "specialize" tier-2 choice screens).
func roll_choices(count: int, weights: Dictionary, rng: RandomNumberGenerator, family_filter: String = "") -> Array:
	var pool := MutationDB.available_for(owned, family_filter)
	var picks: Array = []
	while picks.size() < count and pool.size() > 0:
		var total := 0.0
		for id in pool:
			total += float(weights.get(id, 1.0))
		var w := rng.randf() * total
		var chosen_index := 0
		for i in range(pool.size()):
			w -= float(weights.get(pool[i], 1.0))
			if w <= 0.0:
				chosen_index = i
				break
		picks.append(pool[chosen_index])
		pool.remove_at(chosen_index)
	return picks

func effects_list() -> Array:
	var out: Array = []
	for id in owned:
		var m: MutationData = MutationDB.get_mutation(id)
		if m:
			out.append(m.effects)
	return out

func has_flag(key: String) -> bool:
	for effects in effects_list():
		if effects.get(key, false) == true:
			return true
	return false

## Largest value of `key` across owned mutations (durations, etc).
func max_value(key: String, default_value: float = 0.0) -> float:
	var best := default_value
	for effects in effects_list():
		if effects.has(key):
			best = max(best, float(effects[key]))
	return best

## Product of `key` across owned mutations (multipliers).
func mult_value(key: String, default_value: float = 1.0) -> float:
	var result := default_value
	for effects in effects_list():
		if effects.has(key):
			result *= float(effects[key])
	return result

func display_names() -> Array:
	var out: Array = []
	for id in owned:
		var m: MutationData = MutationDB.get_mutation(id)
		out.append(m.display_name if m else id)
	return out
