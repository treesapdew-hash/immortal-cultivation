class_name InspectPopup
extends CanvasLayer

# =========================================================
# "Inspect": what another cultivator is fielding — their six
# partners and every piece of equipment on them. Save as
# res://ui/inspect_popup.gd
#
#   InspectPopup.open(self, user_id, "Their Name")
#
# Opened from the World chat name menu, the friends list, the
# Arena opponent list and the Arena board. Read-only: this shows
# the snapshot Showcase.push() left on their profile, so nothing
# here can touch the viewer's save.
# =========================================================

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")

var _body: VBoxContainer
var _user_id := ""
var _name := ""


static func open(host: Node, user_id: String, who: String) -> InspectPopup:
	var p := InspectPopup.new()
	p._user_id = user_id
	p._name = who
	host.get_tree().root.add_child(p)
	return p


func _ready() -> void:
	layer = 64   # above the chat box and the friends panel
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
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
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(920, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(_label(_name if _name != "" else "Cultivator", 32, COL_TITLE))

	# The team can run long, so it scrolls inside a fixed height.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 980)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 56)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	v.add_child(close)

	_load()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


func _load() -> void:
	_body.add_child(_note("Looking..."))
	var data := await Showcase.fetch(_user_id)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	for c in _body.get_children():
		c.queue_free()
	if data.is_empty():
		_body.add_child(_note("This cultivator cannot be seen right now."))
		return
	_render(data)


func _render(data: Dictionary) -> void:
	# Header: realm, furthest stage, total power.
	var realm := int(data.get("realm", 0))
	var bits: Array = [str(Realms.get_label(realm, 1))]
	var stage := int(data.get("stage", 0))
	if stage > 0:
		bits.append("Stage %d" % stage)
	var power := int(data.get("power", 0))
	if power > 0:
		bits.append("Power %s" % NumberFormat.short(power))
	_body.add_child(_label("   ·   ".join(PackedStringArray(bits)), 19, COL_GOLD))

	var title_id := str(data.get("title", ""))
	if title_id != "" and Titles.LIST.has(title_id):
		_body.add_child(_label(Titles.title_name(title_id), 22, Titles.colour_of(title_id)))

	_body.add_child(_line())

	var show: Dictionary = data["showcase"] if data.get("showcase") is Dictionary else {}
	var team: Array = show["team"] if show.get("team") is Array else []
	if team.is_empty():
		_body.add_child(_note("They haven't shown their formation yet. It appears once they next sync."))
		return
	for entry in team:
		if entry is Dictionary:
			_body.add_child(_partner_card(entry))

	var array: Array = show["array"] if show.get("array") is Array else []
	if not array.is_empty():
		_body.add_child(_line())
		_body.add_child(_label("Battle Array", 20, COL_GOLD))
		var names := PackedStringArray()
		for n in array:
			names.append(str(n))
		var l := _label(", ".join(names), 17, COL_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)


## One partner: name and realm on top, their four slots below.
func _partner_card(e: Dictionary) -> Control:
	var rarity := int(e.get("rarity", -1))
	var tint := COL_TEXT
	if Enums.RARITY_COLORS.has(rarity):
		tint = Enums.RARITY_COLORS[rarity]

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint, 0.06)
	sb.border_color = Color(tint, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var who := _label(str(e.get("name", "Partner")), 23, tint)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	var stars := int(e.get("stars", 0))
	if stars > 0:
		head.add_child(_label("★%d" % stars, 20, COL_GOLD))

	var sub: Array = []
	var realm_text := str(e.get("realm", ""))
	if realm_text != "":
		sub.append(realm_text)
	var power := int(e.get("power", 0))
	if power > 0:
		sub.append("Power %s" % NumberFormat.short(power))
	if not sub.is_empty():
		var s := _label("   ·   ".join(PackedStringArray(sub)), 16, COL_DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(s)

	var gear: Array = e["gear"] if e.get("gear") is Array else []
	if gear.is_empty():
		var bare := _label("No equipment", 16, COL_DIM)
		bare.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(bare)
		return card
	for g in gear:
		if g is Dictionary:
			v.add_child(_gear_row(g))
	return card


## One slot: "Weapon   Cloudpiercer Sword   Peak-grade Immortal Artifact +12"
func _gear_row(g: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)

	var slot := _label(Showcase.slot_name(int(g.get("slot", 0))), 15, COL_DIM)
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot.custom_minimum_size = Vector2(110, 0)
	h.add_child(slot)

	var item := _label(str(g.get("name", "Unknown")), 17, Showcase.gear_color(g))
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(item)

	var grade := _label(Showcase.gear_text(g), 15, COL_DIM)
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(grade)
	return h


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _note(message: String) -> Label:
	var l := _label(message, 18, COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		line.draw_line(Vector2(0, y), Vector2(line.size.x, y), Color(COL_GOLD, 0.35), 1.0)
	)
	return line


func _label(value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
