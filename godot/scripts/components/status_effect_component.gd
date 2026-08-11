class_name StatusEffectComponent
extends RefCounted

## Timed status effects. Ticks are applied server-side only (Creature only
## calls process() when multiplayer.is_server() or in a local/offline test).

var poison_time: float = 0.0
var poison_source_id: int = -1
var bleed_time: float = 0.0
var stun_time: float = 0.0
var fear_time: float = 0.0
var iframe_time: float = 0.0

var hidden: bool = false
var hidden_timer: float = 0.0

func apply_poison(duration: float, source_entity_id: int) -> void:
	poison_time = max(poison_time, duration)
	poison_source_id = source_entity_id

func apply_bleed(duration: float) -> void:
	bleed_time = max(bleed_time, duration)

func apply_stun(duration: float) -> void:
	stun_time = max(stun_time, duration)

func apply_fear(duration: float) -> void:
	fear_time = max(fear_time, duration)

func apply_iframe(duration: float) -> void:
	iframe_time = max(iframe_time, duration)

func is_stunned() -> bool:
	return stun_time > 0.0

## Advances all timers and returns the hp delta to apply this tick
## (negative = damage, positive = heal from parasitic venom). `owner_creature`
## must expose: mutation (MutationComponent), stats (StatsComponent).
func process(delta: float, owner_creature) -> float:
	var hp_delta := 0.0
	if bleed_time > 0.0:
		bleed_time -= delta
		hp_delta -= 2.0 * delta
	if poison_time > 0.0:
		poison_time -= delta
		var poison_immune: bool = owner_creature.mutation.has_flag(EffectKeys.POISON_IMMUNE)
		if not poison_immune:
			hp_delta -= 3.0 * delta
	if stun_time > 0.0:
		stun_time -= delta
	if fear_time > 0.0:
		fear_time -= delta
	if iframe_time > 0.0:
		iframe_time -= delta
	return hp_delta
