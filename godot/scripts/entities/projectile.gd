class_name Projectile
extends Node2D

## Spitter's ranged attack. Spawned once by the server and replicated to
## every peer the same way FoodItem/WorldObject are (spawn RPC + explicit
## despawn) - but unlike those, a projectile actually needs to move every
## frame. Rather than syncing position every tick, every peer just runs
## the same deterministic straight-line motion locally from the same
## initial velocity, so no per-frame network traffic is needed at all.
## Only the server does hit-detection (see World.gd) and tells everyone
## when to despawn it.

var entity_id: int = -1
var owner_id: int = -1
var kind: String = "venom_spit"
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 1.2
var radius: float = 6.0
var color: Color = Color(0.55, 0.85, 0.25)

func configure(id: int, owner: int, k: String, vel: Vector2, life: float) -> void:
	entity_id = id
	owner_id = owner
	kind = k
	velocity = vel
	lifetime = life
	match k:
		"acid_glob":
			color = Color(0.6, 0.8, 0.2)
			radius = 9.0
		_:
			color = Color(0.55, 0.85, 0.25)
			radius = 6.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	rotation = velocity.angle()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(color, 0.6))
