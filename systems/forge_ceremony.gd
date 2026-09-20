class_name ForgeCeremony
extends CanvasLayer

# =========================================================
# The Spirit Forge reveal.
#
#   ForgeCeremony.play(host, artifact)
#
# Cores spiral into the furnace, the flame swells, a flash,
# then the artifact rises in its grade's colour. Tap to skip
# ahead. Emits finished() when it closes.
# =========================================================

signal finished

## Your art, used when these files exist (drawn versions otherwise).
const CAULDRON_PATH := "res://assets/ui/forge_cauldron.png"
const FLAME_PATH := "res://assets/ui/forge_flame.png"

const GOLD := Color("e2c27a")
const RUSH_AFTER := 0.15     # taps are ignored for this long

var _artifact: Dictionary = {}
var _furnace: Control
var _rays: Control
var _flash: ColorRect
var _reveal: Control
var _heat := 0.0
var _spin := 0.0
var _rushing := false
var _age := 0.0
static var _cauldron: Texture2D = null
static var _flame: Texture2D = null
static var _art_checked := false


static func _load_art() -> void:
	if _art_checked:
		return
	_art_checked = true
	if ResourceLoader.exists(CAULDRON_PATH):
		_cauldron = load(CAULDRON_PATH)
	if ResourceLoader.exists(FLAME_PATH):
		_flame = load(FLAME_PATH)


static func play(host: Node, artifact: Dictionary) -> ForgeCeremony:
	var c := ForgeCeremony.new()
	c._artifact = artifact
	host.get_tree().root.add_child(c)
	return c


func _ready() -> void:
	layer = 70
	set_process(true)
	_load_art()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(_on_input)
	add_child(dim)

	# Rays behind everything, spinning slowly
	_rays = Control.new()
	_rays.anchor_right = 1.0
	_rays.anchor_bottom = 1.0
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.modulate.a = 0.0
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

	_furnace = Control.new()
	_furnace.anchor_right = 1.0
	_furnace.anchor_bottom = 1.0
	_furnace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_furnace.draw.connect(_draw_furnace)
	add_child(_furnace)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_run()


func _process(delta: float) -> void:
	_age += delta
	_spin += delta * 0.35
	if _furnace != null:
		_furnace.queue_redraw()
	if _rays != null and _rays.modulate.a > 0.0:
		_rays.queue_redraw()


func _on_input(event) -> void:
	if event is InputEventMouseButton and event.pressed and _age > RUSH_AFTER:
		if _reveal != null:
			_close()
		else:
			_rushing = true


## Waits, but a tap cuts the wait short.
func _hold(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _rushing:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _run() -> void:
	# 1. The flame builds
	var heat := create_tween()
	heat.tween_method(func(v: float): _heat = v, 0.0, 1.0, 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _hold(1.15)

	# 2. Flash
	var flash := create_tween()
	flash.tween_property(_flash, "color:a", 0.9, 0.12)
	flash.tween_property(_flash, "color:a", 0.0, 0.5)
	await _hold(0.22)

	# 3. The artifact rises
	_furnace.modulate.a = 0.18
	_build_reveal()
	var grade := int(_artifact.get("grade", 0))
	if grade >= 2:
		var rays := create_tween()
		rays.tween_property(_rays, "modulate:a", 1.0, 0.5)


func _build_reveal() -> void:
	var grade := int(_artifact.get("grade", 0))
	var color := Artifacts.grade_color(grade)

	_reveal = VBoxContainer.new()
	_reveal.anchor_left = 0.5
	_reveal.anchor_right = 0.5
	_reveal.anchor_top = 0.5
	_reveal.anchor_bottom = 0.5
	_reveal.offset_left = -300
	_reveal.offset_right = 300
	_reveal.offset_top = -230
	_reveal.offset_bottom = 230
	_reveal.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal.add_theme_constant_override("separation", 10)
	add_child(_reveal)

	var icon := ArtifactIcon.new()
	icon.custom_minimum_size = Vector2(190, 190)
	icon.disabled = true
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(_artifact)
	_reveal.add_child(icon)

	_reveal.add_child(_label(Artifacts.grade_name(grade).to_upper(), 24, color))
	_reveal.add_child(_label(Artifacts.trait_name(_artifact), 40, Artifacts.color_of(_artifact), true))
	var effect := _label(Artifacts.trait_text(_artifact), 22, Color("c9d4e3"))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal.add_child(effect)

	var keep := OrnateButton.new()
	keep.text = "Keep"
	keep.custom_minimum_size = Vector2(260, 66)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.pressed.connect(_close)
	_reveal.add_child(keep)

	# Pop in, with a bigger bounce for better grades
	_reveal.scale = Vector2(0.6, 0.6)
	_reveal.pivot_offset = Vector2(300, 230)
	_reveal.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_reveal, "modulate:a", 1.0, 0.25)
	t.tween_property(_reveal, "scale", Vector2.ONE, 0.45 + grade * 0.04) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	set_process(false)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.1)
	t.parallel().tween_property(_rays, "modulate:a", 0.0, 0.2)
	if _reveal != null:
		t.parallel().tween_property(_reveal, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		finished.emit()
		queue_free()
	)


# ---------------------------------------------------------
# DRAWING
# ---------------------------------------------------------

## Samples a cubic bezier into points.
func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var q := 1.0 - t
		pts.append(p0 * q * q * q + p1 * 3.0 * q * q * t + p2 * 3.0 * q * t * t + p3 * t * t * t)
	return pts


func _ellipse(center: Vector2, rx: float, ry: float, steps := 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## One teardrop of flame.
func _flame_shape(base: Vector2, height: float, width: float, lean: float,
		color: Color, alpha: float) -> void:
	var pts := PackedVector2Array()
	pts.append(base + Vector2(-width, 0))
	pts.append_array(_bezier(
		base + Vector2(-width, 0),
		base + Vector2(-width * 0.9, -height * 0.5),
		base + Vector2(-width * 0.5 + lean, -height * 0.78),
		base + Vector2(lean * 0.5, -height), 10))
	pts.append_array(_bezier(
		base + Vector2(lean * 0.5, -height),
		base + Vector2(width * 0.5 + lean, -height * 0.78),
		base + Vector2(width * 0.9, -height * 0.5),
		base + Vector2(width, 0), 10))
	_furnace.draw_colored_polygon(pts, Color(color, alpha))


## The furnace: a bronze cauldron of molten qi, a flame that swells,
## and cores spiralling into it.
func _draw_furnace() -> void:
	var s := _furnace.size
	var u := minf(s.x, s.y) / 520.0
	var center := Vector2(s.x * 0.5, s.y * 0.5)
	var grade_color := Artifacts.grade_color(int(_artifact.get("grade", 0)))
	var flame_color := Color("ffb04a").lerp(grade_color, _heat * 0.55)

	# Heat glow
	for i in 8:
		var r := (34.0 + i * 18.0) * u * (0.7 + _heat * 1.1)
		_furnace.draw_circle(center, r, Color(flame_color, 0.045 * (1.0 - float(i) / 8.0) * (0.3 + _heat)))

	# Cores spiralling in, on a flattened orbit
	for i in 10:
		var t := clampf(_heat * 1.2 - float(i) / 10.0 * 0.3, 0.0, 1.0)
		var angle := _spin * 3.0 + TAU * i / 10.0
		var radius := 150.0 * u * (1.0 - t)
		var p := center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 - 26.0 * u * t)
		for k in 3:
			_furnace.draw_circle(p, (8.0 - k * 2.5) * u, Color("9fd8ff", 0.18 + k * 0.22))

	# Flame: your art if there is any, otherwise three drawn layers
	var flicker := sin(_spin * 20.0) * 5.0 * u * _heat
	var base := center - Vector2(0, 6.0 * u)
	if _flame != null:
		var height := (150.0 * _heat + 50.0) * u
		var width := height * float(_flame.get_width()) / maxf(float(_flame.get_height()), 1.0)
		var rect := Rect2(base + Vector2(-width * 0.5 + flicker * 0.4, -height), Vector2(width, height))
		_furnace.draw_texture_rect(_flame, rect, false, Color(flame_color, 0.55 + 0.45 * _heat))
	else:
		_flame_shape(base, (150.0 * _heat + 40.0) * u, 40.0 * u, 6.0 * u + flicker, flame_color, 0.35)
		_flame_shape(base, (110.0 * _heat + 30.0) * u, 27.0 * u, -4.0 * u + flicker, Color("ffd06a"), 0.55)
		_flame_shape(base, (70.0 * _heat + 18.0) * u, 15.0 * u, 2.0 * u + flicker * 0.5, Color("fff3c4"), 0.85)

	# Cauldron: your art if there is any
	if _cauldron != null:
		var cw := 260.0 * u
		var ch := cw * float(_cauldron.get_height()) / maxf(float(_cauldron.get_width()), 1.0)
		_furnace.draw_texture_rect(_cauldron,
			Rect2(center + Vector2(-cw * 0.5, 4.0 * u), Vector2(cw, ch)), false)
		return

	var bw := 86.0 * u
	var bh := 58.0 * u
	var cy := center.y + 30.0 * u
	var rim := Vector2(center.x, cy)

	var bowl := PackedVector2Array()
	bowl.append_array(_bezier(
		Vector2(center.x - bw, cy),
		Vector2(center.x - bw * 0.95, cy + bh * 1.25),
		Vector2(center.x + bw * 0.95, cy + bh * 1.25),
		Vector2(center.x + bw, cy), 20))
	var cols := PackedColorArray()
	for p in bowl:
		var t := clampf((p.x - center.x + bw) / (bw * 2.0), 0.0, 1.0)
		cols.append(Color("6a533a").lerp(Color("1d160f"), t))
	_furnace.draw_polygon(bowl, cols)
	var outline := bowl.duplicate()
	outline.append(bowl[0])
	_furnace.draw_polyline(outline, GOLD, 2.0, true)

	# Rim and the molten qi inside
	var rim_pts := _ellipse(rim, bw, 15.0 * u)
	_furnace.draw_colored_polygon(rim_pts, Color("241b13"))
	var rim_line := rim_pts.duplicate()
	rim_line.append(rim_pts[0])
	_furnace.draw_polyline(rim_line, GOLD, 2.5, true)
	for i in 5:
		var f := 1.0 - float(i) / 5.0
		_furnace.draw_colored_polygon(_ellipse(rim, bw * 0.82 * f, 11.0 * u * f),
			Color("7a2f10").lerp(Color("fff0b0"), 1.0 - f))

	# Handles and legs
	for side in [-1.0, 1.0]:
		_furnace.draw_arc(Vector2(center.x + side * bw * 0.98, cy + 16.0 * u), 14.0 * u,
			-1.1, 1.1, 14, GOLD, 3.0, true)
		_furnace.draw_line(
			Vector2(center.x + side * bw * 0.45, cy + bh * 1.02),
			Vector2(center.x + side * bw * 0.55, cy + bh * 1.35), Color("2b2118"), 6.0 * u, true)


## Light rays behind a good artifact.
func _draw_rays() -> void:
	var s := _rays.size
	var center := Vector2(s.x * 0.5, s.y * 0.5)
	var color := Artifacts.grade_color(int(_artifact.get("grade", 0)))
	var count := 14
	for i in count:
		var a := _spin + TAU * i / count
		var spread := 0.05
		_rays.draw_colored_polygon(PackedVector2Array([
			center,
			center + Vector2(cos(a - spread), sin(a - spread)) * s.x,
			center + Vector2(cos(a + spread), sin(a + spread)) * s.x,
		]), Color(color, 0.07))


func _label(text: String, font_size: int, color: Color, glow := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(color, 0.4))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 16)
	return l
