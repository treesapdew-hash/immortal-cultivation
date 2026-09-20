class_name TreasurePopup
extends CanvasLayer

# =========================================================
#   TreasurePopup.open_details(host, uid)
#   TreasurePopup.open_details(host, uid, partner_id)   # with Equip
#   TreasurePopup.open_picker(host, partner_id, slot)
# =========================================================

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")

var _mode := "details"
var _uid := 0
var _partner_id := ""
var _slot := 0
var _panel: PanelContainer
var _body: VBoxContainer
var _hint: Label
var _salvage_armed := false


static func open_details(host: Node, uid: int, partner_id := "") -> TreasurePopup:
	var p := TreasurePopup.new()
	p._mode = "details"
	p._uid = uid
	p._partner_id = partner_id
	host.get_tree().root.add_child.call_deferred(p)
	return p


static func open_picker(host: Node, partner_id: String, slot: int) -> TreasurePopup:
	var p := TreasurePopup.new()
	p._mode = "picker"
	p._partner_id = partner_id
	p._slot = slot
	host.get_tree().root.add_child.call_deferred(p)
	return p


func _ready() -> void:
	layer = 62
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			queue_free()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(860, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)

	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if _mode == "picker":
		_build_picker()
	else:
		_build_details()
	_fit.call_deferred()


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var scroll := _panel.get_child(0) as ScrollContainer
	scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, vp.y * 0.8)


# ---------------------------------------------------------
# PICKER
# ---------------------------------------------------------

func _build_picker() -> void:
	_body.add_child(_label("Choose a Treasure", 34, COL_TITLE, true))
	_body.add_child(_label("Slot %d of %d  ·  for %s" % [_slot + 1, Treasures.SLOTS, _name_of(_partner_id)],
		20, COL_DIM))

	var worn := GameState.treasures_of(_partner_id)
	if worn.size() >= 2:
		var sets := {}
		for t in worn:
			sets[Treasures.set_of(t)] = true
		if sets.size() == 1:
			var set_id: String = sets.keys()[0]
			_body.add_child(_label("Wearing %d/3 of %s — one more completes the set" % [
				worn.size(), Treasures.set_def(set_id).get("name", "")],
				19, COL_OK))
	_body.add_child(_line())

	var items: Array = GameState.treasures.duplicate()
	items.sort_custom(func(a, b):
		var af: bool = a.get("owner", "") == ""
		var bf: bool = b.get("owner", "") == ""
		if af != bf:
			return af
		if int(a["grade"]) != int(b["grade"]):
			return int(a["grade"]) > int(b["grade"])
		return int(a.get("level", 0)) > int(b.get("level", 0)))

	if items.is_empty():
		var l := _label("You have no treasures yet. The Treasure Vault (Events tab) drops them.", 22, COL_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		var holder := CenterContainer.new()
		holder.add_child(grid)
		_body.add_child(holder)
		for t in items:
			grid.add_child(_picker_card(t))

	_body.add_child(_button("Close", false, false, queue_free))


func _picker_card(t: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(188, 0)
	card.add_theme_constant_override("separation", 2)

	var icon := TreasureIcon.new()
	icon.custom_minimum_size = Vector2(118, 118)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(t)
	icon.pressed.connect(_show_item.bind(int(t["uid"])))
	card.add_child(icon)

	var name_l := _label(Treasures.item_name(t), 17, Treasures.grade_color(int(t["grade"])).lightened(0.25))
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(name_l)

	card.add_child(_label("%s  +%d" % [Treasures.grade_name(int(t["grade"])), int(t.get("level", 0))], 15, COL_DIM))
	var set_def := Treasures.set_def(Treasures.set_of(t))
	card.add_child(_label(str(set_def.get("name", "")), 15, set_def.get("color", COL_TEXT)))
	card.add_child(_label(Treasures.stat_text(t), 15, COL_TEXT))

	var wearer: String = t.get("owner", "")
	if wearer == _partner_id and wearer != "":
		card.add_child(_label("Equipped", 15, COL_OK))
	elif wearer != "":
		card.add_child(_label("On %s" % _name_of(wearer), 14, COL_DIM))
	return card


func _show_item(uid: int) -> void:
	_mode = "details"
	_uid = uid
	_rebuild()


# ---------------------------------------------------------
# DETAILS
# ---------------------------------------------------------

func _build_details() -> void:
	var t := GameState.find_treasure(_uid)
	if t.is_empty():
		queue_free()
		return
	var grade := int(t["grade"])
	var color := Treasures.grade_color(grade)
	var set_id := Treasures.set_of(t)
	var set_def := Treasures.set_def(set_id)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_body.add_child(head)
	var icon := TreasureIcon.new()
	icon.custom_minimum_size = Vector2(130, 130)
	icon.disabled = true
	icon.setup(t)
	head.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(info)
	info.add_child(_label(Treasures.item_name(t), 32, color.lightened(0.25), true, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label("%s  ·  %s Set  ·  +%d" % [Treasures.grade_name(grade),
		set_def.get("name", ""), int(t.get("level", 0))], 20, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label(Treasures.stat_text(t), 24, COL_OK, false, HORIZONTAL_ALIGNMENT_LEFT))
	var wearer: String = t.get("owner", "")
	if wearer != "":
		info.add_child(_label("Held by %s" % _name_of(wearer), 19, COL_OK, false, HORIZONTAL_ALIGNMENT_LEFT))

	var desc := _label(str(Treasures.get_def(t["id"]).get("desc", "")), 20, COL_TEXT, false, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(desc)
	_body.add_child(_line())

	# The set
	var worn := 0
	if wearer != "":
		for other in GameState.treasures_of(wearer):
			if Treasures.set_of(other) == set_id:
				worn += 1
	_body.add_child(_label("%s Set   (%d/3 held)" % [set_def.get("name", ""), worn], 24,
		set_def.get("color", COL_TEXT), true, HORIZONTAL_ALIGNMENT_LEFT))
	var set_line := _label("All 3 slots:  " + Treasures.set_effect_text(set_id, grade), 20,
		COL_TEXT if worn >= 3 else COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT)
	set_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(set_line)
	_body.add_child(_label("Shown at %s. The effect uses your weakest treasure of the set." % Treasures.grade_name(grade),
		17, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))

	# Enhancing
	_body.add_child(_line())
	var level := int(t.get("level", 0))
	var dust := GameState.get_item_count(Treasures.DUST_ID)
	var enhance_row := HBoxContainer.new()
	enhance_row.add_theme_constant_override("separation", 12)
	_body.add_child(enhance_row)
	var cost_text := "Fully enhanced (+%d)" % Treasures.MAX_LEVEL
	if level < Treasures.MAX_LEVEL:
		cost_text = "Enhance to +%d:  %s Treasure Dust  (have %s)" % [level + 1,
			NumberFormat.short(Treasures.enhance_cost(t)), NumberFormat.short(dust)]
	var cost_l := _label(cost_text, 19, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT)
	cost_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enhance_row.add_child(cost_l)
	var e1 := _button("Enhance +1", true, false, _on_enhance.bind(1))
	e1.custom_minimum_size = Vector2(190, 58)
	e1.disabled = level >= Treasures.MAX_LEVEL
	enhance_row.add_child(e1)
	var e5 := _button("+5", false, false, _on_enhance.bind(5))
	e5.custom_minimum_size = Vector2(100, 58)
	e5.disabled = level >= Treasures.MAX_LEVEL
	enhance_row.add_child(e5)

	_hint = _label("", 20, COL_BAD)
	_hint.custom_minimum_size.y = 26
	_body.add_child(_hint)

	# Actions
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 10)
	_body.add_child(actions)

	if _partner_id != "":
		if wearer == _partner_id:
			actions.add_child(_button("Swap", true, false, _open_slot_picker))
			actions.add_child(_button("Unequip", false, false, _on_unequip))
		else:
			actions.add_child(_button("Equip" if wearer == "" else "Take & Equip", true, false, _on_equip))

	var copies := Treasures.merge_partners(t).size()
	var merge := _button("Grade Up (%d/2)" % mini(copies, 2), false, false, _on_merge)
	merge.disabled = copies < Treasures.MERGE_COST - 1 or grade >= Treasures.GRADES - 1
	actions.add_child(merge)

	var locked: bool = t.get("locked", false)
	actions.add_child(_button("Unlock" if locked else "Lock", false, false, _on_lock))

	var salvage := _button("Salvage (+%s Dust)" % NumberFormat.short(Treasures.salvage_value(t)),
		false, true, _on_salvage)
	salvage.disabled = locked or wearer != ""
	actions.add_child(salvage)

	if copies < Treasures.MERGE_COST - 1:
		_body.add_child(_label("Grade up: %d copies of the same treasure and grade, plus %s Dust." % [
			Treasures.MERGE_COST, NumberFormat.short(Treasures.merge_dust_cost(t))], 17, COL_DIM))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	_body.add_child(bottom)
	if _partner_id != "":
		bottom.add_child(_button("Back", false, false, _open_slot_picker))
	bottom.add_child(_button("Close", false, false, queue_free))


func _name_of(partner_id: String) -> String:
	if partner_id == GameState.MC_ID:
		return GameState.mc_name
	var data = PartnerDatabase.get_partner(partner_id)
	return data.display_name if data != null else partner_id


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _on_enhance(times: int) -> void:
	var error := ""
	var done := 0
	for i in times:
		error = Treasures.enhance(GameState.find_treasure(_uid))
		if error != "":
			break
		done += 1
	_rebuild()
	if error != "":
		_hint.text = error if done == 0 else "Enhanced +%d, then: %s" % [done, error]


func _on_equip() -> void:
	GameState.equip_treasure(_uid, _partner_id, _slot)
	queue_free()


func _on_unequip() -> void:
	GameState.unequip_treasure(_uid)
	queue_free()


func _on_merge() -> void:
	var error := Treasures.merge(GameState.find_treasure(_uid))
	_rebuild()
	if error != "":
		_hint.text = error
	else:
		_hint.add_theme_color_override("font_color", COL_OK)
		_hint.text = "Now %s!" % Treasures.grade_name(int(GameState.find_treasure(_uid)["grade"]))


func _on_lock() -> void:
	var t := GameState.find_treasure(_uid)
	t["locked"] = not t.get("locked", false)
	GameState.treasures_changed()
	_rebuild()


func _on_salvage() -> void:
	var t := GameState.find_treasure(_uid)
	if int(t["grade"]) >= 4 and not _salvage_armed:
		_salvage_armed = true
		_hint.text = "This is %s. Tap Salvage again to confirm." % Treasures.grade_name(int(t["grade"]))
		return
	if GameState.salvage_treasure(_uid) > 0:
		queue_free()


func _open_slot_picker() -> void:
	_mode = "picker"
	_rebuild()


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(COL_GOLD, 0.0), Color(COL_GOLD, 0.6), Color(COL_GOLD, 0.0)]), 1.5, true)
	)
	return line


func _label(text: String, font_size: int, color: Color, glow := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(color, 0.3))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l


func _button(text: String, gold: bool, danger: bool, callback: Callable) -> OrnateButton:
	var b := OrnateButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 64)
	if danger:
		b.variant = OrnateButton.Variant.CRIMSON
	elif gold:
		b.variant = OrnateButton.Variant.GOLD
	else:
		b.variant = OrnateButton.Variant.DARK
	b.pressed.connect(callback)
	return b
