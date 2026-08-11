extends Node
## Autoload. Owns the ENet connection and entity-id allocation.
## Server = authority for all simulation. Clients only send input and render.

const PORT := 8871
const MAX_PLAYERS := 4

var is_hosting: bool = false
var next_entity_id: int = 1

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_hosting = true
	return OK

func join_game(address: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_hosting = false
	return OK

func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func allocate_entity_id() -> int:
	# Server-only. Guarantees unique ids for creatures/food/objects that need
	# to be addressed over the network.
	var id := next_entity_id
	next_entity_id += 1
	return id

func _on_peer_connected(peer_id: int) -> void:
	player_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	player_disconnected.emit(peer_id)

func _on_connected_ok() -> void:
	pass

func _on_connected_fail() -> void:
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()
