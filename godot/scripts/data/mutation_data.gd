class_name MutationData
extends Resource

## Data-driven description of a single mutation. Creatures never store
## per-mutation booleans - they store an Array[String] of mutation ids and
## everything else (stat deltas, tags, combat hooks) is looked up here.

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "" ## Offense / Defense / Movement / Diet / Senses / Control / Active
@export var family: String = "" ## "claws", "hide", "legs", "venom", "jaws", "diet", ""
@export var tier: int = 1
@export_multiline var description: String = ""
@export var effect_summary: String = ""
@export var tradeoff_summary: String = ""

## Mutation ids that must already be owned before this one can be drafted.
@export var requires: Array[String] = []

## Mutation ids that cannot coexist with this one. Tier-2+ specializations
## within the same family should exclude their siblings so evolution closes
## doors as it opens others.
@export var excludes: Array[String] = []

## Generic effect bag consumed by StatsComponent / CombatComponent /
## MovementComponent / HungerComponent. Keys are effect ids, values are
## numbers or bools. See EffectKeys for the recognized vocabulary.
@export var effects: Dictionary = {}

func _to_string() -> String:
	return "Mutation(%s)" % id
