class_name TreasureIcon
extends Button

# =========================================================
# Square icon for a treasure: grade-coloured frame, drawn
# shape in its set's colour, grade pips and a set dot.
#
#   icon.setup(treasure)
#   icon.setup_empty()
#
# Art override: res://assets/treasures/<id>.png
# =========================================================

const GOLD := Color("e2c27a")
const BG_TOP := Color("172a4a")
const BG_BOTTOM := Color("070e1e")

var treasure: Dictionary = {}
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var hide_empty := false
var show_owner := true
var show_alert := false:
	set(v):
		show_alert = v
		queue_redraw()

var _pulse := 0.0
var _origin := Vector2.ZERO
var _unit := 1.0

static var _art := {}


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(110, 110)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	set_process(false)


func setup(t: Dictionary) -> void:
	treasure = t
	set_process(int(t.get("grade", 0)) >= 4)
	queue_redraw()


func setup_empty() -> void:
	treasure = {}
	set_process(false)
	queue_redraw()


static func art_for(id: String) -> Texture2D:
	if not _art.has(id):
		var path := Treasures.ART_FOLDER + id + ".png"
		_art[id] = load(path) if ResourceLoader.exists(path) else null
	return _art[id]


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var empty := treasure.is_empty()
	if empty and hide_empty:
		if is_pressed():
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		_draw_alert()
		return

	var s := size
	var r := Rect2(Vector2.ZERO, s)
	var grade := int(treasure.get("grade", 0))
	var frame := Color("3a4a62") if empty else Treasures.grade_color(grade)
	var cut := s.x * 0.12
	var shape := ItemSlot._chamfer(r, cut)

	var top := BG_TOP.lerp(frame, 0.12) if not empty else Color("0e1a2e")
	var cols := PackedColorArray()
	for p in shape:
		cols.append(top.lerp(BG_BOTTOM, p.y / s.y))
	draw_polygon(shape, cols)

	if not empty and grade >= 3:
		var glow := 0.16 + 0.05 * grade
		if grade >= 4:
			glow *= 0.8 + 0.2 * sin(_pulse * 2.5)
		for i in 6:
			draw_circle(s * 0.5, s.x * (0.45 - i * 0.06), Color(frame, glow * 0.12))

	if not empty:
		var tex := art_for(str(treasure["id"]))
		if tex != null:
			_draw_fitted(tex, Rect2(s * 0.19, s * 0.62))
		else:
			_origin = s * 0.5
			_unit = s.x / 100.0
			_draw_shape(Treasures.get_def(treasure["id"]).get("shape", "bead"),
				Treasures.color_of(treasure))

	var border := shape.duplicate()
	border.append(shape[0])
	draw_polyline(border, frame, 2.5, true)
	var inner := ItemSlot._chamfer(r.grow(-5.0), cut * 0.7)
	inner.append(inner[0])
	draw_polyline(inner, Color(GOLD, 0.25 if not empty else 0.1), 1.0, true)

	if empty:
		_draw_alert()
		return

	# Grade pips along the top
	var pips := grade + 1
	var gap := s.x * 0.075
	var start := s.x * 0.5 - (pips - 1) * gap * 0.5
	for i in pips:
		_gem(Vector2(start + i * gap, s.y * 0.09), s.x * 0.028, frame.lightened(0.3))

	# Set colour dot
	var set_color: Color = Treasures.set_def(Treasures.set_of(treasure)).get("color", Color.WHITE)
	draw_circle(Vector2(s.x * 0.17, s.y * 0.85), s.x * 0.055, Color(0, 0, 0, 0.6))
	draw_circle(Vector2(s.x * 0.17, s.y * 0.85), s.x * 0.04, set_color)

	if show_owner and treasure.get("owner", "") != "":
		var p := Vector2(s.x * 0.84, s.y * 0.2)
		draw_circle(p, s.x * 0.06, Color(0, 0, 0, 0.6))
		draw_circle(p, s.x * 0.045, Color("7dffa8"))
	if treasure.get("locked", false):
		var lp := Vector2(s.x * 0.16, s.y * 0.2)
		draw_rect(Rect2(lp - Vector2(5, 2), Vector2(10, 8)), GOLD)
		draw_arc(lp - Vector2(0, 2), 4.0, PI, TAU, 8, GOLD, 1.5, true)

	# Enhancement level
	var level := int(treasure.get("level", 0))
	if level > 0:
		var font := get_theme_default_font()
		var fs := int(s.y * 0.17)
		var level_text := "+%d" % level
		var w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var plate := Rect2(s.x - w - 16.0, s.y - fs - 10.0, w + 12.0, fs + 6.0)
		draw_colored_polygon(ItemSlot._chamfer(plate, 5.0), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(plate.position.x + 6.0, plate.end.y - 4.0), level_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe6a8"))

	if selected:
		var sel := ItemSlot._chamfer(r.grow(-1.0), cut)
		sel.append(sel[0])
		draw_polyline(sel, GOLD, 4.0, true)

	if is_pressed():
		draw_colored_polygon(shape, Color(1, 1, 1, 0.08))

	_draw_alert()


func _draw_alert() -> void:
	if not show_alert:
		return
	var p := Vector2(size.x - size.x * 0.13, size.x * 0.13)
	draw_circle(p, size.x * 0.1, Color(0, 0, 0, 0.5))
	draw_circle(p, size.x * 0.075, Color("ff4d4d"))


func _p(dx: float, dy: float) -> Vector2:
	return _origin + Vector2(dx, dy) * _unit


func _gem(p: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.75, 0), p + Vector2(0, r), p + Vector2(-r * 0.75, 0)
	]), color)


func _glow_poly(pts: PackedVector2Array, c: Color) -> void:
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + Vector2(2, 3) * _unit)
	draw_colored_polygon(moved, Color(0, 0, 0, 0.35))
	var cols := PackedColorArray()
	var min_y := pts[0].y
	var max_y := pts[0].y
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for p in pts:
		var t := (p.y - min_y) / maxf(max_y - min_y, 1.0)
		cols.append(c.lightened(0.45).lerp(c.darkened(0.45), t))
	draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, c.darkened(0.65), 1.2, true)


## Each treasure shape, drawn in its set's colour.
func _draw_shape(shape: String, c: Color) -> void:
	var light := c.lightened(0.4)
	var dark := c.darkened(0.5)
	match shape:
		"pagoda", "furnace":
			# Tiered tower (pagoda) or squat furnace
			var tiers := 3 if shape == "pagoda" else 2
			var top_y := -28.0 if shape == "pagoda" else -14.0
			for i in tiers:
				var w := 12.0 + i * 9.0
				var y := top_y + i * 18.0
				_glow_poly(PackedVector2Array([
					_p(-w, y), _p(w, y), _p(w * 0.82, y + 13), _p(-w * 0.82, y + 13)]), c)
				draw_line(_p(-w - 3, y), _p(w + 3, y), light, 2.0 * _unit, true)
			draw_circle(_p(0, top_y - 6), 4.0 * _unit, light)
		"mirror", "dial", "compass", "wheel":
			draw_circle(_p(0, 2) + Vector2(2, 3) * _unit, 22 * _unit, Color(0, 0, 0, 0.35))
			draw_circle(_p(0, 2), 22 * _unit, c.darkened(0.25))
			draw_circle(_p(0, 2), 17 * _unit, light if shape == "mirror" else c.darkened(0.55))
			if shape == "mirror":
				draw_arc(_p(0, 2), 12 * _unit, PI * 1.1, PI * 1.7, 12, Color(1, 1, 1, 0.6), 3.0 * _unit, true)
			elif shape == "wheel":
				draw_arc(_p(0, 2), 17 * _unit, 0, PI, 16, light, 3.0 * _unit, true)
				draw_circle(_p(-8, 2), 4 * _unit, light)
				draw_circle(_p(8, 2), 4 * _unit, dark)
			elif shape == "compass":
				draw_colored_polygon(PackedVector2Array([
					_p(0, -12), _p(5, 2), _p(0, 14), _p(-5, 2)]), light)
			else:
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(_p(0, 2) + Vector2(cos(a), sin(a)) * 10 * _unit,
						_p(0, 2) + Vector2(cos(a), sin(a)) * 16 * _unit, light, 1.5 * _unit, true)
			draw_arc(_p(0, 2), 22 * _unit, 0, TAU, 40, light, 2.0 * _unit, true)
		"gourd":
			draw_circle(_p(0, 12) + Vector2(2, 3) * _unit, 16 * _unit, Color(0, 0, 0, 0.3))
			draw_circle(_p(0, 12), 16 * _unit, c)
			draw_circle(_p(-5, 8), 6 * _unit, light)
			draw_circle(_p(0, -8), 10 * _unit, c.darkened(0.15))
			draw_line(_p(0, -18), _p(0, -24), dark, 5.0 * _unit, true)
			draw_line(_p(-9, 0), _p(9, 0), dark, 3.0 * _unit, true)
		"bell":
			_glow_poly(PackedVector2Array([
				_p(-16, 16), _p(-12, -8), _p(0, -20), _p(12, -8), _p(16, 16)]), c)
			draw_line(_p(-18, 16), _p(18, 16), dark, 3.0 * _unit, true)
			draw_circle(_p(0, 21), 4.0 * _unit, light)
			draw_circle(_p(0, -24), 3.5 * _unit, light)
		"lantern":
			draw_line(_p(0, -28), _p(0, -20), dark, 2.0 * _unit, true)
			_glow_poly(PackedVector2Array([
				_p(-14, -18), _p(14, -18), _p(17, 0), _p(14, 18), _p(-14, 18), _p(-17, 0)]), c)
			draw_line(_p(-16, -18), _p(16, -18), dark, 3.0 * _unit, true)
			draw_line(_p(-16, 18), _p(16, 18), dark, 3.0 * _unit, true)
			draw_circle(_p(0, 0), 6 * _unit, Color(1, 1, 0.85, 0.8))
			draw_line(_p(0, 20), _p(0, 27), light, 2.0 * _unit, true)
		"cauldron":
			_glow_poly(PackedVector2Array([
				_p(-18, -6), _p(18, -6), _p(15, 16), _p(-15, 16)]), c)
			draw_line(_p(-22, -6), _p(22, -6), light, 4.0 * _unit, true)
			draw_line(_p(-12, 16), _p(-14, 24), dark, 4.0 * _unit, true)
			draw_line(_p(12, 16), _p(14, 24), dark, 4.0 * _unit, true)
			for k in 3:
				draw_arc(_p(-8 + k * 8, -12), 4 * _unit, PI, TAU, 8, Color(1, 0.8, 0.5, 0.5), 2.0 * _unit, true)
		"chart", "banner":
			_glow_poly(PackedVector2Array([
				_p(-16, -22), _p(16, -22), _p(16, 20), _p(0, 26), _p(-16, 20)]), c)
			draw_line(_p(-20, -22), _p(20, -22), dark, 3.0 * _unit, true)
			if shape == "chart":
				for k in 5:
					draw_circle(_p(-9 + (k % 3) * 9, -12 + int(k / 3.0) * 12), 2.5 * _unit, light)
				draw_line(_p(-9, -12), _p(9, 0), light, 1.2 * _unit, true)
			else:
				draw_arc(_p(0, -2), 7 * _unit, 0, TAU, 16, light, 2.0 * _unit, true)
				draw_line(_p(-5, -6), _p(5, 4), light, 1.5 * _unit, true)
		"lotus":
			for side in [-1.0, 0.0, 1.0]:
				var tip := _p(side * 16, -18)
				_glow_poly(PackedVector2Array([
					_p(side * 4, 12), tip, _p(side * 4 + side * 8, 8)]), c)
			_glow_poly(PackedVector2Array([
				_p(-20, 12), _p(20, 12), _p(14, 22), _p(-14, 22)]), c.darkened(0.2))
		"ruyi":
			draw_line(_p(-16, 20), _p(10, -10), c.darkened(0.3), 5.0 * _unit, true)
			_glow_poly(PackedVector2Array([
				_p(10, -10), _p(20, -22), _p(8, -26), _p(2, -16)]), c)
			draw_circle(_p(-18, 22), 4.0 * _unit, light)
		"bead", "pearl":
			draw_circle(_p(0, 2) + Vector2(2, 3) * _unit, 18 * _unit, Color(0, 0, 0, 0.3))
			draw_circle(_p(0, 2), 18 * _unit, c)
			draw_circle(_p(-5, -4), 9 * _unit, light)
			draw_circle(_p(-8, -8), 4 * _unit, Color(1, 1, 1, 0.8))
			if shape == "bead":
				for k in 6:
					var a := TAU * k / 6.0
					draw_circle(_p(0, 2) + Vector2(cos(a), sin(a)) * 24 * _unit, 3.5 * _unit, c.darkened(0.2))
		"scale":
			_glow_poly(PackedVector2Array([
				_p(0, -24), _p(18, -4), _p(0, 24), _p(-18, -4)]), c)
			draw_line(_p(0, -24), _p(0, 24), light, 1.5 * _unit, true)
			draw_line(_p(-12, 0), _p(12, 0), Color(1, 1, 1, 0.3), 1.2 * _unit, true)
		"flute", "whistle":
			var length := 26.0 if shape == "flute" else 16.0
			_glow_poly(PackedVector2Array([
				_p(-6, -length), _p(6, -length), _p(5, length), _p(-5, length)]), c)
			for k in 3:
				draw_circle(_p(0, -8 + k * 9), 2.5 * _unit, dark)
			draw_line(_p(-7, -length), _p(7, -length), light, 2.5 * _unit, true)
		"fan":
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(-2.35, -0.79, float(i) / 12.0)
				pts.append(_p(0, 18) + Vector2(cos(a), sin(a)) * 32.0 * _unit)
			pts.append(_p(0, 18))
			_glow_poly(pts, c)
			for i in 5:
				var a := lerpf(-2.35, -0.79, float(i) / 4.0)
				draw_line(_p(0, 18), _p(0, 18) + Vector2(cos(a), sin(a)) * 31.0 * _unit,
					c.darkened(0.6), 1.2 * _unit, true)
			draw_circle(_p(0, 18), 4.0 * _unit, light)
		"sash":
			var ribbon := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				ribbon.append(_p(-24 + t * 48, -18 + sin(t * PI * 1.5) * 16))
			for i in range(8, -1, -1):
				var t := float(i) / 8.0
				ribbon.append(_p(-24 + t * 48, -6 + sin(t * PI * 1.5) * 16))
			_glow_poly(ribbon, c)
		_:
			# chain
			for k in 4:
				var y := -21.0 + k * 14.0
				draw_arc(_p(0, y), 7 * _unit, 0, TAU, 20, c if k % 2 == 0 else light, 3.5 * _unit, true)


## Draws a texture inside `box`, keeping its shape (no stretching).
func _draw_fitted(tex: Texture2D, box: Rect2) -> void:
	if tex == null:
		return
	var tex_size := Vector2(tex.get_size())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var fit := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var drawn := tex_size * fit
	draw_texture_rect(tex, Rect2(box.position + (box.size - drawn) * 0.5, drawn), false)
