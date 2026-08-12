class_name WorldObject
extends Node2D

## Static-ish map feature: tree, rock, water, log, nest, exit. Built entirely
## in code (no .tscn) since its shape is simple and fully data-driven by
## `kind`. Positions come from WorldGenerator using a shared seed so every
## peer produces an identical map without any network traffic; only later
## *mutations* to an object (burned, opened) are replicated by object_id.

var object_id: int = -1
var kind: String = "tree" ## tree, rock, water, log, nest, exit
var radius: float = 20.0
var burned: bool = false
var open: bool = false
var broken: bool = false ## rocks only - see set_broken()/World._try_break_rock()
var color: Color = Color.WHITE

## Rock-only, server-authoritative durability. Never replicated tick-by-tick
## (clients don't need to see partial cracking) - only the final "broken"
## flip goes out, the same way "burned"/"open" already do.
var rock_hp: float = 30.0

var _body: StaticBody2D = null

## Logs sit on their own collision layer, separate from trees/rocks, so a
## creature can selectively ignore JUST logs (Climbing Claws) without also
## ignoring rocks/trees - see Creature._update_collision_shape().
const LAYER_TREE_ROCK := 4
const LAYER_LOG := 16

func _ready() -> void:
	_rebuild_collision()
	queue_redraw()

func configure(id: int, k: String, r: float, c: Color) -> void:
	object_id = id
	kind = k
	radius = r
	color = c
	if is_inside_tree():
		_rebuild_collision()
	queue_redraw()

func is_solid() -> bool:
	if burned:
		return false
	if kind == "log" and open:
		return false
	if kind == "rock" and broken:
		return false
	return kind in ["tree", "rock", "log"]

func _rebuild_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not is_solid():
		return
	_body = StaticBody2D.new()
	_body.collision_layer = LAYER_LOG if kind == "log" else LAYER_TREE_ROCK
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	_body.add_child(shape)
	add_child(_body)

func set_burned(value: bool) -> void:
	burned = value
	_rebuild_collision()
	queue_redraw()

func set_open(value: bool) -> void:
	open = value
	_rebuild_collision()
	queue_redraw()

func set_broken(value: bool) -> void:
	broken = value
	_rebuild_collision()
	queue_redraw()

func _draw() -> void:
	if burned and kind in ["tree", "nest"]:
		return
	match kind:
		"tree":
			draw_circle(Vector2.ZERO, radius, Color(0.29, 0.23, 0.13))
			draw_circle(Vector2(0, -6), radius * 0.9, color)
		"rock":
			if broken:
				draw_circle(Vector2.ZERO, radius, Color(color, 0.3))
			else:
				draw_circle(Vector2.ZERO, radius, color)
				if rock_hp < 30.0:
					# Cracking feedback while a Jaws creature is chewing
					# through it, not just an instant pop from full to gone.
					draw_circle(Vector2.ZERO, radius * 0.5, Color(0.1, 0.1, 0.1, clampf(1.0 - rock_hp / 30.0, 0.0, 0.7)))
		"water":
			draw_circle(Vector2.ZERO, radius, color)
		"log":
			var c := Color(0.3, 0.24, 0.13) if not open else Color(0.3, 0.24, 0.13, 0.35)
			draw_circle(Vector2.ZERO, radius, c)
		"nest":
			draw_circle(Vector2.ZERO, radius, Color(0.55, 0.42, 0.29))
		"burrow":
			draw_circle(Vector2.ZERO, radius, Color(0.15, 0.11, 0.08))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 16, Color(0.35, 0.28, 0.18), 2.0)
		"exit":
			draw_circle(Vector2.ZERO, radius, color)
			draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 24, color, 3.0)
		"dead_giant":
			# A Firstborn skeleton - a few large, pale shapes so it reads as
			# enormous bones even without dedicated art.
			var bone := Color(0.78, 0.74, 0.66)
			draw_circle(Vector2.ZERO, radius * 0.85, bone)
			draw_circle(Vector2(-radius * 0.6, radius * 0.3), radius * 0.35, Color(bone, 0.7))
			draw_circle(Vector2(radius * 0.6, -radius * 0.2), radius * 0.28, Color(bone, 0.7))
			draw_circle(Vector2.ZERO, radius * 0.12, Color(0.2, 0.2, 0.2))
		"giant_tissue":
			# Decayed remains - the smell clue.
			draw_circle(Vector2.ZERO, radius, Color(0.55, 0.45, 0.35, 0.8))
			draw_circle(Vector2.ZERO, radius * 0.4, Color(0.35, 0.28, 0.22, 0.9))
		"giant_excavation":
			# A dug-out patch beneath the ribs.
			draw_circle(Vector2.ZERO, radius, Color(0.45, 0.4, 0.3))
			draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 12, Color(0.25, 0.22, 0.15, 0.7), 2.0)
		"giant_femur":
			# A cracked long bone - the Jaws clue.
			draw_circle(Vector2.ZERO, radius, Color(0.8, 0.75, 0.65))
			draw_line(Vector2(-radius * 0.6, radius * 0.1), Vector2(radius * 0.5, -radius * 0.2), Color(0.25, 0.22, 0.18), 2.0)
		"giant_skull":
			# The elevated skull - the Climbing clue.
			draw_circle(Vector2.ZERO, radius, Color(0.82, 0.78, 0.7))
			draw_circle(Vector2(-radius * 0.25, -radius * 0.1), radius * 0.2, Color(0.15, 0.15, 0.15))
			draw_circle(Vector2(radius * 0.25, -radius * 0.1), radius * 0.2, Color(0.15, 0.15, 0.15))
