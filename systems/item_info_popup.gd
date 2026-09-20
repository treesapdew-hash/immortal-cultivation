class_name ItemInfoPopup
extends CanvasLayer

# =========================================================
# Item info popup, built in code. Save as
#   res://ui/item_info_popup.gd  (next to gear_popup.gd)
#
# Shows an item's icon, name, grade, description, how many
# you own, how many a recipe needs, and where to find it.
# Tap outside or press Close to dismiss.
#
#   ItemInfoPopup.open(self, "herb_id")            # just info
#   ItemInfoPopup.open(self, "herb_id", 25)        # with "needed"
#   ItemInfoPopup.open(self, "pill_id", -1, "Crafted in ...")
# =========================================================

const WIDTH := 700.0
const ICON := 120.0
const LAYER := 20

## Shown under "Where to find" when neither the caller nor the
## item data gives a source. Items can override it with a
## "source" key in ItemDB.
const DEFAULT_SOURCE := "Dropped in main stages. Higher stages drop rarer materials."

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_SHORT := Color("ff7a7a")

var _item_id := ""
var _need := -1
var _source := ""
var _closing := false
var _root: Control
var _panel: PanelContainer


## Opens the popup on top of everything. need < 0 hides the
## "needed" lines; an empty source falls back to the item data.
static func open(host: Node, item_id: String, need := -1, source := "") -> ItemInfoPopup:
	var popup := ItemInfoPopup.new()
	popup._item_id = item_id
	popup._need = need
	popup._source = source
	host.add_child(popup)
	return popup


func _ready() -> void:
	layer = LAYER

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.modulate.a = 0.0

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(30)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.draw.connect(_draw_panel)
	_panel.resized.connect(_panel.queue_redraw)
	center.add_child(_panel)

	_build()

	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.15)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var item: Dictionary = ItemDB.get_item(_item_id)
	var grade: int = item.get("grade", 0)
	var have: int = GameState.get_item_count(_item_id)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	# Icon + name
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	v.add_child(top)

	var icon := ItemSlot.new()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.disabled = true
	icon.show_count = false
	icon.setup_item(_item_id, 0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(icon)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 4)
	top.add_child(titles)

	var title_color: Color = ItemDB.grade_color(grade)
	var title := _label(str(item.get("name", _item_id)), 30, title_color.lightened(0.25), true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(title)
	var grade_text: String = ItemDB.grade_name(grade)
	titles.add_child(_label(grade_text, 18, COL_DIM))

	# Description, if the item has one
	var desc := str(item.get("desc", item.get("description", "")))
	if desc != "":
		var d := _label(desc, 20, COL_TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)

	v.add_child(_fade_line())

	# Stock
	v.add_child(_stat_row("Owned", NumberFormat.short(have), COL_TEXT))
	if _need > 0:
		var enough := have >= _need
		v.add_child(_stat_row("Needed per craft", NumberFormat.short(_need), COL_OK if enough else COL_SHORT))
		if enough:
			v.add_child(_stat_row("Enough for", "%s crafts" % NumberFormat.short(floori(float(have) / float(_need))), COL_OK))
		else:
			v.add_child(_stat_row("Short by", NumberFormat.short(_need - have), COL_SHORT))

	v.add_child(_fade_line())

	# Where to find
	var source := _source
	if source == "":
		source = str(item.get("source", ""))
	if source == "":
		source = DEFAULT_SOURCE
	v.add_child(_label("Where to find", 22, COL_GOLD, true))
	var src := _label(source, 19, COL_TEXT)
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(src)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)

	var close_b := OrnateButton.new()
	close_b.text = "Close"
	close_b.custom_minimum_size = Vector2(260, 60)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	v.add_child(close_b)


func _stat_row(key: String, value: String, value_color: Color) -> Control:
	var h := HBoxContainer.new()
	var k := _label(key, 20, COL_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var val := _label(value, 20, value_color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	return h


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _draw_panel() -> void:
	var s := _panel.size
	_panel.draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	_panel.draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.6), false, 2.0)
	var m := 8.0
	var arm := 36.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(m + corner.x * (s.x - m * 2.0), m + corner.y * (s.y - m * 2.0))
		var dx := arm * (1.0 if corner.x == 0 else -1.0)
		var dy := arm * (1.0 if corner.y == 0 else -1.0)
		_panel.draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]),
			Color(COL_GOLD, 0.8), 2.0, true)


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


func _label(text_value: String, font_size: int, color: Color, glow := false) -> Label:
	var l := Label.new()
	l.text = text_value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(COL_GOLD, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
