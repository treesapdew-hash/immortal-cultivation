class_name TitleBanner
extends Control

# =========================================================
# A title's banner, drawn rather than painted. Save as
# res://ui/title_banner.gd
#
#   var b := TitleBanner.new()
#   b.setup(tier, owned)
#
# Used wherever a title has no art of its own and no frame for its
# tier yet (see Titles.art_of). Painted banners are a long errand and
# the page should not look unfinished until every one of them exists,
# so this stands in: a notched plaque in the tier's colour, with more
# ornament and more light the rarer it gets.
#
# Drops away on its own the moment a PNG appears, because the Codex
# asks Titles.art_of first and only falls back to this.
# =========================================================

## How far the corners are cut in, as a share of height.
const NOTCH := 0.42
## Pips along each end. More for rarer titles.
const PIPS := [1, 1, 2, 2, 3, 3, 4]
## How far the glow reaches, in pixels, by tier.
const GLOW := [0.0, 0.0, 0.0, 2.0, 3.0, 5.0, 7.0]

var tier := 0
var lit := true


func setup(banner_tier: int, is_owned := true) -> void:
	tier = clampi(banner_tier, 0, ItemDB.GRADE_COLORS.size() - 1)
	lit = is_owned
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 2.0 or h <= 2.0:
		return
	var tint: Color = ItemDB.grade_color(tier)
	if not lit:
		# Unearned: the shape stays, the colour goes.
		tint = Color(0.42, 0.45, 0.52)

	var body := _plaque(Rect2(Vector2.ZERO, Vector2(w, h)))

	# A rarer title glows; a Common one is a piece of stone.
	var glow: float = GLOW[tier] if lit else 0.0
	var step := 0
	while float(step) < glow:
		var grow := float(step) + 1.0
		var halo := _plaque(Rect2(-grow, -grow, w + grow * 2.0, h + grow * 2.0))
		draw_colored_polygon(halo, Color(tint, 0.05 * (1.0 - float(step) / maxf(glow, 1.0))))
		step += 1

	# Body, then a lighter band across the top half so it reads as
	# lit from above rather than flat.
	draw_colored_polygon(body, Color(tint, 0.16 if lit else 0.07))
	var top := _plaque(Rect2(0, 0, w, h * 0.5))
	draw_colored_polygon(top, Color(tint, 0.07 if lit else 0.03))

	draw_polyline(_closed(body), Color(tint, 0.85 if lit else 0.35), 1.5, true)
	var inner := _plaque(Rect2(5, 5, w - 10.0, h - 10.0))
	draw_polyline(_closed(inner), Color(tint, 0.4 if lit else 0.18), 1.0, true)

	_pips(w, h, tint)


## A notched plaque: corners cut at an angle, the way a hanging sign
## or a jade tablet is, rather than a plain rectangle.
func _plaque(r: Rect2) -> PackedVector2Array:
	var cut := minf(r.size.y * NOTCH, r.size.x * 0.25)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x
	var y1 := r.position.y + r.size.y
	var mid := y0 + r.size.y * 0.5
	return PackedVector2Array([
		Vector2(x0 + cut, y0), Vector2(x1 - cut, y0), Vector2(x1, mid),
		Vector2(x1 - cut, y1), Vector2(x0 + cut, y1), Vector2(x0, mid),
	])


## The same ring with the first point repeated, for draw_polyline.
func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	out.append(points[0])
	return out


## Small diamonds inside each end, counting up with the tier. Cheap
## to draw and the count alone tells you the rarity at a glance.
func _pips(w: float, h: float, tint: Color) -> void:
	var n: int = PIPS[tier]
	var mid := h * 0.5
	var radius := minf(h * 0.09, 4.0)
	var alpha := 0.9 if lit else 0.3
	for i in n:
		var inset := 11.0 + float(i) * (radius * 2.6)
		for x in [inset, w - inset]:
			var c := Vector2(float(x), mid)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -radius), c + Vector2(radius, 0),
				c + Vector2(0, radius), c + Vector2(-radius, 0),
			]), Color(tint, alpha))
