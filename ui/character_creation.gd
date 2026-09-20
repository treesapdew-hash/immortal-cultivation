extends Control

# =========================================================
# Character creation: name, gender and Dao for the MC.
#
# Setup: a scene with a single Control root + this script,
# added as a child of HomeScreen. It removes itself if the MC
# was already created.
#
# Everything is built in code and drawn on its own top layer,
# so battle effects never show through. Fonts and images in
# the "Look" group are optional.
# =========================================================

signal finished

## Testing: show the screen even if the MC was already created.
@export var always_show := false

## Pause the idle battle while this screen is open.
@export var pause_game := true

@export_group("Look")
@export var background: Texture2D       # optional, blended under the effects
@export var card_frame: Texture2D       # optional frame drawn over the card
@export var title_font: Font
@export var body_font: Font

const CARD_SIZE := Vector2(510, 680)

const GENDERS := ["male", "female"]
const DAO_ORDER := [
	Enums.Path.DIVINE,
	Enums.Path.SPIRIT,
	Enums.Path.MYSTIC,
	Enums.Path.SWORD,
	Enums.Path.MARTIAL,
]


const COL_BG        := Color("050b18")
const COL_PANEL     := Color("0e1c34")
const COL_DIM       := Color("2a4262")
const COL_TEXT      := Color("e8eef7")
const COL_TEXT_DIM  := Color("8a9bb4")
const COL_GOLD      := Color("e0b85a")
const COL_GOLD_TEXT := Color("ffe6a8")
const COL_ERROR     := Color("ff7a7a")


# ---------------------------------------------------------
# SHADERS
# ---------------------------------------------------------

## Deep gradient, drifting mist, a glow behind the card, vignette.
const BG_SHADER := """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.02, 0.04, 0.09, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.03, 0.10, 0.18, 1.0);
uniform vec4 glow_color : source_color = vec4(0.5, 0.83, 1.0, 1.0);
uniform vec2 glow_center = vec2(0.5, 0.33);
uniform float aspect = 1.78;
uniform float opacity = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);

	float mist = fbm(vec2(uv.x * 3.0 + TIME * 0.03, uv.y * 5.0 * aspect * 0.3 - TIME * 0.05));
	col += glow_color.rgb * smoothstep(0.45, 0.9, mist) * 0.10;

	float d = distance(vec2(uv.x, uv.y * aspect), vec2(glow_center.x, glow_center.y * aspect));
	col += glow_color.rgb * 0.30 * exp(-d * d * 7.0);

	float v = smoothstep(1.05, 0.35, distance(uv, vec2(0.5)));
	col *= mix(0.5, 1.0, v);

	COLOR = vec4(col, opacity);
}
"""

## Soft pulsing halo with slow rays, drawn behind the card.
const AURA_SHADER := """
shader_type canvas_item;
render_mode blend_add;

uniform vec4 color : source_color = vec4(0.5, 0.83, 1.0, 1.0);
uniform float intensity = 0.9;

void fragment() {
	vec2 p = UV - 0.5;
	p.y *= 1.25;
	float d = length(p) * 2.0;
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
	float glow = smoothstep(1.0, 0.15, d);
	float ang = atan(p.y, p.x);
	float rays = 0.5 + 0.5 * sin(ang * 14.0 + TIME * 0.5);
	float a = glow * glow * intensity * pulse * mix(0.7, 1.0, rays);
	COLOR = vec4(color.rgb * a, a);
}
"""

## Diagonal shine that sweeps across the card when it changes.
const SHINE_SHADER := """
shader_type canvas_item;

uniform float shine = -1.0;
uniform float width = 0.12;

void fragment() {
	float x = UV.x + UV.y * 0.5;
	float s = 1.0 - smoothstep(0.0, width, abs(x - shine));
	COLOR.rgb += s * 0.4 * COLOR.a;
}
"""


# ---------------------------------------------------------
# STATE
# ---------------------------------------------------------

var _gender := "male"
var _path: Enums.Path = Enums.Path.SWORD
var _accent := Color.WHITE
var _cards := {}                  # "male_sword" -> Texture2D
var _paused_game := false
var _done := false

var _layer: CanvasLayer
var _root: Control
var _col: VBoxContainer

var _bg_mat: ShaderMaterial
var _aura_mat: ShaderMaterial
var _card_mat: ShaderMaterial
var _particles: CPUParticles2D

var _card_box: Control
var _card_inner: Control
var _card_art: TextureRect
var _card_glow: StyleBoxFlat
var _card_border: StyleBoxFlat
var _card_name: Label
var _card_path: Label
var _corner_marks: Array[Label] = []
var _badge: TextureRect

var _gender_buttons: Array[Button] = []
var _gender_on: StyleBoxFlat
var _dao_buttons := {}            # Enums.Path -> Button

var _info_box: StyleBoxFlat
var _info_name: Label
var _chip_row: HBoxContainer
var _chip_boxes: Array[StyleBoxFlat] = []

var _name_edit: LineEdit
var _name_focus: StyleBoxFlat
var _hint_label: Label
var _confirm_button: Button
var _gold_glow: StyleBoxFlat

var _overlay: Control
var _overlay_panel: PanelContainer
var _overlay_thumb: TextureRect
var _overlay_text: Label

var _card_tween: Tween
var _accent_tween: Tween


# ---------------------------------------------------------
# START
# ---------------------------------------------------------

func _ready() -> void:
	if GameState.mc_created and not always_show:
		queue_free()
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	if pause_game:
		get_tree().paused = true
		_paused_game = true

	_gender = GameState.mc_gender if GameState.mc_gender in GENDERS else "male"
	_path = GameState.mc_path
	_accent = _dao_color(_path)

	_load_cards()

	# Own top layer: nothing from the battle can draw over this.
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)

	_root = Control.new()
	_fill(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	if body_font != null:
		th.default_font = body_font
	th.default_font_size = 32
	_root.theme = th
	_layer.add_child(_root)

	_build_background()
	_build_particles()
	_build_content()
	_build_overlay()

	_refresh_dao_info()
	_update_preview(false)
	_update_dao_buttons(true)
	_apply_accent(_accent)
	_on_name_changed("")
	_intro()


func _exit_tree() -> void:
	if _paused_game:
		get_tree().paused = false


# ---------------------------------------------------------
# ART
# ---------------------------------------------------------

func _combo(gender: String, path: int) -> String:
	return "%s_%s" % [gender, str(Enums.Path.keys()[path]).to_lower()]


func _dao_color(path: int) -> Color:
	return Enums.PATH_COLORS.get(path, Color("7fd4ff"))


## Loads all 10 cards up front so switching is instant.
func _load_cards() -> void:
	for g in GENDERS:
		for p in DAO_ORDER:
			var combo := _combo(g, p)
			var folder: String = GameState.MC_ART_FOLDER + combo + "/"
			for file in [combo + "_card.png", "card.png"]:
				if ResourceLoader.exists(folder + file):
					_cards[combo] = load(folder + file)
					break


# ---------------------------------------------------------
# BUILD: BACKGROUND AND PARTICLES
# ---------------------------------------------------------

func _build_background() -> void:
	var base := ColorRect.new()
	base.color = COL_BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(base)
	_root.add_child(base)

	if background != null:
		var image := TextureRect.new()
		image.texture = background
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill(image)
		_root.add_child(image)

	var fx := ColorRect.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(fx)
	_bg_mat = _material(BG_SHADER)
	_bg_mat.set_shader_parameter("opacity", 0.75 if background != null else 1.0)
	fx.material = _bg_mat
	_root.add_child(fx)


## Slow glowing motes drifting up the whole screen.
func _build_particles() -> void:
	var vp := get_viewport().get_visible_rect().size

	_particles = CPUParticles2D.new()
	_particles.amount = 50
	_particles.lifetime = 6.0
	_particles.preprocess = 6.0
	_particles.position = vp * 0.5
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = vp * 0.5
	_particles.direction = Vector2(0, -1)
	_particles.spread = 20.0
	_particles.gravity = Vector2(0, -6)
	_particles.initial_velocity_min = 20.0
	_particles.initial_velocity_max = 70.0
	_particles.scale_amount_min = 0.12
	_particles.scale_amount_max = 0.45
	_particles.texture = _soft_dot()

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.9))
	ramp.add_point(0.7, Color(1, 1, 1, 0.5))
	_particles.color_ramp = ramp

	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_particles.material = add

	_root.add_child(_particles)


# ---------------------------------------------------------
# BUILD: MAIN CONTENT
# ---------------------------------------------------------

func _build_content() -> void:
	var margin := MarginContainer.new()
	_fill(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	_root.add_child(margin)

	_col = VBoxContainer.new()
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_theme_constant_override("separation", 22)
	margin.add_child(_col)

	_build_title()
	_build_card()
	_build_gender()
	_col.add_child(_header("Choose Your Dao"))
	_build_dao_row()
	_build_dao_info()
	_build_name()
	_build_confirm_button()


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_col.add_child(box)

	box.add_child(_label("THE PATH TO IMMORTALITY BEGINS", 24, COL_TEXT_DIM))

	var title := Label.new()
	title.text = "Create Your Cultivator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	if title_font != null:
		ls.font = title_font
	elif body_font != null:
		ls.font = body_font
	ls.font_size = 66
	ls.font_color = COL_GOLD_TEXT
	ls.outline_size = 8
	ls.outline_color = Color("2a1a05")
	ls.shadow_size = 16
	ls.shadow_color = Color(COL_GOLD, 0.45)
	ls.shadow_offset = Vector2.ZERO
	title.label_settings = ls
	box.add_child(title)


func _build_card() -> void:
	_card_box = Control.new()
	_card_box.custom_minimum_size = CARD_SIZE
	_card_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_card_box)

	# Halo, bigger than the card
	var aura := ColorRect.new()
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.position = Vector2(-170, -150)
	aura.size = CARD_SIZE + Vector2(340, 300)
	_aura_mat = _material(AURA_SHADER)
	aura.material = _aura_mat
	_card_box.add_child(aura)

	# Everything that floats and pops together
	_card_inner = Control.new()
	_card_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(_card_inner)
	_card_inner.pivot_offset = CARD_SIZE * 0.5
	_card_box.add_child(_card_inner)

	# Glow plate behind the art
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(plate)
	_card_glow = StyleBoxFlat.new()
	_card_glow.bg_color = COL_BG
	_card_glow.set_corner_radius_all(6)
	_card_glow.shadow_size = 40
	plate.add_theme_stylebox_override("panel", _card_glow)
	_card_inner.add_child(plate)

	# Art
	_card_art = TextureRect.new()
	_card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fill(_card_art)
	_card_mat = _material(SHINE_SHADER)
	_card_art.material = _card_mat
	_card_inner.add_child(_card_art)

	# Dark fade at the bottom so the name is readable
	var shade_grad := Gradient.new()
	shade_grad.set_color(0, Color(0, 0, 0, 0))
	shade_grad.set_color(1, Color(0.01, 0.03, 0.08, 0.92))
	var shade_tex := GradientTexture2D.new()
	shade_tex.gradient = shade_grad
	shade_tex.fill_from = Vector2(0, 0)
	shade_tex.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = shade_tex
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.6
	shade.anchor_bottom = 1.0
	_card_inner.add_child(shade)

	_card_name = _card_label(46, COL_TEXT, -128, -66)
	_card_path = _card_label(28, COL_GOLD, -66, -26)

	# Frame
	if card_frame != null:
		var frame := TextureRect.new()
		frame.texture = card_frame
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		_fill(frame)
		_card_inner.add_child(frame)
	else:
		var border := Panel.new()
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill(border)
		_card_border = StyleBoxFlat.new()
		_card_border.draw_center = false
		_card_border.set_border_width_all(3)
		_card_border.set_corner_radius_all(6)
		border.add_theme_stylebox_override("panel", _card_border)
		_card_inner.add_child(border)

		var inner := Panel.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill(inner)
		inner.offset_left = 12
		inner.offset_top = 12
		inner.offset_right = -12
		inner.offset_bottom = -12
		var hairline := StyleBoxFlat.new()
		hairline.draw_center = false
		hairline.set_border_width_all(1)
		hairline.border_color = Color(COL_GOLD, 0.45)
		inner.add_theme_stylebox_override("panel", hairline)
		_card_inner.add_child(inner)

		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var mark := Label.new()
			mark.text = "◆"
			mark.size = Vector2(44, 44)
			mark.position = corner * CARD_SIZE - Vector2(22, 22)
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mark.add_theme_font_size_override("font_size", 30)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_card_inner.add_child(mark)
			_corner_marks.append(mark)

	# Dao badge
	_badge = TextureRect.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.position = Vector2(-30, -30)
	_badge.size = Vector2(130, 130)
	_card_inner.add_child(_badge)


## Centered label pinned to the bottom of the card.
func _card_label(font_size: int, color: Color, top: float, bottom: float) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = top
	l.offset_bottom = bottom
	var ls := LabelSettings.new()
	if body_font != null:
		ls.font = body_font
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = ls
	_card_inner.add_child(l)
	return l


func _build_gender() -> void:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pill_box := _box(Color(COL_PANEL, 0.9), COL_DIM, 2, 44)
	pill_box.set_content_margin_all(6)
	pill.add_theme_stylebox_override("panel", pill_box)
	_col.add_child(pill)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)

	_gender_on = _box(COL_PANEL, Color.WHITE, 2, 38)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0)
	off.set_corner_radius_all(38)
	off.set_content_margin_all(12)

	var group := ButtonGroup.new()
	for g in GENDERS:
		var b := Button.new()
		b.text = g.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(230, 72)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", off)
		b.add_theme_stylebox_override("pressed", _gender_on)
		b.add_theme_stylebox_override("hover_pressed", _gender_on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", COL_TEXT_DIM)
		b.add_theme_color_override("font_hover_color", COL_TEXT)
		b.button_pressed = g == _gender
		b.pressed.connect(_on_gender_pressed.bind(g))
		row.add_child(b)
		_gender_buttons.append(b)


func _build_dao_row() -> void:
	var row := _row(12)
	_col.add_child(row)

	var group := ButtonGroup.new()
	var off := _box(Color(COL_PANEL, 0.9), COL_DIM, 2, 16)

	for p in DAO_ORDER:
		var c := _dao_color(p)
		var on := _box(c.darkened(0.8), c, 3, 16)
		on.shadow_color = Color(c, 0.5)
		on.shadow_size = 16

		var b := Button.new()
		b.text = str(Enums.PATH_NAMES[p]).trim_suffix(" Path")
		b.icon = DaoIcons.get_icon(p)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(172, 176)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_constant_override("icon_max_width", 96)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", off)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", COL_TEXT_DIM)
		b.add_theme_color_override("font_hover_color", COL_TEXT)
		b.add_theme_color_override("font_pressed_color", c)
		b.add_theme_color_override("font_hover_pressed_color", c)
		b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.45))
		b.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 0.7))
		b.add_theme_color_override("icon_pressed_color", Color.WHITE)
		b.add_theme_color_override("icon_hover_pressed_color", Color.WHITE)
		b.button_pressed = p == _path
		b.pressed.connect(_on_dao_pressed.bind(p))
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
		row.add_child(b)
		_dao_buttons[p] = b


func _build_dao_info() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info_box = _box(Color(COL_PANEL, 0.85), Color.WHITE, 2, 14)
	_info_box.set_content_margin_all(16)
	_info_box.shadow_size = 12
	panel.add_theme_stylebox_override("panel", _info_box)
	_col.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	_info_name = _label("", 36, Color.WHITE)
	v.add_child(_info_name)

	_chip_row = _row(12)
	v.add_child(_chip_row)

	v.add_child(_label("Gender and Dao can't be changed later.", 22, COL_TEXT_DIM))


func _refresh_dao_info() -> void:
	_info_name.text = Enums.PATH_NAMES[_path]

	for chip in _chip_row.get_children():
		_chip_row.remove_child(chip)
		chip.queue_free()
	_chip_boxes.clear()

	for bonus in str(Enums.PATH_DESCRIPTIONS[_path]).split(", "):
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(20)
		sb.set_border_width_all(1)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		_color_chip(sb, _accent)

		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", sb)
		chip.add_child(_label("+ " + bonus, 26, COL_TEXT))
		_chip_row.add_child(chip)
		_chip_boxes.append(sb)


func _build_name() -> void:
	var row := _row(12)
	_col.add_child(row)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(COL_PANEL, 0.9)
	normal.border_width_bottom = 3
	normal.border_color = COL_DIM
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)

	_name_focus = StyleBoxFlat.new()
	_name_focus.draw_center = false
	_name_focus.border_width_bottom = 3
	_name_focus.set_corner_radius_all(12)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Enter your name"
	_name_edit.max_length = GameState.MC_NAME_MAX
	_name_edit.custom_minimum_size = Vector2(580, 92)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 38)
	_name_edit.add_theme_stylebox_override("normal", normal)
	_name_edit.add_theme_stylebox_override("focus", _name_focus)
	_name_edit.add_theme_color_override("font_color", COL_TEXT)
	_name_edit.add_theme_color_override("font_placeholder_color", COL_TEXT_DIM)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_t): _on_confirm_pressed())
	row.add_child(_name_edit)

	var random_button := Button.new()
	random_button.text = "Random"
	random_button.custom_minimum_size = Vector2(180, 92)
	_style_plain(random_button)
	random_button.pressed.connect(_on_random_pressed)
	row.add_child(random_button)

	_hint_label = _label("", 24, COL_ERROR)
	_hint_label.custom_minimum_size.y = 30
	_col.add_child(_hint_label)


func _build_confirm_button() -> void:
	_confirm_button = Button.new()
	_confirm_button.text = "Begin Cultivation"
	_confirm_button.custom_minimum_size = Vector2(600, 116)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gold_glow = _style_gold(_confirm_button)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_col.add_child(_confirm_button)


## Section title with gold lines fading out on both sides.
func _header(text: String) -> HBoxContainer:
	var row := _row(16)
	row.add_child(_fade_line(true))
	row.add_child(_label("◆   " + text + "   ◆", 30, COL_GOLD))
	row.add_child(_fade_line(false))
	return row


func _fade_line(solid_on_right: bool) -> TextureRect:
	var solid := Color(COL_GOLD, 0.8)
	var clear := Color(COL_GOLD, 0.0)
	var g := Gradient.new()
	g.set_color(0, clear if solid_on_right else solid)
	g.set_color(1, solid if solid_on_right else clear)

	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 160
	tex.height = 2

	var line := TextureRect.new()
	line.texture = tex
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(160, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


# ---------------------------------------------------------
# BUILD: CONFIRM POPUP
# ---------------------------------------------------------

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.7)
	_overlay.visible = false
	_fill(_overlay)
	_root.add_child(_overlay)

	var center := CenterContainer.new()
	_fill(center)
	_overlay.add_child(center)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.custom_minimum_size = Vector2(880, 0)
	var sb := _box(COL_PANEL, COL_GOLD, 3, 18)
	sb.set_content_margin_all(36)
	sb.shadow_color = Color(COL_GOLD, 0.3)
	sb.shadow_size = 24
	_overlay_panel.add_theme_stylebox_override("panel", sb)
	_overlay_panel.resized.connect(func(): _overlay_panel.pivot_offset = _overlay_panel.size * 0.5)
	center.add_child(_overlay_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 30)
	_overlay_panel.add_child(v)

	v.add_child(_label("◆   Confirm Your Path   ◆", 38, COL_GOLD))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	v.add_child(body)

	_overlay_thumb = TextureRect.new()
	_overlay_thumb.custom_minimum_size = Vector2(210, 280)
	_overlay_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	body.add_child(_overlay_thumb)

	_overlay_text = Label.new()
	_overlay_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_text.add_theme_font_size_override("font_size", 32)
	_overlay_text.add_theme_color_override("font_color", COL_TEXT)
	body.add_child(_overlay_text)

	var buttons := _row(24)
	v.add_child(buttons)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(320, 100)
	_style_plain(back)
	back.pressed.connect(_hide_overlay)
	buttons.add_child(back)

	var yes := Button.new()
	yes.text = "Confirm"
	yes.custom_minimum_size = Vector2(320, 100)
	_style_gold(yes)
	yes.pressed.connect(_finish)
	buttons.add_child(yes)


func _show_overlay() -> void:
	_overlay_thumb.texture = _cards.get(_combo(_gender, _path))
	_overlay_text.text = "%s\n\n%s  ·  %s\n%s\n\nGender and Dao can't be changed later." % [
		_clean_name(),
		_gender.capitalize(),
		Enums.PATH_NAMES[_path],
		"+ " + str(Enums.PATH_DESCRIPTIONS[_path]).replace(", ", "   + "),
	]

	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_overlay_panel.scale = Vector2(0.9, 0.9)

	var t := create_tween().set_parallel(true)
	t.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	t.tween_property(_overlay_panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_overlay() -> void:
	var t := create_tween()
	t.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): _overlay.visible = false)


# ---------------------------------------------------------
# ANIMATION
# ---------------------------------------------------------

func _intro() -> void:
	var i := 0
	for child in _col.get_children():
		child.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.07 * i)
		t.tween_property(child, "modulate:a", 1.0, 0.45)
		i += 1

	_card_inner.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(_card_inner, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Gentle float
	var bob := create_tween().set_loops()
	bob.tween_property(_card_inner, "position:y", -8.0, 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_card_inner, "position:y", 8.0, 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Breathing glow on the gold button
	var pulse := create_tween().set_loops()
	pulse.tween_property(_gold_glow, "shadow_size", 22, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_gold_glow, "shadow_size", 6, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_place_glow()
	_shine_card(0.5)


## Points the background glow at the card once layout is done.
func _place_glow() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_card_box):
		return

	var vp := _root.size
	if vp.x <= 0.0:
		return

	_bg_mat.set_shader_parameter("glow_center", _card_box.get_global_rect().get_center() / vp)
	_bg_mat.set_shader_parameter("aspect", vp.y / vp.x)


func _shine_card(delay := 0.0) -> void:
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_method(_set_shine, -0.3, 1.8, 0.6)


func _set_shine(value: float) -> void:
	_card_mat.set_shader_parameter("shine", value)


func _update_preview(animate := true) -> void:
	var tex: Texture2D = _cards.get(_combo(_gender, _path))

	_badge.texture = DaoIcons.get_icon(_path)
	_card_path.text = Enums.PATH_NAMES[_path]

	if not animate:
		_card_art.texture = tex
		return

	if _card_tween != null:
		_card_tween.kill()

	_card_tween = create_tween()
	_card_tween.tween_property(_card_art, "modulate:a", 0.0, 0.12)
	_card_tween.tween_callback(func(): _card_art.texture = tex)
	_card_tween.tween_property(_card_art, "modulate:a", 1.0, 0.18)
	_card_tween.tween_method(_set_shine, -0.3, 1.8, 0.55)

	var pop := create_tween()
	pop.tween_property(_card_inner, "scale", Vector2(1.04, 1.04), 0.1)
	pop.tween_property(_card_inner, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_dao_buttons(instant := false) -> void:
	for p in _dao_buttons:
		var b: Button = _dao_buttons[p]
		var target := Vector2.ONE * (1.08 if p == _path else 1.0)
		if instant:
			b.scale = target
		else:
			create_tween().tween_property(b, "scale", target, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tints everything that follows the chosen Dao.
func _apply_accent(c: Color) -> void:
	_accent = c

	_bg_mat.set_shader_parameter("glow_color", c)
	_aura_mat.set_shader_parameter("color", c)
	_particles.color = c

	_card_glow.shadow_color = Color(c, 0.55)
	if _card_border != null:
		_card_border.border_color = c
	for mark in _corner_marks:
		mark.add_theme_color_override("font_color", c)
	_card_path.label_settings.font_color = c

	_gender_on.border_color = c
	_gender_on.bg_color = c.darkened(0.75)
	for b in _gender_buttons:
		b.add_theme_color_override("font_pressed_color", c)
		b.add_theme_color_override("font_hover_pressed_color", c)

	_info_box.border_color = Color(c, 0.7)
	_info_box.shadow_color = Color(c, 0.2)
	_info_name.add_theme_color_override("font_color", c)
	for sb in _chip_boxes:
		_color_chip(sb, c)

	_name_focus.border_color = c
	_name_edit.add_theme_color_override("caret_color", c)


func _color_chip(sb: StyleBoxFlat, c: Color) -> void:
	sb.bg_color = Color(c, 0.12)
	sb.border_color = Color(c, 0.55)


# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------

func _on_gender_pressed(gender: String) -> void:
	if gender == _gender:
		return
	_gender = gender
	_update_preview()


func _on_dao_pressed(path: int) -> void:
	if path == _path:
		return
	_path = path as Enums.Path

	_refresh_dao_info()
	_update_preview()
	_update_dao_buttons()

	if _accent_tween != null:
		_accent_tween.kill()
	_accent_tween = create_tween()
	_accent_tween.tween_method(_apply_accent, _accent, _dao_color(_path), 0.4)


func _clean_name() -> String:
	return GameState.clean_mc_name(_name_edit.text)


func _on_name_changed(_text: String) -> void:
	var n := _clean_name()
	_card_name.text = n if n != "" else "???"
	var error := GameState.validate_mc_name(n)
	_confirm_button.disabled = error != ""
	_hint_label.text = error if n != "" else ""


func _on_random_pressed() -> void:
	var pick := GameState.random_mc_name(_gender)
	for i in 5:
		if pick != _name_edit.text:
			break
		pick = GameState.random_mc_name(_gender)

	# Setting text in code doesn't fire text_changed, so update by hand.
	_name_edit.text = pick
	_on_name_changed(pick)


func _on_confirm_pressed() -> void:
	if _done or GameState.validate_mc_name(_name_edit.text) != "":
		return
	_name_edit.release_focus()
	_show_overlay()


func _finish() -> void:
	if _done:
		return
	_done = true

	GameState.create_main_character(_clean_name(), _gender, _path)

	if _paused_game:
		get_tree().paused = false
		_paused_game = false

	finished.emit()
	# The mentor's first-steps tutorial begins right away
	Tutorial.start("intro", get_tree().root)

	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

## Makes a control fill its parent.
func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _box(bg: Color, border: Color, width := 3, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


func _style_plain(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	var normal := _box(Color(COL_PANEL, 0.9), COL_DIM, 2)
	var down := _box(COL_DIM, COL_TEXT_DIM, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)


## Gold button. Returns its normal style so the glow can pulse.
func _style_gold(b: Button) -> StyleBoxFlat:
	b.focus_mode = Control.FOCUS_NONE

	var normal := _box(Color("5a3f12"), COL_GOLD, 3, 16)
	normal.shadow_color = Color(COL_GOLD, 0.4)
	normal.shadow_size = 10
	var down := _box(Color("7a5818"), COL_GOLD_TEXT, 3, 16)
	var off := _box(Color("151a24"), Color("323845"), 2, 16)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", COL_GOLD_TEXT)
	b.add_theme_color_override("font_hover_color", COL_GOLD_TEXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("4d5462"))
	return normal
