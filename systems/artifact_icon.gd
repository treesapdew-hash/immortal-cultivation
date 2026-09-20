class_name ArtifactIcon
extends Button

# =========================================================
# Square icon for an artifact: grade frame, a sigil drawn from
# the trait's colour and shape, grade pips.
#
#   icon.setup(artifact)
#   icon.setup_empty()
#
# Art override: res://assets/artifacts/<trait>.png
# =========================================================

const ART_FOLDER := "res://assets/artifacts/"
const GOLD := Color("e2c27a")
const BG_TOP := Color("172a4a")
const BG_BOTTOM := Color("070e1e")

var artifact: Dictionary = {}
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
static var _art := {}


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(110, 110)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	set_process(false)


func setup(a: Dictionary) -> void:
	artifact = a
	set_process(int(a.get("grade", 0)) >= 4)
	queue_redraw()


func setup_empty() -> void:
	artifact = {}
	set_process(false)
	queue_redraw()


static func art_for(trait_id: String) -> Texture2D:
	if not _art.has(trait_id):
		var path := ART_FOLDER + trait_id + ".png"
		_art[trait_id] = load(path) if ResourceLoader.exists(path) else null
	return _art[trait_id]


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var empty := artifact.is_empty()
	if empty and hide_empty:
		if is_pressed():
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		_draw_alert()
		return

	var s := size
	var r := Rect2(Vector2.ZERO, s)
	var grade := int(artifact.get("grade", 0))
	var frame := Color("3a4a62") if empty else Artifacts.grade_color(grade)
	var cut := s.x * 0.12
	var shape := ItemSlot._chamfer(r, cut)

	var top := BG_TOP.lerp(frame, 0.12) if not empty else Color("0e1a2e")
	var cols := PackedColorArray()
	for p in shape:
		cols.append(top.lerp(BG_BOTTOM, p.y / s.y))
	draw_polygon(shape, cols)

	if not empty:
		var trait_color := Artifacts.color_of(artifact)
		if grade >= 3:
			var glow := 0.16 + 0.05 * grade
			if grade >= 4:
				glow *= 0.8 + 0.2 * sin(_pulse * 2.5)
			for i in 6:
				draw_circle(s * 0.5, s.x * (0.45 - i * 0.06), Color(trait_color, glow * 0.12))

		var tex := art_for(str(artifact["trait"]))
		if tex != null:
			_draw_fitted(tex, Rect2(s * 0.19, s * 0.62))
		else:
			_draw_sigil(s, trait_color, str(artifact["trait"]))

	var border := shape.duplicate()
	border.append(shape[0])
	draw_polyline(border, frame, 2.5, true)
	var inner := ItemSlot._chamfer(r.grow(-5.0), cut * 0.7)
	inner.append(inner[0])
	draw_polyline(inner, Color(GOLD, 0.25 if not empty else 0.1), 1.0, true)

	if empty:
		_draw_alert()
		return

	var pips := grade + 1
	var gap := s.x * 0.075
	var start := s.x * 0.5 - (pips - 1) * gap * 0.5
	for i in pips:
		_gem(Vector2(start + i * gap, s.y * 0.09), s.x * 0.028, frame.lightened(0.3))

	if show_owner and artifact.get("owner", "") != "":
		var p := Vector2(s.x * 0.84, s.y * 0.2)
		draw_circle(p, s.x * 0.06, Color(0, 0, 0, 0.6))
		draw_circle(p, s.x * 0.045, Color("7dffa8"))
	if artifact.get("locked", false):
		var lp := Vector2(s.x * 0.16, s.y * 0.2)
		draw_rect(Rect2(lp - Vector2(5, 2), Vector2(10, 8)), GOLD)
		draw_arc(lp - Vector2(0, 2), 4.0, PI, TAU, 8, GOLD, 1.5, true)

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


func _gem(p: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.75, 0), p + Vector2(0, r), p + Vector2(-r * 0.75, 0)
	]), color)


## A rune: a ring, a polygon whose sides come from the trait, and
## spokes. Each trait ends up with its own recognisable sigil.
func _draw_sigil(s: Vector2, c: Color, trait_id: String) -> void:
	var center := s * 0.5
	var radius := s.x * 0.28
	var seed_value: int = absi(hash(trait_id))
	var sides: int = 3 + seed_value % 6
	var spin := float(seed_value % 360) * 0.0174533

	draw_arc(center, radius * 1.25, 0.0, TAU, 40, Color(c, 0.35), 2.0, true)
	draw_arc(center, radius * 1.05, 0.0, TAU, 40, Color(c, 0.18), 6.0, true)

	var pts := PackedVector2Array()
	for i in sides:
		var a := spin + TAU * i / sides
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c.lightened(0.45).lerp(c.darkened(0.4), (p.y - center.y + radius) / (radius * 2.0)))
	draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, c.lightened(0.5), 1.6, true)

	# Spokes and a core
	for i in sides:
		var a := spin + TAU * i / sides + PI / sides
		draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.7,
			center + Vector2(cos(a), sin(a)) * radius * 1.22, Color(c, 0.7), 1.6, true)
	draw_circle(center, radius * 0.3, c.lightened(0.55))
	draw_circle(center - Vector2(radius * 0.08, radius * 0.08), radius * 0.13, Color(1, 1, 1, 0.85))


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
