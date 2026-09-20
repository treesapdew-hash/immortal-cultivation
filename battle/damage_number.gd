class_name DamageNumber
extends Label
## Floating combat text in a xianxia style.
##
##   DamageNumber.spawn(fx_layer, global_pos, amount, DamageNumber.Kind.CRIT)
##   DamageNumber.spawn_slash(fx_layer, global_pos, is_crit)
##
## Chinese tags (暴击, 闪避, 灵气) are used when TAG_FONT_PATH points to a
## font with Chinese characters. Otherwise English tags are shown.

enum Kind { NORMAL, CRIT, HEAL, DODGE, QI }

## Font for the numbers, e.g. your UI serif font. Empty = default font.
const FONT_PATH := "res://assets/TrajanPro-Bold.otf"

## Brush font for the Chinese tags, e.g. Ma Shan Zheng (Google Fonts).
## Empty = use FONT_PATH.
const TAG_FONT_PATH := ""

const SEAL_RED := Color("a8121a")
const SEAL_TEXT := Color("fff1dc")

## top / bottom = gradient over the text
const STYLES := {
	Kind.NORMAL: {"size": 48, "top": Color("f3ead6"), "bottom": Color("d6c7a6"),
		"outline": Color("17110c"), "outline_size": 5},
	Kind.CRIT:   {"size": 70, "top": Color("fffaf0"), "bottom": Color("eadcc0"),
		"outline": Color("0e0a07"), "outline_size": 6},
	Kind.HEAL:   {"size": 44, "top": Color("eefbef"), "bottom": Color("a9dcb4"),
		"outline": Color("0e2a18"), "outline_size": 5},
	Kind.DODGE:  {"size": 40, "top": Color("e6ebee"), "bottom": Color("aab6bd"),
		"outline": Color("1b2226"), "outline_size": 4},
	Kind.QI:     {"size": 38, "top": Color("eefaf6"), "bottom": Color("a8dccf"),
		"outline": Color("0c2a26"), "outline_size": 4},
}

const INK := Color(0.05, 0.045, 0.06, 0.85)
const VERMILION := Color("b8321f")

## [Chinese, English]
const TAGS := {
	Kind.CRIT:  ["暴击", "CRITICAL"],
	Kind.DODGE: ["闪避", "DODGE"],
	Kind.QI:    ["灵气", "Qi"],
}

## Vertical colour gradient across the label's text.
const GRADIENT_SHADER := """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0);
uniform vec4 bottom_color : source_color = vec4(1.0);
uniform float height = 100.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float t = clamp(local_y / height, 0.0, 1.0);
	COLOR.rgb *= mix(top_color.rgb, bottom_color.rgb, t);
}
"""

const SWORD_ARC := 1.1   # half-angle of the crescent, in radians

static var _fonts_loaded := false
static var _number_font: Font
static var _tag_font: Font
static var _use_chinese := false
static var _gradient_shader: Shader
static var _glow_texture: Texture2D
static var _additive: CanvasItemMaterial


# ---------------------------------------------------------
# SPAWNING
# ---------------------------------------------------------

static func spawn(layer: Node, at_global: Vector2, amount: int, kind: Kind = Kind.NORMAL) -> void:
	if layer == null:
		push_warning("DamageNumber: no fx layer")
		return
	# Settings: damage numbers can be turned off
	if not Settings.is_on("damage_numbers"):
		return
	_load_shared()

	var n := DamageNumber.new()
	layer.add_child(n)
	n._setup(at_global, amount, kind)


## Short status word ("FROZEN", "SHIELD"...) that drifts up.
static func spawn_text(layer: Node, at_global: Vector2, message: String, color: Color) -> void:
	if layer == null:
		return
	_load_shared()
	var n := DamageNumber.new()
	layer.add_child(n)
	n.text = message
	var ls := _settings(_number_font, 30, Color("0b1626"), 5)
	n.label_settings = ls
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.z_index = 101
	n.size = n.get_minimum_size()
	n.pivot_offset = n.size * 0.5
	n.global_position = at_global - n.size * 0.5 + Vector2(0, -40)
	var mat := ShaderMaterial.new()
	mat.shader = _gradient_shader
	mat.set_shader_parameter("top_color", color.lightened(0.4))
	mat.set_shader_parameter("bottom_color", color)
	mat.set_shader_parameter("height", n.size.y)
	n.material = mat
	n.modulate.a = 0.0
	var t := n.create_tween()
	t.tween_property(n, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(n, "position:y", n.position.y - 70.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(n, "modulate:a", 0.0, 0.35).set_delay(0.55)
	t.tween_callback(n.queue_free)


## Crescent of sword qi across a target. Wide and gold on crits.
static func spawn_slash(layer: Node, center: Vector2, strong: bool) -> void:
	if layer == null:
		return
	_load_shared()

	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.z_index = 99
	if not strong:
		s.material = _additive
	layer.add_child(s)
	s.global_position = center
	s.rotation = randf_range(-0.9, -0.3)
	if randf() < 0.5:
		s.scale.x = -1.0

	var radius := 150.0 if strong else 110.0
	var width := 22.0 if strong else 7.0
	# Crit: black ink brush stroke. Normal: faint white sword qi.
	var core := Color(0.05, 0.045, 0.06, 0.9) if strong else Color(0.85, 0.9, 0.95, 0.45)
	var glow := Color(0.05, 0.045, 0.06, 0.25) if strong else Color(0.7, 0.8, 0.9, 0.12)
	# The arc's centre sits behind the target so the curve crosses it.
	var offset := Vector2(-radius * 0.8, 0)

	s.set_meta("tail", 0.0)
	s.set_meta("tip", 0.0)

	s.draw.connect(func():
		var a := float(s.get_meta("tail"))
		var b := float(s.get_meta("tip"))
		_draw_crescent(s, offset, radius + width * 0.25, a, b, width * 1.5, glow)
		_draw_crescent(s, offset, radius, a, b, width, core)
	)

	var set_tip := func(v: float):
		s.set_meta("tip", v)
		s.queue_redraw()
	var set_tail := func(v: float):
		s.set_meta("tail", v)
		s.queue_redraw()

	var t := s.create_tween()
	t.tween_method(set_tip, 0.0, 1.0, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(set_tail, 0.0, 1.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)


## Draws the part of a crescent between start and end (0-1 along the arc).
## The crescent is thickest in the middle and sharp at both ends.
static func _draw_crescent(c: Control, center: Vector2, radius: float,
		start: float, end: float, width: float, color: Color) -> void:
	if end - start < 0.02:
		return

	var steps := 20
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()

	for i in steps + 1:
		var u := lerpf(start, end, float(i) / steps)
		var ang := lerpf(-SWORD_ARC, SWORD_ARC, u)
		var dir := Vector2(cos(ang), sin(ang))
		var w := width * maxf(sin(PI * u), 0.05)
		outer.append(center + dir * radius)
		inner.append(center + dir * (radius - w))

	inner.reverse()
	outer.append_array(inner)
	c.draw_colored_polygon(outer, color)


# ---------------------------------------------------------
# SHARED RESOURCES
# ---------------------------------------------------------

static func _load_shared() -> void:
	if _fonts_loaded:
		return
	_fonts_loaded = true

	if FONT_PATH != "" and ResourceLoader.exists(FONT_PATH):
		_number_font = load(FONT_PATH)

	var tag_path := TAG_FONT_PATH if TAG_FONT_PATH != "" else FONT_PATH
	if tag_path != "" and ResourceLoader.exists(tag_path):
		_tag_font = load(tag_path)

	# 0x66B4 = 暴. No Chinese glyphs -> English tags.
	_use_chinese = _tag_font != null and _tag_font.has_char(0x66B4)

	_gradient_shader = Shader.new()
	_gradient_shader.code = GRADIENT_SHADER

	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_glow_texture = tex


## Shared with other effects (e.g. ResultBanner).
static func get_number_font() -> Font:
	_load_shared()
	return _number_font


static func get_tag_font() -> Font:
	_load_shared()
	return _tag_font


static func uses_chinese() -> bool:
	_load_shared()
	return _use_chinese


static func get_gradient_shader() -> Shader:
	_load_shared()
	return _gradient_shader


static func _tag(kind: Kind) -> String:
	var pair: Array = TAGS[kind]
	return pair[0] if _use_chinese else pair[1]


static func _settings(font: Font, font_size: int, outline: Color, outline_size: int) -> LabelSettings:
	var ls := LabelSettings.new()
	if font != null:
		ls.font = font
	ls.font_size = font_size
	ls.font_color = Color.WHITE      # the gradient shader colours it
	ls.outline_color = outline
	ls.outline_size = outline_size
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_size = 2
	ls.shadow_offset = Vector2(2, 3)
	return ls


# ---------------------------------------------------------
# SETUP
# ---------------------------------------------------------

func _setup(at_global: Vector2, amount: int, kind: Kind) -> void:
	var st: Dictionary = STYLES[kind]
	var font := _number_font

	match kind:
		Kind.HEAL:
			text = "+" + NumberFormat.short(amount)
		Kind.DODGE:
			text = _tag(kind)
			if _use_chinese:
				font = _tag_font
		Kind.QI:
			text = "+%s %s" % [NumberFormat.short(amount), _tag(kind)]
			if _use_chinese:
				font = _tag_font
		_:
			text = NumberFormat.short(amount)

	label_settings = _settings(font, st["size"], st["outline"], st["outline_size"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z_index = 100

	size = get_minimum_size()
	pivot_offset = size * 0.5
	global_position = at_global - size * 0.5 + Vector2(randf_range(-35.0, 35.0), randf_range(-10.0, 10.0))

	var mat := ShaderMaterial.new()
	mat.shader = _gradient_shader
	mat.set_shader_parameter("top_color", st["top"])
	mat.set_shader_parameter("bottom_color", st["bottom"])
	mat.set_shader_parameter("height", size.y)
	material = mat

	if kind == Kind.CRIT:
		_add_ink_splash(maxf(size.x, size.y) * 0.62)
		if _use_chinese:
			_add_seal()
		else:
			_add_crit_word()

	_animate(kind)


## Black ink splatter behind the number: an organic blot,
## a lighter bleed around it, droplets and a few flicks.
func _add_ink_splash(radius: float) -> void:
	var splash := Control.new()
	splash.show_behind_parent = true
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.position = size * 0.5

	var phase := [randf() * TAU, randf() * TAU, randf() * TAU]
	var blot := _organic_shape(radius, phase, 44)
	var bleed := _organic_shape(radius * 1.18, phase, 44)

	# Smaller blots overlapping the main one
	var extras: Array = []
	for i in randi_range(2, 4):
		var ang := randf() * TAU
		var center := Vector2(cos(ang), sin(ang) * 0.75) * radius * randf_range(0.55, 0.85)
		var r := radius * randf_range(0.28, 0.45)
		var shape := _organic_shape(r, [randf() * TAU, randf() * TAU, randf() * TAU], 24)
		for j in shape.size():
			shape[j] += center
		extras.append(shape)

	# Droplets: smaller the further out they fly
	var drops: Array = []
	for i in randi_range(10, 16):
		var ang := randf() * TAU
		var t := randf()
		var dist := radius * lerpf(1.15, 2.1, t)
		drops.append([Vector2(cos(ang), sin(ang) * 0.75) * dist, lerpf(7.0, 2.0, t)])

	# Flicks: tapered streaks ending in a drop
	var flicks: Array = []
	for i in randi_range(2, 4):
		var ang := randf() * TAU
		var dir := Vector2(cos(ang), sin(ang) * 0.75)
		flicks.append([dir * radius * 0.9, dir * radius * randf_range(1.5, 2.0), randf_range(4.0, 7.0)])

	splash.draw.connect(func():
		splash.draw_colored_polygon(bleed, Color(INK, 0.22))
		splash.draw_colored_polygon(blot, INK)
		for shape in extras:
			splash.draw_colored_polygon(shape, INK)
		for f in flicks:
			var p0: Vector2 = f[0]
			var p1: Vector2 = f[1]
			var w: float = f[2]
			var n := (p1 - p0).orthogonal().normalized()
			splash.draw_colored_polygon(PackedVector2Array([
				p0 + n * w * 0.9, p1 + n * w * 0.5, p1 - n * w * 0.5, p0 - n * w * 0.9
			]), INK)
			splash.draw_circle(p1, w * 0.8, INK)
		for d in drops:
			splash.draw_circle(d[0], d[1], INK)
	)
	add_child(splash)

	splash.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(splash, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55)
	tw.tween_property(splash, "modulate:a", 0.0, 0.5)


## Wobbly ellipse built from a few sine waves, so every splash is unique.
static func _organic_shape(radius: float, phase: Array, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var ang := TAU * i / points
		var wobble: float = 1.0 \
			+ 0.13 * sin(3.0 * ang + phase[0]) \
			+ 0.08 * sin(5.0 * ang + phase[1]) \
			+ 0.05 * sin(9.0 * ang + phase[2])
		var r := radius * wobble * randf_range(0.96, 1.04)
		pts.append(Vector2(cos(ang), sin(ang) * 0.75) * r)
	return pts


## Red seal (暴击) that presses down beside the number.
func _add_seal() -> void:
	var seal := PanelContainer.new()
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.use_parent_material = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = SEAL_RED
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.7, 0.7)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	seal.add_theme_stylebox_override("panel", sb)

	var tag := Label.new()
	tag.text = _tag(Kind.CRIT)
	tag.label_settings = _settings(_tag_font, 30, Color(0, 0, 0, 0), 0)
	tag.label_settings.shadow_color = Color(0, 0, 0, 0)
	tag.label_settings.font_color = SEAL_TEXT
	seal.add_child(tag)
	add_child(seal)

	seal.size = seal.get_combined_minimum_size()
	seal.position = Vector2(size.x - seal.size.x * 0.2, size.y * 0.5 - seal.size.y)
	seal.pivot_offset = seal.size * 0.5
	seal.scale = Vector2(1.8, 1.8)
	seal.modulate.a = 0.0

	var t := create_tween()
	t.tween_interval(0.12)
	t.tween_property(seal, "modulate:a", 0.95, 0.08)
	t.parallel().tween_property(seal, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Small vermilion "CRITICAL" above the number (when there's no Chinese font).
func _add_crit_word() -> void:
	var word := Label.new()
	word.text = _tag(Kind.CRIT)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.label_settings = _settings(_number_font, 22, Color("f3ead6"), 4)
	word.label_settings.font_color = VERMILION
	add_child(word)

	word.size = word.get_minimum_size()
	word.position = Vector2((size.x - word.size.x) * 0.5, -word.size.y * 0.6)
	word.modulate.a = 0.0

	var t := create_tween()
	t.tween_interval(0.1)
	t.tween_property(word, "modulate:a", 1.0, 0.15)


# ---------------------------------------------------------
# MOTION
# ---------------------------------------------------------

func _animate(kind: Kind) -> void:
	var t := create_tween()

	match kind:
		Kind.CRIT:
			# Descend with weight, hold while the array spins, then rise
			scale = Vector2(1.5, 1.5)
			modulate.a = 0.0
			t.tween_property(self, "modulate:a", 1.0, 0.06)
			t.parallel().tween_property(self, "scale", Vector2.ONE, 0.16) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.55)
			t.tween_property(self, "position:y", position.y - 120.0, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.2)

		Kind.DODGE:
			# Drift sideways like a gust of wind
			var side := -1.0 if randf() < 0.5 else 1.0
			modulate.a = 0.0
			t.tween_property(self, "modulate:a", 1.0, 0.1)
			t.parallel().tween_property(self, "position:x", position.x + side * 80.0, 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "position:y", position.y - 30.0, 0.8)
			t.parallel().tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.35)

		Kind.QI:
			# Rise slowly like drifting spirit energy
			modulate.a = 0.0
			t.tween_property(self, "modulate:a", 1.0, 0.2)
			t.parallel().tween_property(self, "position:y", position.y - 160.0, 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.9)

		_:
			# Appear, then float up gently
			scale = Vector2(0.7, 0.7)
			modulate.a = 0.0
			t.tween_property(self, "modulate:a", 1.0, 0.08)
			t.parallel().tween_property(self, "scale", Vector2.ONE, 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.15)
			t.tween_property(self, "position:y", position.y - 90.0, 0.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.2)

	t.tween_callback(queue_free)
