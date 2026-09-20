class_name CardChoicePopup
extends CanvasLayer

# =========================================================
# "Choose your partner" popup. Save as
#   res://ui/card_choice_popup.gd
#
#   var p := CardChoicePopup.open(self, "Red Selection Scroll", options, tier)
#   p.chosen.connect(func(partner_id): ...)
#
# Shows the offered partners as framed cards. Tapping one asks
# once to confirm, then emits `chosen`. Closing emits `closed`
# (nothing is used up).
# =========================================================

signal chosen(partner_id: String)
signal closed

const LAYER := 60
const CARD_WIDTH := 200.0
## Rows of cards shown before the grid starts scrolling.
const MAX_VISIBLE_ROWS := 2
## Name label and row separation under each card.
const ROW_EXTRA := 54.0

const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")

var _title := ""
var _options: Array = []
var _tier := 0
var _note := "Tap a card, then Choose. Later keeps the scroll."
var _picked := ""
var _confirm_button: OrnateButton
var _holders := {}


static func open(host: Node, title: String, options: Array, tier: int, note := "") -> CardChoicePopup:
	var p := CardChoicePopup.new()
	if note != "":
		p._note = note
	p._title = title
	p._options = options
	p._tier = tier
	host.get_tree().root.add_child(p)
	return p


func _ready() -> void:
	layer = LAYER
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var grade_col: Color = ItemDB.grade_color(Realms.tier_index(_tier))
	var tier_color := grade_col.lightened(0.2)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = tier_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(tier_color, 0.35)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label("Choose Your Partner", 36, COL_TITLE, true))
	v.add_child(_label(_title, 20, tier_color))

	var grid := GridContainer.new()
	grid.columns = mini(maxi(_options.size(), 1), 4)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.add_child(grid)

	SummonCard.find_frames(center)
	var card_size := SummonCard.size_for_width(CARD_WIDTH)
	for id in _options:
		var data = PartnerDatabase.get_partner(str(id))
		if data == null:
			continue
		grid.add_child(_card(str(id), data, card_size))

	# A Premium Selection Scroll offers all 15 Premium Reds, which is
	# four rows of cards: far taller than the screen. Past
	# MAX_VISIBLE_ROWS the cards scroll instead of stretching the
	# panel past the buttons below it.
	var rows := int(ceil(float(grid.get_child_count()) / float(maxi(grid.columns, 1))))
	if rows > MAX_VISIBLE_ROWS:
		var scroller := ScrollContainer.new()
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroller.custom_minimum_size = Vector2(0, (card_size.y + ROW_EXTRA) * MAX_VISIBLE_ROWS)
		scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.add_child(grid_center)
		v.add_child(scroller)
	else:
		v.add_child(grid_center)

	if _options.is_empty():
		v.add_child(_label("No partners of this tier exist yet.", 20, COL_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var close := OrnateButton.new()
	close.text = "Later"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 62)
	close.pressed.connect(func():
		closed.emit()
		queue_free()
	)
	row.add_child(close)
	_confirm_button = OrnateButton.new()
	_confirm_button.text = "Choose"
	_confirm_button.custom_minimum_size = Vector2(260, 62)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm)
	row.add_child(_confirm_button)
	v.add_child(_label(_note, 16, COL_DIM))

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.get_combined_minimum_size() * 0.5
	var t := create_tween().set_parallel()
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _card(id: String, data, card_size: Vector2) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var holder := Button.new()
	holder.flat = true
	holder.focus_mode = Control.FOCUS_NONE
	holder.custom_minimum_size = card_size
	for state in ["normal", "hover", "pressed", "focus"]:
		holder.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var card := SummonCard.new()
	card.setup({"partner_id": id}, data.rarity, card_size)
	card.show_front()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	holder.pressed.connect(_pick.bind(id))
	holder.pivot_offset = card_size * 0.5
	box.add_child(holder)
	_holders[id] = holder

	var name_l := _label(data.display_name, 19, Color.WHITE)
	name_l.custom_minimum_size.x = card_size.x
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_l)
	if SummonSystem.is_premium(id):
		box.add_child(_label("PREMIUM", 15, Color("ffcf4a")))
	if GameState.find_owned(id) != null:
		box.add_child(_label("Owned · becomes a fragment", 14, COL_DIM))
	else:
		box.add_child(_label("NEW", 15, COL_OK))
	return box


func _pick(id: String) -> void:
	_picked = id
	for key in _holders:
		var h: Control = _holders[key]
		var on := str(key) == id
		h.modulate = Color(1.15, 1.1, 1.0) if on else Color(0.55, 0.55, 0.6)
		var t := h.create_tween()
		t.tween_property(h, "scale", Vector2(1.06, 1.06) if on else Vector2.ONE, 0.15)
	_confirm_button.disabled = false


func _on_confirm() -> void:
	if _picked == "":
		return
	chosen.emit(_picked)
	queue_free()


func _label(value: String, font_size: int, color: Color, glow := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(1.0, 0.85, 0.4, 0.3))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 12)
	return l
