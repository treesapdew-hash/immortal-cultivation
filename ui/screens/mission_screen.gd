extends PanelContainer

# =========================================================
# Mission tab: Daily, Weekly and Achievements. Save as
#   res://ui/screens/mission_screen.gd
#
# Daily and weekly missions come from missions.gd: claim them
# for activity points, which open 4 milestone chests.
#
# Achievements come from achievements.gd as tier chains. Each
# chain shows only its next unclaimed tier, so claimed ones
# disappear. Ready ones float to the top.
# =========================================================

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_JADE := Color("7dffa8")
const COL_STONES := Color("b9d4ff")
const COL_DOT := Color("ff4d4d")

const TABS := ["Daily", "Weekly", "Achievements"]
const CHEST_W := 96.0
const CHEST_H := 88.0
## Chest art: chest_1.png .. chest_4.png, plus chest_N_open.png.
## Missing files fall back to a drawn chest.
const CHEST_DIR := "res://assets/ui/chests/"

var _tab := "Daily"
var _tab_buttons := {}
var _tab_dots := {}
var _list: VBoxContainer
## Activity bar and chests: above the scroll area, so they never
## sit under the scroll bar and stay visible while scrolling.
var _pinned: VBoxContainer
var _title_label: Label
var _count_label: Label
var _claim_all: OrnateButton
var _toast_holder: Control
var _dirty := true
var _clock := 0.0


func _ready() -> void:
	name = "MissionScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	_build()
	GameState.achievements_changed.connect(_mark_dirty)
	GameState.stage_changed.connect(_mark_dirty)
	GameState.roster_changed.connect(_mark_dirty)
	_rebuild()


func on_opened() -> void:
	_rebuild()
	_check_card_choice()


func _mark_dirty() -> void:
	_dirty = true
	if is_visible_in_tree():
		_rebuild.call_deferred()


func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_title_label = _label("Daily Missions", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	titles.add_child(_title_label)
	titles.add_child(_label("Missions", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	_count_label = _label("", 20, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_count_label.custom_minimum_size.x = 130
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_label)

	_claim_all = OrnateButton.new()
	_claim_all.text = "Claim All"
	_claim_all.custom_minimum_size = Vector2(190, 48)
	_claim_all.add_theme_font_size_override("font_size", 19)
	_claim_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_claim_all.pressed.connect(_on_claim_all)
	head.add_child(_claim_all)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for tab in TABS:
		var b := _make_tab(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons[tab] = b

	v.add_child(_fade_line())

	_pinned = VBoxContainer.new()
	_pinned.add_theme_constant_override("separation", 6)
	v.add_child(_pinned)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	# Padding keeps the right edge clear of the scroll bar
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 4)
	scroll.add_child(pad)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	pad.add_child(_list)

	_toast_holder = Control.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_holder.top_level = true
	add_child(_toast_holder)


func _make_tab(tab: String) -> Button:
	var b := Button.new()
	b.text = tab
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_select_tab.bind(tab))
	b.draw.connect(func():
		var w := b.size.x
		if int(_tab_dots.get(tab, 0)) > 0:
			b.draw_circle(Vector2(w * 0.5 + 58.0, 14.0), 7.0, COL_DOT)
		if tab != _tab:
			return
		var y := b.size.y - 4.0
		b.draw_rect(Rect2(0, 0, w, b.size.y), Color(COL_GOLD, 0.05))
		b.draw_rect(Rect2(w * 0.12, y - 1.0, w * 0.76, 3.0), COL_GOLD)
		var c := Vector2(w * 0.5, y)
		b.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), Color("ffe6a8"))
	)
	return b


func _select_tab(tab: String) -> void:
	if not Unlocks.place_open("mission:" + tab):
		Unlocks.toast(self, Unlocks.requirement_text(Unlocks.feature_at("mission:" + tab)))
		return
	_tab = tab
	_rebuild()


## Keeps the reset timer ticking on the mission tabs.
func _process(delta: float) -> void:
	if _tab == "Achievements" or not is_visible_in_tree():
		return
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_count_label.text = Missions.reset_text(_tab == "Weekly")
		# A new day or week started while the screen was open
		var before := GameState.missions.duplicate()
		Missions.refresh()
		if GameState.missions != before:
			_rebuild()


func _rebuild() -> void:
	_dirty = false
	for holder in [_list, _pinned]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	_pinned.visible = _tab != "Achievements"

	Missions.refresh()
	_tab_dots = {
		"Daily": Missions.claimable_count(false),
		"Weekly": Missions.claimable_count(true),
		"Achievements": Achievements.claimable_count(),
	}
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		b.add_theme_color_override("font_color", Color("ffe6a8") if key == _tab else COL_DIM)
		b.queue_redraw()

	match _tab:
		"Achievements":
			_title_label.text = "Achievements"
			_build_achievements()
		"Weekly":
			_title_label.text = "Weekly Missions"
			_build_missions(true)
		_:
			_title_label.text = "Daily Missions"
			_build_missions(false)

	var is_ready: int = _tab_dots.get(_tab, 0)
	_claim_all.disabled = is_ready == 0
	_claim_all.text = "Claim All (%d)" % is_ready if is_ready > 0 else "Claim All"


func _build_achievements() -> void:
	# Ready first, then closest to done
	var entries := Achievements.current()
	entries.sort_custom(func(a, b):
		var a_ready := Achievements.is_done(a)
		var b_ready := Achievements.is_done(b)
		if a_ready != b_ready:
			return a_ready
		return _fraction(a) > _fraction(b))

	for a in entries:
		_list.add_child(_row(a))
	if entries.is_empty():
		var all_done := _label("Every achievement is complete.", 22, COL_DIM)
		all_done.custom_minimum_size.y = 200
		_list.add_child(all_done)

	_count_label.text = "%d claimed" % GameState.claimed_achievements.size()


# ---------------------------------------------------------
# DAILY / WEEKLY MISSIONS
# ---------------------------------------------------------

func _build_missions(weekly: bool) -> void:
	_count_label.text = Missions.reset_text(weekly)
	_pinned.add_child(_chest_bar(weekly))
	_pinned.add_child(_fade_line())

	# Ready first, then closest to done, claimed last
	var entries: Array = Missions.list(weekly).duplicate()
	entries.sort_custom(func(a, b):
		var a_rank := _mission_rank(a, weekly)
		var b_rank := _mission_rank(b, weekly)
		if a_rank != b_rank:
			return a_rank < b_rank
		return _mission_fraction(a, weekly) > _mission_fraction(b, weekly))
	for m in entries:
		_list.add_child(_mission_row(m, weekly))


func _mission_rank(m: Dictionary, weekly: bool) -> int:
	if Missions.is_claimed(m, weekly):
		return 2
	return 0 if Missions.is_done(m, weekly) else 1


func _mission_fraction(m: Dictionary, weekly: bool) -> float:
	return float(Missions.progress(m, weekly)) / maxf(float(m["goal"]), 1.0)


## Activity bar with the 4 milestone chests sitting on it.
func _chest_bar(weekly: bool) -> Control:
	var pts := Missions.points(weekly)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	box.add_child(head)
	var t := _label("Activity", 22, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("%d / %d" % [pts, Missions.MAX_POINTS], 22, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT))

	var track := Control.new()
	track.custom_minimum_size = Vector2(0, CHEST_H + 44.0)
	box.add_child(track)

	var fill := clampf(float(pts) / float(Missions.MAX_POINTS), 0.0, 1.0)
	var bar_y := CHEST_H * 0.5 + 6.0
	track.draw.connect(func():
		var x0 := 8.0
		var x1 := track.size.x - CHEST_W * 0.5 - 8.0
		track.draw_rect(Rect2(x0, bar_y - 6.0, x1 - x0, 12.0), Color(0, 0, 0, 0.5))
		track.draw_rect(Rect2(x0, bar_y - 6.0, (x1 - x0) * fill, 12.0), Color("ffb84d"))
		track.draw_rect(Rect2(x0, bar_y - 6.0, x1 - x0, 12.0), Color(COL_GOLD, 0.4), false, 1.0)
	)

	var list := Missions.chests(weekly)
	var chest_nodes: Array = []
	for i in list.size():
		var chest_points := int(list[i]["points"])
		var btn := _chest_button(i, weekly)
		track.add_child(btn)
		var lbl := _label(str(chest_points), 17, COL_GOLD if pts >= chest_points else COL_DIM)
		lbl.custom_minimum_size = Vector2(CHEST_W, 24)
		track.add_child(lbl)
		chest_nodes.append([btn, lbl, float(chest_points) / float(Missions.MAX_POINTS)])

	track.resized.connect(func():
		var x0 := 8.0
		var x1 := track.size.x - CHEST_W * 0.5 - 8.0
		for entry in chest_nodes:
			var cx: float = x0 + (x1 - x0) * float(entry[2])
			var btn_node: Control = entry[0]
			var lbl_node: Control = entry[1]
			btn_node.position = Vector2(cx - CHEST_W * 0.5, 6.0)
			lbl_node.position = Vector2(cx - CHEST_W * 0.5, CHEST_H + 12.0)
	)
	return box


## A code-drawn chest: dim when locked, glowing when ready, open when taken.
func _chest_button(index: int, weekly: bool) -> Button:
	var opened := Missions.is_chest_open(index, weekly)
	var is_ready := Missions.is_chest_ready(index, weekly)
	var big := index == Missions.chests(weekly).size() - 1

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CHEST_W, CHEST_H)
	b.size = Vector2(CHEST_W, CHEST_H)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(_on_chest.bind(index, weekly))

	var art := CHEST_DIR + "chest_%d%s.png" % [index + 1, "_open" if opened else ""]
	if not ResourceLoader.exists(art) and opened:
		# No open art yet: use the closed chest, dimmed with a tick
		art = CHEST_DIR + "chest_%d.png" % (index + 1)
	if ResourceLoader.exists(art):
		_add_chest_art(b, art, is_ready, opened)
		return b

	var wood := Color("c8963c") if is_ready else (Color("2c3a52") if opened else Color("4a5a78"))
	if big and not opened:
		wood = Color("d96f3c") if is_ready else Color("6a4a5a")
	var trim := COL_GOLD if is_ready or big else Color("8a9ab8")

	b.draw.connect(func():
		var w := CHEST_W
		if is_ready:
			for g in 4:
				b.draw_circle(Vector2(w * 0.5, 40.0), 34.0 - g * 6.0, Color(1.0, 0.8, 0.35, 0.08))
		# Body
		b.draw_rect(Rect2(10, 34, w - 20, 30), wood)
		b.draw_rect(Rect2(10, 34, w - 20, 30), trim, false, 2.0)
		# Lid: shut, or tipped back when opened
		if opened:
			b.draw_colored_polygon(PackedVector2Array([
				Vector2(12, 34), Vector2(w - 12, 34), Vector2(w - 18, 18), Vector2(18, 18)]), wood.darkened(0.3))
			b.draw_polyline(PackedVector2Array([Vector2(28, 50), Vector2(36, 57), Vector2(52, 42)]),
				COL_OK, 4.0, true)
		else:
			b.draw_rect(Rect2(8, 18, w - 16, 16), wood.darkened(0.15))
			b.draw_rect(Rect2(8, 18, w - 16, 16), trim, false, 2.0)
			b.draw_rect(Rect2(w * 0.5 - 4.0, 18, 8, 46), trim)
			b.draw_rect(Rect2(w * 0.5 - 6.0, 30, 12, 10), Color("3a2a10"))
	)

	if is_ready:
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		b.pivot_offset = Vector2(CHEST_W * 0.5, CHEST_H * 0.6)
	return b


## Chest image on the button: glows and pulses when ready,
## gets a tick once opened.
func _add_chest_art(b: Button, path: String, is_ready: bool, opened: bool) -> void:
	b.draw.connect(func():
		if is_ready:
			for g in 5:
				b.draw_circle(Vector2(CHEST_W * 0.5, CHEST_H * 0.55), 40.0 - g * 6.0, Color(1.0, 0.8, 0.35, 0.09))
	)

	var tex := TextureRect.new()
	tex.texture = load(path) as Texture2D
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if opened:
		tex.modulate = Color(0.7, 0.7, 0.75)
	b.add_child(tex)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if opened:
		var tick := Control.new()
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tick)
		tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tick.draw.connect(func():
			var c := Vector2(CHEST_W - 14.0, CHEST_H - 12.0)
			tick.draw_circle(c, 12.0, Color("1c3a2a"))
			tick.draw_arc(c, 12.0, 0.0, TAU, 20, COL_OK, 2.0, true)
			tick.draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(6, -5)]),
				COL_OK, 3.0, true)
		)

	if is_ready:
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		b.pivot_offset = Vector2(CHEST_W * 0.5, CHEST_H * 0.6)


func _on_chest(index: int, weekly: bool) -> void:
	if Missions.is_chest_ready(index, weekly):
		var got := Missions.open_chest(index, weekly)
		if not got.is_empty():
			_toast(_describe(got), COL_OK)
		_rebuild()
		_check_card_choice()
		return
	var chest: Dictionary = Missions.chests(weekly)[index]
	var need := int(chest["points"])
	var footer := "Opened" if Missions.is_chest_open(index, weekly) else "Reach %d activity to open" % need
	_show_info("%s Chest  ·  %d" % ["Weekly" if weekly else "Daily", need],
		_describe(Missions.preview(index, weekly)), footer, COL_GOLD)


func _mission_row(m: Dictionary, weekly: bool) -> Control:
	var claimed := Missions.is_claimed(m, weekly)
	var is_ready := Missions.is_done(m, weekly) and not claimed
	var progress := mini(Missions.progress(m, weekly), int(m["goal"]))
	var goal := int(m["goal"])

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.08) if is_ready else Color(1, 1, 1, 0.03)
	sb.border_color = COL_GOLD if is_ready else Color("2c4466")
	sb.set_border_width_all(2 if is_ready else 1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", sb)
	if claimed:
		row.modulate = Color(0.6, 0.6, 0.65)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	h.add_child(texts)
	var desc_l := _label(str(m["desc"]), 22, COL_TITLE if is_ready else COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc_l)

	var fill := clampf(float(progress) / maxf(float(goal), 1.0), 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 3, w, 8), Color(0, 0, 0, 0.45))
		bar.draw_rect(Rect2(0, 3, w * fill, 8), COL_OK if is_ready or claimed else Color("8fc8ff"))
		bar.draw_rect(Rect2(0, 3, w, 8), Color(COL_GOLD, 0.3), false, 1.0)
	)
	texts.add_child(bar)
	texts.add_child(_label("%s / %s" % [NumberFormat.short(progress), NumberFormat.short(goal)],
		16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	var pts_l := _label("+%d" % int(m["points"]), 24, Color("ffb84d"))
	pts_l.custom_minimum_size.x = 60
	pts_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pts_l)

	if claimed:
		var done_l := _label("Done", 20, COL_DIM)
		done_l.custom_minimum_size.x = 140
		done_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(done_l)
	else:
		var claim := OrnateButton.new()
		claim.text = "Claim"
		claim.custom_minimum_size = Vector2(140, 52)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim.disabled = not is_ready
		claim.pressed.connect(_on_claim_mission.bind(str(m["id"]), weekly))
		h.add_child(claim)
	return row


func _on_claim_mission(id: String, weekly: bool) -> void:
	var gained := Missions.claim(id, weekly)
	if gained > 0:
		_toast("+%d activity" % gained, Color("ffb84d"))
	_rebuild()


# ---------------------------------------------------------
# ACHIEVEMENTS
# ---------------------------------------------------------

func _fraction(a: Dictionary) -> float:
	return float(Achievements.progress(str(a["track"]))) / maxf(float(a["goal"]), 1.0)


func _row(a: Dictionary) -> Control:
	var is_ready := Achievements.is_done(a)
	var progress := Achievements.progress(str(a["track"]))
	var goal := int(a["goal"])
	var waiting := Achievements.ready_in_chain(Achievements.get_chain(str(a["chain"])))

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.08) if is_ready else Color(1, 1, 1, 0.03)
	sb.border_color = COL_GOLD if is_ready else Color("2c4466")
	sb.set_border_width_all(2 if is_ready else 1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	h.add_child(texts)

	# Name and tier
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	texts.add_child(name_row)
	var name_l := _label(str(a["name"]), 24, COL_TITLE if is_ready else COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_l)
	var tier_l := _label(Achievements.tier_label(a), 17, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	tier_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tier_l)

	texts.add_child(_label(str(a["desc"]), 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	# Progress bar
	var fill := clampf(float(progress) / maxf(float(goal), 1.0), 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 3, w, 10), Color(0, 0, 0, 0.45))
		bar.draw_rect(Rect2(0, 3, w * fill, 10), COL_OK if is_ready else Color("8fc8ff"))
		bar.draw_rect(Rect2(0, 3, w, 10), Color(COL_GOLD, 0.3), false, 1.0)
	)
	texts.add_child(bar)

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 12)
	texts.add_child(count_row)
	count_row.add_child(_label("%s / %s" % [NumberFormat.short(progress), NumberFormat.short(goal)],
		16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if waiting > 1:
		count_row.add_child(_label("%d tiers ready" % waiting, 16, COL_OK, HORIZONTAL_ALIGNMENT_LEFT))

	# Rewards
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 8)
	texts.add_child(rewards)
	for key in a["rewards"]:
		rewards.add_child(_reward_chip(key, a["rewards"][key]))

	var claim := OrnateButton.new()
	claim.text = "Claim"
	claim.custom_minimum_size = Vector2(160, 56)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.disabled = not is_ready
	claim.pressed.connect(_on_claim.bind(str(a["id"])))
	h.add_child(claim)
	return row


## One reward: tappable, and it explains itself.
func _reward_chip(key, value) -> Control:
	var chip := Button.new()
	chip.flat = true
	chip.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	chip.add_theme_font_size_override("font_size", 17)
	chip.custom_minimum_size.y = 40

	match key:
		"jade":
			chip.text = "%s Jade" % NumberFormat.short(int(value))
			chip.add_theme_color_override("font_color", COL_JADE)
			chip.add_theme_color_override("font_hover_color", COL_JADE)
			chip.pressed.connect(_show_info.bind("Immortal Jade",
				"Premium currency, spent on summons and the shop.",
				"+%s" % NumberFormat.short(int(value)), COL_JADE))
		"stones":
			chip.text = "%s Stones" % NumberFormat.short(int(value))
			chip.add_theme_color_override("font_color", COL_STONES)
			chip.add_theme_color_override("font_hover_color", COL_STONES)
			chip.pressed.connect(_show_info.bind("Spirit Stones",
				"Spent on crafting, refining and the shop.",
				"+%s" % NumberFormat.short(int(value)), COL_STONES))
		"qi":
			chip.text = "%s Qi" % NumberFormat.short(int(value))
			chip.add_theme_color_override("font_color", Color("8ff0ff"))
			chip.pressed.connect(_show_info.bind("Qi",
				"Raises your realm and your partners' realms.",
				"+%s" % NumberFormat.short(int(value)), Color("8ff0ff")))
		"card", "card_choice":
			var tier := int(value)
			var tier_color := ItemDB.grade_color(Realms.tier_index(tier)).lightened(0.2)
			var tier_name := str(Enums.Rarity.keys()[tier]).capitalize()
			chip.text = "%s Card%s" % [tier_name, " (your pick)" if key == "card_choice" else ""]
			chip.add_theme_color_override("font_color", tier_color)
			chip.add_theme_color_override("font_hover_color", tier_color)
			var body := "A random %s partner joins you." % tier_name
			if key == "card_choice":
				body = "Choose one %s partner from several to join you." % tier_name
			chip.pressed.connect(_show_info.bind("%s Partner" % tier_name, body, "", tier_color))
		_:
			var item := ItemDB.get_item(str(key))
			chip.text = "%s %s" % [NumberFormat.short(int(value)), item.get("name", str(key))]
			var item_color: Color = ItemDB.grade_color(item.get("grade", 0)).lightened(0.2)
			chip.add_theme_color_override("font_color", item_color)
			chip.add_theme_color_override("font_hover_color", item_color)
			chip.pressed.connect(_show_info.bind(item.get("name", str(key)),
				item.get("desc", ""), "+%s" % NumberFormat.short(int(value)), item_color))
	return chip


## Small card explaining a reward.
func _show_info(title: String, body: String, footer: String, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 61
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free()
	)
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_label(title, 30, color, HORIZONTAL_ALIGNMENT_CENTER, true))
	var body_l := _label(body, 21, COL_TEXT)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body_l)
	if footer != "":
		v.add_child(_label(footer, 22, COL_GOLD))

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(240, 60)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


# ---------------------------------------------------------
# CHOOSING A CARD
# ---------------------------------------------------------

## Opens the chooser for the first pending card choice, if any.
func _check_card_choice() -> void:
	if GameState.pending_card_choices.is_empty():
		return
	var choice: Dictionary = GameState.pending_card_choices[0]

	var layer := CanvasLayer.new()
	layer.layer = 64
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	var tier_color := ItemDB.grade_color(Realms.tier_index(int(choice["tier"]))).lightened(0.2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = tier_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_label("Choose Your Partner", 34, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_label("Reward from: %s" % str(choice.get("from", "")), 19, COL_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)

	SummonCard.find_frames(self)
	var card_size := SummonCard.size_for_width(170.0)
	for id in choice["options"]:
		var data = PartnerDatabase.get_partner(str(id))
		if data == null:
			continue
		var pick := VBoxContainer.new()
		pick.custom_minimum_size.x = card_size.x
		pick.add_theme_constant_override("separation", 4)
		row.add_child(pick)

		var holder := Button.new()
		holder.flat = true
		holder.focus_mode = Control.FOCUS_NONE
		holder.custom_minimum_size = card_size
		for state in ["normal", "hover", "pressed", "focus"]:
			holder.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var card := SummonCard.new()
		card.setup({"partner_id": str(id)}, data.rarity, card_size)
		card.show_front()
		holder.add_child(card)
		holder.pressed.connect(_on_choose_card.bind(str(id), layer))
		pick.add_child(holder)

		var name_l := _label(data.display_name, 18, tier_color)
		name_l.custom_minimum_size.x = card_size.x
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pick.add_child(name_l)

		if GameState.find_owned(str(id)) != null:
			var owned_l := _label("owned  ·  fragment", 14, COL_DIM)
			owned_l.custom_minimum_size.x = card_size.x
			owned_l.clip_text = true
			pick.add_child(owned_l)

	v.add_child(_label("Tap a card to take it. This can't be undone.", 18, COL_DIM))


func _on_choose_card(partner_id: String, layer: CanvasLayer) -> void:
	if Achievements.choose_card(0, partner_id):
		var data = PartnerDatabase.get_partner(partner_id)
		_toast("%s joined you!" % (data.display_name if data != null else "A partner"), COL_OK)
	layer.queue_free()
	_rebuild()
	# More choices waiting? Show the next one.
	_check_card_choice.call_deferred()


func _on_claim(id: String) -> void:
	var got := Achievements.claim(id)
	if not got.is_empty():
		_toast(_describe(got), COL_OK)
	_rebuild()
	_check_card_choice()


func _on_claim_all() -> void:
	if _tab != "Achievements":
		_claim_all_missions(_tab == "Weekly")
		return
	var claimed := Achievements.claim_all()
	if claimed.is_empty():
		return
	var total := {}
	for entry in claimed:
		for key in entry["got"]:
			if key == "items":
				for id in entry["got"]["items"]:
					total[id] = int(total.get(id, 0)) + int(entry["got"]["items"][id])
			elif key == "card":
				total["card"] = str(entry["got"]["card"])
			else:
				total[key] = int(total.get(key, 0)) + int(entry["got"][key])
	_toast("%d claimed  ·  %s" % [claimed.size(), _describe(total)], COL_OK)
	_rebuild()
	_check_card_choice()


func _claim_all_missions(weekly: bool) -> void:
	var result := Missions.claim_all(weekly)
	var parts := PackedStringArray()
	if int(result["points"]) > 0:
		parts.append("+%d activity" % int(result["points"]))
	if int(result["chests"]) > 0:
		parts.append("%d chest%s" % [int(result["chests"]), "" if int(result["chests"]) == 1 else "s"])
		var got: Dictionary = result["got"]
		if not got.is_empty():
			parts.append(_describe(got))
	if not parts.is_empty():
		_toast("  ·  ".join(parts), COL_OK)
	_rebuild()
	_check_card_choice()


func _describe(got: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in got:
		match key:
			"jade":
				parts.append("+%s Jade" % NumberFormat.short(int(got[key])))
			"stones":
				parts.append("+%s Stones" % NumberFormat.short(int(got[key])))
			"qi":
				parts.append("+%s Qi" % NumberFormat.short(int(got[key])))
			"card":
				var data = PartnerDatabase.get_partner(str(got[key]))
				parts.append("%s joined!" % (data.display_name if data != null else "A partner"))
			"card_choice":
				parts.append("a partner to choose")
			"loot_hours":
				parts.append("%dh of stage drops" % int(got[key]))
			"items":
				for id in got[key]:
					parts.append("+%s %s" % [NumberFormat.short(int(got[key][id])),
						ItemDB.get_item(id).get("name", id)])
			_:
				parts.append("+%s %s" % [NumberFormat.short(int(got[key])),
					ItemDB.get_item(str(key)).get("name", str(key))])
	return "  ·  ".join(parts)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _draw_backdrop() -> void:
	var s := size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.4), false, 2.0)
	var m := 10.0
	var arm := 46.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(m + corner.x * (s.x - m * 2.0), m + corner.y * (s.y - m * 2.0))
		var dx := arm * (1.0 if corner.x == 0 else -1.0)
		var dy := arm * (1.0 if corner.y == 0 else -1.0)
		draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]),
			Color(COL_GOLD, 0.7), 2.0, true)


func _fade_line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(COL_GOLD, 0.0), Color(COL_GOLD, 0.7), Color(COL_GOLD, 0.0)]), 1.5, true)
	)
	return line


func _toast(text: String, color: Color) -> void:
	var l := _label(text, 26, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	_toast_holder.add_child(l)
	var r := get_global_rect()
	l.size = Vector2(r.size.x, 40)
	l.global_position = Vector2(r.position.x, r.position.y + r.size.y * 0.4)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.tween_callback(l.queue_free)


func _label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, glow := false) -> Label:
	var l := Label.new()
	l.text = text
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
