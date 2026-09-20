class_name BonusesPopup
extends CanvasLayer

# =========================================================
# "All Bonuses": every team-wide bonus the player has earned,
# added up, with where each part comes from. Save as
# res://ui/bonuses_popup.gd
#
#   BonusesPopup.open(self)
#
# Sources: Codex collection sets (partners, beasts, treasures)
# and Sect Research. These apply to every partner's stats.
# =========================================================

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")

const STATS := ["hp_pct", "atk_pct", "def_pct", "crit"]


static func open(host: Node) -> BonusesPopup:
	var p := BonusesPopup.new()
	host.get_tree().root.add_child(p)
	return p


func _ready() -> void:
	layer = 62
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(880, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_label("All Bonuses", 36, COL_TITLE, true))
	v.add_child(_label("Team-wide bonuses you've earned. They apply to every partner.", 17, COL_DIM))

	# Every source, then the grand total
	var sources := [
		["Codex: Partner Sets", _sum_sets(Codex.partner_sets())],
		["Codex: Beast Sets", _sum_sets(Codex.beast_sets())],
		["Codex: Treasure Sets", _sum_sets(Codex.treasure_sets())],
		["Sect Research", GameState.sect_bonus],
	]
	var total := {}
	for src in sources:
		var b: Dictionary = src[1]
		for stat in b:
			total[stat] = float(total.get(stat, 0.0)) + float(b[stat])

	v.add_child(_total_block(total))
	v.add_child(_line())
	for src in sources:
		v.add_child(_source_row(str(src[0]), src[1]))

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 56)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	v.add_child(close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


## Adds up the bonuses of the completed sets in a list.
func _sum_sets(sets: Array) -> Dictionary:
	var out := {}
	for s in sets:
		if bool(s["done"]):
			out[s["stat"]] = float(out.get(s["stat"], 0.0)) + float(s["value"])
	return out


## The grand total: one big tile per stat.
func _total_block(total: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	for stat in STATS:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COL_GOLD, 0.07)
		sb.border_color = Color(COL_GOLD, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		tile.add_theme_stylebox_override("panel", sb)
		var t := VBoxContainer.new()
		tile.add_child(t)
		var value := float(total.get(stat, 0.0))
		t.add_child(_label("+%s%%" % _num(value), 30, COL_OK if value > 0.0 else COL_DIM))
		t.add_child(_label(str(Codex.STAT_LABELS.get(stat, stat)), 16, COL_TEXT))
		grid.add_child(tile)
	return grid


## One source: its name, then its bonuses ("none yet" if empty).
func _source_row(title: String, bonus: Dictionary) -> Control:
	var h := HBoxContainer.new()
	var n := _label(title, 20, COL_TEXT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var has_any := false
	for stat in bonus:
		if float(bonus[stat]) > 0.0:
			has_any = true
	var text_value := Codex.bonus_text(bonus) if has_any else "None yet"
	var val := _label(text_value, 19, COL_GOLD if has_any else COL_DIM)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	return h


func _num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")


func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		line.draw_line(Vector2(0, y), Vector2(line.size.x, y), Color(COL_GOLD, 0.35), 1.0)
	)
	return line


func _label(value: String, font_size: int, color: Color, glow := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(COL_GOLD, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
