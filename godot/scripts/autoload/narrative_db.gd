extends Node

## Persistent narrative state: discovered clues, unlocked Ancestral Insights,
## and lineage memories. Host-authoritative; clients receive a sync from the
## server when they join and on every new discovery. State is saved to
## user://narrative.json so it survives game restarts.

const SAVE_PATH := "user://narrative.json"

## --- Static data ---
const CLUES := {
	"examine_giant": {
		"mystery_id": "dead_giant",
		"display_name": "Examine the Skeleton",
		"required_mutation_id": "",
		"prerequisite_clue_ids": [],
		"discovery_text": "These bones belonged to something far larger than any creature currently living here.",
		"insight_reward_id": "",
	},
	"smell_giant": {
		"mystery_id": "dead_giant",
		"display_name": "Scent the Remains",
		"required_mutation_id": "keen_smell",
		"prerequisite_clue_ids": ["examine_giant"],
		"discovery_text": "Several species fed here long after the creature died, but another unfamiliar scent remains deep within the bones.",
		"insight_reward_id": "",
	},
	"excavate_giant": {
		"mystery_id": "dead_giant",
		"display_name": "Excavate Beneath the Ribs",
		"required_mutation_id": "digging_claws",
		"prerequisite_clue_ids": ["examine_giant"],
		"discovery_text": "Something unusual was buried beneath the giant when it died.",
		"insight_reward_id": "",
	},
	"break_bone": {
		"mystery_id": "dead_giant",
		"display_name": "Break Open a Bone",
		"required_mutation_id": "jaws",
		"prerequisite_clue_ids": ["examine_giant"],
		"discovery_text": "The internal structure is unusually light and hollow despite the creature's enormous size.",
		"insight_reward_id": "hollow_skeleton",
	},
	"reach_skull": {
		"mystery_id": "dead_giant",
		"display_name": "Reach the Skull",
		"required_mutation_id": "climbing_claws",
		"prerequisite_clue_ids": ["examine_giant"],
		"discovery_text": "Deep marks in the skull were made while the creature was still alive. Something powerful attacked it before it died.",
		"insight_reward_id": "",
	},
}

const MYSTERIES := {
	"dead_giant": {
		"display_name": "The Dead Giant",
		"description": "A colossal skeleton lies in the Forest. What was it, and how did it die?",
		"completion_text": "The Firstborn was hollow-boned, massive, and mortally wounded. Something hunted it.",
		"clue_ids": ["examine_giant", "smell_giant", "excavate_giant", "break_bone", "reach_skull"],
	},
}

const INSIGHTS := {
	"hollow_skeleton": {
		"display_name": "Hollow Skeleton",
		"description": "Enormous creatures can be unexpectedly light inside. The lineage now knows hollow bones are possible.",
		"unlocked_mutation_ids": ["hollow_bones"],
	},
}

const CHAPTERS := {
	"hungry_pack": {
		"display_name": "The Hungry Pack",
		"description": "Razorcats are unusually numerous and aggressive. Prey is scarce.",
		"effect_text": "More Razorcats. Larger packs. More carcasses.",
	},
}

## --- Persistent state ---
var discovered_clues: Array = [] ## list of clue_ids
var unlocked_insights: Array = [] ## list of insight_ids
var completed_mysteries: Array = [] ## list of mystery_ids
var memories: Array = [] ## list of {event_type, generation, biome, world_seed, display_text, order}

var _order_counter: int = 0
var _loaded: bool = false

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	if text == "":
		return
	var data: Dictionary = JSON.parse_string(text)
	if data == null:
		return
	discovered_clues = data.get("discovered_clues", [])
	unlocked_insights = data.get("unlocked_insights", [])
	completed_mysteries = data.get("completed_mysteries", [])
	memories = data.get("memories", [])
	_order_counter = data.get("order_counter", 0)
	_loaded = true

func _save() -> void:
	var data := {
		"discovered_clues": discovered_clues,
		"unlocked_insights": unlocked_insights,
		"completed_mysteries": completed_mysteries,
		"memories": memories,
		"order_counter": _order_counter,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func serialize() -> Dictionary:
	return {
		"discovered_clues": discovered_clues.duplicate(),
		"unlocked_insights": unlocked_insights.duplicate(),
		"completed_mysteries": completed_mysteries.duplicate(),
		"memories": memories.duplicate(),
		"order_counter": _order_counter,
	}

func deserialize(data: Dictionary) -> void:
	discovered_clues = data.get("discovered_clues", [])
	unlocked_insights = data.get("unlocked_insights", [])
	completed_mysteries = data.get("completed_mysteries", [])
	memories = data.get("memories", [])
	_order_counter = data.get("order_counter", 0)

## --- Queries ---

func clue(id: String) -> Dictionary:
	return CLUES.get(id, {})

func mystery(id: String) -> Dictionary:
	return MYSTERIES.get(id, {})

func insight(id: String) -> Dictionary:
	return INSIGHTS.get(id, {})

func mystery_clue_count(id: String) -> int:
	var m := mystery(id)
	var clue_ids: Array = m.get("clue_ids", [])
	var count := 0
	for c in clue_ids:
		if c in discovered_clues:
			count += 1
	return count

func mystery_clue_total(id: String) -> int:
	return mystery(id).get("clue_ids", []).size()

## --- Discovery ---

## Returns true if this is a new discovery. The host calls this and then
## broadcasts the result to clients.
func discover_clue(clue_id: String, c: Creature = null) -> bool:
	if clue_id in discovered_clues:
		return false
	var data := clue(clue_id)
	if data.is_empty():
		return false
	var req: String = data.get("required_mutation_id", "")
	if req != "" and c != null and not c.mutation.has(req):
		return false
	for pre in data.get("prerequisite_clue_ids", []):
		if not pre in discovered_clues:
			return false
	discovered_clues.append(clue_id)

	var reward: String = data.get("insight_reward_id", "")
	if reward != "" and not reward in unlocked_insights:
		unlocked_insights.append(reward)
		add_memory("discovered_insight", c, "Unlocked Ancestral Insight: %s" % insight(reward).get("display_name", reward))

	var mid: String = data.get("mystery_id", "")
	if mid != "" and mystery_clue_count(mid) == mystery_clue_total(mid) and not mid in completed_mysteries:
		completed_mysteries.append(mid)
		add_memory("completed_mystery", c, "Mystery solved: %s" % mystery(mid).get("display_name", mid))
	else:
		add_memory("discovered_clue", c, "Discovered: %s" % data.get("display_name", clue_id))

	_save()
	return true

## --- Memories ---

func add_memory(event_type: String, c: Creature = null, custom_text: String = "") -> void:
	var generation: int = c.generation if c != null else 0
	var biome := ""
	var seed := 0
	_order_counter += 1
	var text := custom_text
	if text == "":
		text = _default_memory_text(event_type, c)
	var entry := {
		"event_type": event_type,
		"generation": generation,
		"biome": biome,
		"world_seed": seed,
		"display_text": text,
		"order": _order_counter,
	}
	memories.append(entry)
	# Keep only the last 30 so the save doesn't bloat.
	if memories.size() > 30:
		memories = memories.slice(-30)
	_save()

func _default_memory_text(event_type: String, c: Creature = null) -> String:
	match event_type:
		"first_mutation":
			return "Generation %d developed its first mutation." % [c.generation if c else 0]
		"first_reproduction":
			return "Generation %d successfully reproduced." % [c.generation if c else 0]
		"first_migration":
			return "Generation %d migrated to a new world." % [c.generation if c else 0]
		"first_apex_kill":
			return "Generation %d killed an apex predator." % [c.generation if c else 0]
		"survived_wildfire":
			return "Generation %d survived a major wildfire." % [c.generation if c else 0]
		"survived_drought":
			return "Generation %d survived a major drought." % [c.generation if c else 0]
		"killed_by_apex":
			return "Generation %d was killed by an apex predator." % [c.generation if c else 0]
		"killed_by_rival":
			return "Generation %d was killed by a rival." % [c.generation if c else 0]
		_:
			return "Generation %d experienced: %s." % [c.generation if c else 0, event_type]

## --- Draft helpers ---

## Returns the list of hidden mutation ids that are currently eligible for a
## creature, based on known insights and the mutations it already owns.
func eligible_hidden_mutations(c: Creature) -> Array:
	var out: Array = []
	for id in unlocked_insights:
		var data := insight(id)
		for mut in data.get("unlocked_mutation_ids", []):
			if not c.mutation.has(mut) and _meets_prerequisites(mut, c):
				out.append(mut)
	return out

func _meets_prerequisites(mutation_id: String, c: Creature) -> bool:
	# Hidden mutations have flexible biological prerequisites. Long-term this
	# should live in the mutation data; for v0.3 we special-case the first one.
	if mutation_id == "hollow_bones":
		return c.mutation.has("long_jumper") or c.mutation.has("climbing_claws")
	var m = MutationDB.get_mutation(mutation_id)
	if m == null:
		return false
	for req in m.requires:
		if not c.mutation.has(req):
			return false
	return true
