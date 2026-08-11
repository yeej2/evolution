class_name SpeciesData
extends Resource

## Data-driven description of a non-player creature species.

@export var id: String = ""
@export var display_name: String = ""
@export_enum("prey", "predator", "apex") var creature_type: String = "prey"
@export var radius: float = 12.0
@export var base_hp: float = 40.0
@export var base_speed: float = 100.0
@export var mass: float = 0.8
@export var bite_damage: float = 8.0
@export var sense_range: float = 180.0
@export var color: Color = Color.WHITE

## Body-zone / combat-geometry properties.
@export var frontal_armor: float = 0.0 ## 0..1, fraction of damage reduced when hit from the front.
@export var frontal_retaliation: bool = false ## Deal a small counter-hit when hit frontally.
@export var rear_damage_bonus: float = 0.0 ## Extra damage fraction taken when hit from the rear.

## Behavior flags read by ai/species_behavior.gd.
@export var herd: bool = false
@export var territorial: bool = false
@export var aquatic: bool = false
@export var water_tether: bool = false
@export var nocturnal: bool = false
@export var scavenger: bool = false
@export var bush_eater: bool = false
@export var pack: bool = false ## courage scales with nearby same-species allies - see wildlife_ai.gd

func _to_string() -> String:
	return "Species(%s)" % id
