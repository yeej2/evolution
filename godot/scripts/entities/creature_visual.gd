extends Node2D
## Simple placeholder rendering: a filled circle sized/colored from the
## owning creature's stats, plus small status-effect ticks. This is the one
## place that should eventually grow into "mechanically readable" creature
## art (visible claws/horns/fins per mutation) - see PLAN.md section 8.4/10.

@onready var creature: Creature = get_parent()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not creature:
		return
	var color: Color = Color.WHITE
	if creature.is_player and creature.lineage_data:
		color = creature.lineage_data.color
	elif creature.species_data:
		color = creature.species_data.color
	var alpha := 0.5 if creature.status.hidden else 1.0
	draw_circle(Vector2.ZERO, creature.stats.radius, Color(color.r, color.g, color.b, alpha))
	draw_arc(Vector2.ZERO, creature.stats.radius + 2.0, creature.facing - 0.4, creature.facing + 0.4, 8, Color.WHITE, 2.0)

	if creature.status.poison_time > 0.0:
		draw_circle(Vector2(-creature.stats.radius * 0.5, -creature.stats.radius - 6.0), 3.0, Color.PURPLE)
	if creature.status.bleed_time > 0.0:
		draw_circle(Vector2(creature.stats.radius * 0.5, -creature.stats.radius - 6.0), 3.0, Color.RED)
	if creature.status.is_stunned():
		draw_circle(Vector2(0.0, -creature.stats.radius - 6.0), 3.0, Color.YELLOW)
	if creature.telegraph > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -creature.stats.radius - 14.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.RED)

	var hp_frac: float = clamp(creature.stats.hp / max(creature.stats.max_hp, 1.0), 0.0, 1.0)
	var bar_w := creature.stats.radius * 2.0
	draw_rect(Rect2(-bar_w / 2.0, creature.stats.radius + 6.0, bar_w, 4.0), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bar_w / 2.0, creature.stats.radius + 6.0, bar_w * hp_frac, 4.0), Color(0.8, 0.2, 0.2))
