extends PanelContainer

# =========================================================
# Events tab, with two tabs of its own. Save as
#   res://ui/screens/events_screen.gd
#
# Daily Trial rules are in trials.gd.
# Challenge fights the next floor in the battle area above.
# Sweep re-collects your best floor. Rules are in dungeons.gd.
# =========================================================

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_SHORT := Color("ff7a7a")

const TABS := ["Daily", "Dungeons"]

var _fg_tick := 0
var _fg_window := -2

var _tab := "Daily"
var _tab_buttons := {}
var _title: Label
var _ranks: OrnateButton
var _list: VBoxContainer
var _status: Label
var _reset_label: Label
var _toast_holder: Control
var _battle: Node
var _fighting := false
var _clock := 0.0


func _ready() -> void:
	name = "EventsScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	_build()
	GameState.stage_changed.connect(_rebuild)
	GameState.roster_changed.connect(_rebuild)
	_connect_battle.call_deferred()
	_rebuild()


func on_opened() -> void:
	_connect_battle()
	if _battle != null and _battle.has_method("is_in_dungeon"):
		_fighting = _battle.call("is_in_dungeon")
	_rebuild()


func _connect_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		return
	_battle = Dungeons.find_battle(self)
	if _battle != null and _battle.has_signal("dungeon_finished"):
		_battle.connect("dungeon_finished", _on_dungeon_finished)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_reset_label.text = "Entries reset in %s" % Shop.time_until_reset()
		# Refresh the Fallen God countdown once a minute, and the moment he descends
		_fg_tick += 1
		var window := FallenGod.open_window()
		if _tab == "Daily" and not _fighting and (_fg_tick >= 60 or window != _fg_window):
			_fg_tick = 0
			_fg_window = window
			_rebuild()
		# Don't stay stuck on "Fighting..." if the battle already moved on
		if _fighting and _battle != null and is_instance_valid(_battle) \
				and _battle.has_method("is_in_dungeon") and not _battle.call("is_in_dungeon"):
			_fighting = false
			_rebuild()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_title = _label("Daily Challenges", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	titles.add_child(_title)
	titles.add_child(_label("Events", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_ranks = OrnateButton.new()
	_ranks.text = "Rankings"
	_ranks.custom_minimum_size = Vector2(170, 46)
	_ranks.add_theme_font_size_override("font_size", 19)
	_ranks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ranks.pressed.connect(_open_rankings.bind(""))
	head.add_child(_ranks)

	_reset_label = _label("", 18, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_reset_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_reset_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for tab in TABS:
		var b := _make_tab(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons[tab] = b

	v.add_child(_fade_line())

	_status = _label("", 20, COL_GOLD)
	_status.custom_minimum_size.y = 28
	v.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	# Padding: room above the first heading (so its glow isn't clipped)
	# and on the right so the scroll bar never covers anything
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
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
		if tab != _tab:
			return
		var w := b.size.x
		var y := b.size.y - 4.0
		b.draw_rect(Rect2(0, 0, w, b.size.y), Color(COL_GOLD, 0.05))
		b.draw_rect(Rect2(w * 0.12, y - 1.0, w * 0.76, 3.0), COL_GOLD)
		var c := Vector2(w * 0.5, y)
		b.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), Color("ffe6a8"))
	)
	return b


func _select_tab(tab: String) -> void:
	_tab = tab
	_rebuild()


func _rebuild() -> void:
	_reset_label.text = "Entries reset in %s" % Shop.time_until_reset()
	var dungeons := _tab == "Dungeons"
	_title.text = "Dungeon Hall" if dungeons else "Daily Challenges"
	_ranks.visible = dungeons
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		b.add_theme_color_override("font_color", Color("ffe6a8") if key == _tab else COL_DIM)
		b.queue_redraw()
	if _fighting:
		_status.text = "Fighting on the battlefield above..."
	elif dungeons:
		_status.text = "Clear floors to climb. Only victories use an entry."
	else:
		_status.text = "A new trial every day. Sunday opens them all."

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	if dungeons:
		for def in Dungeons.LIST:
			_list.add_child(_dungeon_card(def))
		return

	# Daily tab: today's trial(s), then Tribulation Lightning
	_list.add_child(_section_title("Daily Trial",
		"Sunday: every trial is open" if Trials.is_free_day() else "A new trial opens every day",
		"Entries %d / %d" % [Trials.entries_left(), Trials.ENTRIES_PER_DAY]))
	_list.add_child(_fortune_card())
	_list.add_child(_fade_line())
	if Unlocks.is_unlocked("trials"):
		for def in Trials.open_today():
			_list.add_child(_trial_card(def))
	else:
		_list.add_child(_locked_card("trials"))
	_list.add_child(_fade_line())
	_list.add_child(_tribulation_card() if Unlocks.is_unlocked("tribulation") else _locked_card("tribulation"))
	_list.add_child(_fade_line())
	_list.add_child(_fallen_god_card() if Unlocks.is_unlocked("god_path") else _locked_card("god_path"))
	_list.add_child(_fade_line())
	_list.add_child(_beast_forest_card() if Unlocks.is_unlocked("beast_forest") else _locked_card("beast_forest"))


func _dungeon_card(def: Dictionary) -> Control:
	var color: Color = def["color"]
	var open: bool = def.get("open", false)
	var unlocked := Dungeons.is_unlocked(def)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.06) if unlocked else Color(1, 1, 1, 0.025)
	sb.border_color = Color(color, 0.7) if unlocked else Color("2c3a50")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)

	h.add_child(_emblem(def, color, unlocked))

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	h.add_child(mid)

	var name_l := _label(def["name"], 28, color.lightened(0.2) if unlocked else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	name_l.custom_minimum_size.y = 36
	mid.add_child(name_l)
	var desc := _label(def["desc"], 18, COL_TEXT if unlocked else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(desc)

	# Sealed (needs a future system) or not yet reached
	var requirement := Dungeons.requirement_text(def)
	if not open:
		var sealed: String = def.get("sealed", "Coming soon")
		if requirement != "":
			sealed += "  ·  %s to enter" % requirement
		var sealed_l := _label(sealed, 19, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		sealed_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(sealed_l)
		return card
	if not unlocked:
		mid.add_child(_label("%s to enter" % requirement, 20, COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))
		return card

	var top := Dungeons.highest(def)
	var next := Dungeons.next_floor(def)
	var left := Dungeons.entries_left(def)
	mid.add_child(_label("Best floor  %d / %s     Entries today  %d / %d" % [
		top, NumberFormat.short(Dungeons.MAX_FLOOR), left, Dungeons.ENTRIES_PER_DAY],
		18, COL_OK if left > 0 else COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))

	# Rewards of the next floor
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 8)
	mid.add_child(reward_row)
	var boss := "  (Boss)" if Dungeons.is_boss_floor(next) else ""
	reward_row.add_child(_label("Floor %d%s:" % [next, boss], 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var rewards := Dungeons.rewards_for(def, next)
	for id in rewards:
		if id == Dungeons.JADE_KEY:
			var jade := _jade_chip(int(rewards[id]))
			reward_row.add_child(jade)
			continue
		if id == Dungeons.TREASURE_KEY:
			var sample_t := Treasures.make(Treasures.LIST.keys()[0], int(sqrt(float(next)) * 0.55))
			var t_icon := TreasureIcon.new()
			t_icon.custom_minimum_size = Vector2(56, 56)
			t_icon.setup(sample_t)
			t_icon.pressed.connect(_show_info.bind("Treasure",
				"A random treasure from one of the eight sets. Fill all 3 treasure slots with one set "
				+ "for its effect. Deeper floors drop higher grades.",
				"Around %s  ·  You'll get %d" % [Treasures.grade_name(int(sample_t["grade"])), rewards[id]],
				Treasures.grade_color(int(sample_t["grade"])).lightened(0.2)))
			reward_row.add_child(t_icon)
			reward_row.add_child(_label("×%d" % rewards[id], 17, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
			continue
		if id == Dungeons.GEAR_KEY:
			# Preview of the grade this floor drops
			var sample := Gear.make(0, int(sqrt(float(next)) * 1.9), "five_elements")
			var preview := GearIcon.new()
			preview.custom_minimum_size = Vector2(56, 56)
			preview.setup(sample)
			preview.pressed.connect(_show_gear_info.bind(sample, int(rewards[id])))
			reward_row.add_child(preview)
			reward_row.add_child(_label("×%d" % rewards[id], 17, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
			continue
		var slot := ItemSlot.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.setup_item(id, int(rewards[id]))
		slot.pressed.connect(_show_item_info.bind(id, int(rewards[id])))
		reward_row.add_child(slot)

	# Buttons
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	h.add_child(buttons)

	var fight := OrnateButton.new()
	fight.text = "Challenge F%d" % next
	fight.custom_minimum_size = Vector2(210, 60)
	fight.disabled = _fighting or left <= 0 or top >= Dungeons.MAX_FLOOR
	fight.pressed.connect(_on_challenge.bind(def))
	buttons.add_child(fight)

	var ranked := OrnateButton.new()
	ranked.text = "Rank #%d" % Ranking.player_rank(def["id"])
	ranked.variant = OrnateButton.Variant.DARK
	ranked.custom_minimum_size = Vector2(210, 44)
	ranked.add_theme_font_size_override("font_size", 17)
	ranked.pressed.connect(_open_rankings.bind(def["id"]))
	buttons.add_child(ranked)

	var sweep := OrnateButton.new()
	sweep.text = "Sweep F%d" % top if top > 0 else "Sweep"
	sweep.variant = OrnateButton.Variant.DARK
	sweep.custom_minimum_size = Vector2(210, 50)
	sweep.add_theme_font_size_override("font_size", 19)
	sweep.disabled = _fighting or left <= 0 or top <= 0
	sweep.pressed.connect(_on_sweep.bind(def))
	buttons.add_child(sweep)

	return card


## Folder for dungeon emblem art, named by dungeon id (star_trial.png ...).
const EMBLEM_DIR := "res://assets/ui/dungeons/"


## Dungeon emblem: the art in EMBLEM_DIR if it exists, else drawn.
## Locked dungeons show the art darkened, with a padlock.
func _emblem(def: Dictionary, color: Color, lit: bool) -> Control:
	var path := EMBLEM_DIR + "%s.png" % str(def["id"])
	if not ResourceLoader.exists(path):
		return _drawn_emblem(str(def["emblem"]), color, lit)

	var e := Control.new()
	e.custom_minimum_size = Vector2(110, 110)
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var tex := TextureRect.new()
	tex.texture = load(path) as Texture2D
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not lit:
		tex.modulate = Color(0.4, 0.42, 0.48)
	e.add_child(tex)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if not lit:
		var lock_layer := Control.new()
		lock_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.add_child(lock_layer)
		lock_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lock_layer.draw.connect(func():
			var center := lock_layer.size * 0.5
			var lock := Rect2(center - Vector2(14, 6), Vector2(28, 22))
			lock_layer.draw_arc(lock.position + Vector2(14, 0), 9.0, PI, TAU, 12, COL_TEXT, 4.0, true)
			lock_layer.draw_rect(lock, COL_TEXT)
			lock_layer.draw_rect(Rect2(center + Vector2(-2, 1), Vector2(4, 8)), Color(0, 0, 0, 0.6))
		)
	return e


## Drawn dungeon emblem: gold ring and a symbol.
func _drawn_emblem(kind: String, color: Color, lit: bool) -> Control:
	var e := Control.new()
	e.custom_minimum_size = Vector2(110, 110)
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c := color if lit else Color("56637a")
	e.draw.connect(func():
		var center := e.size * 0.5
		var r := e.size.x * 0.42
		for i in 5:
			e.draw_circle(center, r * (1.1 - i * 0.12), Color(c, 0.05))
		e.draw_arc(center, r, 0.0, TAU, 48, COL_GOLD if lit else Color("56637a"), 2.0, true)
		e.draw_arc(center, r * 0.82, 0.0, TAU, 48, Color(c, 0.5), 1.0, true)
		match kind:
			"star":
				var pts := PackedVector2Array()
				for k in 10:
					var a := TAU * k / 10.0 - PI * 0.5
					pts.append(center + Vector2(cos(a), sin(a)) * r * (0.62 if k % 2 == 0 else 0.26))
				e.draw_colored_polygon(pts, c)
			"claw":
				for k in 3:
					var x := center.x + (k - 1) * r * 0.32
					var pts := PackedVector2Array()
					for t in 8:
						var u := t / 7.0
						pts.append(Vector2(x + sin(u * 1.4) * r * 0.18, center.y - r * 0.55 + u * r * 1.1))
					e.draw_polyline(pts, c, 5.0, true)
			"sword":
				e.draw_line(center + Vector2(0, -r * 0.6), center + Vector2(0, r * 0.45), c, 5.0, true)
				e.draw_line(center + Vector2(-r * 0.3, r * 0.25), center + Vector2(r * 0.3, r * 0.25), c, 4.0, true)
				e.draw_circle(center + Vector2(0, r * 0.58), 5.0, c)
			"chest":
				var box := Rect2(center - Vector2(r * 0.5, r * 0.15), Vector2(r, r * 0.55))
				e.draw_rect(box, c)
				e.draw_rect(Rect2(box.position - Vector2(0, r * 0.28), Vector2(r, r * 0.3)), c.lightened(0.2))
				e.draw_rect(Rect2(center - Vector2(4, 6), Vector2(8, 12)), COL_GOLD)
		if not lit:
			# padlock
			var lock := Rect2(center + Vector2(r * 0.3, r * 0.3), Vector2(18, 14))
			e.draw_rect(lock, COL_DIM)
			e.draw_arc(lock.position + Vector2(9, 0), 6.0, PI, TAU, 10, COL_DIM, 2.5, true)
	)
	return e


## Jade reward, tappable like the item icons.
func _jade_chip(amount: int) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", COL_OK)
	b.add_theme_color_override("font_hover_color", COL_OK)
	b.text = "%s Jade" % NumberFormat.short(amount)
	b.pressed.connect(_show_info.bind("Immortal Jade", "Premium currency. Spent on summons, renames and the shop.",
		"You'll get %s" % NumberFormat.short(amount), COL_OK))
	return b


func _show_item_info(id: String, amount: int) -> void:
	var item := ItemDB.get_item(id)
	var grade: int = item.get("grade", 0)
	_show_info(item.get("name", id),
		item.get("desc", ""),
		"%s  ·  You'll get %s" % [ItemDB.grade_name(grade), NumberFormat.short(amount)],
		ItemDB.grade_color(grade).lightened(0.2))


func _show_gear_info(sample: Dictionary, amount: int) -> void:
	_show_info("Equipment",
		"A random weapon, armor, ring or boots from this floor. Deeper floors drop higher grades, "
		+ "and every piece belongs to one of the eight sets.",
		"Around %s  ·  You'll get %d piece%s" % [Gear.grade_text(sample), amount, "" if amount == 1 else "s"],
		Gear.tier_color(sample).lightened(0.2))


## Small card: what a reward is and how much of it you get.
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
	panel.custom_minimum_size = Vector2(700, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_label(title, 32, color, HORIZONTAL_ALIGNMENT_CENTER, true))
	var body_l := _label(body, 21, COL_TEXT)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body_l)
	v.add_child(_label(footer, 20, COL_GOLD))

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(240, 64)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


# ---------------------------------------------------------
# RANKINGS
# ---------------------------------------------------------

var _rank_layer: CanvasLayer
var _rank_dungeon := ""
var _rank_body: VBoxContainer


func _open_rankings(dungeon_id: String) -> void:
	if dungeon_id == "":
		for def in Dungeons.LIST:
			if Dungeons.is_unlocked(def):
				dungeon_id = def["id"]
				break
	if dungeon_id == "":
		_toast("Unlock a dungeon first.", COL_SHORT)
		return
	_rank_dungeon = dungeon_id

	if is_instance_valid(_rank_layer):
		_rank_layer.queue_free()
	_rank_layer = CanvasLayer.new()
	_rank_layer.layer = 61
	add_child(_rank_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_rank_layer.queue_free()
	)
	_rank_layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	_rank_body = VBoxContainer.new()
	_rank_body.add_theme_constant_override("separation", 10)
	panel.add_child(_rank_body)
	_build_rankings()


func _build_rankings() -> void:
	for c in _rank_body.get_children():
		_rank_body.remove_child(c)
		c.queue_free()

	var def := Dungeons.get_def(_rank_dungeon)
	_rank_body.add_child(_label("Dungeon Rankings", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	_rank_body.add_child(_label("Ranked by best floor. Rewards arrive by mail each day.", 19, COL_DIM))

	# Dungeon switcher
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	_rank_body.add_child(tabs)
	for d in Dungeons.LIST:
		if not Dungeons.is_unlocked(d):
			continue
		var b := OrnateButton.new()
		b.text = d["name"]
		b.variant = OrnateButton.Variant.GOLD if d["id"] == _rank_dungeon else OrnateButton.Variant.DARK
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_switch_ranking.bind(d["id"]))
		tabs.add_child(b)

	_rank_body.add_child(_fade_line())

	var list := Ranking.board(_rank_dungeon)
	var my_rank := Ranking.player_rank(_rank_dungeon)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 380)
	_rank_body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)

	for i in mini(Ranking.SHOWN, list.size()):
		rows.add_child(_rank_row(i + 1, list[i]))
	if my_rank > Ranking.SHOWN:
		rows.add_child(_label("...", 20, COL_DIM))
		rows.add_child(_rank_row(my_rank, list[my_rank - 1]))

	_rank_body.add_child(_fade_line())
	_rank_body.add_child(_label("Daily Jade  ·  yours: rank %d → %d Jade" % [
		my_rank, Ranking.reward_for_rank(my_rank)], 20, COL_OK))
	var table := HBoxContainer.new()
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	table.add_theme_constant_override("separation", 18)
	_rank_body.add_child(table)
	for row in Ranking.reward_table():
		table.add_child(_label("%s: %d" % [row["label"], row["jade"]], 17, COL_DIM))

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(240, 64)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): _rank_layer.queue_free())
	_rank_body.add_child(close)


func _switch_ranking(dungeon_id: String) -> void:
	_rank_dungeon = dungeon_id
	_build_rankings()


func _rank_row(place: int, entry: Dictionary) -> Control:
	var mine: bool = entry["is_player"]
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.12) if mine else Color(1, 1, 1, 0.02)
	sb.border_color = Color(COL_GOLD, 0.8) if mine else Color(0, 0, 0, 0)
	sb.set_border_width_all(2 if mine else 0)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)

	var place_color := COL_GOLD if place <= 3 else COL_DIM
	var place_l := _label("#%d" % place, 20, place_color, HORIZONTAL_ALIGNMENT_RIGHT)
	place_l.custom_minimum_size.x = 70
	h.add_child(place_l)

	var name_l := _label(str(entry["name"]), 20, COL_TITLE if mine else COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	h.add_child(name_l)

	h.add_child(_label("Floor %d" % int(entry["floor"]), 20, COL_OK if mine else COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	return row


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

## Heading above a group of cards.
func _section_title(title: String, sub: String, right: String) -> Control:
	var h := HBoxContainer.new()
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	texts.add_child(_label(title, 26, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	if sub != "":
		texts.add_child(_label(sub, 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if right != "":
		var r := _label(right, 19, COL_OK if Trials.entries_left() > 0 else COL_SHORT, HORIZONTAL_ALIGNMENT_RIGHT)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(r)
	return h


func _trial_card(def: Dictionary) -> Control:
	var color: Color = def["color"]
	var unlocked := Trials.is_unlocked()

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07) if unlocked else Color(1, 1, 1, 0.025)
	sb.border_color = Color(color, 0.8) if unlocked else Color("2c3a50")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	h.add_child(_emblem(def, color, unlocked))

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	h.add_child(mid)

	var name_l := _label(def["name"], 28, color.lightened(0.2) if unlocked else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	name_l.custom_minimum_size.y = 36
	mid.add_child(name_l)
	var desc := _label(def["desc"], 18, COL_TEXT if unlocked else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(desc)
	mid.add_child(_label(Trials.dao_text(def), 18, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))

	if not unlocked:
		mid.add_child(_label("Reach Stage %d to enter" % Trials.UNLOCK_STAGE, 20, COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))
		return card

	var top := Trials.highest(def)
	var next := Trials.next_tier(def)
	var left := Trials.entries_left()
	mid.add_child(_label("Best tier  %d / %d" % [top, Trials.MAX_TIER], 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))

	# Rewards of the next tier
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 8)
	mid.add_child(reward_row)
	var boss := "  (Boss)" if Trials.is_boss_tier(next) else ""
	reward_row.add_child(_label("Tier %d%s:" % [next, boss], 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var rewards := Trials.rewards_for(def, next)
	for id in rewards:
		if id == Dungeons.JADE_KEY:
			reward_row.add_child(_jade_chip(int(rewards[id])))
			continue
		var slot := ItemSlot.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.setup_item(id, int(rewards[id]))
		slot.pressed.connect(_show_item_info.bind(id, int(rewards[id])))
		reward_row.add_child(slot)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	h.add_child(buttons)

	var fight := OrnateButton.new()
	fight.text = "Challenge T%d" % next
	fight.custom_minimum_size = Vector2(210, 60)
	fight.disabled = _fighting or left <= 0 or top >= Trials.MAX_TIER
	fight.pressed.connect(_on_trial_challenge.bind(def))
	buttons.add_child(fight)

	var sweep := OrnateButton.new()
	sweep.text = "Sweep T%d" % top if top > 0 else "Sweep"
	sweep.variant = OrnateButton.Variant.DARK
	sweep.custom_minimum_size = Vector2(210, 50)
	sweep.add_theme_font_size_override("font_size", 19)
	sweep.disabled = _fighting or left <= 0 or top <= 0
	sweep.pressed.connect(_on_trial_sweep.bind(def))
	buttons.add_child(sweep)
	return card


## Tribulation Lightning: once a day, survive the heavens' strikes.
func _tribulation_card() -> Control:
	var def := {"id": "tribulation_lightning", "emblem": "star"}
	var color := Color("b89cff")
	var unlocked := Tribulation.is_unlocked()
	var done := Tribulation.done_today()

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07) if unlocked else Color(1, 1, 1, 0.025)
	sb.border_color = Color(color, 0.8) if unlocked and not done else Color("2c3a50")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	h.add_child(_emblem(def, color, unlocked))

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	h.add_child(mid)
	var name_l := _label("Tribulation Lightning", 28, color.lightened(0.2) if unlocked else COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	name_l.custom_minimum_size.y = 36
	mid.add_child(name_l)
	var desc := _label("Once a day, your team faces up to %d waves of ever-stronger lightning. Every %dth wave "
		% [Tribulation.MAX_WAVES, Tribulation.GREAT_EVERY]
		+ "strikes everyone. Only true strength lasts: the further you get, the richer the reward.", 18,
		COL_TEXT if unlocked else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(desc)

	if not unlocked:
		mid.add_child(_label("Reach Stage %d to enter" % Tribulation.UNLOCK_STAGE, 20, COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))
		return card

	mid.add_child(_label("Best  %d / %d waves" % [Tribulation.best(), Tribulation.MAX_WAVES], 18, COL_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT))
	var marks := PackedStringArray()
	var keys: Array = Tribulation.MILESTONES.keys()
	keys.sort()
	for k in keys:
		marks.append(str(k))
	mid.add_child(_label("Milestone rewards at waves  " + " · ".join(marks), 16, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))

	var face := OrnateButton.new()
	face.text = "Faced Today" if done else "Face Tribulation"
	face.custom_minimum_size = Vector2(230, 64)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.disabled = done or _fighting
	face.pressed.connect(_on_tribulation)
	h.add_child(face)
	return card


func _on_tribulation() -> void:
	var error := Tribulation.can_start()
	if error != "":
		_toast(error, COL_SHORT)
		return
	var scene := TribulationScene.open(self)
	scene.finished.connect(_rebuild)
	_rebuild()


## Descent of the Fallen God: daily boss for Divinity EXP and Divine Essence.
func _fallen_god_card() -> Control:
	var def := {"id": "fallen_god", "emblem": "star"}
	var color := Color("ffd36b")
	var unlocked := FallenGod.is_unlocked()
	var window := FallenGod.open_window()
	var open := window >= 0

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.08) if unlocked else Color(1, 1, 1, 0.025)
	sb.border_color = Color(color, 0.9) if unlocked and open else Color("2c3a50")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	h.add_child(_emblem(def, color, unlocked))

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	h.add_child(mid)
	var name_l := _label("Descent of the Fallen God", 28, color.lightened(0.2) if unlocked else COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	name_l.custom_minimum_size.y = 36
	mid.add_child(name_l)
	var desc := _label("Three times a day a fallen god descends. He cannot die: strike as hard as you can "
		+ "in %d rounds for Divinity EXP and Divine Essence." % FallenGod.ROUNDS, 18,
		COL_TEXT if unlocked else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(desc)

	if not unlocked:
		mid.add_child(_label(FallenGod.can_attack(), 20, COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))
		return card

	var hours := PackedStringArray()
	for hr in FallenGod.WINDOWS:
		hours.append("%02d:00" % int(hr))
	mid.add_child(_label("Descends at " + "  ·  ".join(hours) + "  (%dh each)" % FallenGod.WINDOW_HOURS,
		16, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	if open:
		mid.add_child(_label("HE HAS DESCENDED  ·  leaves in %s  ·  attacks %d / %d" % [
			FallenGod.time_text(FallenGod.seconds_left_in_window()), FallenGod.attacks_left(),
			FallenGod.ATTACKS_PER_WINDOW], 18, COL_OK, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		mid.add_child(_label("Next descent at %02d:00  (in %s)" % [FallenGod.next_window_hour(),
			FallenGod.time_text(FallenGod.seconds_to_next_window())], 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var best := FallenGod.best_today()
	var rank := FallenGod.today_rank()
	mid.add_child(_label("Best today: %s damage%s" % [NumberFormat.short(best),
		"  ·  rank #%d" % rank if rank > 0 else ""], 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))

	# Yesterday's rank reward
	var prev_rank := FallenGod.claimable_rank()
	if prev_rank > 0:
		var reward := FallenGod.rank_reward(prev_rank)
		var claim_row := HBoxContainer.new()
		claim_row.add_theme_constant_override("separation", 10)
		mid.add_child(claim_row)
		var claim_l := _label("Yesterday: rank #%d  ·  %d Jade + %d Divine Essence" % [prev_rank, reward[0], reward[1]],
			17, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		claim_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim_row.add_child(claim_l)
		var claim := OrnateButton.new()
		claim.text = "Claim"
		claim.custom_minimum_size = Vector2(140, 46)
		claim.add_theme_font_size_override("font_size", 18)
		claim.pressed.connect(_on_fallen_claim)
		claim_row.add_child(claim)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	h.add_child(buttons)
	var attack := OrnateButton.new()
	attack.text = "Attack" if open else "Not Here"
	attack.custom_minimum_size = Vector2(210, 60)
	attack.disabled = _fighting or FallenGod.can_attack() != ""
	attack.pressed.connect(_on_fallen_attack)
	buttons.add_child(attack)
	var board := OrnateButton.new()
	board.text = "Rankings"
	board.variant = OrnateButton.Variant.DARK
	board.custom_minimum_size = Vector2(210, 50)
	board.add_theme_font_size_override("font_size", 19)
	board.pressed.connect(_open_fallen_rankings)
	buttons.add_child(board)
	return card


## A dimmed placeholder for a feature that isn't open yet.
func _locked_card(id: String) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.025)
	sb.border_color = Color("2c3a50")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	v.add_child(_label(Unlocks.feature_name(id), 26, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_label(str(Unlocks.FEATURES[id][4]), 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_label(Unlocks.requirement_text(id), 18, COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))
	return card


## Beast Forest: hunt spirit beasts for Beast Rings and Beast Cores.
func _beast_forest_card() -> Control:
	var color := Color("8fe0a8")
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.06)
	sb.border_color = Color(color, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	head.add_child(_emblem({"id": "beast_forest", "emblem": "claw"}, color, true))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	head.add_child(mid)
	var name_l := _label("Beast Forest", 28, color.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true)
	name_l.custom_minimum_size.y = 36
	mid.add_child(name_l)
	var desc := _label("Hunt spirit beasts for Beast Rings. Older beasts roam deeper grounds and drop finer rings. "
		+ "Only victories use a hunt.", 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(desc)
	var hunts := HBoxContainer.new()
	hunts.add_theme_constant_override("separation", 12)
	mid.add_child(hunts)
	var left_l := _label("Hunts  %d / %d" % [Beasts.hunts_left(), Beasts.HUNTS_PER_DAY], 20,
		COL_OK if Beasts.hunts_left() > 0 else COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT)
	left_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hunts.add_child(left_l)
	if Beasts.hunts_left() <= 0 and Ads.can_watch("extra_hunt"):
		var ad := OrnateButton.new()
		ad.text = "Watch Ad: +1 Hunt"
		ad.custom_minimum_size = Vector2(240, 46)
		ad.add_theme_font_size_override("font_size", 17)
		ad.pressed.connect(_on_ad_hunt)
		hunts.add_child(ad)
	if Beasts.hunts_left() <= 0 and Beasts.refreshes_left() > 0:
		var buy := OrnateButton.new()
		buy.text = "+1 Hunt  (%d Jade)" % Beasts.REFRESH_JADE
		buy.variant = OrnateButton.Variant.DARK
		buy.custom_minimum_size = Vector2(240, 46)
		buy.add_theme_font_size_override("font_size", 17)
		buy.pressed.connect(_on_buy_hunt)
		hunts.add_child(buy)

	for g in Beasts.GROUNDS:
		v.add_child(_ground_row(g))
	return card


func _ground_row(g: Dictionary) -> Control:
	var open := Beasts.ground_open(g)
	var color: Color = g["color"]
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07) if open else Color(1, 1, 1, 0.025)
	sb.border_color = Color(color, 0.6) if open else Color("2c3a50")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var ring := ItemSlot.new()
	ring.custom_minimum_size = Vector2(64, 64)
	ring.show_count = false
	ring.setup_item(Beasts.ring_icon_id(Beasts.grade_index(int(g["grade"]))), 0)
	ring.disabled = true
	if not open:
		ring.modulate = Color(0.45, 0.45, 0.5)
	h.add_child(ring)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)
	texts.add_child(_label("%s  ·  %s" % [g["name"], g["age"]], 21, color.lightened(0.2) if open else COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT))
	var names := PackedStringArray()
	for sp in g["species"]:
		names.append(Beasts.species_name(str(sp)))
	var sp_l := _label(", ".join(names), 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	sp_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(sp_l)
	var g_idx := Beasts.grade_index(int(g["grade"]))
	if open:
		texts.add_child(_label("%s rings (sometimes %s)  ·  +%d Beast Cores" % [Beasts.grade_name(g_idx),
			Beasts.grade_name(mini(g_idx + 1, 6)), int(g["cores"])], 16, Beasts.grade_text_color(g_idx),
			HORIZONTAL_ALIGNMENT_LEFT))
	else:
		texts.add_child(_label(Beasts.can_hunt(g), 16, COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))

	var hunt := OrnateButton.new()
	hunt.text = "Hunt"
	hunt.custom_minimum_size = Vector2(150, 56)
	hunt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hunt.disabled = _fighting or Beasts.can_hunt(g) != ""
	hunt.pressed.connect(_on_hunt.bind(str(g["id"])))
	h.add_child(hunt)
	return row


func _on_hunt(ground_id: String) -> void:
	_connect_battle()
	var error := Beasts.challenge(self, ground_id)
	if error != "":
		_toast(error, COL_SHORT)
		return
	_fighting = true
	_rebuild()


func _on_ad_hunt() -> void:
	if await Ads.watch(self, "extra_hunt"):
		Beasts.grant_extra_hunt()
		_toast("+1 hunt today.", COL_OK)
	_rebuild()


## Heavenly Fortune: up to 5 rewarded ads a day, each a better reward.
func _fortune_card() -> Control:
	var color := Color("ffd36b")
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07)
	sb.border_color = Color(color, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	v.add_child(_label("Heavenly Fortune", 26, color.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
	var done := Ads.used("fortune")
	var total := Ads.FORTUNE_REWARDS.size()
	v.add_child(_label("Watch a short ad for a gift, up to %d times a day. Each gift is better than the last." % total,
		16, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	# Progress pips: claimed gifts filled in
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	for i in total:
		var pip := Control.new()
		pip.custom_minimum_size = Vector2(26, 26)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var filled := i < done
		pip.draw.connect(func():
			var c := pip.size * 0.5
			var r := 10.0
			var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			if filled:
				pip.draw_colored_polygon(diamond, COL_OK)
			diamond.append(diamond[0])
			pip.draw_polyline(diamond, COL_OK if filled else COL_DIM, 2.0, true)
		)
		pips.add_child(pip)
	v.add_child(pips)
	var next := Ads.next_fortune()
	if next.is_empty():
		v.add_child(_label("All of today's gifts claimed. Come back tomorrow!", 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var parts := PackedStringArray()
		for key in next:
			match str(key):
				"jade":
					parts.append("%d Jade" % int(next[key]))
				"stones_hours":
					parts.append("%dh of Spirit Stones" % int(next[key]))
				_:
					parts.append("%s ×%d" % [str(ItemDB.get_item(str(key)).get("name", key)), int(next[key])])
		v.add_child(_label("Next gift (%d / %d): %s" % [done + 1, total, ", ".join(parts)], 17, COL_GOLD,
			HORIZONTAL_ALIGNMENT_LEFT))
	# Daily ad chests: by total ads watched today (every placement counts)
	var chests := HBoxContainer.new()
	chests.add_theme_constant_override("separation", 12)
	v.add_child(chests)
	chests.add_child(_label("Ads today: %d" % Ads.total_today(), 16, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	for i in Ads.AD_CHESTS.size():
		chests.add_child(_ad_chest(i))
	var watch := OrnateButton.new()
	watch.text = "Watch Ad" if not next.is_empty() else "Done Today"
	watch.custom_minimum_size = Vector2(210, 60)
	watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	watch.disabled = next.is_empty()
	watch.pressed.connect(_on_fortune)
	h.add_child(watch)
	return card


## One daily ad chest: closed, glowing when ready, open when claimed.
func _ad_chest(index: int) -> Control:
	var need := int(Ads.AD_CHESTS[index][0])
	var claimed := Ads.chest_claimed(index)
	var is_ready := Ads.chest_ready(index)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var b := TextureButton.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var n := index + 1
	var closed_path := "res://assets/ui/chests/chest_%d.png" % n
	var open_path := "res://assets/ui/chests/chest_%d_open.png" % n
	var path := open_path if claimed and ResourceLoader.exists(open_path) else closed_path
	if ResourceLoader.exists(path):
		b.texture_normal = load(path) as Texture2D
	if claimed:
		b.modulate = Color(0.55, 0.55, 0.6)
	elif not is_ready:
		b.modulate = Color(0.75, 0.75, 0.8)
	b.disabled = not is_ready
	b.pressed.connect(_on_ad_chest.bind(index))
	box.add_child(b)
	box.add_child(_label("Opened" if claimed else str(need), 14, COL_OK if is_ready else COL_DIM))
	if is_ready:
		var pulse := b.create_tween().set_loops()
		pulse.tween_property(b, "modulate", Color(1.3, 1.2, 0.9), 0.5)
		pulse.tween_property(b, "modulate", Color.WHITE, 0.5)
	return box


func _on_ad_chest(index: int) -> void:
	var got := Ads.claim_chest(index)
	if got != "":
		_toast("Ad chest: " + got, COL_OK)
	_rebuild()


func _on_fortune() -> void:
	var reward := Ads.next_fortune()
	if reward.is_empty():
		return
	if await Ads.watch(self, "fortune"):
		_toast(Ads.give_fortune(reward), COL_OK)
	_rebuild()


func _on_buy_hunt() -> void:
	var error := Beasts.buy_hunt()
	if error != "":
		_toast(error, COL_SHORT)
	else:
		_toast("+1 hunt today.", COL_OK)
	_rebuild()


func _on_fallen_attack() -> void:
	_connect_battle()
	var error := FallenGod.challenge(self)
	if error != "":
		_toast(error, COL_SHORT)
		return
	_fighting = true
	_rebuild()


func _on_fallen_claim() -> void:
	var got := FallenGod.claim_rank_reward()
	if not got.is_empty():
		_toast("Rank #%d  ·  +%d Jade  ·  +%d Divine Essence" % [got[0], got[1], got[2]], COL_OK)
	_rebuild()


## Today's board: simulated rivals and you, by best single attack.
func _open_fallen_rankings() -> void:
	var s := GameState.fallen_god
	var day := GameState.today()
	var rows := FallenGod.board(day, float(s.get("best_ratio", 0.0)) if int(s.get("day", 0)) == day else 0.0)
	var ref := FallenGod.reference_hp()

	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
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
	sb.border_color = Color("ffd36b")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = 760
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(_label("Fallen God Rankings", 32, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_label("Best single attack today  ·  rewards paid tomorrow", 17, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 900)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var you := bool(row.get("you", false))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var col := COL_OK if you else (COL_GOLD if i < 3 else COL_TEXT)
		var rank_l := _label("#%d" % (i + 1), 20, col, HORIZONTAL_ALIGNMENT_LEFT)
		rank_l.custom_minimum_size.x = 70
		line.add_child(rank_l)
		var name_l := _label(str(row["name"]), 20, col, HORIZONTAL_ALIGNMENT_LEFT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_l)
		var dmg := int(float(row["ratio"]) * ref)
		line.add_child(_label(NumberFormat.short(dmg) if dmg > 0 else "-", 20, col, HORIZONTAL_ALIGNMENT_RIGHT))
		list.add_child(line)

	v.add_child(_fade_line())
	var tiers := PackedStringArray()
	var lower := 1
	for r in FallenGod.RANK_REWARDS:
		var top := int(r[0])
		var span := "#%d" % lower if top == lower else ("#%d-%d" % [lower, top] if top < 999 else "#%d+" % lower)
		tiers.append("%s: %d Jade, %d Essence" % [span, int(r[1]), int(r[2])])
		lower = top + 1
	var rewards_l := _label("\n".join(tiers), 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(rewards_l)
	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 56)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


func _on_trial_challenge(def: Dictionary) -> void:
	_connect_battle()
	var error := Trials.challenge(self, def)
	if error != "":
		_toast(error, COL_SHORT)
		return
	_fighting = true
	_rebuild()


func _on_trial_sweep(def: Dictionary) -> void:
	var got := Trials.sweep(def)
	if got.is_empty():
		_toast("Can't sweep right now.", COL_SHORT)
		return
	_toast(_rewards_text(got), COL_OK)
	_rebuild()


func _rewards_text(got: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in got:
		if id == Dungeons.JADE_KEY:
			parts.append("+%s Jade" % NumberFormat.short(int(got[id])))
		else:
			parts.append("+%s %s" % [NumberFormat.short(int(got[id])), ItemDB.get_item(id).get("name", id)])
	return "  ·  ".join(parts)


func _on_challenge(def: Dictionary) -> void:
	_connect_battle()
	var error := Dungeons.challenge(self, def)
	if error != "":
		_toast(error, COL_SHORT)
		return
	_fighting = true
	_rebuild()
	_go_home()   # watch the fight straight away


## Switches the lower panel back to Home so the battle is in view.
func _go_home() -> void:
	var router := get_parent()
	while router != null and not router.has_method("open_tab"):
		router = router.get_parent()
	if router != null:
		router.call("open_tab", "Home")


func _on_dungeon_finished(request: Dictionary, won: bool) -> void:
	_fighting = false
	if str(request.get("kind", "")) == "fallen_god":
		_rebuild()
		return
	if str(request.get("kind", "")) == "beast_hunt":
		if not won:
			_toast("The beast escaped. The hunt wasn't used.", COL_SHORT)
		_rebuild()
		return
	if str(request.get("kind", "")) == "trial":
		var trial := Trials.get_def(str(request["trial"]))
		if won:
			_toast("%s Tier %d cleared!" % [trial.get("name", "Trial"), int(request["tier"])], COL_OK)
		else:
			_toast("Tier %d failed. Strengthen your team and try again." % int(request["tier"]), COL_SHORT)
		_rebuild()
		return
	var def := Dungeons.get_def(request["dungeon"])
	if won:
		_toast("%s Floor %d cleared!" % [def.get("name", ""), request["floor"]], COL_OK)
	else:
		_toast("Floor %d failed. Strengthen your team and try again." % request["floor"], COL_SHORT)
	_rebuild()


func _on_sweep(def: Dictionary) -> void:
	var got := Dungeons.sweep(def)
	if got.is_empty():
		_toast("Can't sweep right now.", COL_SHORT)
		return
	var parts := PackedStringArray()
	for id in got:
		if id == Dungeons.JADE_KEY:
			parts.append("+%s Jade" % NumberFormat.short(got[id]))
			continue
		if id == "__pieces__":
			for piece in got[id]:
				parts.append(Gear.item_name(piece) if piece.has("slot") else Treasures.item_name(piece))
			continue
		parts.append("+%s %s" % [NumberFormat.short(got[id]), ItemDB.get_item(id).get("name", id)])
	_toast("  ·  ".join(parts), COL_OK)
	_rebuild()


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
		draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), Color(COL_GOLD, 0.7), 2.0, true)


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
