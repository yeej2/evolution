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

func _to_string() -> String:
	return "Lineage(%s)" % id
