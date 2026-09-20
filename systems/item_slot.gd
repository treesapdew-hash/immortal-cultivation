class_name ItemSlot
extends Button

# =========================================================
# One square inventory slot.
#   slot.setup_item("starup_pill", 120)
#   slot.setup_fragment(partner_data, 3)
# Grade-coloured frame, drawn icon, count badge.
# Epic and above glow; Legendary and above pulse.
# =========================================================

## Item art, looked up in this order:
##   res://assets/items/<id>.png         e.g. starup_pill.png
##   res://assets/items/pill_<major>.png realm pills, one per major realm
##                                       (pill_0 Mortal ... pill_3 Immortal)
##   res://assets/items/<kind>.png       pill.png / herb.png / core.png,
##                                       tinted with the item's colour
## Falls back to the drawn icon.
const ITEM_FOLDER := "res://assets/items/"

static var _art := {}

const GOLD := Color("e2c27a")
const BG_TOP := Color("172a4a")
const BG_BOTTOM := Color("070e1e")

var grade := 0
var icon_kind := ""          # "pill", "herb", "core", "texture", "portrait"
var art: Texture2D = null    # painted icon, when one exists
var art_tinted := false      # generic art takes the item's colour
var icon_color := Color.WHITE  # colour of the drawn icon (grade colour unless the item has a tint)
var pattern := 0               # pill surface: 0 swirl, 1 rings, 2 specks
var tex: Texture2D
var count := 0
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var show_count := true

var _pulse := 0.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(118, 118)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func setup_item(id: String, amount: int) -> void:
	var item := ItemDB.get_item(id)
	grade = item.get("grade", 0)
	count = amount
	icon_color = item.get("tint", ItemDB.grade_color(grade))
	pattern = item.get("pattern", 0)
	art = null
	art_tinted = false
	var icon_name: String = item.get("icon", "pill")
	if icon_name.begins_with("res://") and ResourceLoader.exists(icon_name):
		icon_kind = "texture"
		tex = load(icon_name)
	else:
		icon_kind = icon_name
		# The item's own art, then a per-realm pill, then the generic
		art = _find_art(id)
		if art == null and item.has("major"):
			art = _find_art("pill_%d" % int(item["major"]))
			art_tinted = art != null       # only a light tint on top
		if art == null:
			art = _find_art(icon_name)
			art_tinted = art != null
	set_process(grade >= 4)
	queue_redraw()


## Looks up (and remembers) an image in the items folder.
static func _find_art(art_name: String) -> Texture2D:
	if not _art.has(art_name):
		var path := ITEM_FOLDER + art_name + ".png"
		_art[art_name] = load(path) if ResourceLoader.exists(path) else null
	return _art[art_name]


## A pill recipe, drawn as a scroll marked with the pill's colour.
func setup_recipe(pill_id: String) -> void:
	setup_item(pill_id, 0)
	icon_kind = "recipe"
	show_count = false
	queue_redraw()


## A partner's soul fragments (spare copies), shown with their portrait.
func setup_fragment(data, amount: int) -> void:
	grade = ItemDB.grade_for_rarity(data.rarity)
	count = amount
	icon_color = ItemDB.grade_color(grade)
	icon_kind = "portrait"
	tex = data.card_texture
	set_process(grade >= 4)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


# ---------------------------------------------------------
# DRAWING
# ---------------------------------------------------------

func _draw() -> void:
	var s := size
	var r := Rect2(Vector2.ZERO, s)
	var c := ItemDB.grade_color(grade)
	var cut := s.x * 0.12

	# Chamfered background with a gradient tinted by grade
	var shape := _chamfer(r, cut)
	var top := BG_TOP.lerp(c, 0.12)
	var cols := PackedColorArray()
	for p in shape:
		cols.append(top.lerp(BG_BOTTOM, p.y / s.y))
	draw_polygon(shape, cols)

	# Soft glow in the middle for Epic and above
	if grade >= 3:
		var glow := 0.18 + 0.06 * grade
		if grade >= 4:
			glow *= 0.8 + 0.2 * sin(_pulse * 2.5)
		for i in 6:
			draw_circle(s * 0.5, s.x * (0.45 - i * 0.06), Color(c, glow * 0.12))

	_draw_icon(s, icon_color)

	# Frame: grade border, inner gold hairline, corner gems
	var border := shape.duplicate()
	border.append(shape[0])
	draw_polyline(border, c, 2.5, true)
	var inner := _chamfer(r.grow(-5.0), cut * 0.7)
	inner.append(inner[0])
	draw_polyline(inner, Color(GOLD, 0.25), 1.0, true)
	_gem(Vector2(cut * 0.55, cut * 0.55), 4.5, c.lightened(0.25))
	_gem(Vector2(s.x - cut * 0.55, s.y - cut * 0.55), 3.5, Color(GOLD, 0.7))

	# Count badge
	if show_count and count > 0:
		var font := get_theme_default_font()
		var fs := int(s.y * 0.19)
		var count_text := NumberFormat.short(count)
		var w := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(s.x - w - 9.0, s.y - 9.0)
		draw_rect(Rect2(pos.x - 5.0, pos.y - fs * 0.95, w + 10.0, fs * 1.15), Color(0, 0, 0, 0.55))
		draw_string_outline(font, pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Selection
	if selected:
		var sel := _chamfer(r.grow(-1.0), cut)
		sel.append(sel[0])
		draw_polyline(sel, GOLD, 4.0, true)
		var halo := _chamfer(r.grow(3.0), cut + 2.0)
		halo.append(halo[0])
		draw_polyline(halo, Color(GOLD, 0.35), 2.0, true)

	# Pressed feedback
	if is_pressed():
		draw_colored_polygon(shape, Color(1, 1, 1, 0.08))


func _draw_icon(s: Vector2, c: Color) -> void:
	var center := s * 0.5

	# Painted art wins. Generic art is tinted with the item's colour.
	if art != null and icon_kind != "portrait" and icon_kind != "recipe":
		var box := Rect2(s * 0.19, s * 0.62)
		if art_tinted:
			draw_circle(center, s.x * 0.3, Color(c, 0.10))
			_draw_fitted_tinted(art, box, c)
		else:
			_draw_fitted(art, box)
		return
	match icon_kind:
		"pill":
			var rad := s.x * 0.22
			# halo
			for i in 4:
				draw_circle(center, rad * (1.9 - i * 0.2), Color(c, 0.07))
			# body with shading
			draw_circle(center + Vector2(2, 3), rad, Color(0, 0, 0, 0.35))
			draw_circle(center, rad, c.darkened(0.4))
			draw_circle(center - Vector2(rad * 0.12, rad * 0.12), rad * 0.84, c)
			draw_circle(center - Vector2(rad * 0.28, rad * 0.28), rad * 0.45, c.lightened(0.3))
			# surface pattern, so pills of similar colour still differ
			match pattern:
				0:
					draw_arc(center, rad * 0.58, -0.4, 2.3, 16, Color(1, 1, 1, 0.4), 1.6, true)
					draw_arc(center, rad * 0.3, 2.6, 4.9, 12, Color(1, 1, 1, 0.3), 1.2, true)
				1:
					draw_arc(center, rad * 0.7, 0.0, TAU, 24, Color(c.darkened(0.5), 0.8), 1.4, true)
					draw_arc(center, rad * 0.45, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.2, true)
				_:
					for k in 5:
						var a := TAU * k / 5.0 + 0.3
						draw_circle(center + Vector2(cos(a), sin(a)) * rad * 0.55, rad * 0.08,
							Color(1, 1, 0.9, 0.7))
			# highlight
			draw_circle(center - Vector2(rad * 0.38, rad * 0.42), rad * 0.18, Color(1, 1, 1, 0.85))
		"herb":
			var stem_bottom := center + Vector2(0, s.y * 0.26)
			draw_line(stem_bottom, center - Vector2(0, s.y * 0.05), Color(c.darkened(0.3)), 2.5, true)
			for side in [-1.0, 1.0]:
				_leaf(center + Vector2(0, s.y * 0.06), side, s.x * 0.24, c)
			_leaf(center - Vector2(0, s.y * 0.06), 0.0, s.x * 0.22, c.lightened(0.15))
		"core":
			# Faceted glowing crystal
			var h := s.y * 0.27
			var w := s.x * 0.17
			for i in 4:
				draw_circle(center, h * (1.5 - i * 0.2), Color(c, 0.07))
			var top := center + Vector2(0, -h)
			var bottom := center + Vector2(0, h)
			var left := center + Vector2(-w, -h * 0.15)
			var right := center + Vector2(w, -h * 0.15)
			draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), c.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([top, center + Vector2(0, -h * 0.1), bottom, left]), c)
			draw_colored_polygon(PackedVector2Array([top, right, center + Vector2(0, -h * 0.1)]), c.lightened(0.35))
			draw_polyline(PackedVector2Array([top, right, bottom, left, top]), c.lightened(0.4), 1.2, true)
			draw_circle(top + Vector2(-w * 0.2, h * 0.35), 2.5, Color(1, 1, 1, 0.8))
		"recipe":
			var w := s.x * 0.5
			var h := s.y * 0.44
			var paper := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
			draw_rect(paper.grow(2), Color(0, 0, 0, 0.35))
			draw_rect(paper, Color("e9dcc0"))
			draw_rect(paper.grow(-4), Color("d8c6a0"), false, 1.0)
			# rollers
			for y in [paper.position.y, paper.end.y]:
				draw_rect(Rect2(paper.position.x - 4, y - 3, w + 8, 6), Color("6b4a2a"))
				draw_circle(Vector2(paper.position.x - 4, y), 3.5, Color("c9a45a"))
				draw_circle(Vector2(paper.end.x + 4, y), 3.5, Color("c9a45a"))
			# pill seal in the middle
			draw_circle(center, w * 0.22, c.darkened(0.3))
			draw_circle(center - Vector2(1, 1), w * 0.18, c)
			draw_circle(center - Vector2(w * 0.06, w * 0.06), w * 0.06, Color(1, 1, 1, 0.8))
			# writing lines
			for k in 2:
				var ly := paper.position.y + 8 + k * 5
				draw_line(Vector2(paper.position.x + 6, ly), Vector2(paper.end.x - 6, ly), Color("8a7450"), 1.0)
		"texture":
			if tex != null:
				var box := Rect2(s * 0.19, s * 0.62)
				_draw_fitted(tex, box)
		"portrait":
			if tex != null:
				# Top-centre crop of the card art (the face)
				var ts := tex.get_size()
				var side := minf(ts.x, ts.y * 0.6)
				var region := Rect2((ts.x - side) * 0.5, ts.y * 0.04, side, side)
				var box := Rect2(Vector2(6, 6), s - Vector2(12, 12))
				draw_texture_rect_region(tex, box, region)
				# fade the lower part so the count stays readable
				draw_polygon(
					PackedVector2Array([Vector2(6, s.y * 0.55), Vector2(s.x - 6, s.y * 0.55), Vector2(s.x - 6, s.y - 6), Vector2(6, s.y - 6)]),
					PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.7)]))
				# small fragment shard mark
				_gem(Vector2(s.x * 0.2, s.y * 0.8), 7.0, c)


func _leaf(base: Vector2, side: float, length: float, c: Color) -> void:
	var dir := Vector2(side * 0.8, -1.0).normalized() if side != 0.0 else Vector2(0, -1)
	var normal := Vector2(-dir.y, dir.x)
	var tip := base + dir * length
	var mid := base + dir * length * 0.5
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var p := base.lerp(tip, t) + normal * sin(t * PI) * length * 0.28
		pts.append(p)
	for i in range(7, 0, -1):
		var t := i / 8.0
		pts.append(base.lerp(tip, t) - normal * sin(t * PI) * length * 0.28)
	draw_colored_polygon(pts, c)
	draw_line(base, tip, c.darkened(0.35), 1.2, true)
	draw_line(mid, mid + normal * length * 0.12, c.lightened(0.3), 1.0, true)


func _gem(p: Vector2, r: float, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.75, 0), p + Vector2(0, r), p + Vector2(-r * 0.75, 0)
	]), c)


static func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + cut, y0), Vector2(x1 - cut, y0), Vector2(x1, y0 + cut), Vector2(x1, y1 - cut),
		Vector2(x1 - cut, y1), Vector2(x0 + cut, y1), Vector2(x0, y1 - cut), Vector2(x0, y0 + cut),
	])


## Draws a texture inside `box`, keeping its shape (no stretching).
func _draw_fitted(picture: Texture2D, box: Rect2) -> void:
	if picture == null:
		return
	var tex_size := Vector2(picture.get_size())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var fit := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var drawn := tex_size * fit
	draw_texture_rect(picture, Rect2(box.position + (box.size - drawn) * 0.5, drawn), false)


## Like _draw_fitted, but multiplied by a colour (for generic art).
func _draw_fitted_tinted(tex_in: Texture2D, box: Rect2, color: Color) -> void:
	if tex_in == null:
		return
	var tex_size := Vector2(tex_in.get_size())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var fit := minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var drawn := tex_size * fit
	# Keep it bright: a soft tint rather than a flat multiply
	draw_texture_rect(tex_in, Rect2(box.position + (box.size - drawn) * 0.5, drawn),
		false, Color.WHITE.lerp(color, 0.65).lightened(0.15))
