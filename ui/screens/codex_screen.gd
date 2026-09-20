extends PanelContainer

# =========================================================
# Codex screen. Save as res://ui/screens/codex_screen.gd
# (the Codex tab opens it). Rules in codex.gd, backgrounds in
# codex_lore.gd.
#
# Three pages: Partners, Beasts, Treasures. Each shows its
# collection sets (with the team bonus each one gives) and every
# entry: discovered ones with art, the rest as dark silhouettes.
# Tap a discovered entry for its background.
# =========================================================

const TABS := ["Partners", "Beasts", "Treasures", "Titles"]
const CELL := Vector2(150, 200)

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")

var _tab := "Partners"
## Server-held titles are fetched once per visit to this screen, not
## on every tab switch: they change rarely and it costs a round trip.
var _titles_synced := false
var _tab_buttons := {}
var _body: VBoxContainer
var _summary: Label


func _ready() -> void:
	name = "CodexScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := _label("Codex", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_summary = _label("", 18, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary.visible = false
	head.add_child(_summary)


	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	root.add_child(tabs)
	for t in TABS:
		var b := OrnateButton.new()
		b.text = t
		b.custom_minimum_size = Vector2(220, 58)
		b.pressed.connect(_switch.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	pad.add_child(_body)

	_switch(_tab)


## Called by the router each time the tab opens.
func on_opened() -> void:
	_switch(_tab)


func _switch(tab: String) -> void:
	_tab = tab
	for t in _tab_buttons:
		var b: OrnateButton = _tab_buttons[t]
		b.variant = OrnateButton.Variant.GOLD if t == tab else OrnateButton.Variant.DARK
	_summary.text = "Team bonus: " + Codex.bonus_text(Codex.totals())
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _tab:
		"Beasts":
			_build_beasts()
		"Treasures":
			_build_treasures()
		"Titles":
			_build_titles()
		_:
			_build_partners()


# ---------------------------------------------------------
# TITLES
# ---------------------------------------------------------

## Every title, earned or not, grouped by tier. Every one you hold
## adds its bonus; the worn one is what others see beside your name.
func _build_titles() -> void:
	# Most titles ride counters that were already ticking before this
	# page existed, so bring them up to date on the way in rather than
	# waiting for the next thing that happens to bump a stat.
	Titles.refresh()
	# Nothing gates the Titles page, so no unlock announces it; this
	# is the first time the player can have seen it.
	Tutorial.start("titles", self)
	# Placements and sect ranks live on the server. Fetched alongside,
	# not awaited: the page draws now with what is already known and
	# redraws if the server disagrees.
	if not _titles_synced:
		_titles_synced = true
		_sync_server_titles()
	var owned := Titles.owned_ids()
	_body.add_child(_label("Earned %d / %d titles" % [owned.size(), Titles.LIST.size()],
		20, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var note := _label("Every title you hold adds its bonus. The one you wear is what "
		+ "other cultivators see beside your name.", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)

	# What they add up to, so the stacking is visible rather than implied.
	var totals := Titles.totals()
	if not totals.is_empty():
		var parts := PackedStringArray()
		for stat in totals:
			var stat_label: String = Gear.STAT_NAMES.get(str(stat), str(stat))
			parts.append("+%s%% %s" % [_pct(float(totals[stat])), stat_label])
		var sum_l := _label("  ·  ".join(parts), 17, COL_OK, HORIZONTAL_ALIGNMENT_LEFT)
		sum_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(sum_l)

	if Titles.worn() != "":
		var off := Button.new()
		off.text = "Wear no title"
		off.flat = true
		off.focus_mode = Control.FOCUS_NONE
		off.add_theme_font_size_override("font_size", 17)
		off.add_theme_color_override("font_color", COL_DIM)
		off.pressed.connect(func(): _wear(""))
		_body.add_child(off)

	# Rarest first: the page should open on something worth seeing.
	for tier in range(ItemDB.GRADE_NAMES.size() - 1, -1, -1):
		var ids: Array = []
		for id in Titles.LIST:
			if Titles.tier_of(str(id)) == tier:
				ids.append(str(id))
		if ids.is_empty():
			continue
		ids.sort_custom(func(a, b): return Titles.title_name(a) < Titles.title_name(b))
		var have := ids.filter(func(x): return Titles.owns(str(x))).size()
		_body.add_child(_heading("%s  (%d / %d)" % [ItemDB.grade_name(tier), have, ids.size()],
			ItemDB.grade_color(tier)))
		for id in ids:
			_body.add_child(_title_row(str(id)))


func _pct(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")


## One title: its banner (or a drawn plate until the art lands), what
## it grants, and how it is earned. Tapping an owned one wears it.
func _title_row(id: String) -> Control:
	var have := Titles.owns(id)
	var tint := Titles.colour_of(id)
	var is_worn := Titles.worn() == id

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 104)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint, 0.16 if is_worn else (0.06 if have else 0.02))
	normal.border_color = Color(tint, 0.9 if is_worn else (0.5 if have else 0.18))
	normal.set_border_width_all(2 if is_worn else 1)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint, 0.2 if have else 0.05)
	for state in ["normal", "focus"]:
		b.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed"]:
		b.add_theme_stylebox_override(state, hover)
	if have:
		b.pressed.connect(func(): _wear(id))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)

	h.add_child(_title_banner(id, tint, have))

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 1)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(texts)

	var head := "%s%s" % [Titles.title_name(id), "   (worn)" if is_worn else ""]
	texts.add_child(_label(head, 20, tint if have else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	var bonus_row := HBoxContainer.new()
	bonus_row.add_theme_constant_override("separation", 10)
	bonus_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(bonus_row)
	bonus_row.add_child(_label(Titles.bonus_text(id), 16,
		COL_OK if have else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	# Standings run out; say so on the row rather than letting one
	# quietly vanish between visits.
	var left := Titles.remaining_text(id)
	if left != "":
		bonus_row.add_child(_label(left, 15, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))

	var t: Dictionary = Titles.get_title(id)
	var how := str(t.get("how", ""))
	if not have:
		# Say how far along they are, when it is something countable.
		var need := Titles.goal(id)
		var at := Titles.progress(id)
		if t.has("track") and need > 1:
			how += "   (%s / %s)" % [NumberFormat.short(at), NumberFormat.short(need)]
		elif bool(t.get("server", false)):
			how += "   (awarded by the heavens)"
	var how_l := _label(how, 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	how_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how_l.custom_minimum_size.x = 1
	texts.add_child(how_l)
	return b


## The banner art, or a drawn plate in the tier's colour while the
## art is still being made.
func _title_banner(id: String, tint: Color, have: bool) -> Control:
	var art := Titles.art_of(id)
	if art != null:
		var tex := TextureRect.new()
		tex.texture = art
		tex.custom_minimum_size = Vector2(256, 64)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not have:
			tex.modulate = Color(0.35, 0.37, 0.42)
		return tex

	var plate := Control.new()
	plate.custom_minimum_size = Vector2(256, 64)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := tint if have else Color(0.35, 0.37, 0.42)
	plate.draw.connect(func():
		var r := Rect2(Vector2.ZERO, plate.size)
		plate.draw_rect(r, Color(shade, 0.12))
		plate.draw_rect(r, Color(shade, 0.7), false, 1.5)
		var inset := r.grow(-6.0)
		plate.draw_rect(inset, Color(shade, 0.35), false, 1.0)
	)
	return plate


## Pulls the server-held set and redraws only if it differs, so a
## rank gained or lost elsewhere shows up without a relaunch. Compares
## the whole set rather than the newly granted ones, because a sync
## can take a title away as well as give one.
func _sync_server_titles() -> void:
	if not Showcase.available():
		return
	var before := Titles.owned_ids()
	await Showcase.pull_titles()
	if not is_instance_valid(self) or not is_inside_tree() or _tab != "Titles":
		return
	if Titles.owned_ids() != before:
		_rebuild()


func _wear(id: String) -> void:
	Titles.wear(id)
	_rebuild()


# ---------------------------------------------------------
# PAGES
# ---------------------------------------------------------

func _build_partners() -> void:
	SummonCard.find_frames(self)
	var all: Array = PartnerDatabase.get_all()
	var found := 0
	for d in all:
		if Codex.has_partner(d.partner_id):
			found += 1
	_body.add_child(_label("Discovered %d / %d partners" % [found, all.size()], 20, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(_sets_line(Codex.partner_sets()))
	for tier in Enums.Rarity.values():
		var list: Array = all.filter(func(d): return int(d.rarity) == int(tier))
		if list.is_empty():
			continue
		list.sort_custom(func(a, b): return str(a.display_name) < str(b.display_name))
		var have := list.filter(func(d): return Codex.has_partner(d.partner_id)).size()
		var tier_name := str(Enums.Rarity.keys()[tier]).capitalize()
		var col: Color = ItemDB.grade_color(Realms.tier_index(int(tier)))
		_body.add_child(_heading("%s  (%d / %d)" % [tier_name, have, list.size()], col.lightened(0.2)))
		var grid := _grid()
		for d in list:
			grid.add_child(_partner_cell(d, col))
		_body.add_child(grid)


func _build_beasts() -> void:
	var tamed := 0
	for sp in Beasts.SPECIES:
		if Codex.beast_tamed(str(sp)):
			tamed += 1
	_body.add_child(_label("Tamed %d / %d spirit beasts" % [tamed, Beasts.SPECIES.size()], 20, COL_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(_sets_line(Codex.beast_sets()))
	for g in Beasts.GROUNDS:
		var species: Array = g["species"]
		var have := species.filter(func(sp): return Codex.beast_tamed(str(sp))).size()
		_body.add_child(_heading("%s  ·  %s  (%d / %d)" % [g["name"], g["age"], have, species.size()], g["color"]))
		var grid := _grid()
		for sp in species:
			grid.add_child(_beast_cell(str(sp), g["color"]))
		_body.add_child(grid)


func _build_treasures() -> void:
	_body.add_child(_label("Found %d / %d treasures" % [GameState.codex_treasures.size(), Treasures.LIST.size()], 20,
		COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(_sets_line(Codex.treasure_sets()))
	for set_id in Treasures.SETS:
		var set_def: Dictionary = Treasures.SETS[set_id]
		var ids: Array = []
		for id in Treasures.LIST:
			if str(Treasures.LIST[id]["set"]) == str(set_id):
				ids.append(str(id))
		var have := ids.filter(func(id): return Codex.has_treasure(str(id))).size()
		_body.add_child(_heading("%s  (%d / %d)" % [set_def["name"], have, ids.size()], set_def["color"]))
		var grid := _grid()
		for id in ids:
			grid.add_child(_treasure_cell(str(id)))
		_body.add_child(grid)


# ---------------------------------------------------------
# SETS
# ---------------------------------------------------------

func _current_sets() -> Array:
	match _tab:
		"Beasts":
			return Codex.beast_sets()
		"Treasures":
			return Codex.treasure_sets()
	return Codex.partner_sets()


## The summary strip at the top of each page: this page's collection
## sets (opens the Sets popup) and the team's total bonus (opens All
## Bonuses), as two cards in the Codex's own style.
func _sets_line(sets: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var done := sets.filter(func(x): return bool(x["done"])).size()
	var fill := float(done) / float(maxi(sets.size(), 1))

	var left := _strip_card(_open_sets)
	var lv: VBoxContainer = left.get_child(0)
	lv.add_child(_label("Collection Sets  »", 20, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT))
	lv.add_child(_label("%d / %d complete" % [done, sets.size()], 16, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 1, bar.size.x, 6), Color(0, 0, 0, 0.5))
		bar.draw_rect(Rect2(0, 1, bar.size.x * fill, 6), COL_GOLD)
	)
	lv.add_child(bar)
	row.add_child(left)

	var right := _strip_card(func(): BonusesPopup.open(self))
	var rv: VBoxContainer = right.get_child(0)
	rv.add_child(_label("Team Bonus  »", 20, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT))
	# Every team-wide source, so this agrees with All Bonuses. Path
	# Resonance and Titles were missing, which made the strip read
	# lower than the stats the player actually had.
	var total := Codex.totals().duplicate()
	for source in [GameState.sect_bonus, GameState.path_bonus, GameState.title_bonus]:
		for stat in source:
			total[stat] = float(total.get(stat, 0.0)) + float(source[stat])
	var summary := _label(Codex.bonus_text(total).replace(", ", "  ·  "), 16, COL_OK if not total.is_empty() else COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT)
	# One line, trimmed. NOT autowrapped: an autowrapped Label whose
	# minimum width is pinned to 1 reports the height it would need
	# wrapping at one pixel, which grew with every bonus earned until
	# this strip stood 710px tall and pushed the whole page off the
	# screen. The full breakdown is a tap away in All Bonuses.
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.custom_minimum_size.x = 1
	rv.add_child(summary)
	row.add_child(right)
	return row


## A tappable card: a dark panel with a gold border, lighter on hover.
func _strip_card(on_press: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(COL_GOLD, 0.05)
	normal.border_color = Color(COL_GOLD, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(COL_GOLD, 0.12)
	hover.border_color = Color(COL_GOLD, 0.8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.pressed.connect(on_press)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	# The button sizes itself to its content
	v.resized.connect(func(): b.custom_minimum_size.y = v.size.y + 24.0)
	v.position = Vector2(12, 12)
	b.resized.connect(func(): v.size.x = b.size.x - 24.0)
	return b


## The current page's collection sets in a popup.
func _open_sets() -> void:
	var sets := _current_sets()
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free()
	)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(920, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var done := sets.filter(func(x): return bool(x["done"])).size()
	v.add_child(_label("%s Collection Sets" % _tab.trim_suffix("s") if _tab != "Treasures" else "Treasure Collection Sets",
		30, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_label("%d / %d complete  ·  Team bonus from these: %s" % [done, sets.size(),
		Codex.bonus_text(_sum(sets))], 17, COL_GOLD))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 1100)
	v.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	scroll.add_child(pad)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	pad.add_child(list)
	var ordered := sets.duplicate()
	var by_progress := func(a, b) -> bool:
		if bool(a["done"]) != bool(b["done"]):
			return bool(a["done"])
		return float(a["have"]) / float(a["need"]) > float(b["have"]) / float(b["need"])
	ordered.sort_custom(by_progress)
	for x in ordered:
		list.add_child(_set_row(x))
	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 56)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


func _sum(sets: Array) -> Dictionary:
	var out := {}
	for x in sets:
		if bool(x["done"]):
			out[x["stat"]] = float(out.get(x["stat"], 0.0)) + float(x["value"])
	return out

func _sets_section(sets: Array) -> void:
	var done := sets.filter(func(s): return bool(s["done"])).size()
	_body.add_child(_heading("Collection Sets  (%d / %d complete)" % [done, sets.size()], COL_TITLE))
	# Completed and closest-to-done first
	var ordered := sets.duplicate()
	var by_progress := func(a, b) -> bool:
		if bool(a["done"]) != bool(b["done"]):
			return bool(a["done"])
		return float(a["have"]) / float(a["need"]) > float(b["have"]) / float(b["need"])
	ordered.sort_custom(by_progress)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for s in ordered:
		grid.add_child(_set_row(s))
	_body.add_child(grid)


func _set_row(s: Dictionary) -> Control:
	var done := bool(s["done"])
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_OK, 0.08) if done else Color(1, 1, 1, 0.03)
	sb.border_color = Color(COL_OK, 0.7) if done else Color("2c4466")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var n := _label(str(s["name"]) + ("  ·  Complete" if done else ""), 19, COL_OK if done else COL_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(n)
	top.add_child(_label(Codex.set_bonus_text(s), 18, COL_GOLD if done else COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	var d := _label(str(s["desc"]), 14, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var fill := clampf(float(s["have"]) / float(maxi(int(s["need"]), 1)), 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 1, w, 8), Color(0, 0, 0, 0.5))
		bar.draw_rect(Rect2(0, 1, w * fill, 8), COL_OK if done else COL_GOLD)
	)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	bar_row.add_child(_label("%d / %d" % [int(s["have"]), int(s["need"])], 14, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	v.add_child(bar_row)
	return panel


# ---------------------------------------------------------
# ENTRY CELLS
# ---------------------------------------------------------

func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


## A cell: art in a framed box, name under it. Undiscovered = silhouette + ???.
func _cell(tex: Texture2D, title: String, frame: Color, found: bool, dim := false) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CELL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art_h := CELL.y - 34.0
	b.draw.connect(func():
		var r := Rect2(Vector2(2, 2), Vector2(CELL.x - 4, art_h))
		b.draw_rect(r, Color(0.03, 0.05, 0.1, 0.95))
		b.draw_rect(r, Color(frame, 0.8 if found else 0.3), false, 2.0)
	)
	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(5, 5)
	art.size = Vector2(CELL.x - 10, art_h - 6)
	art.clip_contents = true
	if not found:
		art.modulate = Color(0, 0, 0, 0.85)    # silhouette
	elif dim:
		art.modulate = Color(0.55, 0.55, 0.6)
	b.add_child(art)
	b.clip_contents = true
	var n := _label(title if found or dim else "???", 15, COL_TEXT if found else COL_DIM)
	n.position = Vector2(0, art_h + 4)
	n.size = Vector2(CELL.x, 26)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_child(n)
	b.disabled = not found and not dim
	return b


## A partner: their real tier-framed card (a dark silhouette until found).
func _partner_cell(d, _frame: Color) -> Control:
	var found := Codex.has_partner(d.partner_id)
	var card_size := SummonCard.size_for_width(CELL.x - 6)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CELL.x, card_size.y + 30)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var card := SummonCard.new()
	card.setup({"partner_id": str(d.partner_id)}, int(d.rarity), card_size)
	card.show_front()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(3, 0)
	if not found:
		card.modulate = Color(0.08, 0.08, 0.1, 0.9)
	b.add_child(card)
	var n := _label(str(d.display_name) if found else "???", 15, COL_TEXT if found else COL_DIM)
	n.position = Vector2(0, card_size.y + 3)
	n.size = Vector2(CELL.x, 26)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_child(n)
	b.disabled = not found
	b.pressed.connect(_open_partner.bind(str(d.partner_id)))
	return b


func _beast_cell(species: String, frame: Color) -> Control:
	var tamed := Codex.beast_tamed(species)
	var seen := Codex.beast_slain(species) > 0
	var b := _cell(Beasts.species_art(species), Beasts.species_name(species), frame, tamed, seen and not tamed)
	b.pressed.connect(_open_beast.bind(species))
	return b


func _treasure_cell(id: String) -> Control:
	var found := Codex.has_treasure(id)
	var grade := int(GameState.codex_treasures.get(id, 0))
	var def := Treasures.get_def(id)
	var b := _cell(null, str(def.get("name", id)), Treasures.grade_color(grade), found)
	# Treasure art is drawn by TreasureIcon
	var icon := TreasureIcon.new()
	icon.setup(Treasures.make(id, grade))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(CELL.x * 0.5 - 60, 18)
	icon.size = Vector2(120, 120)
	if not found:
		icon.modulate = Color(0, 0, 0, 0.85)
	b.add_child(icon)
	b.move_child(icon, 0)
	b.pressed.connect(_open_treasure.bind(id))
	return b


# ---------------------------------------------------------
# DETAILS
# ---------------------------------------------------------

func _open_partner(partner_id: String) -> void:
	var d = PartnerDatabase.get_partner(partner_id)
	if d == null:
		return
	var lore := CodexLore.partner(partner_id)
	var tier := str(Enums.Rarity.keys()[int(d.rarity)]).capitalize()
	var dao := str(Enums.Path.keys()[int(d.path)]).capitalize()
	var sub := PackedStringArray()
	if str(d.form_name) != "":
		sub.append(str(d.form_name))
	if SummonSystem.is_premium(partner_id):
		tier = "Premium " + tier
	sub.append("%s  ·  %s Dao" % [tier, dao])
	if str(lore[0]) != "":
		sub.append("From " + str(lore[0]))
	var skill := PartnerSkills.skill_for(partner_id, int(d.rarity))
	var skill_info := {}
	if skill.is_empty():
		skill_info = {"title": "Signature Skill", "name": "None",
			"desc": "White partners fight with basic attacks.", "numbers": "", "trigger": ""}
	else:
		var mode := PartnerSkills.mode_for(int(d.rarity))
		var trigger := "Triggers when the energy bar is full"
		if mode == "proc":
			trigger = "Triggers: %d%% chance on each attack (weaker version)" % int(PartnerSkills.proc_chance(int(d.rarity)))
		skill_info = {"title": "Signature Skill", "name": str(skill["name"]), "desc": str(skill["desc"]),
			"numbers": Skills.summary(skill), "trigger": trigger}
	SummonCard.find_frames(self)
	var card_size := SummonCard.size_for_width(320.0)
	var card := SummonCard.new()
	card.setup({"partner_id": partner_id}, int(d.rarity), card_size)
	card.show_front()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = card_size
	_detail(null, str(d.display_name), "\n".join(sub), str(lore[1]), PackedStringArray(),
		ItemDB.grade_color(Realms.tier_index(int(d.rarity))), {}, card, skill_info)


func _open_beast(species: String) -> void:
	var entry: Array = Beasts.SPECIES.get(species, [])
	var ground := ""
	var color := COL_GOLD
	for g in Beasts.GROUNDS:
		var in_ground: Array = g["species"]
		if in_ground.has(species):
			ground = "%s  ·  %s" % [g["name"], g["age"]]
			color = g["color"]
	var dao := str(Enums.Path.keys()[Beasts.species_dao(species)]).capitalize()
	var extra := PackedStringArray()
	extra.append("Slain %d  ·  Tamed %d" % [Codex.beast_slain(species), int(Beasts.codex_entry(species).get("tamed", 0))])
	var skill_info := {}
	if entry.size() > 5:
		# Its strength with one 10-Year ring inside, as a baseline
		var base: Dictionary = PartnerSkills.TEMPLATES.get(str(entry[5]), {})
		var s := base.duplicate()
		var mult := Beasts.BEAST_POWER_BASE + Beasts.BEAST_POWER_PER_RING
		s["power"] = float(s.get("power", 0.0)) * mult
		for key in ["heal_ally", "shield_team"]:
			if s.has(key):
				s[key] = float(s[key]) * mult
		skill_info = {"title": "Beast Skill", "name": str(entry[3]), "desc": str(entry[4]),
			"numbers": Skills.summary(s) + "  (with one 10-Year ring)",
			"trigger": "As a Soul Spirit: fires every %d actions once a ring is inside. More and older rings make it stronger." % Beasts.BEAST_EVERY}
	_detail(Beasts.species_art(species), Beasts.species_name(species), "%s Dao spirit beast\n%s" % [dao, ground],
		str(CodexLore.BEASTS.get(species, "")), extra, color, {}, null, skill_info)


func _open_treasure(id: String) -> void:
	var def := Treasures.get_def(id)
	var grade := int(GameState.codex_treasures.get(id, 0))
	var t := Treasures.make(id, grade)
	var set_id := str(def.get("set", ""))
	var set_def := Treasures.set_def(set_id)
	var extra := PackedStringArray()
	extra.append("Best found: %s  ·  %s" % [Treasures.grade_name(grade), Treasures.stat_text(t)])
	extra.append("%s set (3 worn): %s" % [set_def.get("name", ""), Treasures.set_effect_text(set_id, grade)])
	_detail(null, str(def.get("name", id)), "%s treasure" % set_def.get("name", ""),
		str(CodexLore.TREASURES.get(id, def.get("desc", ""))), extra, Treasures.grade_color(grade), t)


## The detail popup: art on the left, words on the right.
func _detail(tex: Texture2D, title: String, subtitle: String, lore: String, extra: PackedStringArray,
		color: Color, treasure := {}, card_node: Control = null, skill_info := {}) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free()
	)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(920, 0)
	center.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel.add_child(h)

	if card_node != null:
		var holder := CenterContainer.new()
		holder.add_child(card_node)
		h.add_child(holder)
	elif not treasure.is_empty():
		var icon := TreasureIcon.new()
		icon.setup(treasure)
		icon.custom_minimum_size = Vector2(300, 300)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon)
	else:
		var art := TextureRect.new()
		art.texture = tex
		art.custom_minimum_size = Vector2(320, 440)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(art)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	v.add_child(_label(title, 32, color.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, true))
	var sub := _label(subtitle, 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(_line())
	var lore_l := _label(lore, 20, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	lore_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lore_l)
	v.add_child(_line())
	if not skill_info.is_empty():
		v.add_child(_skill_block(skill_info, color))
	for line in extra:
		var l := _label(str(line), 18, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(200, 54)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


## Skill panel: name, description, the numbers, and how it triggers.
func _skill_block(info: Dictionary, color: Color) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07)
	sb.border_color = Color(color, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(_label(str(info.get("title", "Skill")), 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_label(str(info.get("name", "")), 24, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	for key in ["desc", "numbers", "trigger"]:
		var value := str(info.get(key, ""))
		if value == "":
			continue
		var col := COL_TEXT
		if key == "numbers":
			col = COL_OK
		elif key == "trigger":
			col = COL_GOLD
		var l := _label(value, 18, col, HORIZONTAL_ALIGNMENT_LEFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if str(info.get("numbers", "")).contains("turn"):
		v.add_child(_label("Durations are in turns: a status lasts through that many of the target's turns.", 14,
			COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	return panel


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _heading(text_value: String, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_label(text_value, 22, color, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_line())
	return v


func _draw_backdrop() -> void:
	var s := size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.4), false, 2.0)


func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(COL_GOLD, 0.0), Color(COL_GOLD, 0.6), Color(COL_GOLD, 0.0)]), 1.5, true)
	)
	return line


func _label(value: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, glow := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(COL_GOLD, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
