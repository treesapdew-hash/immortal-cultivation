extends PanelContainer

# =========================================================
# Spatial Ring (inventory), built in code. Save as
#   res://ui/screens/inventory_screen.gd
#
# Tabs: Pills, Materials, Equipment, Treasures, Partners.
# Tap an item for its details at the bottom. Partners (and
# their Soul Fragments) can be salvaged for Star-up Pills.
# Currencies live in the top bar, so they're not shown here.
# =========================================================

const TABS := ["Pills", "Materials", "Fragments", "Equipment", "Treasures", "Partners"]
const SLOT_SIZE := 118.0
const CARD_WIDTH := 128.0
const COLUMNS := 7
const CARD_COLUMNS := 5

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_BORDER := Color("3a5a80")
const COL_GOLD   := Color("e2c27a")
const COL_TITLE  := Color("f2d98a")
const COL_TEXT   := Color("c9d4e3")
const COL_DIM    := Color("7f8ea3")
const COL_GOOD   := Color("7dffa8")
const COL_WARN   := Color("ff8a7a")
const COL_GOLD_TX := Color("ffe6a8")
const COL_PILL   := Color("f0b35a")

const TIER_COLORS := [
	Color("d9dde3"), Color("4d9bff"), Color("3fcf6a"), Color("a864f2"),
	Color("f24d4d"), Color("ffc93c"), Color("aef2ff"),
]

var _tab := "Pills"
var _tab_buttons := {}
var _count_label: Label
var _mass_button: Button
var _grid: GridContainer
var _empty_box: VBoxContainer
var _empty_title: Label
var _empty_text: Label
var _selected: Control
var _toast_holder: Control
var _dirty := true

# Details bar
var _detail_icon: ItemSlot
var _detail_gear: GearIcon
var _detail_treasure: TreasureIcon
var _detail_name: Label
var _detail_grade: Label
var _detail_desc: Label
var _detail_owned: Label
var _detail_action: OrnateButton
var _detail_action_2: OrnateButton
var _action_1 := Callable()
var _action_2 := Callable()

# Mass salvage settings (remembered while the game runs)
var _mass_tiers := {0: true, 1: true, 2: false, 3: false, 4: false, 5: false, 6: false}
var _mass_partners := true
var _mass_fragments := true
var _mass_one_star_only := true
var _mass_layer: CanvasLayer
var _mass_summary: Label
var _mass_go: Button

## Tiers from here up need an extra confirmation (Red = 4).
const MASS_CONFIRM_FROM := 4

# Salvage popup
var _popup_layer: CanvasLayer
var _popup_index := -1
var _copy_count := 1
var _confirm_armed := false


func _ready() -> void:
	name = "InventoryScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop.bind(self))
	resized.connect(queue_redraw)

	SummonCard.find_frames(self)
	_build()
	GameState.currency_changed.connect(_on_currency_changed)
	GameState.roster_changed.connect(_mark_dirty)
	GameState.formation_changed.connect(_mark_dirty)
	GameState.gear_updated.connect(_mark_dirty)
	GameState.treasures_updated.connect(_mark_dirty)
	_select_tab("Pills")


func on_opened() -> void:
	if _dirty:
		_rebuild()


var _last_signature := ""


## Qi and stones change constantly in battle; only rebuild when
## something shown here (items, pills, fragments) actually changed.
func _on_currency_changed() -> void:
	var sig := _signature()
	if sig != _last_signature:
		_mark_dirty()


func _signature() -> String:
	return "%d|%s|%s|%d" % [GameState.starup_pills, str(GameState.items), str(GameState.partner_copies),
		GameState.gear.size() + GameState.treasures.size() * 1000]


func _mark_dirty() -> void:
	_dirty = true
	if is_visible_in_tree():
		_rebuild.call_deferred()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_label("Spatial Ring", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	titles.add_child(_label("Inventory", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	_mass_button = _button("Mass Salvage", Vector2(190, 46), true)
	_mass_button.add_theme_font_size_override("font_size", 19)
	_mass_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mass_button.pressed.connect(_on_mass_pressed)
	head.add_child(_mass_button)

	_count_label = _label("", 20, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_count_label.custom_minimum_size.x = 90
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_label)

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for tab in TABS:
		var b := _make_tab(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons[tab] = b

	v.add_child(_fade_line())

	# Content
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var center := CenterContainer.new()
	content.add_child(center)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_grid)

	_empty_box = VBoxContainer.new()
	_empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_box.custom_minimum_size.y = 260
	_empty_box.add_theme_constant_override("separation", 8)
	content.add_child(_empty_box)
	var seal := Control.new()
	seal.custom_minimum_size = Vector2(0, 90)
	seal.draw.connect(func():
		var c := Vector2(seal.size.x * 0.5, 45)
		seal.draw_arc(c, 34, 0, TAU, 48, Color(COL_GOLD, 0.35), 2.0, true)
		seal.draw_arc(c, 26, 0, TAU, 48, Color(COL_GOLD, 0.18), 1.0, true)
		for i in 8:
			var a := TAU * i / 8.0
			var d := Vector2(cos(a), sin(a))
			seal.draw_line(c + d * 36, c + d * 42, Color(COL_GOLD, 0.35), 1.5, true)
		seal.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -12), c + Vector2(9, 0), c + Vector2(0, 12), c + Vector2(-9, 0)]), Color(COL_GOLD, 0.4))
	)
	_empty_box.add_child(seal)
	_empty_title = _label("", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_empty_box.add_child(_empty_title)
	_empty_text = _label("", 22, COL_DIM)
	_empty_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_box.add_child(_empty_text)

	# Details bar
	v.add_child(_fade_line())
	v.add_child(_build_details())

	_toast_holder = Control.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_holder.top_level = true
	add_child(_toast_holder)


func _build_details() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 150
	bar.clip_contents = true
	bar.add_theme_constant_override("separation", 16)

	_detail_icon = ItemSlot.new()
	_detail_icon.custom_minimum_size = Vector2(124, 124)
	_detail_icon.disabled = true
	_detail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_detail_icon)

	_detail_gear = GearIcon.new()
	_detail_gear.custom_minimum_size = Vector2(124, 124)
	_detail_gear.disabled = true
	_detail_gear.visible = false
	_detail_gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_detail_gear)

	_detail_treasure = TreasureIcon.new()
	_detail_treasure.custom_minimum_size = Vector2(124, 124)
	_detail_treasure.disabled = true
	_detail_treasure.visible = false
	_detail_treasure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_detail_treasure)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	bar.add_child(texts)

	_detail_name = _label("", 26, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_detail_name.clip_text = true
	_detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_detail_name)
	_detail_grade = _label("", 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_detail_grade.clip_text = true
	texts.add_child(_detail_grade)
	_detail_desc = _label("", 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.max_lines_visible = 2
	_detail_desc.custom_minimum_size.x = 100
	texts.add_child(_detail_desc)
	_detail_owned = _label("", 18, COL_GOLD_TX, HORIZONTAL_ALIGNMENT_LEFT)
	_detail_owned.clip_text = true
	texts.add_child(_detail_owned)

	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	bar.add_child(actions)
	_detail_action = _button("", Vector2(210, 60), true)
	_detail_action.pressed.connect(_run_action.bind(1))
	actions.add_child(_detail_action)
	_detail_action_2 = _button("", Vector2(210, 52), false)
	_detail_action_2.pressed.connect(_run_action.bind(2))
	actions.add_child(_detail_action_2)

	return bar


func _run_action(which: int) -> void:
	var action := _action_1 if which == 1 else _action_2
	if action.is_valid():
		action.call()


func _make_tab(tab: String) -> Button:
	var b := Button.new()
	b.text = tab
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(_select_tab.bind(tab))
	b.draw.connect(func():
		if tab != _tab:
			return
		var w := b.size.x
		var y := b.size.y - 4.0
		# glowing underline with a centre gem
		b.draw_rect(Rect2(w * 0.12, y - 1.0, w * 0.76, 3.0), COL_GOLD)
		b.draw_rect(Rect2(w * 0.08, y - 4.0, w * 0.84, 9.0), Color(COL_GOLD, 0.12))
		var c := Vector2(w * 0.5, y)
		b.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), COL_GOLD_TX)
		# soft wash behind the active tab
		b.draw_rect(Rect2(0, 0, w, b.size.y), Color(COL_GOLD, 0.05))
	)
	return b


func _select_tab(tab: String) -> void:
	_tab = tab
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		var active: bool = key == tab
		b.add_theme_color_override("font_color", COL_GOLD_TX if active else COL_DIM)
		b.add_theme_color_override("font_hover_color", COL_GOLD_TX if active else COL_TEXT)
		b.queue_redraw()
	_rebuild()


# ---------------------------------------------------------
# CONTENT
# ---------------------------------------------------------

func _rebuild() -> void:
	_dirty = false
	_last_signature = _signature()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_selected = null

	var total := 0
	for id in ItemDB.all_ids():
		if GameState.get_item_count(id) > 0:
			total += 1
	for id in GameState.partner_copies:
		total += 1
	total += GameState.gear.size()
	_count_label.text = "Items  %d" % total
	_mass_button.visible = _tab in ["Partners", "Equipment"]
	if _tab == "Treasures":
		_mass_button.visible = false

	match _tab:
		"Pills":
			_fill_items(ItemDB.Category.PILL, [])
		"Materials":
			_fill_materials()
		"Fragments":
			_fill_fragments()
		"Equipment":
			_fill_gear()
		"Treasures":
			_fill_treasures()
		"Partners":
			_fill_partners()

	_show_default_details()


## Owned items in a category. `always` ids are shown even at 0.
func _fill_items(category: int, always: Array) -> void:
	_grid.columns = COLUMNS
	var shown := 0
	for id in ItemDB.ids_in(category):
		var n := GameState.get_item_count(id)
		if n <= 0 and not id in always:
			continue
		var slot := ItemSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.setup_item(id, n)
		slot.pressed.connect(_on_item_pressed.bind(slot, id))
		_grid.add_child(slot)
		shown += 1
	_set_empty(shown == 0, category)


func _fill_materials() -> void:
	_grid.columns = COLUMNS
	var shown := 0
	for id in ItemDB.ids_in(ItemDB.Category.MATERIAL):
		var n := GameState.get_item_count(id)
		if n <= 0:
			continue
		var slot := ItemSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.setup_item(id, n)
		slot.pressed.connect(_on_item_pressed.bind(slot, id))
		_grid.add_child(slot)
		shown += 1
	_set_empty(shown == 0, ItemDB.Category.MATERIAL)


## Treasures, best grade first.
func _fill_treasures() -> void:
	_grid.columns = COLUMNS
	var items: Array = GameState.treasures.duplicate()
	items.sort_custom(func(a, b):
		if int(a["grade"]) != int(b["grade"]):
			return int(a["grade"]) > int(b["grade"])
		if int(a.get("level", 0)) != int(b.get("level", 0)):
			return int(a.get("level", 0)) > int(b.get("level", 0))
		return str(a["id"]) < str(b["id"]))
	for t in items:
		var icon := TreasureIcon.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		icon.setup(t)
		icon.pressed.connect(_on_treasure_pressed.bind(icon, int(t["uid"])))
		_grid.add_child(icon)
	_set_empty(items.is_empty(), ItemDB.Category.TREASURE)


func _on_treasure_pressed(icon: TreasureIcon, uid: int) -> void:
	_select(icon)
	var t := GameState.find_treasure(uid)
	if t.is_empty():
		return
	_detail_icon.visible = false
	_detail_gear.visible = false
	_detail_treasure.visible = true
	_detail_treasure.setup(t)

	var set_def := Treasures.set_def(Treasures.set_of(t))
	_detail_name.text = Treasures.item_name(t)
	_detail_name.add_theme_color_override("font_color",
		Treasures.grade_color(int(t["grade"])).lightened(0.25))
	_detail_grade.text = "%s  ·  %s Set  ·  +%d" % [Treasures.grade_name(int(t["grade"])),
		set_def.get("name", ""), int(t.get("level", 0))]
	_detail_desc.text = "%s.  All 3 slots: %s" % [Treasures.stat_text(t),
		Treasures.set_effect_text(Treasures.set_of(t), int(t["grade"]))]
	var wearer: String = t.get("owner", "")
	_detail_owned.text = "Held by %s" % _wearer_name(wearer) if wearer != "" else "Not equipped"
	_set_actions("Manage", _open_treasure.bind(uid))


func _open_treasure(uid: int) -> void:
	TreasurePopup.open_details(self, uid)


## Equipment pieces, best first.
func _fill_gear() -> void:
	_grid.columns = COLUMNS
	var items: Array = GameState.gear.duplicate()
	items.sort_custom(func(a, b):
		if Gear.grade_index(a) != Gear.grade_index(b):
			return Gear.grade_index(a) > Gear.grade_index(b)
		if int(a["refine"]) != int(b["refine"]):
			return int(a["refine"]) > int(b["refine"])
		return int(a["slot"]) < int(b["slot"]))
	for item in items:
		var icon := GearIcon.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		icon.setup(item)
		icon.pressed.connect(_on_gear_pressed.bind(icon, int(item["uid"])))
		_grid.add_child(icon)
	_set_empty(items.is_empty(), ItemDB.Category.EQUIPMENT)


func _on_gear_pressed(icon: GearIcon, uid: int) -> void:
	_select(icon)
	_detail_treasure.visible = false
	var item := GameState.find_gear(uid)
	if item.is_empty():
		return
	_detail_icon.visible = false
	_detail_gear.visible = true
	_detail_gear.setup(item)
	_detail_name.text = Gear.item_name(item)
	_detail_name.add_theme_color_override("font_color", Gear.tier_color(item).lightened(0.25))
	_detail_grade.text = "%s  ·  %s  ·  +%d" % [Gear.grade_text(item), Gear.SLOT_NAMES[int(item["slot"])], int(item["refine"])]
	var set_def: Dictionary = Gear.SETS.get(item["set"], {})
	var stats := Gear.item_stats(item)
	var main := Gear.main_stats(int(item["slot"]), Gear.grade_index(item))
	var parts := PackedStringArray()
	for stat in main:
		parts.append(Gear.format_stat(stat, stats[stat]))
	_detail_desc.text = "%s Set  ·  %s" % [set_def.get("name", "?"), ",  ".join(parts)]
	var wearer: String = item.get("owner", "")
	_detail_owned.text = "Worn by %s" % _wearer_name(wearer) if wearer != "" else "Not equipped"
	_set_actions("Manage", _open_gear.bind(uid))


func _open_gear(uid: int) -> void:
	GearPopup.open_details(self, uid)


func _wearer_name(partner_id: String) -> String:
	if partner_id == GameState.MC_ID:
		return GameState.mc_name
	var data = PartnerDatabase.get_partner(partner_id)
	return data.display_name if data != null else partner_id


## Soul Fragments (spare copies), highest tier first.
func _fill_fragments() -> void:
	_grid.columns = COLUMNS
	var shown := 0
	var ids := GameState.partner_copies.keys()
	ids.sort_custom(func(a, b):
		var da = PartnerDatabase.get_partner(a)
		var db = PartnerDatabase.get_partner(b)
		return (da.rarity if da else 0) > (db.rarity if db else 0))
	for id in ids:
		var data = PartnerDatabase.get_partner(id)
		var n := GameState.get_copies(id)
		if data == null or n <= 0:
			continue
		var slot := ItemSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.setup_fragment(data, n)
		slot.pressed.connect(_on_fragment_pressed.bind(slot, id))
		_grid.add_child(slot)
		shown += 1

	_empty_box.visible = shown == 0
	_grid.visible = shown > 0
	_empty_title.text = "No Soul Fragments"
	_empty_text.text = "Summoning a partner you already own gives a Soul Fragment."


func _fill_partners() -> void:
	_grid.columns = CARD_COLUMNS
	var entries: Array = []
	for i in range(1, GameState.roster.size()):
		var p: OwnedPartner = GameState.roster[i]
		var data := p.get_data()
		if data == null:
			continue
		entries.append({"index": i, "partner": p, "data": data,
			"copies": GameState.get_copies(p.partner_id),
			"in_team": GameState.get_slot_of(i) > 0,
			"in_array": BattleArray.is_member(p.partner_id)})
	entries.sort_custom(func(a, b):
		if a["data"].rarity != b["data"].rarity:
			return a["data"].rarity > b["data"].rarity
		return a["copies"] > b["copies"])

	for e in entries:
		_grid.add_child(_make_partner_card(e))

	_empty_box.visible = entries.is_empty()
	_grid.visible = not entries.is_empty()
	_empty_title.text = "No partners yet"
	_empty_text.text = "Summon to recruit companions. Partners you no longer need can be salvaged here."


func _set_empty(empty: bool, category: int) -> void:
	_empty_box.visible = empty
	_grid.visible = not empty
	match category:
		ItemDB.Category.PILL:
			_empty_title.text = "No pills"
			_empty_text.text = "Pills come from Alchemy, events and the shop."
		ItemDB.Category.MATERIAL:
			_empty_title.text = "No materials"
			_empty_text.text = "Herbs and beast cores drop from stages and the Beast Den."
		ItemDB.Category.EQUIPMENT:
			_empty_title.text = "No equipment yet"
			_empty_text.text = "Weapons, armor, rings and boots drop in the Armory Ruins (Events tab)."
		_:
			_empty_title.text = "No treasures yet"
			_empty_text.text = "Treasures drop in the Treasure Vault (Events tab). Hold 3 of one set for its effect."


## Partner card with your tier frame; name sits underneath it.
func _make_partner_card(e: Dictionary) -> Control:
	var data = e["data"]
	var p: OwnedPartner = e["partner"]
	var card_size := SummonCard.size_for_width(CARD_WIDTH)
	var name_h := 24.0

	var holder := Button.new()
	holder.flat = true
	holder.focus_mode = Control.FOCUS_NONE
	holder.custom_minimum_size = card_size + Vector2(0, name_h)
	for state in ["normal", "hover", "pressed", "focus"]:
		holder.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var card := SummonCard.new()
	card.setup({"partner_id": p.partner_id}, data.rarity, card_size)
	card.show_front()
	if e["in_team"]:
		card.modulate = Color(0.6, 0.6, 0.65)
	holder.add_child(card)

	var name_label := _label(data.display_name, 14, COL_TEXT)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.position = Vector2(0, card_size.y + 2)
	name_label.size = Vector2(card_size.x, name_h - 2)
	holder.add_child(name_label)

	if e["copies"] > 0:
		var tag := _label("×%d" % e["copies"], 16, COL_PILL)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 5)
		tag.position = Vector2(0, card_size.y * 0.07)
		tag.size = Vector2(card_size.x - 14, 22)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		holder.add_child(tag)

	if e["in_team"] or e["in_array"]:
		var ribbon := _label("IN TEAM" if e["in_team"] else "IN ARRAY", 14,
			COL_GOOD if e["in_team"] else COL_GOLD)
		ribbon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		ribbon.add_theme_constant_override("outline_size", 5)
		ribbon.position = Vector2(0, card_size.y * 0.44)
		ribbon.size = Vector2(card_size.x, 20)
		holder.add_child(ribbon)

	# Gold outline when selected
	holder.draw.connect(func():
		if _selected == holder:
			holder.draw_rect(Rect2(Vector2(-3, -3), card_size + Vector2(6, 6)), COL_GOLD, false, 3.0)
			holder.draw_rect(Rect2(Vector2(-6, -6), card_size + Vector2(12, 12)), Color(COL_GOLD, 0.25), false, 2.0)
	)
	holder.pressed.connect(_on_partner_pressed.bind(holder, e["index"]))
	return holder


# ---------------------------------------------------------
# SELECTION AND DETAILS
# ---------------------------------------------------------

func _select(node: Control) -> void:
	var old := _selected
	_selected = node
	for n in [old, node]:
		if is_instance_valid(n):
			if n is ItemSlot or n is GearIcon or n is TreasureIcon:
				n.selected = n == _selected
			else:
				n.queue_redraw()


func _set_actions(text_1: String, action_1: Callable, text_2 := "", action_2 := Callable()) -> void:
	_action_1 = action_1
	_action_2 = action_2
	# Salvaging is destructive: crimson. Everything else: gold.
	_detail_action.variant = OrnateButton.Variant.CRIMSON if text_1.begins_with("Salvage") \
		else OrnateButton.Variant.GOLD
	_detail_action.text = text_1
	_detail_action.visible = text_1 != ""
	_detail_action_2.text = text_2
	_detail_action_2.visible = text_2 != ""


func _show_default_details() -> void:
	_detail_gear.visible = false
	_detail_treasure.visible = false
	_detail_icon.visible = false
	_detail_name.text = _tab
	_detail_grade.text = ""
	_detail_owned.text = ""
	match _tab:
		"Fragments", "Partners":
			var value := GameState.get_all_copies_salvage_value()
			_detail_desc.text = "Tap a card or item for details."
			if value > 0:
				_set_actions("Salvage All\nFragments", _on_salvage_all)
				_detail_owned.text = "All fragments:  +%s Pills" % NumberFormat.short(value)
			else:
				_set_actions("", Callable())
		_:
			_detail_desc.text = "Tap an item for details."
			_set_actions("", Callable())


func _on_item_pressed(slot: ItemSlot, id: String) -> void:
	_select(slot)
	_detail_gear.visible = false
	_detail_treasure.visible = false
	var item := ItemDB.get_item(id)
	var grade: int = item.get("grade", 0)
	var n := GameState.get_item_count(id)

	_detail_icon.visible = true
	_detail_icon.setup_item(id, n)
	_detail_icon.show_count = false
	_detail_name.text = item.get("name", id)
	_detail_name.add_theme_color_override("font_color", ItemDB.grade_color(grade).lightened(0.2))
	_detail_grade.text = "%s  ·  %s" % [ItemDB.grade_name(grade), ItemDB.CATEGORY_NAMES[item.get("category", 0)]]
	_detail_desc.text = item.get("desc", "")
	_detail_owned.text = "Owned:  %s" % NumberFormat.full(n)

	# Selection Scrolls open straight from the bag, rather than
	# sending the player to the Summoning Altar to do it.
	var tier := SummonSystem.scroll_tier(id)
	if tier >= 0 and n > 0:
		_set_actions("Open", _open_scroll.bind(id, tier))
		return

	# Premium Soul Essence forges a Soul Fragment for a Premium Red,
	# which is the only way to awaken one (they can't be summoned).
	if id == GameState.PREMIUM_ESSENCE_ID:
		_detail_desc.text += "\n\n%d Essence forges 1 Soul Fragment." % GameState.ESSENCE_PER_FRAGMENT
		if n >= GameState.ESSENCE_PER_FRAGMENT:
			_set_actions("Forge\nFragment", _open_essence_forge)
		else:
			_set_actions("", Callable())
		return

	match item.get("action", ""):
		"awaken":
			_set_actions("Awaken\nPartners", _go_to.bind("Partner"))
		_:
			_set_actions("", Callable())


## Turns Premium Soul Essence into a Soul Fragment for a chosen
## Premium Red. Only partners you already own are offered: a fragment
## for someone you don't have can't be spent.
func _open_essence_forge() -> void:
	var owned := SummonSystem.owned_premium_ids()
	if owned.is_empty():
		_toast("You have no Premium Reds yet.", COL_WARN)
		return
	var note := "Tap a cultivator, then Choose. Costs %d Essence for 1 Soul Fragment." \
		% GameState.ESSENCE_PER_FRAGMENT
	var popup := CardChoicePopup.open(self, "Premium Soul Essence", owned, Enums.Rarity.RED, note)
	var on_chosen := func(partner_id: String) -> void:
		var problem := GameState.forge_premium_fragment(partner_id)
		if problem == "":
			var data = PartnerDatabase.get_partner(partner_id)
			_toast("+1 Soul Fragment for %s." % (data.display_name if data != null else "them"), COL_GOOD)
		else:
			_toast(problem, COL_WARN)
		_rebuild()
	popup.chosen.connect(on_chosen)


## Picks a partner from a Selection Scroll. The scroll is only spent
## once a choice is confirmed, so backing out costs nothing.
func _open_scroll(item_id: String, tier: int) -> void:
	var options := SummonSystem.options_for_scroll(item_id)
	if options.is_empty():
		_toast("This scroll has nothing to offer.", COL_WARN)
		return
	var title := str(ItemDB.get_item(item_id).get("name", "Selection Scroll"))
	var popup := CardChoicePopup.open(self, title, options, tier)
	var on_chosen := func(partner_id: String) -> void:
		if SummonSystem.choose_from_scroll(item_id, partner_id):
			var data = PartnerDatabase.get_partner(partner_id)
			_toast("%s joined you!" % (data.display_name if data != null else "A partner"), COL_GOOD)
		_rebuild()
	popup.chosen.connect(on_chosen)


func _on_fragment_pressed(slot: ItemSlot, partner_id: String) -> void:
	_select(slot)
	_detail_gear.visible = false
	_detail_treasure.visible = false
	var data = PartnerDatabase.get_partner(partner_id)
	var n := GameState.get_copies(partner_id)
	var grade := ItemDB.grade_for_rarity(data.rarity)

	_detail_icon.visible = true
	_detail_icon.setup_fragment(data, n)
	_detail_icon.show_count = false
	_detail_name.text = "%s Soul Fragment" % data.display_name
	_detail_name.add_theme_color_override("font_color", ItemDB.grade_color(grade).lightened(0.2))
	_detail_grade.text = "%s  ·  Soul Fragment" % str(Enums.Rarity.keys()[data.rarity]).capitalize()
	_detail_desc.text = "Used to awaken %s, or salvaged for %s Pills each." % [
		data.display_name, NumberFormat.short(GameState.get_copy_salvage_value(partner_id))]
	_detail_owned.text = "Owned:  %s" % NumberFormat.full(n)

	var owned := GameState.find_owned(partner_id)
	var index := GameState.roster.find(owned)
	if index > 0:
		_set_actions("Salvage", _open_detail.bind(index))
	else:
		_set_actions("", Callable())


func _on_partner_pressed(holder: Control, roster_index: int) -> void:
	_select(holder)
	_detail_gear.visible = false
	_detail_treasure.visible = false
	var p: OwnedPartner = GameState.roster[roster_index]
	var data := p.get_data()
	var grade := ItemDB.grade_for_rarity(data.rarity)
	var copies := GameState.get_copies(p.partner_id)

	_detail_icon.visible = true
	_detail_icon.setup_fragment(data, 0)
	_detail_icon.show_count = false
	_detail_name.text = data.display_name
	_detail_name.add_theme_color_override("font_color", ItemDB.grade_color(grade).lightened(0.2))
	_detail_grade.text = "%s  ·  %s  ·  Stars %d" % [
		str(Enums.Rarity.keys()[data.rarity]).capitalize(), p.get_realm_text(), p.stars]
	if GameState.get_slot_of(roster_index) > 0:
		_detail_desc.text = "In your team."
	elif BattleArray.is_member(p.partner_id):
		_detail_desc.text = "In the Battle Array."
	else:
		_detail_desc.text = "Can be salvaged for Star-up Pills."
	_detail_owned.text = "Soul Fragments:  %d" % copies
	_set_actions("Salvage", _open_detail.bind(roster_index))


func _on_salvage_all() -> void:
	var pills := GameState.salvage_all_copies()
	if pills > 0:
		_toast("+%s Star-up Pills" % NumberFormat.short(pills), COL_PILL)


func _go_to(quick_tab: String) -> void:
	# The router is an ancestor (the screen sits inside a wrapper)
	var router := get_parent()
	while router != null and not router.has_method("open_quick"):
		router = router.get_parent()
	if router != null:
		router.call("open_quick", quick_tab)


# ---------------------------------------------------------
# DETAIL POPUP
# ---------------------------------------------------------

func _open_detail(roster_index: int) -> void:
	_close_detail()
	_popup_index = roster_index
	_copy_count = 1
	_confirm_armed = false

	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 60
	get_tree().root.add_child(_popup_layer)
	_build_detail()


func _close_detail() -> void:
	if is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
	_popup_layer = null
	_popup_index = -1


func _build_detail() -> void:
	var p: OwnedPartner = GameState.roster[_popup_index]
	var data := p.get_data()
	var color: Color = TIER_COLORS[clampi(Realms.tier_index(data.rarity), 0, TIER_COLORS.size() - 1)]
	var copies := GameState.get_copies(p.partner_id)
	var per_copy := GameState.get_copy_salvage_value(p.partner_id)
	var value := GameState.get_partner_salvage_value(_popup_index)
	var block := GameState.can_salvage_partner(_popup_index)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_detail()
	)
	_popup_layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c1a30")
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	# Header: art + name
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	v.add_child(top)

	var art := TextureRect.new()
	art.texture = data.card_texture
	art.custom_minimum_size = Vector2(150, 200)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top.add_child(art)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(info)
	info.add_child(_label(data.display_name, 38, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label(str(Enums.Rarity.keys()[data.rarity]).capitalize(), 24, color, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label(p.get_realm_text() + "   ·   Stars %d" % p.stars, 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label("Soul Fragments: %d" % copies, 24, COL_PILL if copies > 0 else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	v.add_child(_divider())

	# --- Spare copies ---
	v.add_child(_label("Salvage Soul Fragments", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	if copies <= 0:
		v.add_child(_label("No Soul Fragments.", 22, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)

		var minus := _button("−", Vector2(70, 64), false)
		var count_label := _label("", 30, COL_TEXT)
		count_label.custom_minimum_size = Vector2(80, 0)
		var plus := _button("+", Vector2(70, 64), false)
		var max_b := _button("Max", Vector2(100, 64), false)
		var gain := _label("", 26, COL_PILL, HORIZONTAL_ALIGNMENT_RIGHT)
		gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var update := func():
			_copy_count = clampi(_copy_count, 1, copies)
			count_label.text = str(_copy_count)
			gain.text = "+%s Pills" % NumberFormat.short(_copy_count * per_copy)
		var dec := func():
			_copy_count -= 1
			update.call()
		var inc := func():
			_copy_count += 1
			update.call()
		var to_max := func():
			_copy_count = copies
			update.call()
		minus.pressed.connect(dec)
		plus.pressed.connect(inc)
		max_b.pressed.connect(to_max)
		update.call()

		for node in [minus, count_label, plus, max_b, gain]:
			row.add_child(node)

		var salvage_copies := _button("Salvage Fragments", Vector2(0, 72), true, true)
		salvage_copies.pressed.connect(func():
			if ItemDB.grade_for_rarity(data.rarity) >= MASS_CONFIRM_FROM:
				_confirm_dialog(_popup_layer,
					"Salvage %d %s Soul Fragment%s? This can't be undone." % [
						_copy_count, data.display_name, "" if _copy_count == 1 else "s"],
					_do_salvage_copies.bind(p.partner_id))
			else:
				_do_salvage_copies(p.partner_id)
		)
		v.add_child(salvage_copies)

	v.add_child(_divider())

	# --- Whole partner ---
	v.add_child(_label("Salvage Partner", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := "Removes %s for good, including their Soul Fragments. Gives back half of the pills and Qi spent on them." % data.display_name
	var desc_label := _label(desc, 22, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_label)

	var gains := "+%s Pills" % NumberFormat.short(value["pills"])
	if value["qi"] > 0:
		gains += "     +%s Qi" % NumberFormat.short(value["qi"])
	v.add_child(_label(gains, 28, COL_PILL, HORIZONTAL_ALIGNMENT_LEFT))

	var salvage_partner := _button("Salvage Partner", Vector2(0, 72), false, true)
	if block != "":
		salvage_partner.disabled = true
		v.add_child(_label(block, 22, COL_WARN, HORIZONTAL_ALIGNMENT_LEFT))
	var is_rare := ItemDB.grade_for_rarity(data.rarity) >= MASS_CONFIRM_FROM
	salvage_partner.pressed.connect(func():
		# Red and up: proper confirmation box
		if is_rare:
			_confirm_dialog(_popup_layer,
				"Salvage %s for good? They're %s tier. This can't be undone." % [
					data.display_name, str(Enums.Rarity.keys()[data.rarity]).capitalize()],
				_do_salvage_partner.bind(_popup_index))
			return
		# Lower tiers: two taps, the first arms it, the second salvages
		if not _confirm_armed:
			_confirm_armed = true
			salvage_partner.text = "Tap again to confirm"
			# Tween lives on the button, so it's cancelled if the popup closes
			var reset := salvage_partner.create_tween()
			reset.tween_interval(3.0)
			reset.tween_callback(_disarm_salvage.bind(salvage_partner))
			return
		_do_salvage_partner(_popup_index)
	)
	v.add_child(salvage_partner)

	var close := _button("Close", Vector2(0, 70), false)
	close.pressed.connect(_close_detail)
	v.add_child(close)


func _on_mass_pressed() -> void:
	if _tab == "Equipment":
		_open_gear_mass()
	else:
		_open_mass()


# ---------------------------------------------------------
# MASS SALVAGE (EQUIPMENT)
# ---------------------------------------------------------

var _gear_mass_tiers := {0: true, 1: true, 2: false, 3: false, 4: false, 5: false, 6: false}
var _gear_mass_skip_refined := true
var _gear_mass_summary: Label
var _gear_mass_go: Button


## Pieces the filters would salvage (never locked, worn, or the gear you kept).
func _gear_mass_selection() -> Dictionary:
	var uids: Array = []
	var ore := 0
	var rare := 0
	for item in GameState.gear:
		if item.get("locked", false) or item.get("owner", "") != "":
			continue
		if not _gear_mass_tiers.get(int(item["tier"]), false):
			continue
		if _gear_mass_skip_refined and int(item.get("refine", 0)) > 0:
			continue
		uids.append(int(item["uid"]))
		ore += Gear.salvage_value(item)
		if int(item["tier"]) >= MASS_CONFIRM_FROM:
			rare += 1
	return {"uids": uids, "ore": ore, "rare": rare}


func _open_gear_mass() -> void:
	_close_mass()
	_mass_layer = CanvasLayer.new()
	_mass_layer.layer = 60
	get_tree().root.add_child(_mass_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(_on_mass_dim_input)
	_mass_layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mass_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c1a30")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	v.add_child(_label("Mass Salvage Equipment", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_label("Worn, locked pieces are always kept.", 20, COL_DIM))
	v.add_child(_fade_line())

	v.add_child(_label("Tiers to salvage", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var tiers := GridContainer.new()
	tiers.columns = 4
	tiers.add_theme_constant_override("h_separation", 10)
	tiers.add_theme_constant_override("v_separation", 10)
	v.add_child(tiers)
	for t in 7:
		tiers.add_child(_mass_toggle(Gear.TIER_NAMES[t], ItemDB.grade_color(t),
			_gear_mass_tiers.get(t, false), _on_gear_mass_tier.bind(t), Vector2(190, 56)))

	v.add_child(_mass_toggle("Keep refined pieces (+1 or more)", COL_GOLD, _gear_mass_skip_refined,
		_on_gear_mass_refined, Vector2(0, 54)))

	v.add_child(_fade_line())
	_gear_mass_summary = _label("", 24, COL_PILL)
	_gear_mass_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_gear_mass_summary)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	v.add_child(buttons)
	var cancel := _button("Cancel", Vector2(260, 72), false)
	cancel.pressed.connect(_close_mass)
	buttons.add_child(cancel)
	_gear_mass_go = _button("Salvage", Vector2(300, 72), true, true)
	_gear_mass_go.pressed.connect(_on_gear_mass_go)
	buttons.add_child(_gear_mass_go)

	_update_gear_mass()


func _on_gear_mass_tier(on: bool, tier: int) -> void:
	_gear_mass_tiers[tier] = on
	_update_gear_mass()


func _on_gear_mass_refined(on: bool) -> void:
	_gear_mass_skip_refined = on
	_update_gear_mass()


func _update_gear_mass() -> void:
	if not is_instance_valid(_gear_mass_summary):
		return
	var sel := _gear_mass_selection()
	_gear_mass_summary.text = "%d piece%s  ·  +%s Refining Ore" % [
		sel["uids"].size(), "" if sel["uids"].size() == 1 else "s", NumberFormat.short(sel["ore"])]
	if sel["rare"] > 0:
		_gear_mass_summary.text += "\nIncludes %d %s or higher" % [sel["rare"], Gear.TIER_NAMES[MASS_CONFIRM_FROM]]
	_gear_mass_go.disabled = sel["uids"].is_empty()


func _on_gear_mass_go() -> void:
	var sel := _gear_mass_selection()
	if sel["uids"].is_empty():
		return
	if sel["rare"] > 0:
		_confirm_dialog(_mass_layer,
			"This includes %d %s or higher. This can't be undone." % [sel["rare"], Gear.TIER_NAMES[MASS_CONFIRM_FROM]],
			_do_gear_mass.bind(sel))
	else:
		_do_gear_mass(sel)


func _do_gear_mass(sel: Dictionary) -> void:
	_close_mass()
	var ore := GameState.salvage_gear_batch(sel["uids"])
	if ore > 0:
		_toast("+%s Refining Ore" % NumberFormat.short(ore), COL_PILL)


# ---------------------------------------------------------
# MASS SALVAGE
# ---------------------------------------------------------

## What the current filters would salvage.
func _mass_selection() -> Dictionary:
	var partners: Array = []
	var fragments: Array = []
	var pills := 0
	var qi := 0
	var frag_count := 0
	var rare := 0
	var taken := {}

	if _mass_partners:
		for i in range(1, GameState.roster.size()):
			if GameState.can_salvage_partner(i) != "":
				continue
			var p: OwnedPartner = GameState.roster[i]
			var data := p.get_data()
			if data == null:
				continue
			var t := ItemDB.grade_for_rarity(data.rarity)
			if not _mass_tiers.get(t, false):
				continue
			if _mass_one_star_only and p.stars > 1:
				continue
			partners.append(i)
			taken[p.partner_id] = true
			var value := GameState.get_partner_salvage_value(i)
			pills += value["pills"]
			qi += value["qi"]
			frag_count += value["copies"]
			if t >= MASS_CONFIRM_FROM:
				rare += 1

	if _mass_fragments:
		for id in GameState.partner_copies:
			if taken.has(id):
				continue
			var data = PartnerDatabase.get_partner(id)
			if data == null:
				continue
			var t := ItemDB.grade_for_rarity(data.rarity)
			if not _mass_tiers.get(t, false):
				continue
			var n := GameState.get_copies(id)
			if n <= 0:
				continue
			fragments.append(id)
			frag_count += n
			pills += n * GameState.get_copy_salvage_value(id)
			if t >= MASS_CONFIRM_FROM:
				rare += 1

	return {"partners": partners, "fragments": fragments, "pills": pills,
		"qi": qi, "frag_count": frag_count, "rare": rare}


func _open_mass() -> void:
	_close_mass()
	_mass_layer = CanvasLayer.new()
	_mass_layer.layer = 60
	get_tree().root.add_child(_mass_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(_on_mass_dim_input)
	_mass_layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mass_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c1a30")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(30)
	sb.shadow_color = Color(COL_GOLD, 0.2)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	v.add_child(_label("Mass Salvage", 38, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_fade_line())

	# Tier filters
	v.add_child(_label("Tiers to salvage", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var tiers := GridContainer.new()
	tiers.columns = 4
	tiers.add_theme_constant_override("h_separation", 10)
	tiers.add_theme_constant_override("v_separation", 10)
	v.add_child(tiers)
	for t in 7:
		var tier_text := str(Enums.Rarity.keys()[t]).capitalize()
		tiers.add_child(_mass_toggle(tier_text, ItemDB.grade_color(t), _mass_tiers.get(t, false),
			_on_mass_tier.bind(t), Vector2(190, 56)))

	v.add_child(_fade_line())

	# Options
	v.add_child(_label("Include", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 8)
	v.add_child(opts)
	opts.add_child(_mass_toggle("Whole partners (not in team or array)", COL_GOLD, _mass_partners,
		_on_mass_option.bind("partners"), Vector2(0, 54)))
	opts.add_child(_mass_toggle("Soul Fragments", COL_GOLD, _mass_fragments,
		_on_mass_option.bind("fragments"), Vector2(0, 54)))
	opts.add_child(_mass_toggle("Only 1-star partners (skip starred-up ones)", COL_GOLD, _mass_one_star_only,
		_on_mass_option.bind("one_star"), Vector2(0, 54)))

	v.add_child(_fade_line())

	_mass_summary = _label("", 24, COL_PILL, HORIZONTAL_ALIGNMENT_CENTER)
	_mass_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_mass_summary)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	v.add_child(buttons)

	var cancel := _button("Cancel", Vector2(260, 72), false)
	cancel.pressed.connect(_close_mass)
	buttons.add_child(cancel)

	_mass_go = _button("Salvage", Vector2(300, 72), true, true)
	_mass_go.pressed.connect(_on_mass_go)
	buttons.add_child(_mass_go)

	_update_mass_summary()


func _close_mass() -> void:
	if is_instance_valid(_mass_layer):
		_mass_layer.queue_free()
	_mass_layer = null


func _on_mass_dim_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_mass()


## Toggle button: tinted border, filled when on.
func _mass_toggle(text: String, color: Color, on: bool, callback: Callable, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if min_size.x > 0 else HORIZONTAL_ALIGNMENT_LEFT

	var off := StyleBoxFlat.new()
	off.bg_color = Color(1, 1, 1, 0.03)
	off.border_color = Color(color, 0.35)
	off.set_border_width_all(2)
	off.set_corner_radius_all(8)
	off.set_content_margin_all(10)
	var on_box: StyleBoxFlat = off.duplicate()
	on_box.bg_color = Color(color, 0.18)
	on_box.border_color = color
	on_box.shadow_color = Color(color, 0.25)
	on_box.shadow_size = 6

	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off)
	b.add_theme_stylebox_override("pressed", on_box)
	b.add_theme_stylebox_override("hover_pressed", on_box)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", COL_DIM)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.toggled.connect(callback)
	return b


func _on_mass_tier(on: bool, tier: int) -> void:
	_mass_tiers[tier] = on
	_update_mass_summary()


func _on_mass_option(on: bool, which: String) -> void:
	match which:
		"partners":
			_mass_partners = on
		"fragments":
			_mass_fragments = on
		"one_star":
			_mass_one_star_only = on
	_update_mass_summary()


func _update_mass_summary() -> void:
	if not is_instance_valid(_mass_summary):
		return
	var sel := _mass_selection()
	var parts := PackedStringArray()
	parts.append("%d partner%s" % [sel["partners"].size(), "" if sel["partners"].size() == 1 else "s"])
	parts.append("%s Soul Fragment%s" % [NumberFormat.short(sel["frag_count"]), "" if sel["frag_count"] == 1 else "s"])
	var gains := "+%s Star-up Pills" % NumberFormat.short(sel["pills"])
	if sel["qi"] > 0:
		gains += "   +%s Qi" % NumberFormat.short(sel["qi"])
	_mass_summary.text = "  ·  ".join(parts) + "\n" + gains
	if sel["rare"] > 0:
		_mass_summary.text += "\nIncludes %d Red or higher" % sel["rare"]
	_mass_go.disabled = sel["pills"] <= 0


func _on_mass_go() -> void:
	var sel := _mass_selection()
	if sel["pills"] <= 0:
		return
	if sel["rare"] > 0:
		_confirm_rare(sel)
	else:
		_do_mass(sel)


## Extra step when Red or higher is included.
func _confirm_rare(sel: Dictionary) -> void:
	_confirm_dialog(_mass_layer,
		"This includes %d Red or higher partner%s or fragment%s. This can't be undone." % [
			sel["rare"], "" if sel["rare"] == 1 else "s", "" if sel["rare"] == 1 else "s"],
		_do_mass.bind(sel))


## "Are you sure?" box on top of a popup layer.
func _confirm_dialog(layer: CanvasLayer, message: String, on_yes: Callable) -> void:
	if not is_instance_valid(layer):
		return
	var box := ColorRect.new()
	box.color = Color(0, 0, 0, 0.6)
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	layer.add_child(box)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	box.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a0c10")
	sb.border_color = COL_WARN
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	v.add_child(_label("Are you sure?", 36, COL_WARN, HORIZONTAL_ALIGNMENT_CENTER, true))
	var msg := _label(message, 24, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)

	var back := _button("Go Back", Vector2(240, 70), false)
	back.pressed.connect(box.queue_free)
	row.add_child(back)

	var yes := _button("Salvage Anyway", Vector2(280, 70), false, true)
	yes.pressed.connect(on_yes)
	row.add_child(yes)


func _do_mass(sel: Dictionary) -> void:
	_close_mass()
	var got := GameState.salvage_batch(sel["partners"], sel["fragments"])
	if got["pills"] > 0:
		var msg := "+%s Star-up Pills" % NumberFormat.short(got["pills"])
		if got["qi"] > 0:
			msg += "   +%s Qi" % NumberFormat.short(got["qi"])
		_toast(msg, COL_PILL)


func _do_salvage_copies(partner_id: String) -> void:
	var count := _copy_count
	_close_detail()
	var pills := GameState.salvage_copies(partner_id, count)
	if pills > 0:
		_toast("+%s Star-up Pills" % NumberFormat.short(pills), COL_PILL)


func _do_salvage_partner(index: int) -> void:
	_close_detail()
	var got := GameState.salvage_partner(index)
	if not got.is_empty():
		var msg := "+%s Star-up Pills" % NumberFormat.short(got["pills"])
		if got["qi"] > 0:
			msg += "   +%s Qi" % NumberFormat.short(got["qi"])
		_toast(msg, COL_PILL)


func _disarm_salvage(button: Button) -> void:
	_confirm_armed = false
	button.text = "Salvage Partner"


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _draw_backdrop(c: Control) -> void:
	var s := c.size
	# vertical gradient and a thin gold border
	c.draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	c.draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.4), false, 2.0)
	# faint concentric rings (the ring's "space")
	var center := Vector2(s.x * 0.5, s.y * 0.45)
	for i in 4:
		c.draw_arc(center, s.x * (0.2 + i * 0.12), 0.0, TAU, 96, Color(COL_GOLD, 0.035), 1.5, true)
	# corner ornaments
	var m := 10.0
	var arm := 46.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(m + corner.x * (s.x - m * 2.0), m + corner.y * (s.y - m * 2.0))
		var dx := arm * (1.0 if corner.x == 0 else -1.0)
		var dy := arm * (1.0 if corner.y == 0 else -1.0)
		c.draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), Color(COL_GOLD, 0.7), 2.0, true)
		var g := p + Vector2(dx, dy) * 0.12
		c.draw_colored_polygon(PackedVector2Array([
			g + Vector2(0, -4), g + Vector2(3, 0), g + Vector2(0, 4), g + Vector2(-3, 0)]), COL_GOLD)


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
		var c := Vector2(w * 0.5, y)
		line.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -4), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0)]), COL_GOLD)
	)
	return line


func _toast(text: String, color: Color) -> void:
	var l := _label(text, 30, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	_toast_holder.add_child(l)
	var r := get_global_rect()
	l.size = Vector2(r.size.x, 40)
	l.global_position = Vector2(r.position.x, r.position.y + r.size.y * 0.35)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 60.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.tween_callback(l.queue_free)


func _divider() -> Control:
	return _fade_line()


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


func _button(text: String, min_size: Vector2, gold: bool, danger := false) -> OrnateButton:
	var b := OrnateButton.new()
	b.text = text
	b.custom_minimum_size = min_size
	if danger:
		b.variant = OrnateButton.Variant.CRIMSON
	elif gold:
		b.variant = OrnateButton.Variant.GOLD
	else:
		b.variant = OrnateButton.Variant.DARK
	return b
