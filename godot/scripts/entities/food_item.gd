class_name FoodItem
extends Node2D

## Dynamic, server-authoritative food pickup. Built in code (no .tscn).

var entity_id: int = -1
var kind: String = "berry" ## berry or carcass
var amount: float = 20.0
var radius: float = 6.0
var cooked: bool = false
var fresh_kill: bool = false
var poisonous: bool = false
var color: Color = Color.WHITE

func configure(id: int, k: String, amt: float, r: float, c: Color) -> void:
	entity_id = id
	kind = k
	amount = amt
	radius = r
	color = c
	queue_redraw()

func _draw() -> void:
	var c := color
	if poisonous:
		c = Color(0.54, 0.29, 0.69)
	draw_circle(Vector2.ZERO, radius, c)
	if kind == "carcass":
		draw_arc(Vector2.ZERO, radius, 0, TAU, 12, Color(0.23, 0.16, 0.1), 2.0)
	if cooked:
		draw_arc(Vector2.ZERO, radius + 3, 0, TAU, 10, Color(1.0, 0.42, 0.0), 1.5)
