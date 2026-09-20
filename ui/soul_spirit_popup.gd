class_name SoulSpiritPopup
extends CanvasLayer

# =========================================================
# Soul Spirit screen for one partner, built in code. Save as
#   res://ui/soul_spirit_popup.gd
#
#   SoulSpiritPopup.open(self, partner_id)
#
# Bond a tamed beast as the partner's Soul Spirit, put spirit
# rings into its 6 slots (they awaken and power its Beast Skill),
# and merge or salvage spare rings. Rules are in beasts.gd.
# =========================================================

const LAYER := 61   # under gear popups (62)

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")

var _partner_id := ""
var _mode := "main"        # main / pick_spirit / pick_ring
var _pick_slot := -1
var _body: VBoxContainer
var _title: Label


static func open(host: Node, partner_id: String) -> SoulSpiritPopup:
	var p := SoulSpiritPopup.new()
	p._partner_id = partner_id
	host.get_tree().root.add_child(p)
	return p


func _ready() -> void:
	layer = LAYER
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
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
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(1000, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = _label("Soul Spirit", 34, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(160, 52)
	close.pressed.connect(queue_free)
	head.add_child(close)
	v.add_child(_line())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 1250)
	v.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 6)
	scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	pad.add_child(_body)

	_rebuild()


func _partner() -> OwnedPartner:
	return GameState.find_owned(_partner_id)


func _rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var p := _partner()
	var data = p.get_data() if p != null else null
	_title.text = "Soul Spirit  ·  %s" % (data.display_name if data != null else "Partner")
	match _mode:
		"pick_spirit":
			_build_spirit_picker()
		"pick_ring":
			_build_ring_picker()
		_:
			_build_main()


# ---------------------------------------------------------
# MAIN VIEW
# ---------------------------------------------------------

func _build_main() -> void:
	var spirit := Beasts.spirit_of(_partner_id)
	if spirit.is_empty():
		var none := _label("No Soul Spirit bonded yet.", 24, COL_TEXT)
		_body.add_child(none)
		var hint := _label("Tame spirit beasts in the Beast Forest (Events > Daily), then bond one here. "
			+ "Put spirit rings into it to awaken its Beast Skill.", 18, COL_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(hint)
		var bond := OrnateButton.new()
		bond.text = "Bond a Soul Spirit (%d free)" % Beasts.free_spirits().size()
		bond.custom_minimum_size = Vector2(420, 64)
		bond.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bond.disabled = Beasts.free_spirits().is_empty()
		bond.pressed.connect(_set_mode.bind("pick_spirit"))
		_body.add_child(bond)
		_body.add_child(_line())
		_build_ring_bag()
		return

	_body.add_child(_spirit_card(spirit))
	_body.add_child(_label("Spirit Rings", 24, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	_body.add_child(_ring_slots(spirit))
	_body.add_child(_line())
	_build_ring_bag()


func _spirit_card(spirit: Dictionary) -> Control:
	var species := str(spirit["species"])
	var entry: Array = Beasts.SPECIES.get(species, [])
	var color := Color(str(entry[6])) if entry.size() > 6 else COL_GOLD

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07)
	sb.border_color = Color(color, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(260, 260)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = Beasts.species_art(species)
	h.add_child(art)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	v.add_child(_label(Beasts.species_name(species), 30, color.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, true))
	var dao := str(Enums.Path.keys()[Beasts.species_dao(species)]).capitalize()
	v.add_child(_label("%s Dao Soul Spirit" % dao, 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_line())

	var skill := Beasts.beast_skill_for(_partner_id)
	var skill_name := str(entry[3]) if entry.size() > 3 else "Beast Skill"
	v.add_child(_label("Beast Skill: %s" % skill_name, 22, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := _label(str(entry[4]) if entry.size() > 4 else "", 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	if skill.is_empty():
		v.add_child(_label("Dormant: put a spirit ring in to awaken it.", 17, COL_BAD, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var line := _label("Awakened  ·  fires every %d actions  ·  %s" % [Beasts.BEAST_EVERY, Skills.summary(skill)],
			16, COL_OK, HORIZONTAL_ALIGNMENT_LEFT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(line)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var change := OrnateButton.new()
	change.text = "Change Spirit"
	change.variant = OrnateButton.Variant.DARK
	change.custom_minimum_size = Vector2(210, 50)
	change.add_theme_font_size_override("font_size", 18)
	change.disabled = Beasts.free_spirits().is_empty()
	change.pressed.connect(_set_mode.bind("pick_spirit"))
	buttons.add_child(change)
	var release := OrnateButton.new()
	release.text = "Release"
	release.variant = OrnateButton.Variant.DARK
	release.custom_minimum_size = Vector2(170, 50)
	release.add_theme_font_size_override("font_size", 18)
	release.pressed.connect(func():
		Beasts.release(int(spirit["uid"]))
		_rebuild()
	)
	buttons.add_child(release)
	return card


## The spirit's 6 ring slots: open, filled or locked by realm.
func _ring_slots(spirit: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	var open_count := Beasts.open_slots(spirit)
	var by_slot := {}
	for r in Beasts.rings_in(spirit):
		by_slot[int(r["slot"])] = r
	for i in Beasts.RING_SLOT_REALMS.size():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		grid.add_child(box)
		if by_slot.has(i):
			var ring: Dictionary = by_slot[i]
			var slot := ItemSlot.new()
			slot.custom_minimum_size = Vector2(140, 140)
			slot.show_count = false
			slot.setup_item(Beasts.ring_icon_id(int(ring["grade"])), 0)
			slot.pressed.connect(_on_filled_slot.bind(int(ring["uid"])))
			box.add_child(slot)
			box.add_child(_label(Beasts.grade_name(int(ring["grade"])), 14,
				Beasts.grade_text_color(int(ring["grade"]))))
		elif i < open_count:
			var empty := _slot_button("+", true)
			empty.pressed.connect(_on_empty_slot.bind(i))
			box.add_child(empty)
			box.add_child(_label("Insert", 14, COL_OK))
		else:
			box.add_child(_slot_button("Locked", false))
			var need := int(Beasts.RING_SLOT_REALMS[i])
			var realm_l := _label(str(Realms.get_label(need, 1)), 12, COL_DIM)
			realm_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			realm_l.custom_minimum_size.x = 140
			box.add_child(realm_l)
	var center := CenterContainer.new()
	center.add_child(grid)
	return center


## Spare rings: merge by age, and each ring with Salvage.
func _build_ring_bag() -> void:
	var spares := Beasts.spare_rings()
	_body.add_child(_label("Ring Bag  (%d spare)" % spares.size(), 24, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	_body.add_child(_label("Beast Cores: %s" % NumberFormat.short(GameState.get_item_count(Beasts.CORE_ID)), 18,
		COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))

	# Merge rows
	for g in 6:
		var n := Beasts.spare_of_age(g).size()
		if n < Beasts.MERGE_COUNT:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := _label("Merge %d × %s  →  1 × %s  (%d cores)" % [Beasts.MERGE_COUNT, Beasts.grade_name(g),
			Beasts.grade_name(g + 1), int(Beasts.MERGE_CORES[g])], 18, Beasts.grade_text_color(g + 1),
			HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var merge := OrnateButton.new()
		merge.text = "Merge"
		merge.custom_minimum_size = Vector2(150, 48)
		merge.disabled = GameState.get_item_count(Beasts.CORE_ID) < int(Beasts.MERGE_CORES[g])
		merge.pressed.connect(_on_merge.bind(g))
		row.add_child(merge)
		_body.add_child(row)

	if spares.is_empty():
		_body.add_child(_label("No spare rings. Hunt in the Beast Forest to find more.", 18, COL_DIM))
	for r in spares:
		_body.add_child(_ring_row(r, "salvage"))


# ---------------------------------------------------------
# PICKERS
# ---------------------------------------------------------

func _build_spirit_picker() -> void:
	_body.add_child(_label("Choose a Soul Spirit", 26, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	var hint := _label("Each spirit bonds one partner. Rings already in a spirit stay with it.", 17, COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT)
	_body.add_child(hint)
	var spirits := Beasts.free_spirits()
	if spirits.is_empty():
		_body.add_child(_label("No free Soul Spirits. Tame more in the Beast Forest.", 20, COL_DIM))
	for s in spirits:
		_body.add_child(_spirit_row(s))
	_body.add_child(_back_button())


func _spirit_row(spirit: Dictionary) -> Control:
	var species := str(spirit["species"])
	var entry: Array = Beasts.SPECIES.get(species, [])
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color("2c4466")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(110, 110)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = Beasts.species_art(species)
	h.add_child(art)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label(Beasts.species_name(species), 22, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var in_it := Beasts.rings_in(spirit).size()
	v.add_child(_label("%s  ·  %d ring%s inside" % [str(entry[3]) if entry.size() > 3 else "Beast Skill",
		in_it, "" if in_it == 1 else "s"], 16, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var d := _label(str(entry[4]) if entry.size() > 4 else "", 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var bond := OrnateButton.new()
	bond.text = "Bond"
	bond.custom_minimum_size = Vector2(150, 54)
	bond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bond.pressed.connect(func():
		var error := Beasts.bond(int(spirit["uid"]), _partner_id)
		if error == "":
			_mode = "main"
		_rebuild()
	)
	h.add_child(bond)
	return row


func _build_ring_picker() -> void:
	_body.add_child(_label("Insert a ring into slot %d" % (_pick_slot + 1), 26, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	var spares := Beasts.spare_rings()
	if spares.is_empty():
		_body.add_child(_label("No spare rings. Hunt in the Beast Forest to find more.", 20, COL_DIM))
	for r in spares:
		_body.add_child(_ring_row(r, "insert"))
	_body.add_child(_back_button())


## One ring: icon, name, its lines, and an action (insert / salvage / remove).
func _ring_row(ring: Dictionary, action: String) -> Control:
	var g := int(ring["grade"])
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.border_color = Color(Beasts.grade_text_color(g), 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var icon := ItemSlot.new()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.show_count = false
	icon.setup_item(Beasts.ring_icon_id(g), 0)
	icon.disabled = true
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label(Beasts.ring_name(ring), 20, Beasts.grade_text_color(g), HORIZONTAL_ALIGNMENT_LEFT))
	for line in Beasts.ring_lines(ring):
		v.add_child(_label(str(line), 16, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))

	var b := OrnateButton.new()
	b.custom_minimum_size = Vector2(160, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	match action:
		"insert":
			b.text = "Insert"
			b.pressed.connect(_on_insert.bind(int(ring["uid"])))
		"remove":
			b.text = "Remove"
			b.variant = OrnateButton.Variant.DARK
			b.pressed.connect(func():
				Beasts.remove_ring(int(ring["uid"]))
				_rebuild()
			)
		_:
			b.text = "Salvage (+%d)" % int(Beasts.SALVAGE_CORES[g])
			b.variant = OrnateButton.Variant.DARK
			b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(func():
				Beasts.salvage(int(ring["uid"]))
				_rebuild()
			)
	h.add_child(b)
	return row


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _set_mode(mode: String) -> void:
	_mode = mode
	_rebuild()


func _on_empty_slot(slot: int) -> void:
	_pick_slot = slot
	_set_mode("pick_ring")


## A filled slot: show that ring with Remove, and the bag to swap from.
func _on_filled_slot(ring_uid: int) -> void:
	var ring := Beasts.find_ring(ring_uid)
	if ring.is_empty():
		return
	_pick_slot = int(ring["slot"])
	_mode = "pick_ring"
	_rebuild()
	_body.add_child(_label("In this slot now:", 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(_ring_row(ring, "remove"))
	_body.move_child(_body.get_child(_body.get_child_count() - 1), 1)
	_body.move_child(_body.get_child(_body.get_child_count() - 1), 1)


func _on_insert(ring_uid: int) -> void:
	var spirit := Beasts.spirit_of(_partner_id)
	if spirit.is_empty():
		return
	Beasts.insert_ring(ring_uid, int(spirit["uid"]), _pick_slot)
	_mode = "main"
	_rebuild()


func _on_merge(g: int) -> void:
	Beasts.merge(g)
	_rebuild()


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

## An empty (open or locked) ring slot, drawn in the same chamfered
## square shape as the item slots.
func _slot_button(text_value: String, is_open: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 140)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not is_open
	b.flat = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.draw.connect(func():
		var r := Rect2(Vector2(6, 6), b.size - Vector2(12, 12))
		var shape := ItemSlot._chamfer(r, r.size.x * 0.14)
		var fill := Color(0.05, 0.09, 0.17, 0.95) if is_open else Color(0.03, 0.05, 0.1, 0.8)
		if is_open and b.is_hovered():
			fill = Color(0.08, 0.14, 0.24, 0.95)
		b.draw_colored_polygon(shape, fill)
		var outline := shape.duplicate()
		outline.append(shape[0])
		b.draw_polyline(outline, Color(COL_OK, 0.55) if is_open else Color("2c3a50"), 2.0, true)
		var font := b.get_theme_default_font()
		var fs := 48 if is_open else 16
		var w := font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		b.draw_string(font, r.get_center() + Vector2(-w * 0.5, fs * 0.35), text_value,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_OK if is_open else COL_DIM)
	)
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	return b


func _back_button() -> Control:
	var back := OrnateButton.new()
	back.text = "Back"
	back.variant = OrnateButton.Variant.DARK
	back.custom_minimum_size = Vector2(200, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_set_mode.bind("main"))
	return back


func _line() -> Control:
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
