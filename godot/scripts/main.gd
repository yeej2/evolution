extends Node

const WorldScene: PackedScene = preload("res://scenes/World.tscn")
const GameUIScript = preload("res://scripts/ui/game_ui.gd")

var world: World = null
var my_creature: Creature = null
var ui = null
var camera: Camera2D = null

var _charging_pounce := false
var _pounce_charge := 0.0
var _space_was_down := false
var _rmb_was_down := false

var _spectating := false
var _spectate_cam_pos := Vector2.ZERO
const SPECTATE_PAN_SPEED := 480.0

signal _world_ready
var _auto_wander := false
var _auto_attack := false

func _ready() -> void:
	ui = GameUIScript.new()
	add_child(ui)
	ui.host_pressed.connect(_on_host_pressed)
	ui.join_pressed.connect(_on_join_pressed)
	ui.lineage_chosen.connect(_on_lineage_chosen)
	ui.mutation_chosen.connect(_on_mutation_chosen)
	ui.migrate_pressed.connect(_on_migrate_pressed)
	ui.reproduce_chosen.connect(_on_reproduce_chosen)
	ui.restart_pressed.connect(_on_restart_pressed)
	NetworkManager.player_connected.connect(_on_peer_connected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	ui.show_menu()
	_maybe_run_cli_autopilot()

## Test-only hook so two headless Godot processes can prove out the network
## layer without a human clicking buttons: `--autohost=stalker` or
## `--autojoin=127.0.0.1:grazer`. Not used by the normal interactive flow.
func _maybe_run_cli_autopilot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autohost="):
			var lineage := arg.split("=")[1]
			var biome_id := "forest"
			for e in OS.get_cmdline_user_args():
				if e.begins_with("--biome="):
					biome_id = e.split("=")[1]
			_on_host_pressed(biome_id)
			_on_lineage_chosen(lineage)
			for e in OS.get_cmdline_user_args():
				if e.begins_with("--forceevent="):
					_force_event(e.split("=")[1])
				elif e == "--forcemigrate":
					_test_force_migrate()
				elif e == "--forcemigrate_remote":
					_test_force_migrate_remote()
				elif e == "--testspit":
					_test_spit()
				elif e == "--testcombo":
					_test_combo()
				elif e == "--testgrab":
					_test_grab()
		elif arg.begins_with("--autojoin="):
			# Supports both host:lineage (default port) and
			# host:port:lineage, matching the interactive Join field's
			# host:port parsing (needed for playit.gg-style tunnels) so
			# tests can actually target a non-default port.
			var parts := arg.split("=")[1].split(":")
			var lineage: String = parts[-1]
			var address: String = ":".join(parts.slice(0, parts.size() - 1))
			_on_join_pressed(address)
			await _world_ready
			_on_lineage_chosen(lineage)
			for e in OS.get_cmdline_user_args():
				if e == "--forcemigrate":
					_test_force_migrate()
	for arg in OS.get_cmdline_user_args():
		if arg == "--debugprint":
			var t := Timer.new()
			add_child(t)
			t.wait_time = 1.0
			t.timeout.connect(_debug_print_status)
			t.start()
		elif arg == "--autowander":
			_auto_wander = true
		elif arg == "--autoattack":
			_auto_attack = true

## Test-only: reproduce the reported "migrate button doesn't do anything"
## bug report by directly forcing checklist-eligibility and then invoking
## the exact same handler the button's pressed signal calls, so we're
## testing the real code path, not a guess about it.
func _test_force_migrate() -> void:
	# Hosting: my_creature IS the server-authoritative object, so forcing
	# fields locally is legitimate (same as _test_force_migrate_remote does
	# for a joined client). Joined client: forcing local fields would only
	# fool the client's own display, not the server's real copy - the
	# actual test there is whether --forcemigrate_remote's server-side
	# force correctly replicates down and the RPC path honors it.
	await get_tree().create_timer(35.0).timeout
	if my_creature and (NetworkManager.is_hosting or multiplayer.multiplayer_peer == null):
		my_creature.apex_killed = true
		my_creature.distance_traveled = 999999.0
	if my_creature:
		print("[test] pre-migrate can_migrate=%s hp=%s apex_killed=%s dist=%s" % [my_creature.can_migrate(), my_creature.stats.hp, my_creature.apex_killed, my_creature.distance_traveled])
	await get_tree().create_timer(0.5).timeout
	_on_migrate_pressed()
	await get_tree().create_timer(1.0).timeout
	print("[test] after migrate: gameover_visible=%s title=%s my_creature_null=%s" % [ui.gameover_panel.visible, ui.gameover_title.text if ui.gameover_panel.visible else "n/a", my_creature == null])

## Test-only, run on the HOST: forces the *other* (joined) player's
## server-authoritative checklist fields true, so the client-side migrate
## test below is exercising real replication + the server-side
## can_migrate() re-check in rpc_request_migrate, not just its own local
## mirror (which a client can't actually make the server trust).
func _test_force_migrate_remote() -> void:
	await get_tree().create_timer(30.0).timeout
	var found := false
	for c in world.creatures_by_id.values():
		if c.is_player and c != my_creature:
			found = true
			c.apex_killed = true
			c.distance_traveled = 999999.0
			print("[test] host forced remote entity=%d can_migrate=%s" % [c.entity_id, c.can_migrate()])
	if not found:
		print("[test] host found no remote player creature to force")

## Test-only: verify Spitter's full path (mutation grant -> fire -> real
## projectile -> hit detection -> poison/damage) without needing a human
## to draft the mutation and aim a mouse.
func _test_spit() -> void:
	await get_tree().create_timer(2.0).timeout
	if my_creature == null:
		return
	my_creature.add_mutation("venom_gland")
	my_creature.add_mutation("projectile_gland")
	# Aim directly at the nearest wildlife creature so a hit is
	# deterministic to verify, not left to chance.
	var target: Creature = null
	var best := INF
	for c in world.creatures_by_id.values():
		if c == my_creature or c.is_player:
			continue
		var d: float = my_creature.global_position.distance_to(c.global_position)
		if d < best:
			best = d
			target = c
	if target:
		my_creature.aim_angle = my_creature.global_position.direction_to(target.global_position).angle()
		print("[test] target=%s hp_before=%.1f dist=%.1f" % [target.species_id, target.stats.hp, best])
	print("[test] spitter mutations=%s ranged=%s" % [my_creature.mutation.owned, my_creature.mutation.has_flag(EffectKeys.RANGED_ATTACK)])
	_send_fire()
	await get_tree().create_timer(1.5).timeout
	print("[test] projectiles_by_id after fire+settle: %s" % [world.projectiles_by_id.keys()])
	if target and is_instance_valid(target):
		print("[test] target hp_after=%.1f poisoned=%s" % [target.stats.hp, target.status.poison_time > 0.0])

## Test-only: verify Predatory Talons' combo stacking by biting the same
## nearby target three times in a row and confirming increasing damage.
func _test_combo() -> void:
	await get_tree().create_timer(2.0).timeout
	if my_creature == null:
		return
	my_creature.add_mutation("rending_claws")
	my_creature.add_mutation("predatory_talons")
	var target: Creature = null
	var best := INF
	for c in world.creatures_by_id.values():
		if c == my_creature or c.is_player:
			continue
		var d: float = my_creature.global_position.distance_to(c.global_position)
		if d < best:
			best = d
			target = c
	if target == null:
		print("[test] no target found for combo test")
		return
	my_creature.global_position = target.global_position - Vector2(target.stats.radius + my_creature.stats.radius, 0)
	print("[test] combo target=%s hp_before=%.1f" % [target.species_id, target.stats.hp])
	for i in range(3):
		world.server_resolve_bite(my_creature, target)
		print("[test] hit %d: combo_count=%d target_hp=%.1f" % [i, my_creature.combo_count, target.stats.hp])
		await get_tree().create_timer(0.3).timeout

## Test-only: verify Crushing Grip's full path - grab, crush (damage over
## repeated calls), drag (position follows grabber), and throw (knockback
## + damage + release).
func _test_grab() -> void:
	await get_tree().create_timer(2.0).timeout
	if my_creature == null:
		return
	my_creature.add_mutation("grasping_claws")
	my_creature.add_mutation("crushing_grip")
	var target: Creature = null
	var best := INF
	for c in world.creatures_by_id.values():
		if c == my_creature or c.is_player:
			continue
		var d: float = my_creature.global_position.distance_to(c.global_position)
		if d < best:
			best = d
			target = c
	if target == null:
		print("[test] no target found for grab test")
		return
	my_creature.global_position = target.global_position - Vector2(target.stats.radius + my_creature.stats.radius - 5.0, 0)
	print("[test] grab target=%s hp_before=%.1f" % [target.species_id, target.stats.hp])
	_send_grab()
	await get_tree().create_timer(0.3).timeout
	print("[test] after grab: grab_target_id=%d target.grabbed_by_id=%d" % [my_creature.grab_target_id, target.grabbed_by_id])
	_send_grab() # crush
	await get_tree().create_timer(0.3).timeout
	print("[test] after crush: target_hp=%.1f" % target.stats.hp)
	my_creature.aim_angle = 0.0
	var pos_before := target.global_position
	_send_throw()
	await get_tree().create_timer(0.5).timeout
	print("[test] after throw: target_hp=%.1f moved=%.1f grab_target_id=%d target.grabbed_by_id=%d" % [target.stats.hp, pos_before.distance_to(target.global_position), my_creature.grab_target_id, target.grabbed_by_id])

## Test-only: `--forceevent=predator_surge` skips the random wait and starts
## an event immediately, since the natural trigger chance is ~0.3%/sec (mean
## wait of several minutes) which is too slow to verify interactively.
func _force_event(event_id: String) -> void:
	var ed: WorldEventData = EventDB.get_event(event_id)
	if ed == null:
		return
	world.current_event_id = event_id
	world.event_timer = ed.duration
	WorldEventManager.start_event(world, event_id)
	world.event_state_changed.emit(event_id, "active")

func _debug_print_status() -> void:
	if world == null:
		print("[debug] no world yet")
		return
	var alive := my_creature != null and is_instance_valid(my_creature)
	print("[debug] t=%.1f creatures=%d food=%d my_creature=%s" % [
		world.day_time, world.creatures_by_id.size(), world.food_by_id.size(),
		("hp=%.1f pos=%s mut=%s" % [my_creature.stats.hp, my_creature.global_position, my_creature.mutation.owned]) if alive else "none"
	])
	for c in world.creatures_by_id.values():
		if not c.is_player:
			print("   wildlife entity=%d species=%s pos=%s hp=%.1f/%.1f" % [c.entity_id, c.species_id, c.global_position, c.stats.hp, c.stats.max_hp])

# ------------------------------------------------------------------
# Connection flow
# ------------------------------------------------------------------

func _on_host_pressed(biome_id: String = "forest") -> void:
	var port := NetworkManager.PORT
	for e in OS.get_cmdline_user_args():
		if e.begins_with("--port="):
			port = int(e.split("=")[1])
	var err := NetworkManager.host_game(port)
	if err != OK:
		ui.show_message("Failed to host (error %s)." % err)
		return
	_spawn_world()
	world.host_start(-1, biome_id)
	ui.show_lineage_select()

func _on_join_pressed(address: String) -> void:
	# Tunneling services (playit.gg, port-forwarded routers, etc.) very
	# commonly expose a public port that differs from NetworkManager.PORT -
	# the box needs to accept "host:port", not just a bare host that always
	# connects on the default port regardless of what was typed.
	var host := address if address != "" else "127.0.0.1"
	var port := NetworkManager.PORT
	var sep := host.rfind(":")
	if sep != -1:
		var maybe_port := host.substr(sep + 1)
		if maybe_port.is_valid_int():
			port = int(maybe_port)
			host = host.substr(0, sep)
	var err := NetworkManager.join_game(host, port)
	if err != OK:
		ui.show_message("Failed to join (error %s)." % err)
		return
	ui.show_message("Connecting to %s:%d..." % [host, port])
	multiplayer.connected_to_server.connect(_on_connected_ok, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connect_failed, CONNECT_ONE_SHOT)

func _on_connected_ok() -> void:
	_spawn_world()
	ui.show_lineage_select()
	_world_ready.emit()

func _on_connect_failed() -> void:
	ui.show_message("Connection failed.")

func _on_server_disconnected() -> void:
	ui.show_message("Disconnected from host.")

func _on_peer_connected(_peer_id: int) -> void:
	pass # World.gd handles authoritative catch-up itself (see _on_peer_connected_send_catchup).

func _spawn_world() -> void:
	world = WorldScene.instantiate()
	add_child(world)
	world.player_died.connect(_on_player_died)
	world.mutation_draft_offered.connect(_on_mutation_draft_offered)
	world.event_state_changed.connect(_on_event_state_changed)
	world.local_player_ready.connect(_on_local_player_ready)
	world.hud_refresh.connect(_on_hud_refresh)
	world.migrate_rejected.connect(func(): ui.show_message("Can't migrate yet - checklist not actually met server-side."))
	camera = Camera2D.new()
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)
	camera.make_current()

# ------------------------------------------------------------------
# Player lifecycle
# ------------------------------------------------------------------

func _on_lineage_chosen(lineage_id: String) -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.local_join(lineage_id)
	else:
		world.rpc_request_join.rpc_id(1, lineage_id)
	ui.show_hud()

func _on_local_player_ready(c: Creature) -> void:
	my_creature = c
	_spectating = false

func _on_player_died(entity_id: int) -> void:
	if my_creature and is_instance_valid(my_creature) and my_creature.entity_id == entity_id:
		var won := my_creature.can_migrate()
		ui.show_game_over(won, my_creature)
		# Otherwise the camera would just freeze at the death spot forever -
		# let the dead player look around the still-running world instead.
		_spectate_cam_pos = my_creature.global_position
		_spectating = true
		# The server despawns/queue_frees this creature right after emitting
		# player_died, so drop our reference now - otherwise _physics_process
		# keeps calling methods on a freed instance every frame afterward.
		my_creature = null

func _on_mutation_draft_offered(choices: Array) -> void:
	ui.show_mutation_draft(choices)

func _on_mutation_chosen(mutation_id: String) -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		my_creature.add_mutation(mutation_id)
	else:
		world.rpc_choose_mutation.rpc_id(1, mutation_id)
	ui.hide_mutation_draft()

func _on_migrate_pressed() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		var won := my_creature.can_migrate()
		ui.show_game_over(won, my_creature)
		_spectate_cam_pos = my_creature.global_position
		_spectating = true
		my_creature = null
	else:
		world.rpc_request_migrate.rpc_id(1)

func _on_reproduce_chosen(mutation_id: String) -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_reproduce(mutation_id)
	else:
		world.rpc_request_reproduce.rpc_id(1, mutation_id)
	ui.show_hud()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_event_state_changed(event_id: String, phase: String) -> void:
	ui.show_event_banner(event_id, phase)

func _on_hud_refresh() -> void:
	if my_creature and is_instance_valid(my_creature):
		ui.update_hud(my_creature, world)

# ------------------------------------------------------------------
# Local input -> server RPCs
# ------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _spectating:
		var pan := Vector2.ZERO
		if Input.is_action_pressed("move_right"):
			pan.x += 1
		if Input.is_action_pressed("move_left"):
			pan.x -= 1
		if Input.is_action_pressed("move_down"):
			pan.y += 1
		if Input.is_action_pressed("move_up"):
			pan.y -= 1
		_spectate_cam_pos += pan.normalized() * SPECTATE_PAN_SPEED * _delta if pan.length() > 0.05 else Vector2.ZERO
		if camera:
			camera.global_position = _spectate_cam_pos
		return
	if my_creature == null or not is_instance_valid(my_creature) or not world:
		return
	if camera:
		camera.global_position = my_creature.global_position
	# The host is authority for its own creature and never receives its own
	# rpc_snapshot broadcast (it's call_remote), so the HUD has to read local
	# state directly rather than waiting on World's hud_refresh signal.
	ui.update_hud(my_creature, world)

	var move := Vector2.ZERO
	if _auto_wander:
		move = Vector2.RIGHT
	else:
		if Input.is_action_pressed("move_right"):
			move.x += 1
		if Input.is_action_pressed("move_left"):
			move.x -= 1
		if Input.is_action_pressed("move_down"):
			move.y += 1
		if Input.is_action_pressed("move_up"):
			move.y -= 1
	var aim := 0.0 if _auto_wander else (get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2.0).angle()
	var sprint := Input.is_action_pressed("sprint")

	_send_move(move, aim, sprint)

	# Client-side prediction: the server is still authoritative (its
	# resolved position comes back via rpc_snapshot and gently reconciles
	# this), but without this the client's own creature only appears to
	# move after a full network round trip, which reads as input lag.
	if not NetworkManager.is_hosting and multiplayer.multiplayer_peer != null:
		my_creature.move_input = move
		my_creature.aim_angle = aim
		my_creature.sprint_held = sprint
		my_creature._process_player_movement(_delta)
		# The server clamps every creature to WORLD_SIZE in its own tick,
		# but that's a no-op for a non-host client's *own* creature - it's
		# predicted locally here specifically so server corrections don't
		# overwrite it, so nothing was ever pulling it back once it walked
		# past the edge. Same clamp, applied locally too.
		world._clamp_to_world(my_creature)

	if _auto_wander and int(Engine.get_physics_frames()) % 30 == 0:
		_send_eat()
	if _auto_attack and int(Engine.get_physics_frames()) % 20 == 0:
		_send_bite()

	# Biology changes what the mouse buttons do: Projectile Gland (Spitter)
	# swaps Space from bite/charge to "fire while aiming" the moment RMB is
	# held; Crushing Grip (Behemoth) swaps Space into grab/crush and RMB
	# into throw. Neither touches Space's normal meaning for anyone who
	# hasn't evolved that mutation, regardless of starting lineage.
	var has_ranged: bool = my_creature.mutation.has_flag(EffectKeys.RANGED_ATTACK)
	var has_grab: bool = my_creature.mutation.has_flag(EffectKeys.GRAB_ATTACK)
	my_creature.aiming = has_ranged and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	var space_down := Input.is_action_pressed("bite_pounce")
	var rmb_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if has_grab:
		if space_down and not _space_was_down:
			_send_grab()
		if rmb_down and not _rmb_was_down and my_creature.grab_target_id != -1:
			_send_throw()
		_charging_pounce = false
		_pounce_charge = 0.0
	elif has_ranged and my_creature.aiming:
		if space_down and not _space_was_down:
			_send_fire()
		_charging_pounce = false
		_pounce_charge = 0.0
	else:
		if space_down and not _space_was_down:
			_charging_pounce = true
			_pounce_charge = 0.0
		if space_down and _charging_pounce:
			_pounce_charge = clampf(_pounce_charge + _delta_charge(), 0.0, 1.0)
		if not space_down and _space_was_down:
			# A human "tap" routinely holds a key for 80-150ms, so the commit
			# threshold has to be well above that or every bite attempt turns
			# into an unintended (and unresolved-looking) pounce.
			if _charging_pounce and _pounce_charge > 0.2:
				_send_pounce(_pounce_charge)
			else:
				_send_bite()
			_charging_pounce = false
			_pounce_charge = 0.0
	_space_was_down = space_down
	_rmb_was_down = rmb_down
	ui.update_charge_bar(_charging_pounce, _pounce_charge)

	if Input.is_action_just_pressed("eat"):
		_send_eat()

	if Input.is_action_just_pressed("dodge"):
		_send_special()

func _delta_charge() -> float:
	return get_physics_process_delta_time() / 0.9

func _send_move(move: Vector2, aim: float, sprint: bool) -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_submit_move(move, aim, sprint)
	else:
		world.rpc_submit_move.rpc_id(1, move, aim, sprint)

func _send_bite() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_bite()
	else:
		world.rpc_request_bite.rpc_id(1)

func _send_pounce(charge: float) -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_pounce(charge)
	else:
		world.rpc_request_pounce.rpc_id(1, charge)

func _send_eat() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_eat()
	else:
		world.rpc_request_eat.rpc_id(1)

func _send_special() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_special()
	else:
		world.rpc_request_special.rpc_id(1)

func _send_fire() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_fire()
	else:
		world.rpc_request_fire.rpc_id(1)

func _send_grab() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_grab()
	else:
		world.rpc_request_grab.rpc_id(1)

func _send_throw() -> void:
	if NetworkManager.is_hosting or multiplayer.multiplayer_peer == null:
		world.rpc_request_throw()
	else:
		world.rpc_request_throw.rpc_id(1)
