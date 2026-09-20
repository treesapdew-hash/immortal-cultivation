class_name OrnateButton
extends Button

# =========================================================
# Ornate button drawn in code: cut corners, gradient body,
# gold border with an inner hairline, diamond studs.
#
#   var b := OrnateButton.new()
#   b.text = "Salvage"
#   b.variant = OrnateButton.Variant.CRIMSON
# =========================================================

enum Variant { GOLD, CRIMSON, DARK }

const GOLD := Color("e2c27a")
const GOLD_LIGHT := Color("fff0c2")

## [top colour, bottom colour, border colour, text colour]
const LOOKS := {
	Variant.GOLD:    [Color("6b4a14"), Color("2e1f08"), Color("e2c27a"), Color("ffe6a8")],
	Variant.CRIMSON: [Color("6e1a1a"), Color("2a0808"), Color("e08a6a"), Color("ffd9c8")],
	Variant.DARK:    [Color("1a2c4a"), Color("0a1426"), Color("6f8fb8"), Color("d6e2f2")],
}

var variant: Variant = Variant.GOLD:
	set(v):
		variant = v
		_apply_text_colors()
		_redraw()

# The body is drawn on a child placed behind the button, so the
# button's own text always stays on top.
var _bg: Control


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		add_theme_stylebox_override(state, sb)
	add_theme_font_size_override("font_size", 22)
	_apply_text_colors()

	_bg = Control.new()
	_bg.show_behind_parent = true
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.draw.connect(_draw_body)
	add_child(_bg, false, Node.INTERNAL_MODE_FRONT)

	for sig in [button_down, button_up, mouse_entered, mouse_exited, resized]:
		sig.connect(_redraw)


func _redraw() -> void:
	if _bg != null:
		_bg.queue_redraw()


var _was_disabled := false


## Redraw when the button is enabled or disabled from code.
func _process(_delta: float) -> void:
	if disabled != _was_disabled:
		_was_disabled = disabled
		_redraw()


func _apply_text_colors() -> void:
	var look: Array = LOOKS[variant]
	for key in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(key, look[3])
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", Color("5a606c"))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("outline_size", 3)


func _draw_body() -> void:
	var c := _bg
	var look: Array = LOOKS[variant]
	var top: Color = look[0]
	var bottom: Color = look[1]
	var border: Color = look[2]

	var down := is_pressed()
	var hover := is_hovered() and not disabled
	if disabled:
		top = Color("1b2030")
		bottom = Color("0e121c")
		border = Color("3a4150")
	elif down:
		top = top.lightened(0.12)
		bottom = bottom.lightened(0.08)
	elif hover:
		top = top.lightened(0.06)

	var s := c.size
	var cut := minf(s.y * 0.28, 16.0)
	var shape := _chamfer(Rect2(Vector2.ZERO, s), cut)

	# Soft glow behind enabled buttons
	if not disabled:
		var glow := _chamfer(Rect2(Vector2(-3, -3), s + Vector2(6, 6)), cut + 2.0)
		c.draw_colored_polygon(glow, Color(border, 0.12 if not hover else 0.2))

	# Body gradient
	var cols := PackedColorArray()
	for p in shape:
		cols.append(top.lerp(bottom, p.y / s.y))
	c.draw_polygon(shape, cols)

	# Sheen on the upper half
	var sheen := _chamfer(Rect2(Vector2(3, 3), Vector2(s.x - 6, s.y * 0.42)), cut * 0.7)
	c.draw_colored_polygon(sheen, Color(1, 1, 1, 0.06 if not down else 0.02))

	# Border and inner hairline
	var outline := shape.duplicate()
	outline.append(shape[0])
	c.draw_polyline(outline, border, 2.0, true)
	var inner := _chamfer(Rect2(Vector2(5, 5), s - Vector2(10, 10)), cut * 0.6)
	inner.append(inner[0])
	c.draw_polyline(inner, Color(border, 0.35), 1.0, true)

	# Diamond studs on both ends
	var mid := s.y * 0.5
	for x in [3.0, s.x - 3.0]:
		_gem(c, Vector2(x, mid), 5.5, border.lightened(0.2) if not disabled else border)
	# Small gem top centre
	_gem(c, Vector2(s.x * 0.5, 1.5), 3.5, border)


static func _gem(on: CanvasItem, p: Vector2, r: float, color: Color) -> void:
	on.draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)
	]), color)


static func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + cut, y0), Vector2(x1 - cut, y0), Vector2(x1, y0 + cut), Vector2(x1, y1 - cut),
		Vector2(x1 - cut, y1), Vector2(x0 + cut, y1), Vector2(x0, y1 - cut), Vector2(x0, y0 + cut),
	])
