class_name SummonCard
extends Control

# =========================================================
# One summon card. Used big (the stage) and small (the arc).
#
#   var card := SummonCard.new()
#   card.setup(result, effect_tier, Vector2(420, 560))
#   await card.anticipate(0.8)   # rare pulls only
#   await card.flip()
#   card.play_fx(true)
# =========================================================

const TIER_COLORS := [
	Color("e6e9ee"),   # White
	Color("5aa8ff"),   # Blue
	Color("4ddc7a"),   # Green
	Color("b476ff"),   # Purple
	Color("ff4d4d"),   # Red
	Color("ffcf4a"),   # Gold
	Color("9ff6ff"),   # Prismatic
]
const TIER_NAMES := ["White", "Blue", "Green", "Purple", "Red", "Gold", "Prismatic"]

const GOLD := Color("e2c27a")

## Logo shown on the card back (leave empty for the drawn emblem).
const BACK_LOGO_PATH := "res://assets/game_logo.png"
## Logo width as a fraction of the card width.
const BACK_LOGO_WIDTH := 0.8
## Colours for the logo card back (jade-black lacquer to match the logo).
const BACK_LOGO_TOP := Color("0f2a26")
const BACK_LOGO_BOTTOM := Color("040a0b")
const BACK_LOGO_GLOW := Color(0.35, 0.95, 0.65, 0.3)

## Turns a logo's dark background see-through and fades its square edges.
const LOGO_SHADER := """
shader_type canvas_item;
uniform float dark_low = 0.08;
uniform float dark_high = 0.28;
uniform float edge = 0.47;
void fragment() {
	float lum = max(COLOR.r, max(COLOR.g, COLOR.b));
	float a = smoothstep(dark_low, dark_high, lum);
	float d = distance(UV, vec2(0.5));
	a *= 1.0 - smoothstep(edge - 0.08, edge, d);
	COLOR.a *= a;
}
"""
const BACK_TOP := Color("16294d")
const BACK_BOTTOM := Color("080f22")

## Cuts the art to the inside of the frame (traced from the frame's
## transparency), plus a diagonal shine that sweeps across it.
const SHINE_SHADER := """
shader_type canvas_item;
uniform float shine = -1.0;
uniform float width = 0.14;
uniform vec2 rect_size = vec2(100.0, 100.0);

// Frame mask (white = inside the frame), in card space
uniform bool use_mask = false;
uniform sampler2D frame_mask : filter_linear;
uniform vec2 art_offset = vec2(0.0);
uniform vec2 card_size = vec2(100.0, 100.0);
uniform float spread = 0.01;

// Fallback when there's no mask: cut corners
uniform float chamfer = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos / rect_size;

	if (use_mask) {
		// Sample around the pixel so the art reaches slightly under the border
		vec2 c = (local_pos + art_offset) / card_size;
		vec2 d = vec2(spread, spread * card_size.x / card_size.y);
		float m = texture(frame_mask, c).r;
		m = max(m, texture(frame_mask, c + vec2(d.x, 0.0)).r);
		m = max(m, texture(frame_mask, c - vec2(d.x, 0.0)).r);
		m = max(m, texture(frame_mask, c + vec2(0.0, d.y)).r);
		m = max(m, texture(frame_mask, c - vec2(0.0, d.y)).r);
		m = max(m, texture(frame_mask, c + d * 0.7).r);
		m = max(m, texture(frame_mask, c - d * 0.7).r);
		m = max(m, texture(frame_mask, c + vec2(d.x, -d.y) * 0.7).r);
		m = max(m, texture(frame_mask, c + vec2(-d.x, d.y) * 0.7).r);
		COLOR.a *= smoothstep(0.3, 0.7, m);
	} else if (chamfer > 0.0) {
		vec2 q = vec2(min(p.x, 1.0 - p.x), min(p.y, 1.0 - p.y));
		float cy = chamfer * rect_size.x / rect_size.y;
		float cut = q.x / chamfer + q.y / cy;
		COLOR.a *= smoothstep(0.97, 1.03, cut);
	}

	float x = p.x + p.y * 0.5;
	float s = 1.0 - smoothstep(0.0, width, abs(x - shine));
	COLOR.rgb += s * 0.45 * COLOR.a;
}
"""


## Tier frames (White ... Prismatic), borrowed from PartnerPanel.
static var tier_frames: Array = []

## The art is cut to the exact inside of each frame automatically.
## ART_SPREAD lets it reach slightly under the border so no gap shows
## (fraction of the card width). Raise it if you see a gap, lower it
## if art shows outside the border.
const ART_SPREAD := 0.008

## Size of the art box around the opening (fraction of the card).
const ART_OVERLAP := 0.02

## Used only if a frame can't be measured.
const ART_INSET := 0.06

## Corner cut, only used if a frame can't be traced.
const ART_CHAMFER := 0.12

static var _openings := {}        # frame texture -> Rect2 (0-1)
static var _masks := {}           # frame texture -> ImageTexture (or null)

static var _logo: Texture2D
static var _logo_loaded := false
static var _back_gradient: Texture2D
static var _logo_back_gradient: Texture2D
static var _logo_shader: Shader

static var _glow_tex: Texture2D
static var _dot_tex: Texture2D
static var _additive: CanvasItemMaterial
static var _shine_shader: Shader

var result: Dictionary
var data                      # PartnerData (may be null)
var tier := 0                 # tier used for colours and effects
var level := 0                # 0 = White ... 6 = Prismatic
var revealed := false
var base_scale := Vector2.ONE

var _color: Color
var _aura: TextureRect
var _rays: Control
var _back: Control
var _front: Control
var _art: TextureRect
var _shine_mat: ShaderMaterial
var _sparkles: CPUParticles2D
var _float_tween: Tween
var _aura_tween: Tween
var _ray_tween: Tween


# ---------------------------------------------------------
# SETUP
# ---------------------------------------------------------

func setup(res: Dictionary, effect_tier: int, card_size: Vector2) -> void:
	_load_shared()
	result = res
	tier = effect_tier
	level = clampi(Realms.tier_index(effect_tier), 0, TIER_COLORS.size() - 1)
	_color = TIER_COLORS[level]
	data = PartnerDatabase.get_partner(res.get("partner_id", ""))

	size = card_size
	pivot_offset = card_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


static func tier_color(effect_tier: int) -> Color:
	return TIER_COLORS[clampi(Realms.tier_index(effect_tier), 0, TIER_COLORS.size() - 1)]


static func tier_name(effect_tier: int) -> String:
	return TIER_NAMES[clampi(Realms.tier_index(effect_tier), 0, TIER_NAMES.size() - 1)]


## Finds PartnerPanel in the current scene and uses its tier frames.
static func find_frames(from: Node) -> void:
	if not tier_frames.is_empty():
		return
	var scene := from.get_tree().current_scene
	if scene == null:
		return
	var panel := scene.find_child("PartnerPanel", true, false)
	if panel != null and "card_tier_frames" in panel:
		tier_frames = panel.get("card_tier_frames")
	if tier_frames.is_empty():
		push_warning("SummonCard: no tier frames found on PartnerPanel, using drawn frames")


static func frame_for(effect_tier: int) -> Texture2D:
	var i := clampi(Realms.tier_index(effect_tier), 0, TIER_COLORS.size() - 1)
	if i < tier_frames.size():
		return tier_frames[i]
	return null


## Traces the frame's see-through centre by filling outward from the
## middle. Gives the exact inside shape (as a mask) and its bounding box.
## Falls back to a plain inset if the frame can't be traced.
static func frame_opening(frame: Texture2D) -> Rect2:
	if not _openings.has(frame):
		_trace_frame(frame)
	return _openings[frame]


static func frame_mask(frame: Texture2D) -> Texture2D:
	if not _openings.has(frame):
		_trace_frame(frame)
	return _masks.get(frame)


static func _trace_frame(frame: Texture2D) -> void:
	var fallback := Rect2(ART_INSET, ART_INSET * 0.75, 1.0 - ART_INSET * 2.0, 1.0 - ART_INSET * 1.5)
	_openings[frame] = fallback
	_masks[frame] = null

	var img := frame.get_image()
	if img == null or img.is_empty():
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)

	# Work on a small copy: fast, and plenty precise for a mask
	var max_w := 220
	if img.get_width() > max_w:
		var shrink := float(max_w) / img.get_width()
		img.resize(max_w, maxi(1, int(img.get_height() * shrink)), Image.INTERPOLATE_BILINEAR)

	var w := img.get_width()
	var h := img.get_height()
	var src := img.get_data()
	var inside := PackedByteArray()
	inside.resize(w * h)

	var start := int(h * 0.5) * w + int(w * 0.5)
	if src[start * 4 + 3] >= 128:
		push_warning("SummonCard: frame centre isn't see-through, using a plain inset")
		return

	var queue := PackedInt32Array([start])
	inside[start] = 255
	var head := 0
	var min_x := w
	var max_x := 0
	var min_y := h
	var max_y := 0

	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		@warning_ignore("integer_division")
		var y := i / w

		# Reaching the image edge means the border has a gap: give up
		if x == 0 or y == 0 or x == w - 1 or y == h - 1:
			push_warning("SummonCard: frame border has a gap, using a plain inset")
			return

		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)

		for n in [i - 1, i + 1, i - w, i + w]:
			if inside[n] == 0 and src[n * 4 + 3] < 128:
				inside[n] = 255
				queue.append(n)

	var mask_img := Image.create_from_data(w, h, false, Image.FORMAT_L8, inside)
	_masks[frame] = ImageTexture.create_from_image(mask_img)
	_openings[frame] = Rect2(
		float(min_x) / w, float(min_y) / h,
		float(max_x - min_x + 1) / w, float(max_y - min_y + 1) / h)


## Card size for a given width, matching your frames' proportions.
static func size_for_width(width: float) -> Vector2:
	var frame := frame_for(Enums.Rarity.WHITE)
	if frame != null and frame.get_width() > 0:
		return Vector2(width, width * frame.get_height() / float(frame.get_width()))
	return Vector2(width, width * 4.0 / 3.0)


static func _load_shared() -> void:
	if _additive != null:
		return
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_glow_tex = _radial(256)
	_dot_tex = _radial(32)

	_shine_shader = Shader.new()
	_shine_shader.code = SHINE_SHADER

	var g := Gradient.new()
	g.set_color(0, BACK_TOP)
	g.set_color(1, BACK_BOTTOM)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 128
	_back_gradient = gt

	var lg := Gradient.new()
	lg.set_color(0, BACK_LOGO_TOP)
	lg.set_color(1, BACK_LOGO_BOTTOM)
	var lgt := GradientTexture2D.new()
	lgt.gradient = lg
	lgt.fill = GradientTexture2D.FILL_RADIAL
	lgt.fill_from = Vector2(0.5, 0.45)
	lgt.fill_to = Vector2(1.1, 0.45)
	lgt.width = 128
	lgt.height = 128
	_logo_back_gradient = lgt

	_logo_shader = Shader.new()
	_logo_shader.code = LOGO_SHADER


static func _get_logo() -> Texture2D:
	if not _logo_loaded:
		_logo_loaded = true
		if BACK_LOGO_PATH != "" and ResourceLoader.exists(BACK_LOGO_PATH):
			_logo = load(BACK_LOGO_PATH)
	return _logo


static func _radial(px: int) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _build() -> void:
	var s := size

	# Aura (behind everything)
	_aura = TextureRect.new()
	_aura.texture = _glow_tex
	_aura.material = _additive
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aura.stretch_mode = TextureRect.STRETCH_SCALE
	_aura.size = Vector2(s.x * 2.3, s.y * 1.9)
	_aura.position = s * 0.5 - _aura.size * 0.5
	_aura.pivot_offset = _aura.size * 0.5
	_aura.modulate = Color(_color, 0.0)
	add_child(_aura)

	# Light rays (Red and above)
	_rays = Control.new()
	_rays.material = _additive
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.position = s * 0.5
	_rays.visible = false
	_rays.modulate = Color(_color, 0.0)
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

	# Sparkles (Green and above)
	_sparkles = CPUParticles2D.new()
	_sparkles.texture = _dot_tex
	_sparkles.material = _additive
	_sparkles.position = s * 0.5
	_sparkles.emitting = false
	_sparkles.lifetime = 1.4
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparkles.emission_rect_extents = s * 0.55
	_sparkles.direction = Vector2(0, -1)
	_sparkles.spread = 40.0
	_sparkles.gravity = Vector2(0, -30)
	_sparkles.initial_velocity_min = 10.0
	_sparkles.initial_velocity_max = 50.0
	_sparkles.scale_amount_min = 0.15 * s.x / 420.0 + 0.1
	_sparkles.scale_amount_max = 0.45 * s.x / 420.0 + 0.2
	_sparkles.color = _color.lightened(0.3)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.6, Color(1, 1, 1, 0.7))
	_sparkles.color_ramp = ramp
	add_child(_sparkles)

	# Card back
	_back = Control.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.size = s
	add_child(_back)
	_build_back(s)

	# Card front
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.size = s
	_front.clip_contents = true
	_front.visible = false
	add_child(_front)

	var bg := ColorRect.new()
	bg.color = BACK_BOTTOM
	bg.size = s
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.add_child(bg)

	var frame_tex := frame_for(tier)
	var art_rect := Rect2(Vector2.ZERO, s)
	var mask: Texture2D = null
	if frame_tex != null:
		var o := frame_opening(frame_tex)
		mask = frame_mask(frame_tex)
		var pad := ART_OVERLAP
		art_rect = Rect2(
			(o.position.x - pad) * s.x, (o.position.y - pad) * s.y,
			(o.size.x + pad * 2.0) * s.x, (o.size.y + pad * 2.0) * s.y)

	_art = TextureRect.new()
	_art.texture = data.card_texture if data != null else null
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.position = art_rect.position
	_art.size = art_rect.size
	_shine_mat = ShaderMaterial.new()
	_shine_mat.shader = _shine_shader
	_shine_mat.set_shader_parameter("rect_size", _art.size)
	if mask != null:
		_shine_mat.set_shader_parameter("use_mask", true)
		_shine_mat.set_shader_parameter("frame_mask", mask)
		_shine_mat.set_shader_parameter("art_offset", _art.position)
		_shine_mat.set_shader_parameter("card_size", s)
		_shine_mat.set_shader_parameter("spread", ART_SPREAD)
	else:
		_shine_mat.set_shader_parameter("chamfer", ART_CHAMFER if frame_tex != null else 0.0)
	_art.material = _shine_mat
	_front.add_child(_art)

	if frame_tex != null:
		# Your tier frame over the art
		bg.color = Color(0, 0, 0, 0)
		var frame_rect := TextureRect.new()
		frame_rect.texture = frame_tex
		frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
		frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_rect.size = s
		_front.add_child(frame_rect)
	else:
		var frame := Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.size = s
		frame.draw.connect(_draw_front_frame.bind(frame))
		_front.add_child(frame)


## Back: dark lacquer, soft glow, your logo, and the White frame.
## Falls back to the drawn star emblem if the logo or frame is missing.
func _build_back(s: Vector2) -> void:
	var frame_tex := frame_for(Enums.Rarity.WHITE)
	var logo := _get_logo()

	if frame_tex == null:
		_back.draw.connect(_draw_back)
		if logo != null:
			_add_logo(s, Rect2(Vector2.ZERO, s))
		return

	var o := frame_opening(frame_tex)
	var mask := frame_mask(frame_tex)
	var inner := Rect2(o.position * s, o.size * s).grow(s.x * ART_OVERLAP)

	# Background cut to the frame's inside
	var bg := TextureRect.new()
	bg.texture = _logo_back_gradient if logo != null else _back_gradient
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = inner.position
	bg.size = inner.size
	var mat := ShaderMaterial.new()
	mat.shader = _shine_shader
	mat.set_shader_parameter("rect_size", inner.size)
	if mask != null:
		mat.set_shader_parameter("use_mask", true)
		mat.set_shader_parameter("frame_mask", mask)
		mat.set_shader_parameter("art_offset", inner.position)
		mat.set_shader_parameter("card_size", s)
		mat.set_shader_parameter("spread", ART_SPREAD)
	else:
		mat.set_shader_parameter("chamfer", ART_CHAMFER)
	bg.material = mat
	_back.add_child(bg)

	# Faint rings and a glow behind the logo
	var deco := Control.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.size = s
	deco.draw.connect(func():
		var c := s * 0.5
		var r := s.x * 0.36
		deco.draw_arc(c, r, 0.0, TAU, 72, Color(GOLD, 0.25), 1.5, true)
		deco.draw_arc(c, r * 0.86, 0.0, TAU, 72, Color(GOLD, 0.12), 1.0, true)
		for i in 24:
			var ang := TAU * i / 24.0
			var d := Vector2(cos(ang), sin(ang))
			deco.draw_line(c + d * r * 1.02, c + d * r * (1.08 if i % 2 == 0 else 1.05), Color(GOLD, 0.3), 1.2, true)
		# Faint star specks (same pattern on every card)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 26:
			var p := Vector2(rng.randf_range(0.15, 0.85) * s.x, rng.randf_range(0.12, 0.88) * s.y)
			if p.distance_to(c) < r * 1.1:
				continue
			deco.draw_circle(p, rng.randf_range(0.6, 1.6) * s.x / 420.0 + 0.4, Color(1, 1, 1, rng.randf_range(0.15, 0.45)))
	)
	_back.add_child(deco)

	var glow := TextureRect.new()
	glow.texture = _glow_tex
	glow.material = _additive
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2(s.x, s.x) * 0.95
	glow.position = s * 0.5 - glow.size * 0.5
	glow.modulate = BACK_LOGO_GLOW if logo != null else Color(0.45, 0.6, 1.0, 0.35)
	_back.add_child(glow)

	if logo != null:
		_add_logo(s, inner)
	else:
		# No logo: small drawn emblem instead
		var emblem := Control.new()
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.size = s
		emblem.draw.connect(func():
			var c := s * 0.5
			var r := s.x * 0.22
			var star := PackedVector2Array()
			for i in 16:
				var ang := TAU * i / 16.0 - PI * 0.5
				star.append(c + Vector2(cos(ang), sin(ang)) * r * (0.92 if i % 2 == 0 else 0.36))
			emblem.draw_colored_polygon(star, Color(GOLD, 0.9))
		)
		_back.add_child(emblem)

	var frame_rect := TextureRect.new()
	frame_rect.texture = frame_tex
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_rect.size = s
	_back.add_child(frame_rect)


func _add_logo(s: Vector2, area: Rect2) -> void:
	var logo := TextureRect.new()
	logo.texture = _get_logo()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := minf(s.x * BACK_LOGO_WIDTH, area.size.x * 0.95)
	logo.size = Vector2(w, w)
	var mat := ShaderMaterial.new()
	mat.shader = _logo_shader
	logo.material = mat
	logo.position = s * 0.5 - logo.size * 0.5
	_back.add_child(logo)


# ---------------------------------------------------------
# DRAWING
# ---------------------------------------------------------

## Tarot-style back: gradient, double gold border, star and moon emblem.
func _draw_back() -> void:
	var c := _back
	var s := c.size
	var r := Rect2(Vector2.ZERO, s)
	c.draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([BACK_TOP, BACK_TOP, BACK_BOTTOM, BACK_BOTTOM]))

	var lw := maxf(2.0, s.x * 0.012)
	var m := s.x * 0.06
	c.draw_rect(r.grow(-lw * 0.5), GOLD, false, lw)
	c.draw_rect(r.grow(-m), Color(GOLD, 0.5), false, maxf(1.0, lw * 0.5))

	var center := s * 0.5
	var radius := s.x * 0.28
	c.draw_arc(center, radius, 0.0, TAU, 64, Color(GOLD, 0.85), lw * 0.8, true)
	c.draw_arc(center, radius * 0.74, 0.0, TAU, 64, Color(GOLD, 0.4), lw * 0.5, true)

	# Eight-point star
	var star := PackedVector2Array()
	for i in 16:
		var ang := TAU * i / 16.0 - PI * 0.5
		var rr := radius * (0.92 if i % 2 == 0 else 0.36)
		star.append(center + Vector2(cos(ang), sin(ang)) * rr)
	c.draw_colored_polygon(star, Color(GOLD, 0.9))
	c.draw_circle(center, radius * 0.18, BACK_TOP)
	c.draw_circle(center, radius * 0.09, GOLD)

	# Crescent moon above, ornament lines top and bottom
	var moon := Vector2(center.x, s.y * 0.2)
	c.draw_circle(moon, radius * 0.18, Color(GOLD, 0.8))
	c.draw_circle(moon + Vector2(radius * 0.07, -radius * 0.03), radius * 0.15, BACK_TOP)
	for side in [-1.0, 1.0]:
		var y: float = center.y + side * s.y * 0.36
		c.draw_line(Vector2(m * 2.0, y), Vector2(s.x - m * 2.0, y), Color(GOLD, 0.4), maxf(1.0, lw * 0.5))
		_diamond(c, Vector2(center.x, y), radius * 0.12, GOLD)

	# Corner diamonds
	for corner in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
		_diamond(c, corner, radius * 0.08, GOLD)


func _draw_front_frame(c: Control) -> void:
	var s := c.size
	var r := Rect2(Vector2.ZERO, s)
	var lw := maxf(1.5, s.x * 0.008)

	# Soft dark fade at the bottom
	c.draw_polygon(
		PackedVector2Array([Vector2(0, s.y * 0.78), Vector2(s.x, s.y * 0.78), s, Vector2(0, s.y)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45)]))

	# Slim gold outer frame
	c.draw_rect(r.grow(-lw * 0.5), GOLD, false, lw)
	# Thin tier-coloured line just inside
	var m := s.x * 0.035
	c.draw_rect(r.grow(-m), Color(_color, 0.85), false, maxf(1.0, lw * 0.6))
	# Faint second gold hairline
	c.draw_rect(r.grow(-m - lw * 2.5), Color(GOLD, 0.35), false, 1.0)

	# Corner brackets instead of a heavy border
	var arm := s.x * 0.09
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(corner.x * s.x, corner.y * s.y)
		var dx := arm * (1.0 if corner.x == 0 else -1.0)
		var dy := arm * (1.0 if corner.y == 0 else -1.0)
		var inset := Vector2(m if corner.x == 0 else -m, m if corner.y == 0 else -m) * 0.5
		c.draw_polyline(PackedVector2Array([p + inset + Vector2(dx, 0), p + inset, p + inset + Vector2(0, dy)]),
			GOLD, lw * 1.6, true)

	# Small gem at the top centre in the tier colour
	_diamond(c, Vector2(s.x * 0.5, m), s.x * 0.022, _color.lightened(0.25))


## Soft light rays that fade out along their length.
func _draw_rays() -> void:
	var count := 10
	for i in count:
		var ang := TAU * i / count
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var length := size.y * (0.85 if i % 2 == 0 else 0.6)
		var base := size.x * 0.25
		var width := size.x * (0.05 if i % 2 == 0 else 0.03)
		var near := Color(1, 1, 1, 0.35)
		var far := Color(1, 1, 1, 0.0)
		_rays.draw_polygon(
			PackedVector2Array([
				dir * base + side * width,
				dir * length,
				dir * base - side * width,
			]),
			PackedColorArray([near, far, near]))


static func _diamond(c: CanvasItem, p: Vector2, r: float, color: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)
	]), color)


# ---------------------------------------------------------
# ANIMATION
# ---------------------------------------------------------

func start_float() -> void:
	stop_float()
	var y := position.y
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(self, "position:y", y - 10.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position:y", y + 10.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_float() -> void:
	if _float_tween != null:
		_float_tween.kill()
		_float_tween = null


## Build-up before a rare card flips: the aura swells and the card trembles.
func anticipate(duration: float) -> void:
	var t := create_tween().set_parallel(true)
	_aura.scale = Vector2(0.5, 0.5)
	t.tween_property(_aura, "modulate:a", 0.9, duration).set_ease(Tween.EASE_IN)
	t.tween_property(_aura, "scale", Vector2(1.25, 1.25), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var shake := create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var strength := 0.01 + 0.04 * float(i) / steps * (1.5 if level >= 4 else 1.0)
		shake.tween_property(self, "rotation", randf_range(-strength, strength), 0.05)
	shake.tween_property(self, "rotation", 0.0, 0.05)

	await shake.finished


func flip(duration := 0.4) -> void:
	var t := create_tween()
	t.tween_property(self, "scale:x", 0.0, duration * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	show_front()
	var t2 := create_tween()
	t2.tween_property(self, "scale:x", base_scale.x, duration * 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t2.finished


func show_front() -> void:
	revealed = true
	_back.visible = false
	_front.visible = true


## Effects by tier. strong = the big stage card, otherwise the arc.
func play_fx(strong: bool) -> void:
	# Aura: everyone gets a soft glow, rarer = brighter and pulsing
	if _aura_tween != null:
		_aura_tween.kill()
	var alpha := (0.2 + level * 0.09) * (1.0 if strong else 0.5)
	_aura.scale = Vector2.ONE
	_aura_tween = create_tween()
	_aura_tween.tween_property(_aura, "modulate:a", alpha, 0.3)
	if level >= 3:
		# Pulse (the first step only matters on the first loop)
		_aura_tween.set_loops()
		_aura_tween.tween_property(_aura, "modulate:a", alpha * 0.55, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_aura_tween.tween_property(_aura, "modulate:a", alpha, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Sparkles from Green up
	if level >= 2:
		_sparkles.amount = (10 + level * 8) if strong else (4 + level * 2)
		_sparkles.emitting = true

	# Rays from Red up, big card only
	if level >= 4 and strong:
		_rays.visible = true
		var rt := create_tween()
		rt.tween_property(_rays, "modulate:a", 0.7, 0.6)
		_ray_tween = create_tween().set_loops()
		_ray_tween.tween_property(_rays, "rotation", TAU, 30.0).from(0.0)

	# Shine sweep from Purple up
	if level >= 3:
		var st := create_tween()
		st.tween_method(func(v: float): _shine_mat.set_shader_parameter("shine", v), -0.3, 1.8, 0.8)
	elif strong:
		var st := create_tween()
		st.tween_method(func(v: float): _shine_mat.set_shader_parameter("shine", v), -0.3, 1.8, 0.6)


func stop_fx() -> void:
	for tw in [_aura_tween, _ray_tween]:
		if tw != null:
			tw.kill()
	_aura_tween = null
	_ray_tween = null
	_sparkles.emitting = false
	_rays.visible = false
	_aura.modulate.a = 0.0
