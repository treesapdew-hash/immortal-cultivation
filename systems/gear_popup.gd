class_name GearPopup
extends CanvasLayer

# =========================================================
#   GearPopup.open_details(host, uid)                # from the Inventory
#   GearPopup.open_details(host, uid, partner_id)    # with Equip / Unequip
#   GearPopup.open_picker(host, partner_id, slot)    # choose gear for a slot
# =========================================================

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_BONUS := Color("8fc8ff")
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


static func open_details(host: Node, uid: int, partner_id := "") -> GearPopup:
	var p := GearPopup.new()
	p._mode = "details"
	p._uid = uid
	p._partner_id = partner_id
	host.get_tree().root.add_child.call_deferred(p)
	return p


static func open_picker(host: Node, partner_id: String, slot: int) -> GearPopup:
	var p := GearPopup.new()
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
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(880, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(COL_GOLD, 0.18)
	sb.shadow_size = 20
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 0)
	_panel.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)

	_rebuild()


func _on_dim_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _rebuild() -> void:
	_clear()
	match _mode:
		"picker":
			_build_picker()
		"transfer":
			_build_transfer()
		_:
			_build_details()
	_fit.call_deferred()


## Keeps the popup inside the screen; scrolls if it's taller.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var scroll := _panel.get_child(0) as ScrollContainer
	scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, vp.y * 0.8)


# ---------------------------------------------------------
# PICKER
# ---------------------------------------------------------

func _build_picker() -> void:
	var data = PartnerDatabase.get_partner(_partner_id)
	var who: String = GameState.mc_name if _partner_id == GameState.MC_ID else (data.display_name if data != null else "")
	_body.add_child(_label("Choose %s" % Gear.SLOT_NAMES[_slot], 34, COL_TITLE, true))
	_body.add_child(_label("for %s" % who, 20, COL_DIM))
	_body.add_child(_line())

	var items: Array = GameState.gear.filter(func(g): return int(g["slot"]) == _slot)
	# Free pieces first, then best grade and refine
	items.sort_custom(func(a, b):
		var af: bool = a.get("owner", "") == ""
		var bf: bool = b.get("owner", "") == ""
		if af != bf:
			return af
		if Gear.grade_index(a) != Gear.grade_index(b):
			return Gear.grade_index(a) > Gear.grade_index(b)
		return int(a["refine"]) > int(b["refine"]))

	var equipped := GameState.gear_in_slot(_partner_id, _slot)
	var equipped_score := Gear.score(equipped) if not equipped.is_empty() else 0.0

	if items.is_empty():
		var l := _label("You have no %s yet. The Armory Ruins (Events tab) drop equipment." % Gear.SLOT_NAMES[_slot].to_lower(), 22, COL_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)
	else:
		if not equipped.is_empty():
			_body.add_child(_label("Wearing: %s  ·  %s  ·  +%d" % [
				Gear.item_name(equipped), Gear.grade_text(equipped), int(equipped["refine"])],
				19, COL_OK, false, HORIZONTAL_ALIGNMENT_CENTER))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		var holder := CenterContainer.new()
		holder.add_child(grid)
		_body.add_child(holder)
		for item in items:
			grid.add_child(_picker_card(item, equipped_score))

	_body.add_child(_button("Close", false, false, queue_free))


func _open_slot_picker() -> void:
	_mode = "picker"
	_slot = int(GameState.find_gear(_uid).get("slot", _slot))
	_rebuild()


func _open_transfer() -> void:
	_mode = "transfer"
	_rebuild()


## Pick another piece whose refine level moves onto this one.
func _build_transfer() -> void:
	var item := GameState.find_gear(_uid)
	if item.is_empty():
		queue_free()
		return
	_body.add_child(_label("Transfer Refinement", 34, COL_TITLE, true))
	_body.add_child(_label("Move another %s's refine level onto %s (+%d)." % [
		Gear.SLOT_NAMES[int(item["slot"])].to_lower(), Gear.item_name(item), int(item["refine"])],
		20, COL_TEXT))
	_body.add_child(_label("The piece you choose is used up.", 18, COL_DIM))
	_body.add_child(_line())

	var sources := Gear.transfer_sources(item)
	if sources.is_empty():
		_body.add_child(_label("No refined %s to take from." % Gear.SLOT_NAMES[int(item["slot"])].to_lower(), 20, COL_DIM))
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		_body.add_child(list)
		for source in sources:
			list.add_child(_transfer_row(item, source))

	_hint = _label("", 20, COL_BAD)
	_hint.custom_minimum_size.y = 26
	_body.add_child(_hint)
	_body.add_child(_button("Back", false, false, _show_item.bind(_uid)))


func _transfer_row(item: Dictionary, source: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon := GearIcon.new()
	icon.custom_minimum_size = Vector2(84, 84)
	icon.disabled = true
	icon.setup(source)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(_label("%s  +%d" % [Gear.item_name(source), int(source["refine"])],
		22, Gear.tier_color(source).lightened(0.25), false, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label("%s  ·  %s Stones" % [Gear.grade_text(source),
		NumberFormat.short(Gear.transfer_cost(source))], 18, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))

	var take := _button("Take +%d" % int(source["refine"]), true, false, _on_transfer.bind(int(source["uid"])))
	take.custom_minimum_size = Vector2(190, 58)
	take.disabled = int(source["refine"]) <= int(item["refine"])
	row.add_child(take)
	return row


func _on_transfer(source_uid: int) -> void:
	var error := Gear.transfer_refine(GameState.find_gear(_uid), GameState.find_gear(source_uid))
	if error != "":
		_hint.text = error
		return
	_show_item(_uid)


## One choice in the picker: icon, name, grade and how it compares.
func _picker_card(item: Dictionary, equipped_score: float) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(188, 0)
	card.add_theme_constant_override("separation", 2)

	var icon := GearIcon.new()
	icon.custom_minimum_size = Vector2(118, 118)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(item)
	icon.pressed.connect(_show_item.bind(int(item["uid"])))
	card.add_child(icon)

	var name_l := _label(Gear.item_name(item), 17, Gear.tier_color(item).lightened(0.25))
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(name_l)

	var grade_l := _label("%s  +%d" % [Gear.grade_text(item), int(item["refine"])], 15, COL_DIM)
	grade_l.clip_text = true
	card.add_child(grade_l)

	var set_def: Dictionary = Gear.SETS.get(item["set"], {})
	card.add_child(_label(str(set_def.get("name", "")), 15, set_def.get("color", COL_TEXT)))

	# Better or worse than what's worn
	var wearer: String = item.get("owner", "")
	if wearer == _partner_id and wearer != "":
		card.add_child(_label("Equipped", 16, COL_OK))
	else:
		var diff := Gear.score(item) - equipped_score
		var pct := 100.0 if equipped_score <= 0.0 else diff / equipped_score * 100.0
		var text := "New" if equipped_score <= 0.0 else "%s%d%% power" % ["+" if diff > 0.0 else "", int(pct)]
		card.add_child(_label(text, 16, COL_OK if diff > 0.0 else COL_BAD))
		if wearer != "":
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
	var item := GameState.find_gear(_uid)
	if item.is_empty():
		queue_free()
		return
	var color := Gear.tier_color(item)

	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_body.add_child(head)
	var icon := GearIcon.new()
	icon.custom_minimum_size = Vector2(130, 130)
	icon.disabled = true
	icon.setup(item)
	head.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(info)
	info.add_child(_label(Gear.item_name(item), 32, color.lightened(0.25), true, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label("%s  ·  %s" % [Gear.grade_text(item), Gear.SLOT_NAMES[int(item["slot"])]],
		20, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(_label("Refined  +%d / +%d" % [int(item["refine"]), Gear.MAX_REFINE],
		20, COL_TITLE, false, HORIZONTAL_ALIGNMENT_LEFT))
	var wearer: String = item.get("owner", "")
	if wearer != "":
		info.add_child(_label("Worn by %s" % _name_of(wearer), 20, COL_OK, false, HORIZONTAL_ALIGNMENT_LEFT))

	# Compared with what's already in that slot
	if _partner_id != "" and wearer != _partner_id:
		var current := GameState.gear_in_slot(_partner_id, int(item["slot"]))
		if not current.is_empty():
			_body.add_child(_line())
			_body.add_child(_label("Compared with %s (+%d)" % [Gear.item_name(current), int(current["refine"])],
				20, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
			var now := Gear.item_stats(current)
			var soon := Gear.item_stats(item)
			var keys := {}
			for k in now:
				keys[k] = true
			for k in soon:
				keys[k] = true
			var diff := HBoxContainer.new()
			diff.add_theme_constant_override("separation", 18)
			_body.add_child(diff)
			for stat in keys:
				var delta := float(soon.get(stat, 0.0)) - float(now.get(stat, 0.0))
				if absf(delta) < 0.05:
					continue
				var sign_text := "+" if delta > 0.0 else "-"
				var text := "%s %s%s" % [Gear.STAT_NAMES.get(stat, stat), sign_text,
					(String.num(snappedf(absf(delta), 0.1)) + "%") if stat in Gear.PERCENT_STATS
					else NumberFormat.short(int(absf(delta)))]
				diff.add_child(_label(text, 19, COL_OK if delta > 0.0 else COL_BAD, false, HORIZONTAL_ALIGNMENT_LEFT))

	_body.add_child(_line())

	# Stats
	var stats := Gear.item_stats(item)
	var main := Gear.main_stats(int(item["slot"]), Gear.grade_index(item))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_body.add_child(grid)
	for stat in main:
		grid.add_child(_label("◆ " + Gear.format_stat(stat, stats[stat]), 22, COL_TEXT, false, HORIZONTAL_ALIGNMENT_LEFT))
	for line in item["bonus"]:
		var stat: String = line[0]
		var v := Gear.bonus_value(stat, Gear.grade_index(item), float(line[1])) * Gear.refine_mult(stat, int(item["refine"]))
		grid.add_child(_label("◇ " + Gear.format_stat(stat, v), 22, COL_BONUS, false, HORIZONTAL_ALIGNMENT_LEFT))

	# Set
	_body.add_child(_line())
	var set_def: Dictionary = Gear.SETS.get(item["set"], {})
	if not set_def.is_empty():
		var worn := 0
		if wearer != "":
			worn = int(Gear.set_counts(wearer).get(item["set"], 0))
		var dao_name: String = Enums.PATH_NAMES.get(set_def["dao"], "")
		_body.add_child(_label("%s Set   (%d/4 worn)" % [set_def["name"], worn], 24, set_def["color"], true, HORIZONTAL_ALIGNMENT_LEFT))
		# Numbers shown at this piece's grade (Dao match not included)
		var g := Gear.grade_index(item)
		var two := PackedStringArray()
		var two_stats := Gear.two_piece(item["set"], g)
		for stat in two_stats:
			two.append(Gear.format_stat(stat, two_stats[stat]))
		_body.add_child(_label("2 pieces:  " + ", ".join(two), 20, COL_TEXT if worn >= 2 else COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
		var four := _label("4 pieces:  " + Gear.four_piece_text(item["set"], g), 20, COL_TEXT if worn >= 4 else COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT)
		four.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(four)
		_body.add_child(_label("Shown at %s. Set bonuses use your weakest counted piece." % Gear.grade_text(item),
			17, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
		_body.add_child(_label("%s: +50%% set bonuses on %s partners" % [dao_name, dao_name.trim_suffix(" Path")],
			18, COL_GOLD, false, HORIZONTAL_ALIGNMENT_LEFT))

	# Refine
	_body.add_child(_line())
	var refine_row := HBoxContainer.new()
	refine_row.add_theme_constant_override("separation", 12)
	_body.add_child(refine_row)
	var r := int(item["refine"])
	var cost_text := "Max refine reached"
	if r < Gear.MAX_REFINE:
		var cost := Gear.refine_cost(item)
		var ore_name: String = ItemDB.get_item(cost["ore_id"]).get("name", "Ore")
		cost_text = "Next: %s Stones  ·  %d %s  (have %s)" % [
			NumberFormat.short(cost["stones"]), cost["ore"], ore_name,
			NumberFormat.short(GameState.get_item_count(cost["ore_id"]))]
		if int(item["refine"]) >= Gear.HEAVENLY_FROM - 1 and int(item["refine"]) < Gear.HEAVENLY_FROM:
			cost_text += "\nPast +%d you'll need Heavenly Refining Ore." % Gear.HEAVENLY_FROM
	var cost_l := _label(cost_text, 18, COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT)
	cost_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refine_row.add_child(cost_l)
	var r1 := _button("Refine +1", true, false, _on_refine.bind(1))
	r1.custom_minimum_size = Vector2(170, 58)
	r1.disabled = r >= Gear.MAX_REFINE
	refine_row.add_child(r1)
	var r10 := _button("+10", false, false, _on_refine.bind(10))
	r10.custom_minimum_size = Vector2(100, 58)
	r10.disabled = r >= Gear.MAX_REFINE
	refine_row.add_child(r10)

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
			var label := "Equip" if wearer == "" else "Take & Equip"
			actions.add_child(_button(label, true, false, _on_equip))

	var sources := Gear.transfer_sources(item).size()
	var transfer := _button("Transfer Refine (%d)" % sources, false, false, _open_transfer)
	transfer.disabled = sources == 0
	actions.add_child(transfer)

	var mergeable := Gear.merge_partners(item).size()
	var merge := _button("Merge (%d/2)" % mini(mergeable, 2), false, false, _on_merge)
	merge.disabled = mergeable < 2 or Gear.grade_index(item) >= Gear.GRADES - 1
	actions.add_child(merge)

	var locked: bool = item.get("locked", false)
	actions.add_child(_button("Unlock" if locked else "Lock", false, false, _on_lock))

	var salvage := _button("Salvage (+%d Ore)" % Gear.salvage_value(item), false, true, _on_salvage)
	salvage.disabled = locked or wearer != ""
	actions.add_child(salvage)

	if mergeable < 2:
		_body.add_child(_label("Merge: 3 unworn pieces of the same slot and grade make 1 of the next grade.", 17, COL_DIM))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	_body.add_child(bottom)
	if _partner_id != "":
		bottom.add_child(_button("Back", false, false, _back_to_picker))
	bottom.add_child(_button("Close", false, false, queue_free))


func _name_of(partner_id: String) -> String:
	if partner_id == GameState.MC_ID:
		return GameState.mc_name
	var data = PartnerDatabase.get_partner(partner_id)
	return data.display_name if data != null else partner_id


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _on_refine(times: int) -> void:
	var item := GameState.find_gear(_uid)
	var done := 0
	var error := ""
	for i in times:
		error = Gear.refine(item)
		if error != "":
			break
		done += 1
	_rebuild()
	if done == 0 and error != "":
		_hint.text = error
	elif error != "":
		_hint.text = "Refined +%d, then: %s" % [done, error]


func _on_equip() -> void:
	GameState.equip_gear(_uid, _partner_id)
	queue_free()


func _on_unequip() -> void:
	GameState.unequip_gear(_uid)
	queue_free()


func _on_merge() -> void:
	var error := Gear.merge(GameState.find_gear(_uid))
	_rebuild()
	if error != "":
		_hint.text = error
	else:
		_hint.add_theme_color_override("font_color", COL_OK)
		_hint.text = "Merged into %s!" % Gear.grade_text(GameState.find_gear(_uid))


func _on_lock() -> void:
	var item := GameState.find_gear(_uid)
	item["locked"] = not item.get("locked", false)
	GameState.gear_changed()
	_rebuild()


func _on_salvage() -> void:
	var item := GameState.find_gear(_uid)
	# Red and above need a second tap
	if int(item["tier"]) >= 4 and not _salvage_armed:
		_salvage_armed = true
		_hint.text = "This is a %s. Tap Salvage again to confirm." % Gear.grade_text(item)
		return
	var ore := GameState.salvage_gear(_uid)
	if ore > 0:
		queue_free()


func _back_to_picker() -> void:
	_mode = "picker"
	_slot = int(GameState.find_gear(_uid).get("slot", _slot))
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
