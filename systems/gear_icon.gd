class_name GearIcon
extends Button

# =========================================================
# Square icon for a piece of gear:
#   tier-coloured frame, drawn weapon / robe / ring / boots,
#   1-4 gems for the sub-grade, "+12" refine, set colour dot,
#   and a small mark when someone is wearing it.
#
#   icon.setup(item)          # a piece of gear
#   icon.setup_empty(slot)    # empty slot outline
# =========================================================

## Optional icon art. Looked up in this order:
##   res://assets/gear/<set>_<slot>.png   e.g. azure_cloud_weapon.png
##   res://assets/gear/<slot>.png         e.g. weapon.png
## Falls back to the drawn icon.
const ICON_FOLDER := "res://assets/gear/"
const SLOT_FILES := ["weapon", "armor", "ring", "boots"]

static var _icons := {}

const GOLD := Color("e2c27a")
const BG_TOP := Color("172a4a")
const BG_BOTTOM := Color("070e1e")

var item: Dictionary = {}
var slot := 0
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var show_owner := true
## Draw nothing for an empty slot (lets the art underneath show).
var hide_empty := false
## Glows in the set's colour when the wearer has all 4 pieces.
var full_set := false
## Red dot: something better is waiting in the bag.
var show_alert := false:
	set(v):
		show_alert = v
		queue_redraw()

var _pulse := 0.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(110, 110)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	set_process(false)


func setup(piece: Dictionary) -> void:
	item = piece
	slot = int(piece.get("slot", 0))
	full_set = Gear.is_full_set(piece)
	set_process(int(piece.get("tier", 0)) >= 4 or full_set)
	queue_redraw()


func setup_empty(empty_slot: int) -> void:
	item = {}
	slot = empty_slot
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if item.is_empty() and hide_empty:
		if is_pressed():
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		_draw_alert()
		return
	var s := size
	var r := Rect2(Vector2.ZERO, s)
	var empty := item.is_empty()
	var c := Color("3a4a62") if empty else Gear.tier_color(item)
	var cut := s.x * 0.12
	var shape := ItemSlot._chamfer(r, cut)

	var top := BG_TOP.lerp(c, 0.12) if not empty else Color("0e1a2e")
	var cols := PackedColorArray()
	for p in shape:
		cols.append(top.lerp(BG_BOTTOM, p.y / s.y))
	draw_polygon(shape, cols)

	if not empty and int(item["tier"]) >= 3:
		var glow := 0.16 + 0.05 * int(item["tier"])
		if int(item["tier"]) >= 4:
			glow *= 0.8 + 0.2 * sin(_pulse * 2.5)
		for i in 6:
			draw_circle(s * 0.5, s.x * (0.45 - i * 0.06), Color(c, glow * 0.12))

	_draw_piece(s, c if not empty else Color("4a5a72"), empty)

	var border := shape.duplicate()
	border.append(shape[0])

	# Full set: a breathing halo in the set's colour
	if full_set:
		var set_glow: Color = Gear.SETS.get(item["set"], {}).get("color", c)
		var pulse := 0.45 + 0.35 * sin(_pulse * 2.2)
		for i in 3:
			var ring := ItemSlot._chamfer(r.grow(2.0 + i * 3.0), cut + 1.0 + i)
			ring.append(ring[0])
			draw_polyline(ring, Color(set_glow, pulse * (0.5 - i * 0.14)), 3.0, true)
		draw_polyline(border, set_glow.lerp(c, 0.3), 3.0, true)
	else:
		draw_polyline(border, c, 2.5, true)
	var inner := ItemSlot._chamfer(r.grow(-5.0), cut * 0.7)
	inner.append(inner[0])
	draw_polyline(inner, Color(GOLD, 0.25 if not empty else 0.1), 1.0, true)

	if empty:
		return

	# Sub-grade gems along the top (1 Low ... 4 Peak)
	var gems := int(item["sub"]) + 1
	var gap := s.x * 0.1
	var start := s.x * 0.5 - (gems - 1) * gap * 0.5
	for i in gems:
		_gem(Vector2(start + i * gap, s.y * 0.1), s.x * 0.035, c.lightened(0.3))

	# Set colour dot, bottom-left
	var set_def: Dictionary = Gear.SETS.get(item["set"], {})
	var set_color: Color = set_def.get("color", Color.WHITE)
	draw_circle(Vector2(s.x * 0.17, s.y * 0.83), s.x * 0.055, Color(0, 0, 0, 0.6))
	draw_circle(Vector2(s.x * 0.17, s.y * 0.83), s.x * 0.04, set_color)

	var font := get_theme_default_font()
	# Refine level, bottom-right
	var refine := int(item.get("refine", 0))
	if refine > 0:
		var fs := int(s.y * 0.17)
		var refine_text := "+%d" % refine
		var w := font.get_string_size(refine_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var plate := Rect2(s.x - w - 16.0, s.y - fs - 10.0, w + 12.0, fs + 6.0)
		draw_colored_polygon(ItemSlot._chamfer(plate, 5.0), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(plate.position.x + 6.0, plate.end.y - 4.0), refine_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe6a8"))

	# Worn marker, top-right
	if show_owner and item.get("owner", "") != "":
		var p := Vector2(s.x * 0.84, s.y * 0.2)
		draw_circle(p, s.x * 0.06, Color(0, 0, 0, 0.6))
		draw_circle(p, s.x * 0.045, Color("7dffa8"))
	if item.get("locked", false):
		var p := Vector2(s.x * 0.16, s.y * 0.2)
		draw_rect(Rect2(p - Vector2(5, 2), Vector2(10, 8)), GOLD)
		draw_arc(p - Vector2(0, 2), 4.0, PI, TAU, 8, GOLD, 1.5, true)

	if selected:
		var sel := ItemSlot._chamfer(r.grow(-1.0), cut)
		sel.append(sel[0])
		draw_polyline(sel, GOLD, 4.0, true)

	if is_pressed():
		draw_colored_polygon(shape, Color(1, 1, 1, 0.08))

	_draw_alert()


## Red dot in the top-right corner.
func _draw_alert() -> void:
	if not show_alert:
		return
	var p := Vector2(size.x - size.x * 0.13, size.x * 0.13)
	draw_circle(p, size.x * 0.1, Color(0, 0, 0, 0.5))
	draw_circle(p, size.x * 0.075, Color("ff4d4d"))
	draw_circle(p - Vector2(size.x * 0.02, size.x * 0.02), size.x * 0.028, Color(1, 1, 1, 0.7))


## Art for this piece, or null if none was made yet.
static func icon_texture(set_id: String, slot_index: int) -> Texture2D:
	var key := "%s_%d" % [set_id, slot_index]
	if _icons.has(key):
		return _icons[key]
	var tex: Texture2D = null
	for path in [ICON_FOLDER + set_id + "_" + SLOT_FILES[slot_index] + ".png",
			ICON_FOLDER + SLOT_FILES[slot_index] + ".png"]:
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	_icons[key] = tex
	return tex


## Drawing origin and scale, set by _draw_piece.
var _origin := Vector2.ZERO
var _unit := 1.0


## A point in the icon's own coordinates (100 x 100 design grid).
func _p(dx: float, dy: float) -> Vector2:
	return _origin + Vector2(dx, dy) * _unit


## Polygon filled with a metal gradient running from `from` to `to`.
func _metal(pts: PackedVector2Array, from: Vector2, to: Vector2, c: Color) -> void:
	var axis := to - from
	var len2 := maxf(axis.length_squared(), 0.001)
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p - from).dot(axis) / len2, 0.0, 1.0)
		# light -> colour -> shadow, like brushed metal
		var col: Color
		if t < 0.45:
			col = c.lightened(0.55).lerp(c, t / 0.45)
		else:
			col = c.lerp(c.darkened(0.6), (t - 0.45) / 0.55)
		cols.append(col)
	draw_polygon(pts, cols)


func _outline(pts: PackedVector2Array, c: Color, width := 1.2) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, c.darkened(0.7), width, true)


func _shadow(pts: PackedVector2Array, offset: Vector2) -> void:
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + offset)
	draw_colored_polygon(moved, Color(0, 0, 0, 0.35))


## The piece, drawn in its tier colour with set-coloured accents.
## Each set uses its own shapes (see Gear.SETS "shapes").
func _draw_piece(s: Vector2, c: Color, empty: bool) -> void:
	var u := s.x / 100.0
	var m := s * 0.5
	var body := Color(c, 0.35) if empty else c
	var set_def: Dictionary = Gear.SETS.get(item.get("set", ""), {}) if not empty else {}
	var accent: Color = set_def.get("color", body.lightened(0.5))

	# Painted art, if there is any for this set and slot
	if not empty and not item.is_empty():
		var tex := icon_texture(str(item["set"]), slot)
		if tex != null:
			var box := Rect2(s * 0.19, s * 0.62)
			_draw_fitted(tex, box)
			return

	_origin = m
	_unit = u

	draw_circle(m, s.x * 0.34, Color(body, 0.06))
	draw_circle(m, s.x * 0.24, Color(body, 0.06))

	var shapes: Array = set_def.get("shapes", ["sword", "robe", "gem_ring", "boot"])
	var shape_name: String = shapes[slot] if slot < shapes.size() else "sword"

	match shape_name:
		"sword": _draw_sword(body, accent)
		"axe": _draw_axe(body, accent)
		"spear": _draw_spear(body, accent)
		"halberd": _draw_halberd(body, accent)
		"fan": _draw_fan(body, accent)
		"dagger": _draw_dagger(body, accent)
		"staff": _draw_staff(body, accent)
		"seal": _draw_seal(body, accent)
		"robe": _draw_robe(body, accent, false)
		"plate": _draw_plate(body, accent)
		"cloak": _draw_robe(body, accent, true)
		"gem_ring": _draw_ring(body, accent, false)
		"seal_ring": _draw_ring(body, accent, true)
		"slipper": _draw_boot(body, accent, true)
		_: _draw_boot(body, accent, false)


# ---------------------------------------------------------
# WEAPONS
# ---------------------------------------------------------

func _shaft(from: Vector2, to: Vector2, c: Color, width: float) -> void:
	draw_line(from, to, c.darkened(0.55), width, true)
	draw_line(from, to, c.darkened(0.25), width * 0.45, true)


func _draw_sword(c: Color, accent: Color) -> void:
	var blade := PackedVector2Array([_p(26, -30), _p(6, -8), _p(-2, 2), _p(-6, -2), _p(10, -16)])
	_shadow(blade, Vector2(2, 3) * _unit)
	_metal(blade, _p(-6, -2), _p(26, -30), c)
	_outline(blade, c)
	draw_colored_polygon(PackedVector2Array([_p(26, -30), _p(12, -12), _p(2, 0), _p(-2, 2)]), Color(1, 1, 1, 0.28))
	var guard := PackedVector2Array([_p(-14, -6), _p(2, 10), _p(-4, 16), _p(-20, 0)])
	_metal(guard, _p(-20, 0), _p(2, 10), c)
	_outline(guard, c)
	_shaft(_p(-10, 10), _p(-22, 22), c, 4.5 * _unit)
	draw_circle(_p(-24, 24), 4.5 * _unit, accent)


func _draw_axe(c: Color, accent: Color) -> void:
	_shaft(_p(-16, 26), _p(6, -22), c, 5.0 * _unit)
	var head := PackedVector2Array([_p(2, -18), _p(26, -24), _p(30, -2), _p(6, -2), _p(0, -10)])
	_shadow(head, Vector2(2, 3) * _unit)
	_metal(head, _p(0, -10), _p(30, -18), c)
	_outline(head, c)
	draw_colored_polygon(PackedVector2Array([_p(2, -18), _p(26, -24), _p(18, -14)]), Color(1, 1, 1, 0.25))
	var back := PackedVector2Array([_p(-2, -16), _p(-14, -18), _p(-12, -4), _p(-1, -4)])
	_metal(back, _p(-14, -18), _p(0, -4), c)
	_outline(back, c)
	draw_circle(_p(-16, 26), 4.0 * _unit, accent)


func _draw_spear(c: Color, accent: Color) -> void:
	_shaft(_p(-20, 28), _p(14, -14), c, 4.0 * _unit)
	var head := PackedVector2Array([_p(22, -30), _p(18, -12), _p(10, -6), _p(12, -16)])
	_shadow(head, Vector2(2, 3) * _unit)
	_metal(head, _p(10, -6), _p(22, -30), c)
	_outline(head, c)
	# tassel
	draw_line(_p(12, -8), _p(4, 2), accent, 3.0 * _unit, true)
	draw_line(_p(12, -8), _p(16, 2), accent, 3.0 * _unit, true)


func _draw_halberd(c: Color, accent: Color) -> void:
	_shaft(_p(-18, 28), _p(10, -20), c, 4.5 * _unit)
	var head := PackedVector2Array([_p(16, -30), _p(12, -12), _p(6, -8), _p(8, -18)])
	_metal(head, _p(6, -8), _p(16, -30), c)
	_outline(head, c)
	var blade := PackedVector2Array([_p(12, -16), _p(30, -12), _p(26, 0), _p(10, -6)])
	_shadow(blade, Vector2(2, 3) * _unit)
	_metal(blade, _p(10, -6), _p(30, -14), c)
	_outline(blade, c)
	draw_circle(_p(-18, 28), 4.0 * _unit, accent)


func _draw_fan(c: Color, accent: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var a := lerpf(-2.35, -0.79, float(i) / steps)
		pts.append(_p(0, 18) + Vector2(cos(a), sin(a)) * 34.0 * _unit)
	pts.append(_p(0, 18))
	_shadow(pts, Vector2(2, 3) * _unit)
	_metal(pts, _p(-26, -10), _p(26, 18), c)
	_outline(pts, c)
	for i in 5:
		var a := lerpf(-2.35, -0.79, float(i) / 4.0)
		draw_line(_p(0, 18), _p(0, 18) + Vector2(cos(a), sin(a)) * 33.0 * _unit, c.darkened(0.6), 1.2 * _unit, true)
	draw_circle(_p(0, 18), 4.5 * _unit, accent)


func _draw_dagger(c: Color, accent: Color) -> void:
	var blade := PackedVector2Array([_p(18, -24), _p(6, -6), _p(-2, 0), _p(2, -10)])
	_shadow(blade, Vector2(2, 3) * _unit)
	_metal(blade, _p(-2, 0), _p(18, -24), c)
	_outline(blade, c)
	draw_colored_polygon(PackedVector2Array([_p(18, -24), _p(9, -11), _p(4, -6)]), Color(1, 1, 1, 0.3))
	var guard := PackedVector2Array([_p(-8, -4), _p(4, 6), _p(0, 11), _p(-12, 1)])
	_metal(guard, _p(-12, 1), _p(4, 6), c)
	_outline(guard, c)
	_shaft(_p(-6, 8), _p(-16, 20), c, 4.0 * _unit)
	draw_circle(_p(-18, 22), 4.0 * _unit, accent)


func _draw_staff(c: Color, accent: Color) -> void:
	_shaft(_p(-14, 30), _p(8, -14), c, 4.5 * _unit)
	draw_arc(_p(12, -22), 11.0 * _unit, 0.0, TAU, 28, c.lightened(0.2), 4.0 * _unit, true)
	draw_circle(_p(12, -22), 6.0 * _unit, accent)
	draw_circle(_p(10, -24), 2.2 * _unit, Color(1, 1, 1, 0.8))
	draw_circle(_p(-14, 30), 3.5 * _unit, accent)


func _draw_seal(c: Color, accent: Color) -> void:
	var top := PackedVector2Array([_p(-16, -6), _p(16, -6), _p(20, 4), _p(-20, 4)])
	var base := PackedVector2Array([_p(-20, 4), _p(20, 4), _p(20, 22), _p(-20, 22)])
	_shadow(base, Vector2(2, 3) * _unit)
	_metal(base, _p(-20, 4), _p(20, 22), c)
	_outline(base, c)
	_metal(top, _p(-16, -6), _p(20, 4), c.lightened(0.15))
	_outline(top, c)
	# knob
	draw_circle(_p(0, -14), 7.0 * _unit, accent)
	draw_circle(_p(-2, -16), 2.5 * _unit, Color(1, 1, 1, 0.75))
	# engraved face
	draw_rect(Rect2(_p(-12, 9), Vector2(24, 9) * _unit), accent.darkened(0.2), false, 1.5 * _unit)


# ---------------------------------------------------------
# ARMOR
# ---------------------------------------------------------

func _draw_robe(c: Color, accent: Color, hooded: bool) -> void:
	var robe := PackedVector2Array([
		_p(-11, -24), _p(11, -24), _p(25, -12), _p(19, -2), _p(13, -7),
		_p(17, 26), _p(-17, 26), _p(-13, -7), _p(-19, -2), _p(-25, -12)])
	_shadow(robe, Vector2(2, 3) * _unit)
	_metal(robe, _p(-20, -20), _p(20, 24), c)
	_outline(robe, c)
	if hooded:
		var hood := PackedVector2Array([_p(-13, -22), _p(0, -34), _p(13, -22), _p(6, -20), _p(0, -26), _p(-6, -20)])
		_metal(hood, _p(-13, -34), _p(13, -20), c.lightened(0.1))
		_outline(hood, c)
	else:
		draw_colored_polygon(PackedVector2Array([_p(-11, -24), _p(0, -8), _p(11, -24),
			_p(4, -24), _p(0, -16), _p(-4, -24)]), c.darkened(0.55))
	draw_colored_polygon(PackedVector2Array([_p(-13, -7), _p(-6, -6), _p(-8, 26), _p(-17, 26)]), Color(1, 1, 1, 0.13))
	var sash := PackedVector2Array([_p(-18, 4), _p(18, 4), _p(18, 11), _p(-18, 11)])
	draw_colored_polygon(sash, accent.darkened(0.25))
	_outline(sash, c)
	draw_colored_polygon(PackedVector2Array([_p(0, 1), _p(4, 7.5), _p(0, 14), _p(-4, 7.5)]), accent.lightened(0.35))


func _draw_plate(c: Color, accent: Color) -> void:
	var torso := PackedVector2Array([
		_p(-16, -20), _p(16, -20), _p(22, -8), _p(18, 22), _p(0, 28), _p(-18, 22), _p(-22, -8)])
	_shadow(torso, Vector2(2, 3) * _unit)
	_metal(torso, _p(-20, -20), _p(20, 26), c)
	_outline(torso, c, 1.4)
	# pauldrons
	for side in [-1.0, 1.0]:
		var pad := PackedVector2Array([
			_p(side * 16, -22), _p(side * 30, -14), _p(side * 26, -2), _p(side * 15, -6)])
		_metal(pad, _p(side * 30, -22), _p(side * 15, -2), c.lightened(0.12))
		_outline(pad, c)
	# chest ridges and gem
	draw_line(_p(-10, -6), _p(10, -6), c.darkened(0.6), 2.0 * _unit, true)
	draw_line(_p(-9, 4), _p(9, 4), c.darkened(0.6), 2.0 * _unit, true)
	draw_colored_polygon(PackedVector2Array([_p(0, -18), _p(6, -12), _p(0, -6), _p(-6, -12)]), accent)


# ---------------------------------------------------------
# RING AND BOOTS
# ---------------------------------------------------------

func _draw_ring(c: Color, accent: Color, seal: bool) -> void:
	draw_arc(_p(0, 8), 17.0 * _unit, 0.0, TAU, 40, c.darkened(0.2), 7.0 * _unit, true)
	draw_arc(_p(0, 8), 17.0 * _unit, PI * 1.05, PI * 1.55, 16, Color(1, 1, 1, 0.35), 2.0 * _unit, true)
	draw_arc(_p(0, 8), 17.0 * _unit, PI * 0.1, PI * 0.5, 16, c.darkened(0.6), 2.0 * _unit, true)
	var g := _p(0, -15)
	if seal:
		var face := PackedVector2Array([g + Vector2(-11, -9) * _unit, g + Vector2(11, -9) * _unit,
			g + Vector2(11, 9) * _unit, g + Vector2(-11, 9) * _unit])
		_shadow(face, Vector2(2, 3) * _unit)
		_metal(face, g + Vector2(-11, -9) * _unit, g + Vector2(11, 9) * _unit, c.lightened(0.1))
		_outline(face, c)
		draw_rect(Rect2(g + Vector2(-6, -4) * _unit, Vector2(12, 8) * _unit), accent, false, 1.6 * _unit)
	else:
		var gem := PackedVector2Array([g + Vector2(0, -11) * _unit, g + Vector2(10, -1) * _unit,
			g + Vector2(0, 11) * _unit, g + Vector2(-10, -1) * _unit])
		_shadow(gem, Vector2(2, 3) * _unit)
		_metal(gem, g + Vector2(-10, 0) * _unit, g + Vector2(10, 10) * _unit, accent)
		_outline(gem, accent)
		draw_colored_polygon(PackedVector2Array([g + Vector2(0, -11) * _unit,
			g + Vector2(10, -1) * _unit, g]), Color(1, 1, 1, 0.45))
		draw_colored_polygon(PackedVector2Array([g + Vector2(-6, -3) * _unit,
			g + Vector2(-2, -6) * _unit, g + Vector2(-3, -1) * _unit]), Color(1, 1, 1, 0.8))


func _draw_boot(c: Color, accent: Color, light: bool) -> void:
	var wing := PackedVector2Array([_p(-9, -6), _p(-27, -17), _p(-30, -3), _p(-12, 6)])
	_metal(wing, _p(-30, -10), _p(-9, 0), accent.lightened(0.15))
	_outline(wing, c)
	var boot: PackedVector2Array
	if light:
		# soft slipper
		boot = PackedVector2Array([_p(-8, -14), _p(10, -14), _p(12, 4), _p(26, 14),
			_p(26, 24), _p(-12, 24), _p(-13, 2)])
	else:
		boot = PackedVector2Array([_p(-9, -26), _p(11, -26), _p(11, 6), _p(26, 13),
			_p(27, 24), _p(-13, 24), _p(-13, 2)])
	_shadow(boot, Vector2(2, 3) * _unit)
	_metal(boot, _p(-13, -20), _p(20, 24), c)
	_outline(boot, c)
	var cuff_top := -14.0 if light else -26.0
	draw_colored_polygon(PackedVector2Array([_p(-9, cuff_top), _p(11, cuff_top),
		_p(11, cuff_top + 8), _p(-9, cuff_top + 8)]), accent.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([_p(-13, 19), _p(27, 19), _p(27, 24), _p(-13, 24)]), c.darkened(0.55))
	draw_circle(_p(1, -2), 4.0 * _unit, accent.lightened(0.3))


func _gem(p: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.75, 0), p + Vector2(0, r), p + Vector2(-r * 0.75, 0)
	]), color)


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
