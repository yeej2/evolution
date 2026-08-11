extends Node
## Autoload. Small bag of run-wide state that isn't owned by any single
## scene (current world reference, RNG seed, generation number). The server
## is authoritative for all of it; it's replicated to clients as plain RPCs
## by WorldEventManager / SpawnManager rather than per-frame sync, since it
## changes rarely.

var rng := RandomNumberGenerator.new()
var generation: int = 1
var world: Node = null ## set by World.gd on _ready()

func _ready() -> void:
	rng.randomize()

func register_world(w: Node) -> void:
	world = w
