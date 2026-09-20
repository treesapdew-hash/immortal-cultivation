class_name ArtifactPopup
extends CanvasLayer

# =========================================================
#   ArtifactPopup.open_details(host, uid)
#   ArtifactPopup.open_details(host, uid, partner_id)   # with Equip
#   ArtifactPopup.open_picker(host, partner_id, slot)
#   ArtifactPopup.open_lifebound(host, partner_id)      # bonded artifact
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
var _last_roll: Array = []


static func open_details(host: Node, uid: int, partner_id := "") -> ArtifactPopup:
	return _open(host, "details", uid, partner_id, 0)


static func open_picker(host: Node, partner_id: String, slot: int) -> ArtifactPopup:
	return _open(host, "picker", 0, partner_id, slot)


static func open_lifebound(host: Node, partner_id: String) -> ArtifactPopup:
	return _open(host, "lifebound", 0, partner_id, 0)


static func _open(host: Node, mode: String, uid: int, partner_id: String, slot: int) -> ArtifactPopup:
	var p := ArtifactPopup.new()
	p._mode = mode
	p._uid = uid
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
	match _mode:
		"picker":
			_build_picker()
		"lifebound":
			_build_lifebound()
		_:
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
	_body.add_child(_label("Choose an Artifact", 34, COL_TITLE, true))
	_body.add_child(_label("Slot %d of %d  ·  for %s" % [_slot + 1, Artifacts.SLOTS, _name_of(_partner_id)],
		20, COL_DIM))
	_body.add_child(_line())

	var items: Array = GameState.artifacts.duplicate()
	items.sort_custom(func(a, b):
		var af: bool = a.get("owner", "") == ""
		var bf: bool = b.get("owner", "") == ""
		if af != bf:
			return af
		return int(a["grade"]) > int(b["grade"]))

	if items.is_empty():
		var l := _label("You have no artifacts yet. Forge them at the Spirit Forge (Growth tab).", 22, COL_DIM)
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
		for a in items:
			grid.add_child(_picker_card(a))

	_body.add_child(_button("Close", false, false, queue_free))


func _picker_card(a: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(190, 0)
	card.add_theme_constant_override("separation", 2)

	var icon := ArtifactIcon.new()
	icon.custom_minimum_size = Vector2(118, 118)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(a)
	icon.pressed.connect(_show_item.bind(int(a["uid"])))
	card.add_child(icon)

	card.add_child(_label(Artifacts.trait_name(a), 17, Artifacts.color_of(a).lightened(0.2)))
	card.add_child(_label(Artifacts.grade_name(int(a["grade"])), 15, COL_DIM))
	var effect := _label(Artifacts.trait_text(a), 14, COL_TEXT)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	card.add_child(effect)

	var wearer: String = a.get("owner", "")
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
	var a := GameState.find_artifact(_uid)
	if a.is_empty():
		queue_free()
		return
	var grade := int(a["grade"])

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_body.add_child(head)
	var icon := ArtifactIcon.new()
	icon.custom_minimum_size = Vector2(130, 130)
	icon.disabled = true
	icon.setup(a)
	head.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(info)
	info.add_child(_label(Artifacts.trait_name(a), 32, Artifacts.color_of(a).lightened(0.2), true, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label(Artifacts.grade_name(grade), 20, Artifacts.grade_color(grade), false, HORIZONTAL_ALIGNMENT_LEFT))
	var effect := _label(Artifacts.trait_text(a), 22, COL_OK, false, HORIZONTAL_ALIGNMENT_LEFT)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(effect)
	var wearer: String = a.get("owner", "")
	if wearer != "":
		info.add_child(_label("Held by %s" % _name_of(wearer), 19, COL_OK, false, HORIZONTAL_ALIGNMENT_LEFT))

	_body.add_child(_line())
	var cores := GameState.get_item_count(Artifacts.CORE_ID)
	_body.add_child(_label("Artifact Cores: %s" % NumberFormat.short(cores), 19, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))

	_hint = _label("", 20, COL_BAD)
	_hint.custom_minimum_size.y = 26
	_body.add_child(_hint)

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

	var temper := _button("Temper (%s)" % NumberFormat.short(Artifacts.temper_cost(a)), true, false, _on_temper)
	temper.disabled = grade >= Artifacts.GRADES - 1
	actions.add_child(temper)
	actions.add_child(_button("Unlock" if a.get("locked", false) else "Lock", false, false, _on_lock))
	var salvage := _button("Salvage (+%s)" % NumberFormat.short(Artifacts.salvage_value(a)),
		false, true, _on_salvage)
	salvage.disabled = a.get("locked", false) or wearer != ""
	actions.add_child(salvage)

	_body.add_child(_label("An artifact's trait is fixed at the forge. Tempering raises its grade; "
		+ "salvage the ones you don't want.", 17, COL_DIM))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	_body.add_child(bottom)
	if _partner_id != "":
		bottom.add_child(_button("Back", false, false, _open_slot_picker))
	bottom.add_child(_button("Close", false, false, queue_free))


# ---------------------------------------------------------
# LIFEBOUND ARTIFACT
# ---------------------------------------------------------

func _build_lifebound() -> void:
	var artifact := Lifebound.get_for(_partner_id)
	var grade := int(artifact["grade"])

	var stars := int(artifact.get("stars", 0))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_body.add_child(head)
	var icon := LifeboundIcon.new()
	icon.custom_minimum_size = Vector2(110, 110)
	icon.disabled = true
	icon.setup(artifact)
	head.add_child(icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	titles.add_child(_label("Lifebound Artifact", 32, COL_TITLE, true, HORIZONTAL_ALIGNMENT_LEFT))
	titles.add_child(_label("%s  ·  %s  ·  %d★" % [_name_of(_partner_id), ItemDB.grade_name(grade), stars],
		20, ItemDB.grade_color(grade), false, HORIZONTAL_ALIGNMENT_LEFT))
	if stars > 0:
		titles.add_child(_label("Stars raise every line by %d%%" % int((Lifebound.star_mult(artifact) - 1.0) * 100),
			18, COL_OK, false, HORIZONTAL_ALIGNMENT_LEFT))
	var intro := _label("Upgrading rerolls every unsealed line: values can rise or fall. "
		+ "Seal the ones you like, though each sealed line makes upgrading cost more.",
		18, COL_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(intro)
	_body.add_child(_line())

	if stars <= 0:
		var none := _label("Nothing is bonded yet. Craft a Lifebound Seed at the Spirit Forge, "
			+ "then bond it here.", 20, COL_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(none)

	for i in artifact["lines"].size():
		_body.add_child(_lifebound_row(artifact, i))

	# Bonding a seed
	_body.add_child(_line())
	var seeds := HBoxContainer.new()
	seeds.add_theme_constant_override("separation", 10)
	_body.add_child(seeds)
	seeds.add_child(_label("Seeds:", 19, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	var has_seed := false
	for star in range(Lifebound.MAX_STARS, 0, -1):
		var count := Lifebound.seed_count(star)
		if count <= 0:
			continue
		has_seed = true
		var bond := _button("Bond %d★ (x%d)" % [star, count], star > stars, false, _on_bond.bind(star))
		bond.custom_minimum_size = Vector2(190, 52)
		bond.disabled = star <= stars
		seeds.add_child(bond)
	if not has_seed:
		seeds.add_child(_label("none — craft them at the Spirit Forge", 18, COL_DIM,
			false, HORIZONTAL_ALIGNMENT_LEFT))

	_hint = _label("", 20, COL_BAD)
	_hint.custom_minimum_size.y = 26
	_body.add_child(_hint)

	var essence := GameState.get_item_count(Lifebound.ESSENCE_ID)
	_body.add_child(_label("Lifebound Essence: %s" % NumberFormat.short(essence), 19, COL_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	row.add_child(_button("Upgrade (%s)" % NumberFormat.short(Lifebound.upgrade_cost(artifact)),
		true, false, _on_lifebound_upgrade))
	var grade_button := _button("Raise Grade (%s)" % NumberFormat.short(Lifebound.grade_up_cost(artifact)),
		false, false, _on_lifebound_grade)
	grade_button.disabled = grade >= Lifebound.GRADES - 1
	row.add_child(grade_button)
	row.add_child(_button("Close", false, false, queue_free))


func _lifebound_row(artifact: Dictionary, index: int) -> Control:
	var line: Dictionary = artifact["lines"][index]
	var stat: String = line["stat"]
	var sealed: bool = line["sealed"]
	var fill := Lifebound.line_fill(artifact, index)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)

	var head := HBoxContainer.new()
	texts.add_child(head)
	var name_l := _label(Gear.format_stat(stat, float(line["value"])), 22,
		COL_OK if sealed else COL_TEXT, false, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	# What it rolled last time
	if index < _last_roll.size():
		var delta := float(line["value"]) - float(_last_roll[index])
		if absf(delta) > 0.05:
			head.add_child(_label("%s%s" % ["+" if delta > 0 else "", String.num(snappedf(delta, 0.1))],
				18, COL_OK if delta > 0 else COL_BAD, false, HORIZONTAL_ALIGNMENT_RIGHT))
	head.add_child(_label("max %s" % String.num(snappedf(Lifebound.stat_ceiling(stat, int(artifact["grade"])), 0.1)),
		16, COL_DIM, false, HORIZONTAL_ALIGNMENT_RIGHT))

	# The fill bar
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 2, w, 10), Color(0, 0, 0, 0.45))
		bar.draw_rect(Rect2(0, 2, w * fill, 10), COL_OK if sealed else Color("8fc8ff"))
		bar.draw_rect(Rect2(0, 2, w, 10), Color(COL_GOLD, 0.35), false, 1.0)
	)
	texts.add_child(bar)

	var seal := _button("Sealed" if sealed else "Seal", sealed, false, _on_seal.bind(index))
	seal.custom_minimum_size = Vector2(150, 52)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seal)
	return row


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _on_equip() -> void:
	GameState.equip_artifact(_uid, _partner_id, _slot)
	queue_free()


func _on_unequip() -> void:
	GameState.unequip_artifact(_uid)
	queue_free()


func _on_temper() -> void:
	var error := Artifacts.temper(GameState.find_artifact(_uid))
	_rebuild()
	if error != "":
		_hint.text = error


func _on_lock() -> void:
	var a := GameState.find_artifact(_uid)
	a["locked"] = not a.get("locked", false)
	GameState.artifacts_changed()
	_rebuild()


func _on_salvage() -> void:
	var a := GameState.find_artifact(_uid)
	if int(a["grade"]) >= 4 and not _salvage_armed:
		_salvage_armed = true
		_hint.text = "This is %s. Tap Salvage again to confirm." % Artifacts.grade_name(int(a["grade"]))
		return
	if GameState.salvage_artifact(_uid) > 0:
		queue_free()


func _open_slot_picker() -> void:
	_mode = "picker"
	_rebuild()


func _on_seal(index: int) -> void:
	Lifebound.toggle_seal(_partner_id, index)
	_rebuild()


func _on_lifebound_upgrade() -> void:
	var out := Lifebound.upgrade(_partner_id)
	_last_roll = out.get("before", [])
	_rebuild()
	if out.has("error"):
		_hint.text = str(out["error"])


func _on_bond(star: int) -> void:
	var error := Lifebound.bond(_partner_id, star)
	_rebuild()
	if error != "":
		_hint.text = error


func _on_lifebound_grade() -> void:
	var error := Lifebound.grade_up(_partner_id)
	_last_roll = []
	_rebuild()
	if error != "":
		_hint.text = error


func _name_of(partner_id: String) -> String:
	if partner_id == GameState.MC_ID:
		return GameState.mc_name
	var data = PartnerDatabase.get_partner(partner_id)
	return data.display_name if data != null else partner_id


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
	b.custom_minimum_size = Vector2(250, 62)
	if danger:
		b.variant = OrnateButton.Variant.CRIMSON
	elif gold:
		b.variant = OrnateButton.Variant.GOLD
	else:
		b.variant = OrnateButton.Variant.DARK
	b.pressed.connect(callback)
	return b
