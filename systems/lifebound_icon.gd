class_name LifeboundIcon
extends Button

# =========================================================
# The bonded artifact: a jade pendant on a knotted cord, with
# a grade-coloured frame and star pips.
#
#   icon.setup(artifact)     # {grade, stars, lines}
#   icon.setup_empty()       # nothing bonded yet
#
# Art override: res://assets/ui/lifebound.png
# =========================================================

const ART_PATH := "res://assets/ui/lifebound.png"
const GOLD := Color("e2c27a")
const BG_TOP := Color("172a4a")
const BG_BOTTOM := Color("070e1e")

var artifact: Dictionary = {}
var _pulse := 0.0
## Red dot in the corner (e.g. a seed is ready to bond), like gear slots.
var show_alert := false:
	set(v):
		show_alert = v
		queue_redraw()
static var _art: Texture2D = null
static var _art_checked := false


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(96, 96)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	set_process(false)


func setup(a: Dictionary) -> void:
	artifact = a
	set_process(int(a.get("stars", 0)) >= 5)
	queue_redraw()


func setup_empty() -> void:
	artifact = {}
	set_process(false)
	queue_redraw()


static func art() -> Texture2D:
	if not _art_checked:
		_art_checked = true
		_art = load(ART_PATH) if ResourceLoader.exists(ART_PATH) else null
	return _art


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var bonded := not artifact.is_empty() and int(artifact.get("stars", 0)) > 0
	var grade := int(artifact.get("grade", 0))
	var frame := ItemDB.grade_color(grade) if bonded else Color("3a4a62")
	var cut := s.x * 0.12
	var shape := ItemSlot._chamfer(Rect2(Vector2.ZERO, s), cut)

	var top := BG_TOP.lerp(frame, 0.12) if bonded else Color("0e1a2e")
	var cols := PackedColorArray()
	for p in shape:
		cols.append(top.lerp(BG_BOTTOM, p.y / s.y))
	draw_polygon(shape, cols)

	var jade := Color("8fffc4") if bonded else Color("4a5a72")
	if bonded and int(artifact.get("stars", 0)) >= 5:
		var pulse := 0.5 + 0.5 * sin(_pulse * 2.0)
		for i in 5:
			draw_circle(s * 0.5, s.x * (0.4 - i * 0.05), Color(jade, 0.04 * pulse))

	var tex := art()
	if tex != null:
		# Unbonded: faded and grey, so an empty Lifebound doesn't look equipped
		var tint := Color.WHITE if bonded else Color(0.45, 0.5, 0.6, 0.45)
		_draw_fitted(tex, Rect2(s * 0.19, s * 0.62), tint)
	else:
		_draw_pendant(s, jade)

	var border := shape.duplicate()
	border.append(shape[0])
	draw_polyline(border, frame, 2.5, true)

	# Star pips along the bottom
	var stars := int(artifact.get("stars", 0))
	if stars > 0:
		var shown := mini(stars, 5)
		var gap := s.x * 0.115
		var start := s.x * 0.5 - (shown - 1) * gap * 0.5
		for i in shown:
			_star(Vector2(start + i * gap, s.y * 0.88), s.x * 0.05, GOLD)
		if stars > 5:
			var font := get_theme_default_font()
			draw_string(font, Vector2(s.x * 0.5 + shown * gap * 0.5, s.y * 0.93),
				"x%d" % stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)

	if is_pressed():
		draw_colored_polygon(shape, Color(1, 1, 1, 0.08))

	# Red dot, the same as the gear slots
	if show_alert:
		var p := Vector2(s.x - s.x * 0.13, s.x * 0.13)
		draw_circle(p, s.x * 0.1, Color(0, 0, 0, 0.5))
		draw_circle(p, s.x * 0.075, Color("ff4d4d"))
		draw_circle(p - Vector2(s.x * 0.02, s.x * 0.02), s.x * 0.028, Color(1, 1, 1, 0.7))


## Jade disc on a knotted cord.
func _draw_pendant(s: Vector2, c: Color) -> void:
	var center := Vector2(s.x * 0.5, s.y * 0.47)
	var r := s.x * 0.2

	# Cord
	draw_arc(Vector2(center.x, center.y - r * 1.9), r * 1.05, 0.35 * PI, 0.65 * PI, 14,
		Color("c9522e"), 3.0, true)
	draw_line(center + Vector2(-r * 0.5, -r * 1.2), center + Vector2(0, -r), Color("c9522e"), 3.0, true)
	draw_line(center + Vector2(r * 0.5, -r * 1.2), center + Vector2(0, -r), Color("c9522e"), 3.0, true)

	# Disc with a hole
	draw_circle(center + Vector2(2, 3), r, Color(0, 0, 0, 0.35))
	draw_circle(center, r, c.darkened(0.3))
	draw_circle(center - Vector2(r * 0.12, r * 0.12), r * 0.86, c)
	draw_circle(center, r * 0.3, BG_BOTTOM)
	draw_arc(center, r * 0.62, PI * 1.05, PI * 1.6, 14, Color(1, 1, 1, 0.5), 2.5, true)

	# Tassel
	draw_line(center + Vector2(0, r), center + Vector2(0, r * 1.7), Color("c9522e"), 2.5, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-r * 0.22, r * 1.7), center + Vector2(r * 0.22, r * 1.7),
		center + Vector2(0, r * 2.2)]), Color("c9522e"))


func _star(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, c)


## Draws a texture inside `box`, keeping its shape (no stretching).
func _draw_fitted(tex: Texture2D, box: Rect2, tint := Color.WHITE) -> void:
	if tex == null:
		return
	var tex_size := Vector2(tex.get_size())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var fit := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var drawn := tex_size * fit
	draw_texture_rect(tex, Rect2(box.position + (box.size - drawn) * 0.5, drawn), false, tint)
