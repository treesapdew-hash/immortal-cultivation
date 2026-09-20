class_name BreakthroughCeremony
extends CanvasLayer

# =========================================================
# Breakthrough ceremony, built in code. Save as
#   res://ui/breakthrough_ceremony.gd
#
#   BreakthroughCeremony.play(host, partner, success, qi_lost, major)
#
# Success: the screen darkens, a pillar of light strikes, a
# formation array spins up behind the partner's card, and a
# plaque sweeps in with the new realm. Major realm breakthroughs
# (into a new major realm) also open the heavenly gate.
# Failure: the array shatters, red smoke, a shake.
# Tap anywhere to skip ahead.
#
# Art in assets/ui/breakthrough/ (drawn fallback if missing):
#   bt_pillar.png  bt_array.png  bt_banner.png  bt_gate.png
#   bt_banner_fail.png  bt_array_broken.png
# =========================================================

signal finished

const ART_DIR := "res://assets/ui/breakthrough/"
const LAYER := 64   # above the breakthrough popup (60) and gear popups (62)

const COL_GOLD := Color("ffe6a8")
const COL_TEXT := Color("f4ecd8")
const COL_SUB := Color("c9d4e3")
const COL_FAIL := Color("ff8a7a")
const COL_FAIL_SUB := Color("b8a8a8")

## Screen layout, as shares of the screen.
const CARD_Y := 0.36
const PLAQUE_Y := 0.69
const CARD_WIDTH := 0.38
const ARRAY_WIDTH := 0.9
const PLAQUE_WIDTH := 0.94

## Where the text goes on the plaque art, as shares of the (trimmed)
## plaque: x, y, width, height. Tuned for the phoenix plaque, whose
## blue panel is a band in the middle. Nudge y up or down if the text
## sits too low or high.
const PLAQUE_TEXT := Rect2(0.25, 0.4, 0.5, 0.34)

var _partner: OwnedPartner
var _success := true
var _major := false
var _qi_lost := 0

var _root: Control
var _flash: ColorRect
var _array: Control
var _card: Control
var _plaque: Control
var _continue: OrnateButton
var _fx: Control
var _particles: Array = []
var _skip := false
var _done := false


static func play(host: Node, partner: OwnedPartner, success: bool, qi_lost := 0,
		major := false) -> BreakthroughCeremony:
	var c := BreakthroughCeremony.new()
	c._partner = partner
	c._success = success
	c._qi_lost = qi_lost
	c._major = major and success
	host.get_tree().root.add_child(c)
	return c


func _ready() -> void:
	layer = LAYER
	# Settings: "Fast" jumps straight to the result
	_skip = Settings.is_on("fast_ceremony")
	_build()
	_run.call_deferred()


func _process(delta: float) -> void:
	# Rising sparkles (success) or smoke (failure)
	if _fx == null:
		return
	for p in _particles:
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
	_particles = _particles.filter(func(p): return float(p["life"]) > 0.0)
	_fx.queue_redraw()
	if _array != null and is_instance_valid(_array) and _success:
		_array.rotation += delta * (0.25 if not _major else 0.35)


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := _root.get_viewport_rect().size

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.name = "Dim"

	# Heavenly gate behind everything (major breakthroughs)
	if _major:
		var gate := _image("bt_gate")
		if gate != null:
			gate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			gate.size = screen
			gate.pivot_offset = screen * 0.5
			gate.modulate.a = 0.0
			gate.name = "Gate"
			_root.add_child(gate)

	# Formation array
	var array_side := screen.x * ARRAY_WIDTH
	var array_img := _image("bt_array" if _success else "bt_array_broken")
	if array_img != null:
		_array = array_img
	else:
		_array = Control.new()
		_array.draw.connect(_draw_fallback_array.bind(_array))
	_array.size = Vector2(array_side, array_side)
	_array.position = Vector2(screen.x * 0.5, screen.y * CARD_Y) - _array.size * 0.5
	_array.pivot_offset = _array.size * 0.5
	_array.modulate.a = 0.0
	_array.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_array)

	# Light pillar (success)
	if _success:
		var pillar_img := _image("bt_pillar")
		var pillar: Control = pillar_img
		if pillar == null:
			var bar := ColorRect.new()
			bar.color = Color(1.0, 0.92, 0.6, 0.55)
			pillar = bar
		var pw := screen.x * (0.75 if _major else 0.6)
		pillar.size = Vector2(pw, screen.y * (CARD_Y + 0.2))
		pillar.position = Vector2(screen.x * 0.5 - pw * 0.5, -pillar.size.y)
		pillar.modulate.a = 0.0
		pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pillar.name = "Pillar"
		_root.add_child(pillar)

	# The partner's card, in its tier frame (same card as the summon screen)
	var card_w := screen.x * CARD_WIDTH
	SummonCard.find_frames(_root)
	var card_size := SummonCard.size_for_width(card_w)
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = card_size
	card.position = Vector2(screen.x * 0.5, screen.y * CARD_Y) - card_size * 0.5 + Vector2(0, 80)
	card.pivot_offset = card_size * 0.5
	card.modulate.a = 0.0
	var data = _partner.get_data() if _partner != null else null
	if data != null:
		var rarity: int = int(data.rarity)   # the MC's data follows its tier
		var face := SummonCard.new()
		face.setup({"partner_id": _partner.partner_id}, rarity, card_size)
		face.show_front()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
	_card = card
	_root.add_child(card)

	# Sparkles / smoke layer
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_particles)
	_root.add_child(_fx)
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Plaque with the result text
	_plaque = _build_plaque(screen)
	_plaque.modulate.a = 0.0
	_root.add_child(_plaque)

	_continue = OrnateButton.new()
	_continue.text = "Continue"
	_continue.variant = OrnateButton.Variant.GOLD if _success else OrnateButton.Variant.DARK
	_continue.custom_minimum_size = Vector2(300, 80)
	_continue.size = Vector2(300, 80)
	_continue.position = Vector2(screen.x * 0.5 - 150, _plaque.position.y + _plaque.size.y + 20.0)
	_continue.visible = false
	_continue.pressed.connect(_close)
	_root.add_child(_continue)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_plaque(screen: Vector2) -> Control:
	var w := screen.x * PLAQUE_WIDTH
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true

	var tex := _load("bt_banner" if _success else "bt_banner_fail")
	var h := w * 0.3
	if tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = ResultBanner._visible_region(tex)
		h = w * atlas.region.size.y / maxf(atlas.region.size.x, 1.0)
		var img := TextureRect.new()
		img.texture = atlas
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.size = Vector2(w, h)
		holder.add_child(img)
	else:
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0c1a33", 0.95) if _success else Color("1c1414", 0.95)
		sb.border_color = COL_GOLD if _success else Color("7a3a30")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
		panel.add_theme_stylebox_override("panel", sb)
		panel.size = Vector2(w, h)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(panel)
	holder.size = Vector2(w, h)
	holder.position = Vector2(screen.x * 0.5 - w * 0.5, screen.y * PLAQUE_Y - h * 0.5)
	holder.pivot_offset = holder.size * 0.5

	# Text, centred on the plaque's inner panel
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		box.position = Vector2(w * PLAQUE_TEXT.position.x, h * PLAQUE_TEXT.position.y)
		box.size = Vector2(w * PLAQUE_TEXT.size.x, h * PLAQUE_TEXT.size.y)
	else:
		box.position = Vector2(w * 0.1, h * 0.14)
		box.size = Vector2(w * 0.8, h * 0.72)
	holder.add_child(box)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(v)

	var ui := w / 1000.0
	if _success:
		v.add_child(_text("GREAT BREAKTHROUGH!" if _major else "BREAKTHROUGH!", int(46 * ui), COL_GOLD, true))
		v.add_child(_text(_partner.get_realm_text() if _partner != null else "", int(28 * ui), COL_TEXT, false))
		if _major and _partner != null:
			v.add_child(_text("Entered the %s" % Realms.get_major_name(_partner.realm_index), int(20 * ui), COL_SUB, false))
	else:
		v.add_child(_text("BREAKTHROUGH FAILED", int(42 * ui), COL_FAIL, true))
		v.add_child(_text("Your Qi scattered  ·  lost %s Qi" % NumberFormat.short(_qi_lost), int(22 * ui), COL_FAIL_SUB, false))
		v.add_child(_text("Gather yourself and try again", int(18 * ui), COL_FAIL_SUB, false))

	# Fit the text inside the plaque's middle, once the layout is known.
	_fit_plaque_text(box, v, box.position, box.size)

	# A shine that sweeps across once (success)
	if _success:
		var shine := Control.new()
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.size = Vector2(w * 0.12, h)
		shine.position = Vector2(-w * 0.2, 0)
		shine.draw.connect(func():
			var sw := shine.size.x
			shine.draw_colored_polygon(PackedVector2Array([
				Vector2(sw * 0.4, 0), Vector2(sw, 0), Vector2(sw * 0.6, h), Vector2(0, h)]),
				Color(1, 1, 1, 0.28))
		)
		shine.name = "Shine"
		holder.add_child(shine)
	return holder


# ---------------------------------------------------------
# SEQUENCE
# ---------------------------------------------------------

func _run() -> void:
	var screen := _root.get_viewport_rect().size
	var dim: ColorRect = _root.get_node("Dim")
	_tween(dim, "color:a", 0.88, 0.35)
	await _wait(0.3)

	var gate := _root.get_node_or_null("Gate") as Control
	if gate != null:
		_tween(gate, "modulate:a", 0.9, 0.8)
		var zoom := gate.create_tween()
		zoom.tween_property(gate, "scale", Vector2(1.08, 1.08), 4.0)
		await _wait(0.6)

	if _success:
		# Pillar strikes down, with a flash
		var pillar := _root.get_node_or_null("Pillar") as Control
		if pillar != null:
			pillar.modulate.a = 1.0
			_tween(pillar, "position:y", 0.0, 0.25)
			await _wait(0.2)
			_flash_screen(0.7)
		_tween(_array, "modulate:a", 1.0, 0.5)
		_array.scale = Vector2(0.6, 0.6)
		_tween(_array, "scale", Vector2.ONE, 0.6)
		_spawn_sparkles(screen, 40 if _major else 26)
	else:
		# The array shatters: red flash and a shake
		_array.modulate = Color(1, 1, 1, 0)
		_tween(_array, "modulate:a", 1.0, 0.3)
		await _wait(0.3)
		_flash_screen(0.45, Color(0.8, 0.1, 0.05))
		_shake(18.0)
		_spawn_smoke(screen, 30)

	# The card rises into place
	_tween(_card, "modulate:a", 1.0, 0.4)
	_tween(_card, "position:y", _card.position.y - 80.0, 0.5)
	if _success:
		_card.modulate = Color(1.8, 1.6, 1.1, 0.0)
		var glow := _card.create_tween()
		glow.tween_interval(_dur(0.45))
		glow.tween_property(_card, "modulate", Color.WHITE, _dur(0.6))
	else:
		_card.modulate = Color(0.55, 0.5, 0.5, 0.0)
	await _wait(0.5)

	# The plaque sweeps in
	_plaque.scale = Vector2(0.7, 0.7)
	_tween(_plaque, "modulate:a", 1.0, 0.25)
	var pop := _plaque.create_tween()
	pop.tween_property(_plaque, "scale", Vector2.ONE, _dur(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shine := _plaque.get_node_or_null("Shine") as Control
	if shine != null:
		var sweep := shine.create_tween()
		sweep.tween_interval(_dur(0.35))
		sweep.tween_property(shine, "position:x", _plaque.size.x * 1.1, _dur(0.7))
	await _wait(1.2 if _major else 0.8)

	_show_continue()


func _show_continue() -> void:
	if _done:
		return
	_done = true
	_continue.visible = true
	_continue.modulate.a = 0.0
	var t := _continue.create_tween()
	t.tween_property(_continue, "modulate:a", 1.0, 0.25)


## Tap anywhere to skip to the end.
func _on_tap(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if _done:
		return
	_skip = true


func _close() -> void:
	finished.emit()
	queue_free()


# ---------------------------------------------------------
# EFFECTS
# ---------------------------------------------------------

func _dur(seconds: float) -> float:
	return 0.05 if _skip else seconds


func _wait(seconds: float) -> void:
	if _skip:
		return
	await get_tree().create_timer(seconds).timeout


func _tween(node: Object, property: String, value: Variant, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(node, property, value, _dur(seconds))


func _flash_screen(strength: float, color := Color.WHITE) -> void:
	if not Settings.is_on("screen_effects"):
		return
	_flash.color = Color(color.r, color.g, color.b, strength)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, _dur(0.5))


func _shake(amount: float) -> void:
	if not Settings.is_on("screen_effects"):
		return
	var t := create_tween()
	for _i in 10:
		t.tween_property(_root, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.04)
	t.tween_property(_root, "position", Vector2.ZERO, 0.05)


func _spawn_sparkles(screen: Vector2, count: int) -> void:
	var c := Vector2(screen.x * 0.5, screen.y * CARD_Y)
	for _i in count:
		_particles.append({
			"pos": c + Vector2(randf_range(-screen.x * 0.35, screen.x * 0.35), randf_range(-100, 300)),
			"vel": Vector2(randf_range(-20, 20), randf_range(-160, -60)),
			"life": randf_range(1.2, 2.6), "size": randf_range(3.0, 7.0),
			"color": Color(1.0, randf_range(0.8, 0.95), randf_range(0.4, 0.7)),
		})


func _spawn_smoke(screen: Vector2, count: int) -> void:
	var c := Vector2(screen.x * 0.5, screen.y * CARD_Y)
	for _i in count:
		_particles.append({
			"pos": c + Vector2(randf_range(-screen.x * 0.3, screen.x * 0.3), randf_range(0, 300)),
			"vel": Vector2(randf_range(-30, 30), randf_range(-90, -30)),
			"life": randf_range(1.5, 3.0), "size": randf_range(18.0, 40.0),
			"color": Color(randf_range(0.3, 0.5), 0.05, 0.05),
		})


func _draw_particles() -> void:
	for p in _particles:
		var a := clampf(float(p["life"]), 0.0, 1.0)
		var col: Color = p["color"]
		var sz := float(p["size"])
		if _success:
			_fx.draw_circle(p["pos"], sz * 2.2, Color(col, a * 0.18))
			_fx.draw_circle(p["pos"], sz, Color(col, a))
		else:
			_fx.draw_circle(p["pos"], sz, Color(col, a * 0.35))


## Drawn stand-in for the array art.
func _draw_fallback_array(c: Control) -> void:
	var centre := c.size * 0.5
	var r := c.size.x * 0.45
	var col := Color(1.0, 0.85, 0.45) if _success else Color(0.8, 0.25, 0.2)
	for i in 4:
		c.draw_arc(centre, r * (1.0 - i * 0.18), 0.0, TAU, 96, Color(col, 0.7 - i * 0.12), 4.0, true)
	for k in 8:
		var a := TAU * k / 8.0
		c.draw_line(centre + Vector2(cos(a), sin(a)) * r * 0.46, centre + Vector2(cos(a), sin(a)) * r,
			Color(col, 0.5), 2.0, true)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _load(art_name: String) -> Texture2D:
	var path := ART_DIR + art_name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _image(art_name: String) -> TextureRect:
	var tex := _load(art_name)
	if tex == null:
		return null
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Scales the plaque text down until it fits, and keeps it centred on
## the plaque's text area.
##
## A container's minimum size is only known after a layout pass, so
## measuring in the same frame the labels were added returned a stale
## size: nothing was scaled down and the box never re-centred, so long
## lines spilled past the plaque and were clipped. Two frames is what
## screen_router waits for the same reason.
func _fit_plaque_text(box: Control, v: Control, base_pos: Vector2, base_size: Vector2) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(box) or not is_instance_valid(v):
		return

	var need := v.get_combined_minimum_size()
	if need.x <= 0.0 or need.y <= 0.0:
		return

	var fit := minf(1.0, minf(base_size.x / need.x, base_size.y / need.y))
	var box_size := Vector2(maxf(base_size.x, need.x), maxf(base_size.y, need.y))
	var centre := base_pos + base_size * 0.5
	box.size = box_size
	box.position = centre - box_size * 0.5
	box.pivot_offset = box_size * 0.5
	box.scale = Vector2(fit, fit)


func _text(value: String, font_size: int, color: Color, heading: bool) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", maxi(font_size, 12))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 8 if heading else 5)
	if heading:
		l.add_theme_color_override("font_shadow_color", Color(color, 0.45))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 16)
	return l
