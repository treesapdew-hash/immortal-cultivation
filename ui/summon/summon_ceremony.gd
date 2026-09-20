class_name SummonCeremony
extends CanvasLayer

# =========================================================
# Full-screen summon reveal.
#
#   var c := SummonCeremony.open(self, results, 10)
#   c.summon_again.connect(...)
#   await c.finished
#
# Cards are revealed one by one (tap to speed up, Skip to
# reveal all), then shown together in an arc with the best
# one on the centre stage.
# =========================================================

signal finished
signal summon_again(count: int)

## While only White cards have art, the effects follow the tier that
## was ROLLED (so you can see Purple/Red effects on White art).
## Set to false once other tiers have cards.
const EFFECTS_FROM_ROLL := false

const STAGE_WIDTH := 420.0
const ARC_WIDTH := 126.0

const GOLD := Color("e2c27a")
const TEXT := Color("e8eef7")
const DIM := Color("8a9bb4")
const NEW_COLOR := Color("7dffa8")

## Starfield, drifting nebula and a beam of light from above.
const BG_SHADER := """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.3, 0.42, 0.9, 1.0);
uniform vec4 beam_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float beam = 0.0;
uniform float aspect = 1.78;

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

float stars(vec2 p, float density, float cells) {
	vec2 g = p * cells;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	vec2 o = vec2(hash(id + 1.3), hash(id + 2.7)) - 0.5;
	float d = length(f - o * 0.6);
	float twinkle = 0.55 + 0.45 * sin(TIME * (1.0 + h * 4.0) + h * 50.0);
	return step(density, h) * smoothstep(0.09, 0.0, d) * twinkle;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x, uv.y * aspect);

	vec3 col = mix(vec3(0.01, 0.015, 0.04), vec3(0.03, 0.05, 0.11), uv.y);

	float n = fbm(p * 2.0 + vec2(TIME * 0.01, -TIME * 0.02));
	float n2 = fbm(p * 3.5 - vec2(TIME * 0.015, TIME * 0.005));
	col += tint.rgb * smoothstep(0.45, 0.95, n) * 0.35;
	col += vec3(0.45, 0.28, 0.7) * smoothstep(0.55, 1.0, n2) * 0.12;

	col += vec3(1.0) * stars(p, 0.96, 40.0) * 0.9;
	col += vec3(0.8, 0.9, 1.0) * stars(p + 3.1, 0.93, 90.0) * 0.5;

	float bx = abs(uv.x - 0.5);
	float b = exp(-bx * bx * 6000.0) * 0.5 + exp(-bx * bx * 120.0) * 0.18;
	b *= smoothstep(0.75, 0.0, uv.y);
	col += beam_color.rgb * b * beam;

	col *= mix(0.5, 1.0, smoothstep(1.1, 0.3, distance(uv, vec2(0.5, 0.45))));
	COLOR = vec4(col, 1.0);
}
"""

var _results: Array = []
var STAGE_SIZE := Vector2(420, 560)    # set from your frames' shape
var ARC_SIZE := Vector2(126, 168)
var _count := 1
var _vp := Vector2(1080, 1920)
var _paused_game := false
var _skip := false
var _tapped := false
var _closing := false
var _in_summary := false

var _root: Control
var _bg_mat: ShaderMaterial
var _arc_layer: Control
var _stage_layer: Control
var _arc_cards: Array = []
var _stage_card: SummonCard
var _focused := -1

var _name_box: Control
var _tier_gems: Control
var _gem_count := 1
var _gem_color := Color.WHITE
var _name_label: Label
var _tag_label: Label
var _form_label: Label
var _hint: Label
var _skip_button: Button
var _buttons: HBoxContainer
var _again_button: Button
var _flash: ColorRect

# Tier backdrop behind the stage card: a tinted light burst, a slowly
# turning formation array, and (Red and up) rising sparkles.
const BURST_ART := "res://assets/ui/summon/summon_burst.png"
const ARRAY_ART := "res://assets/ui/breakthrough/bt_array.png"
var _aura_layer: Control
var _aura_burst: TextureRect
var _aura_array: TextureRect
var _aura_sparks: Control
var _aura_pulse: Tween
var _aura_tier := 0
var _aura_rarity := 0
var _aura_on := false
var _aura_time := 0.0
var _sparks: Array = []


static func open(host: Node, results: Array, count: int) -> SummonCeremony:
	var c := SummonCeremony.new()
	c._results = results
	c._count = count
	host.get_tree().root.add_child.call_deferred(c)
	return c


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().paused:
		get_tree().paused = true
		_paused_game = true

	_vp = get_viewport().get_visible_rect().size
	SummonCard.find_frames(self)
	STAGE_SIZE = SummonCard.size_for_width(STAGE_WIDTH)
	ARC_SIZE = SummonCard.size_for_width(ARC_WIDTH)
	_build()
	_run()


func _exit_tree() -> void:
	if _paused_game:
		get_tree().paused = false


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_fill(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	var font := DamageNumber.get_number_font()
	if font != null:
		th.default_font = font
	_root.theme = th
	add_child(_root)

	# Background also catches taps
	var bg := ColorRect.new()
	_fill(bg)
	_bg_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BG_SHADER
	_bg_mat.shader = shader
	_bg_mat.set_shader_parameter("aspect", _vp.y / _vp.x)
	_bg_mat.set_shader_parameter("beam", 0.0)
	_bg_mat.set_shader_parameter("beam_color", Color(0.85, 0.92, 1.0))
	bg.material = _bg_mat
	bg.gui_input.connect(_on_bg_input)
	_root.add_child(bg)

	_arc_layer = Control.new()
	_fill(_arc_layer)
	_arc_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_arc_layer)

	_build_aura()

	_stage_layer = Control.new()
	_fill(_stage_layer)
	_stage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage_layer)

	_build_name_box()

	_hint = _label("Tap to continue", 26, DIM)
	_hint.position = Vector2(0, _vp.y * 0.83)
	_hint.size = Vector2(_vp.x, 40)
	_hint.modulate.a = 0.0
	_root.add_child(_hint)

	_skip_button = _button("Skip", Vector2(170, 70), false)
	_skip_button.position = Vector2(_vp.x - 200, 60)
	_skip_button.pressed.connect(_on_skip)
	_root.add_child(_skip_button)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 30)
	_buttons.position = Vector2(0, _vp.y * 0.87)
	_buttons.size = Vector2(_vp.x, 110)
	_buttons.visible = false
	_root.add_child(_buttons)

	var close := _button("Close", Vector2(280, 100), false)
	close.pressed.connect(_close)
	_buttons.add_child(close)

	var cost := SummonSystem.get_cost(_count)
	_again_button = _button("Summon ×%d\n%s Jade" % [_count, NumberFormat.short(cost)], Vector2(320, 100), true)
	_again_button.pressed.connect(func():
		summon_again.emit(_count)
		_close()
	)
	_buttons.add_child(_again_button)

	_flash = ColorRect.new()
	_fill(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)


## The tier backdrop: burst and array (hidden until a card is shown).
func _build_aura() -> void:
	_aura_layer = Control.new()
	_fill(_aura_layer)
	_aura_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_layer.modulate.a = 0.0
	_root.add_child(_aura_layer)

	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var centre := _stage_center()

	if ResourceLoader.exists(ARRAY_ART):
		_aura_array = TextureRect.new()
		_aura_array.texture = load(ARRAY_ART) as Texture2D
		_aura_array.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_aura_array.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_aura_array.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aura_array.material = add
		var side := STAGE_SIZE.x * 1.9
		_aura_array.size = Vector2(side, side)
		_aura_array.position = centre - _aura_array.size * 0.5
		_aura_array.pivot_offset = _aura_array.size * 0.5
		_aura_layer.add_child(_aura_array)

	if ResourceLoader.exists(BURST_ART):
		_aura_burst = TextureRect.new()
		_aura_burst.texture = load(BURST_ART) as Texture2D
		_aura_burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_aura_burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_aura_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aura_burst.material = add
		var side := STAGE_SIZE.x * 2.6
		_aura_burst.size = Vector2(side, side)
		_aura_burst.position = centre - _aura_burst.size * 0.5
		_aura_burst.pivot_offset = _aura_burst.size * 0.5
		_aura_layer.add_child(_aura_burst)

	_aura_sparks = Control.new()
	_fill(_aura_sparks)
	_aura_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_sparks.draw.connect(_draw_sparks)
	_aura_layer.add_child(_aura_sparks)


## Shows the backdrop in a tier's colour. level = the card's effect level.
func _show_aura(tier: int, level: int) -> void:
	_aura_tier = Realms.tier_index(tier)
	_aura_rarity = tier
	_aura_on = true
	var col := _aura_color()
	var strength := 0.4 if _aura_tier <= 0 else clampf(0.55 + float(level) * 0.1, 0.55, 1.0)
	if _aura_burst != null:
		_aura_burst.self_modulate = Color(col, strength)
		_aura_burst.scale = Vector2(0.6, 0.6)
		var bloom := create_tween()
		bloom.tween_property(_aura_burst, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if _aura_array != null:
		_aura_array.self_modulate = Color(col, strength * 0.8)
	if _aura_pulse != null:
		_aura_pulse.kill()
		_aura_pulse = null
	if _aura_tier >= 3 and _aura_burst != null:
		# Rarer cards breathe
		_aura_pulse = create_tween().set_loops()
		_aura_pulse.tween_property(_aura_burst, "scale", Vector2(1.08, 1.08), 1.1).set_trans(Tween.TRANS_SINE)
		_aura_pulse.tween_property(_aura_burst, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE)
	_sparks.clear()
	_fade(_aura_layer, 1.0, 0.3)


func _hide_aura() -> void:
	_aura_on = false
	if _aura_pulse != null:
		_aura_pulse.kill()
		_aura_pulse = null
	_fade(_aura_layer, 0.0, 0.25)


func _aura_color() -> Color:
	if _aura_tier >= 6:
		# Prismatic slowly cycles through the rainbow
		return Color.from_hsv(fmod(_aura_time * 0.15, 1.0), 0.45, 1.0)
	if _aura_tier <= 0:
		return Color(0.85, 0.9, 1.0)
	var c: Color = SummonCard.tier_color(_aura_rarity)
	return c


func _process(delta: float) -> void:
	_aura_time += delta
	if _aura_array != null and _aura_on:
		_aura_array.rotation += delta * 0.18
	if _aura_on and _aura_tier >= 6:
		var col := _aura_color()
		if _aura_burst != null:
			_aura_burst.self_modulate = Color(col, _aura_burst.self_modulate.a)
		if _aura_array != null:
			_aura_array.self_modulate = Color(col, _aura_array.self_modulate.a)
	# Red and up: sparkles rising around the card
	if _aura_on and _aura_tier >= 4:
		if randf() < delta * 14.0:
			var c := _stage_center()
			_sparks.append({
				"pos": c + Vector2(randf_range(-STAGE_SIZE.x * 0.7, STAGE_SIZE.x * 0.7), STAGE_SIZE.y * randf_range(0.1, 0.5)),
				"vel": Vector2(randf_range(-12, 12), randf_range(-140, -60)),
				"life": randf_range(1.2, 2.4), "size": randf_range(2.0, 5.0)})
	for p in _sparks:
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
	_sparks = _sparks.filter(func(p): return float(p["life"]) > 0.0)
	if _aura_sparks != null:
		_aura_sparks.queue_redraw()


func _draw_sparks() -> void:
	var col := _aura_color().lightened(0.35)
	for p in _sparks:
		var a := clampf(float(p["life"]), 0.0, 1.0)
		var sz := float(p["size"])
		_aura_sparks.draw_circle(p["pos"], sz * 2.4, Color(col, a * 0.18))
		_aura_sparks.draw_circle(p["pos"], sz, Color(col, a))


## "—— Name ——" under the stage, with tier and NEW / +1 Copy.
func _build_name_box() -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(0, _stage_center().y + STAGE_SIZE.y * 0.5 + 40)
	box.size = Vector2(_vp.x, 170)
	box.modulate.a = 0.0
	_root.add_child(box)
	_name_box = box

	# Row of gems in the tier colour: White = 1 ... Red = 5
	_tier_gems = Control.new()
	_tier_gems.custom_minimum_size = Vector2(0, 26)
	_tier_gems.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_gems.draw.connect(func():
		var gap := 26.0
		var start := _tier_gems.size.x * 0.5 - (_gem_count - 1) * gap * 0.5
		for g in _gem_count:
			var p := Vector2(start + g * gap, _tier_gems.size.y * 0.5)
			var r := 9.0
			_tier_gems.draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)
			]), _gem_color)
			_tier_gems.draw_polyline(PackedVector2Array([
				p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0), p + Vector2(0, -r)
			]), GOLD, 1.2, true)
	)
	box.add_child(_tier_gems)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	row.add_child(_ornament_line(false))
	_name_label = _label("", 52, TEXT)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_name_label.add_theme_constant_override("shadow_offset_x", 0)
	_name_label.add_theme_constant_override("shadow_offset_y", 3)
	_name_label.add_theme_constant_override("shadow_outline_size", 8)
	row.add_child(_name_label)
	row.add_child(_ornament_line(true))

	# The partner's form, e.g. "Fallen Heart Flame"
	_form_label = _label("", 26, GOLD)
	box.add_child(_form_label)

	_tag_label = _label("", 26, NEW_COLOR)
	box.add_child(_tag_label)


func _ornament_line(on_right: bool) -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(170, 20)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		var inner := 0.0 if on_right else w
		var outer := w if on_right else 0.0
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(outer, y), Vector2(inner, y)]),
			PackedColorArray([Color(GOLD, 0.0), GOLD]), 2.0, true)
		# Small diamonds near the name
		var dir := 1.0 if on_right else -1.0
		for k in 2:
			var cx := inner + dir * (8.0 + k * 16.0)
			var r := 5.0 - k * 1.5
			line.draw_colored_polygon(PackedVector2Array([
				Vector2(cx, y - r), Vector2(cx + r * 0.7, y), Vector2(cx, y + r), Vector2(cx - r * 0.7, y)
			]), GOLD)
	)
	return line


# ---------------------------------------------------------
# LAYOUT
# ---------------------------------------------------------

func _stage_center() -> Vector2:
	return Vector2(_vp.x * 0.5, _vp.y * 0.53)


## Centre, rotation and scale of card i of n in the top arc.
func _arc_place(i: int, n: int) -> Array:
	var arc_y := _vp.y * 0.17
	if n == 1:
		return [Vector2(_vp.x * 0.5, arc_y), 0.0, 1.0]

	var spread := deg_to_rad(minf(66.0, 9.0 * (n - 1)))
	var t := float(i) / (n - 1)
	var a := lerpf(-spread * 0.5, spread * 0.5, t)
	var edge := sin(spread * 0.5)
	var x := _vp.x * 0.5 + (sin(a) / edge if edge > 0.0 else 0.0) * _vp.x * 0.39
	var y := arc_y - (1.0 - cos(a)) * 420.0    # ends curve upward
	var scale_f := lerpf(1.0, 0.86, absf(a) / (spread * 0.5))
	return [Vector2(x, y), a * 0.8, scale_f]


func _effect_tier(res: Dictionary) -> int:
	if EFFECTS_FROM_ROLL:
		return res.get("tier", 0)
	var data = PartnerDatabase.get_partner(res.get("partner_id", ""))
	return data.rarity if data != null else res.get("tier", 0)


# ---------------------------------------------------------
# SEQUENCE
# ---------------------------------------------------------

func _run() -> void:
	# Hidden, face-down cards waiting in the arc
	var n := _results.size()
	for i in n:
		var card := SummonCard.new()
		card.setup(_results[i], _effect_tier(_results[i]), ARC_SIZE)
		var place := _arc_place(i, n)
		card.position = place[0] - ARC_SIZE * 0.5
		card.rotation = place[1]
		card.base_scale = Vector2.ONE * place[2]
		card.scale = card.base_scale
		card.z_index = 20 - int(absf(i - (n - 1) * 0.5) * 2.0)
		card.modulate.a = 0.0
		_arc_layer.add_child(card)
		_arc_cards.append(card)

	# Fade in the scene
	_root.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 1.0, 0.3)
	await t.finished

	for i in n:
		if _skip or _closing:
			break
		await _reveal_one(i)

	if not _closing:
		await _show_summary()


func _reveal_one(i: int) -> void:
	var res: Dictionary = _results[i]
	var tier := _effect_tier(res)
	var card := SummonCard.new()
	card.setup(res, tier, STAGE_SIZE)
	var home := _stage_center() - STAGE_SIZE * 0.5
	card.position = home + Vector2(0, -260)
	card.modulate.a = 0.0
	_stage_layer.add_child(card)
	_stage_card = card

	# Beam in the tier colour
	_set_beam(_beam_color(tier), 0.7 if card.level >= 3 else 0.45)

	var t := create_tween().set_parallel(true)
	t.tween_property(card, "position", home, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.3)
	await t.finished
	card.start_float()

	if _skip:
		_discard_stage()
		return

	# Build-up for rare pulls
	if card.level >= 3:
		if card.level >= 4:
			_darken_then_flash()
		await card.anticipate(1.1 if card.level >= 4 else 0.7)
	else:
		await _wait(0.25)

	if _skip:
		_discard_stage()
		return

	await card.flip(0.4)
	_show_aura(tier, card.level)
	card.play_fx(true)
	if card.level >= 4:
		_flash_screen(0.7)
		_shake(18.0)
	elif card.level >= 3:
		_flash_screen(0.35)

	_show_name(res, tier)
	_fade(_hint, 1.0, 0.3)
	await _wait(3.0 if card.level >= 3 else 1.6)
	_fade(_hint, 0.0, 0.2)
	_fade(_name_box, 0.0, 0.2)

	if _skip:
		_discard_stage()
		return

	# Fly up into the arc
	_hide_aura()
	card.stop_float()
	card.stop_fx()
	var slot: SummonCard = _arc_cards[i]
	var target_center: Vector2 = slot.position + ARC_SIZE * 0.5
	var target_scale := slot.base_scale * (ARC_SIZE.x / STAGE_SIZE.x)
	var fly := create_tween().set_parallel(true)
	fly.tween_property(card, "position", target_center - STAGE_SIZE * 0.5, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(card, "scale", target_scale, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(card, "rotation", slot.rotation, 0.35)
	await fly.finished

	_discard_stage()
	slot.show_front()
	slot.modulate.a = 1.0
	slot.play_fx(false)


func _discard_stage() -> void:
	if is_instance_valid(_stage_card):
		_stage_card.queue_free()
	_stage_card = null


func _show_summary() -> void:
	_hide_aura()
	_in_summary = true
	_fade(_skip_button, 0.0, 0.2)
	_skip_button.disabled = true
	_fade(_hint, 0.0, 0.1)
	_set_beam(Color(0.85, 0.92, 1.0), 0.35)

	# Reveal anything skipped, in a quick cascade
	var pending: Array = []
	for card in _arc_cards:
		if not card.revealed:
			pending.append(card)
	for card in pending:
		card.modulate.a = 1.0
	for card in pending:
		card.flip(0.22)
		card.play_fx(false)
		await _sleep(0.06)
	if not pending.is_empty():
		await _sleep(0.25)

	# Arc cards become tappable
	for i in _arc_cards.size():
		var card: SummonCard = _arc_cards[i]
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_arc_card_input.bind(i))

	_focus(_best_index())

	_hint.text = "Tap a card to view it"
	_hint.position.y = _vp.y * 0.815
	_fade(_hint, 1.0, 0.3)

	_again_button.disabled = not SummonSystem.can_afford(_count)
	_buttons.visible = true
	_buttons.modulate.a = 0.0
	_fade(_buttons, 1.0, 0.3)


func _best_index() -> int:
	var best := 0
	for i in _arc_cards.size():
		if _arc_cards[i].level > _arc_cards[best].level:
			best = i
	return best


## Shows card i big on the stage and lifts it in the arc.
func _focus(i: int) -> void:
	if i == _focused:
		return
	_focused = i

	for j in _arc_cards.size():
		var arc: SummonCard = _arc_cards[j]
		var place := _arc_place(j, _arc_cards.size())
		var lift := Vector2(0, -24) if j == i else Vector2.ZERO
		var scale_to: Vector2 = arc.base_scale * (1.12 if j == i else 1.0)
		var move := create_tween().set_parallel(true)
		move.tween_property(arc, "position", place[0] - ARC_SIZE * 0.5 + lift, 0.2)
		move.tween_property(arc, "scale", scale_to, 0.2)

	_discard_stage()
	var res: Dictionary = _results[i]
	var tier := _effect_tier(res)
	var card := SummonCard.new()
	card.setup(res, tier, STAGE_SIZE)
	card.position = _stage_center() - STAGE_SIZE * 0.5
	card.show_front()
	card.scale = Vector2(0.9, 0.9)
	card.modulate.a = 0.0
	_stage_layer.add_child(card)
	_stage_card = card

	var t := create_tween().set_parallel(true)
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.2)
	card.play_fx(true)
	card.start_float()
	_show_aura(tier, card.level)

	_set_beam(_beam_color(tier), 0.3 + card.level * 0.05)
	_show_name(res, tier)


func _show_name(res: Dictionary, tier: int) -> void:
	var data = PartnerDatabase.get_partner(res.get("partner_id", ""))
	_name_label.text = data.display_name if data != null else "?"
	_form_label.text = str(data.form_name) if data != null else ""
	_form_label.visible = _form_label.text != ""
	_fit_name()
	_gem_count = clampi(Realms.tier_index(tier), 0, 6) + 1
	_gem_color = SummonCard.tier_color(tier)
	_tier_gems.queue_redraw()
	var is_new: bool = res.get("is_new", false)
	_tag_label.text = "NEW" if is_new else "+1 Copy"
	_tag_label.add_theme_color_override("font_color", NEW_COLOR if is_new else DIM)

	_name_box.modulate.a = 0.0
	_name_box.position.y = _stage_center().y + STAGE_SIZE.y * 0.5 + 60
	var t := create_tween().set_parallel(true)
	t.tween_property(_name_box, "modulate:a", 1.0, 0.3)
	t.tween_property(_name_box, "position:y", _name_box.position.y - 20, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Shrinks the name until it fits between the ornament lines.
func _fit_name() -> void:
	var font := _name_label.get_theme_font("font")
	var fs := 52
	var max_w := _vp.x * 0.62
	if font != null:
		while fs > 28 and font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			fs -= 2
	_name_label.add_theme_font_size_override("font_size", fs)


# ---------------------------------------------------------
# EFFECTS
# ---------------------------------------------------------

func _set_beam(color: Color, strength: float) -> void:
	var from_color: Color = _bg_mat.get_shader_parameter("beam_color")
	var from_beam: float = _bg_mat.get_shader_parameter("beam")
	var t := create_tween().set_parallel(true)
	t.tween_method(func(c: Color): _bg_mat.set_shader_parameter("beam_color", c), from_color, color, 0.4)
	t.tween_method(func(v: float): _bg_mat.set_shader_parameter("beam", v), from_beam, strength, 0.4)


## Mostly white, with just a hint of the tier colour.
func _beam_color(tier: int) -> Color:
	return SummonCard.tier_color(tier).lerp(Color(0.9, 0.95, 1.0), 0.75)


func _flash_screen(strength: float) -> void:
	_flash.color = Color(1, 1, 1, strength)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)


## Screen dims before a Red reveal.
func _darken_then_flash() -> void:
	_flash.color = Color(0, 0, 0, 0)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.45, 0.9)


func _shake(strength: float) -> void:
	var t := create_tween()
	for i in 8:
		t.tween_property(_root, "position",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.035)
		strength *= 0.8
	t.tween_property(_root, "position", Vector2.ZERO, 0.05)


func _fade(node: CanvasItem, alpha: float, duration: float) -> void:
	create_tween().tween_property(node, "modulate:a", alpha, duration)


# ---------------------------------------------------------
# INPUT AND TIMING
# ---------------------------------------------------------

func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_tapped = true


func _on_arc_card_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_focus(i)


func _on_skip() -> void:
	_skip = true
	_tapped = true


## Waits up to `seconds`, but a tap or Skip ends it early.
func _wait(seconds: float) -> void:
	_tapped = false
	var elapsed := 0.0
	while elapsed < seconds and not _tapped and not _skip and not _closing:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _close() -> void:
	if _closing:
		return
	_closing = true
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.3)
	await t.finished
	if _paused_game:
		get_tree().paused = false
		_paused_game = false
	finished.emit()
	queue_free()


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, min_size: Vector2, gold: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size = min_size
	b.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(2)
	normal.set_content_margin_all(10)
	if gold:
		normal.bg_color = Color("5a3f12")
		normal.border_color = GOLD
		normal.shadow_color = Color(GOLD, 0.35)
		normal.shadow_size = 12
	else:
		normal.bg_color = Color(0.05, 0.09, 0.18, 0.85)
		normal.border_color = Color(GOLD, 0.55)
	var down: StyleBoxFlat = normal.duplicate()
	down.bg_color = normal.bg_color.lightened(0.15)
	var off: StyleBoxFlat = normal.duplicate()
	off.bg_color = Color("151a24")
	off.border_color = Color("323845")
	off.shadow_size = 0

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color("ffe6a8") if gold else TEXT)
	b.add_theme_color_override("font_hover_color", Color("ffe6a8") if gold else TEXT)
	b.add_theme_color_override("font_disabled_color", Color("5a606c"))
	return b
