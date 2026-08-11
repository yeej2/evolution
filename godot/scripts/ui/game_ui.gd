extends CanvasLayer

## All UI for the vertical slice, built in code rather than a hand-authored
## .tscn (there just isn't enough of it yet to warrant editor layout work).

signal host_pressed(biome_id: String)
signal join_pressed(address: String)
signal lineage_chosen(lineage_id: String)
signal mutation_chosen(mutation_id: String)
signal migrate_pressed
signal reproduce_chosen(mutation_id: String)
signal restart_pressed

var menu_panel: Control
var lineage_panel: Control
var hud_panel: Control
var draft_panel: Control
var gameover_panel: Control
var message_label: Label
var event_label: Label
var hud_labels: Dictionary = {}
var migrate_button: Button
var reproduce_button: Button
var near_exit := false

var draft_row: HBoxContainer
var gameover_title: Label
var gameover_stats: Label
var gameover_repro_row: HBoxContainer

func _ready() -> void:
	layer = 10
	_build_menu()
	_build_lineage_select()
	_build_hud()
	_build_draft()
	_build_gameover()

func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true

func show_menu() -> void:
	_hide_all()
	menu_panel.visible = true

func show_lineage_select() -> void:
	_hide_all()
	lineage_panel.visible = true

func show_hud() -> void:
	_hide_all()
	hud_panel.visible = true

func show_mutation_draft(choices: Array) -> void:
	for child in draft_row.get_children():
		child.queue_free()
	for id in choices:
		var m: MutationData = MutationDB.get_mutation(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 100)
		b.text = "%s\n\n%s\n(%s)" % [m.display_name, m.effect_summary, m.tradeoff_summary]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.pressed.connect(func(): mutation_chosen.emit(id))
		draft_row.add_child(b)
	draft_panel.visible = true

func hide_mutation_draft() -> void:
	draft_panel.visible = false

func show_game_over(won: bool, c: Creature) -> void:
	_hide_all()
	gameover_title.text = "You Survived!" if won else "You Died"
	var names := c.mutation.display_names()
	gameover_stats.text = "Generation %d\nMass: %.1f  Speed: %.0f\nMutations: %s" % [c.generation, c.stats.mass, c.stats.speed, ", ".join(names) if names.size() > 0 else "none"]

	for child in gameover_repro_row.get_children():
		child.queue_free()
	if names.size() > 0:
		for id in c.mutation.owned:
			var m: MutationData = MutationDB.get_mutation(id)
			var b := Button.new()
			b.text = "Reproduce with %s" % m.display_name
			b.pressed.connect(func(): reproduce_chosen.emit(id))
			gameover_repro_row.add_child(b)
	else:
		var b := Button.new()
		b.text = "Reproduce (no traits to pass on)"
		b.pressed.connect(func(): reproduce_chosen.emit(""))
		gameover_repro_row.add_child(b)

	gameover_panel.visible = true

const PENDING_MESSAGES := {
	"wildfire": "You smell smoke on the wind...",
	"predator_surge": "You hear distant howls closing in...",
}

func show_event_banner(event_id: String, phase: String) -> void:
	if phase == "pending":
		event_label.text = PENDING_MESSAGES.get(event_id, "Something is changing...")
	elif phase == "active":
		var ed: WorldEventData = EventDB.get_event(event_id)
		event_label.text = "EVENT: %s" % ed.display_name
	event_label.visible = true
	get_tree().create_timer(4.0).timeout.connect(func(): event_label.visible = false)

func update_hud(c: Creature, world: World) -> void:
	hud_labels["stats"].text = "Gen %d  Mass %.1f  Speed %.0f" % [c.generation, c.stats.mass, c.stats.speed]
	hud_labels["hp"].text = "HP: %d / %d" % [int(c.stats.hp), int(c.stats.max_hp)]
	hud_labels["hunger"].text = "Hunger: %d%%   Energy: %d%%" % [int(c.hunger.hunger), int(c.hunger.energy)]
	var names := c.mutation.display_names()
	hud_labels["mutations"].text = "Mutations: %s" % (", ".join(names) if names.size() > 0 else "none")
	var checklist := c.migration_checklist()
	var parts: Array = []
	for item in checklist:
		parts.append("%s %s" % [item["label"], "OK" if item["done"] else "x"])
	hud_labels["migration"].text = "Migrate via any one: %s" % " | ".join(parts)

	near_exit = false
	for o in world.objects_by_id.values():
		if o.kind == "exit" and c.global_position.distance_to(o.global_position) < c.stats.radius + o.radius + 10.0:
			near_exit = true
			break
	migrate_button.visible = near_exit and c.can_migrate()

# ------------------------------------------------------------------
# Building
# ------------------------------------------------------------------

func _hide_all() -> void:
	menu_panel.visible = false
	lineage_panel.visible = false
	hud_panel.visible = false
	gameover_panel.visible = false
	message_label.visible = false

func _panel(anchor_center: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	add_child(p)
	if anchor_center:
		# Centering has to happen AFTER this panel's children (title, button
		# rows, etc.) are added - set_anchors_preset(CENTER) captures the
		# panel's *current* minimum size to compute its centered offsets,
		# and at this point (called at the top of each _build_*()) it has no
		# children yet, so it centers a zero-size box. Every panel then grew
		# to fit its real content while keeping those stale zero-size
		# offsets, leaving it pinned near the top-left corner instead of
		# actually centered - which is also why it visually collided with
		# the HUD (also top-left) and made panels' own titles overlap their
		# first row of buttons. Deferring one frame lets content get added
		# first so centering is computed from the real size.
		p.set_anchors_preset.call_deferred(Control.PRESET_CENTER)
	else:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
	return p

func _build_menu() -> void:
	menu_panel = _panel()
	var v := VBoxContainer.new()
	menu_panel.add_child(v)
	var title := Label.new()
	title.text = "EVOLUTION\nMultiplayer Vertical Slice 0.1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var host_row := HBoxContainer.new()
	v.add_child(host_row)
	var biome_select := OptionButton.new()
	biome_select.add_item("Forest", 0)
	biome_select.add_item("Wetlands", 1)
	biome_select.add_item("Highlands", 2)
	biome_select.set_meta("ids", ["forest", "wetlands", "highlands"])
	biome_select.selected = 0
	host_row.add_child(biome_select)
	var host_btn := Button.new()
	host_btn.text = "Host"
	host_btn.pressed.connect(func(): host_pressed.emit(biome_select.get_meta("ids")[biome_select.selected]))
	host_row.add_child(host_btn)
	var join_row := HBoxContainer.new()
	v.add_child(join_row)
	var address_edit := LineEdit.new()
	address_edit.placeholder_text = "127.0.0.1 or host:port"
	address_edit.custom_minimum_size = Vector2(200, 0)
	join_row.add_child(address_edit)
	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(func(): join_pressed.emit(address_edit.text))
	join_row.add_child(join_btn)
	message_label = Label.new()
	message_label.visible = false
	v.add_child(message_label)
	menu_panel.visible = false

func _build_lineage_select() -> void:
	lineage_panel = _panel()
	var v := VBoxContainer.new()
	lineage_panel.add_child(v)
	var title := Label.new()
	title.text = "Choose a lineage"
	v.add_child(title)
	var row := HBoxContainer.new()
	v.add_child(row)
	for id in LineageDB.all_ids():
		var l: LineageData = LineageDB.get_lineage(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 90)
		b.text = "%s\n\n%s" % [l.display_name, l.bonus_description]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.pressed.connect(func(): lineage_chosen.emit(id))
		row.add_child(b)
	lineage_panel.visible = false

func _build_hud() -> void:
	hud_panel = PanelContainer.new()
	add_child(hud_panel)
	hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_panel.position = Vector2(16, 16)
	hud_panel.custom_minimum_size = Vector2(360, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.05, 0.75)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	hud_panel.add_theme_stylebox_override("panel", style)

	var v := VBoxContainer.new()
	hud_panel.add_child(v)
	var key_order := ["stats", "hp", "hunger", "mutations", "migration"]
	for key in key_order:
		var lbl := Label.new()
		lbl.text = ""
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(lbl)
		hud_labels[key] = lbl
	hud_labels["hp"].add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	hud_labels["migration"].add_theme_font_size_override("font_size", 13)
	hud_labels["migration"].add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))

	event_label = Label.new()
	event_label.visible = false
	event_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	event_label.position.y = 10
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 22)
	event_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	event_label.add_theme_constant_override("outline_size", 4)
	event_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_child(event_label)

	migrate_button = Button.new()
	migrate_button.text = "Migrate (win the run)"
	migrate_button.visible = false
	migrate_button.custom_minimum_size = Vector2(0, 44)
	migrate_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	migrate_button.position.y -= 54
	migrate_button.pressed.connect(func(): migrate_pressed.emit())
	add_child(migrate_button)

	hud_panel.visible = false

func _build_draft() -> void:
	draft_panel = _panel()
	var v := VBoxContainer.new()
	draft_panel.add_child(v)
	var title := Label.new()
	title.text = "Evolve - pick one adaptation"
	v.add_child(title)
	draft_row = HBoxContainer.new()
	v.add_child(draft_row)
	draft_panel.visible = false

func _build_gameover() -> void:
	gameover_panel = _panel()
	var v := VBoxContainer.new()
	gameover_panel.add_child(v)
	gameover_title = Label.new()
	gameover_title.text = "You Died"
	v.add_child(gameover_title)
	gameover_stats = Label.new()
	v.add_child(gameover_stats)
	gameover_repro_row = HBoxContainer.new()
	v.add_child(gameover_repro_row)
	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	v.add_child(restart_btn)
	gameover_panel.visible = false
