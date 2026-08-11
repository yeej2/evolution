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
var color: Color = Color.WHITE

var _body: StaticBody2D = null

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
	return kind in ["tree", "rock", "log"]

func _rebuild_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not is_solid():
		return
	_body = StaticBody2D.new()
	_body.collision_layer = 4
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

func _draw() -> void:
	if burned and kind in ["tree", "nest"]:
		return
	match kind:
		"tree":
			draw_circle(Vector2.ZERO, radius, Color(0.29, 0.23, 0.13))
			draw_circle(Vector2(0, -6), radius * 0.9, color)
		"rock":
			draw_circle(Vector2.ZERO, radius, color)
		"water":
			draw_circle(Vector2.ZERO, radius, color)
		"log":
			var c := Color(0.3, 0.24, 0.13) if not open else Color(0.3, 0.24, 0.13, 0.35)
			draw_circle(Vector2.ZERO, radius, c)
		"nest":
			draw_circle(Vector2.ZERO, radius, Color(0.55, 0.42, 0.29))
		"exit":
			draw_circle(Vector2.ZERO, radius, color)
			draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 24, color, 3.0)
