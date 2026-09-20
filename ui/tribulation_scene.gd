class_name TribulationScene
extends CanvasLayer

# =========================================================
# Tribulation Lightning scene, built in code. Save as
#   res://ui/tribulation_scene.gd
#
#   TribulationScene.open(host)   # after Tribulation.can_start() == ""
#
# Rules and rewards are in tribulation.gd. Optional art:
#   assets/ui/effects/tribulation_cloud.png  (clouds at the top)
# =========================================================

signal finished

const CLOUD_ART := "res://assets/ui/effects/tribulation_cloud.png"
const LAYER := 58

const COL_SKY_TOP := Color("0a0716")
const COL_SKY_BOTTOM := Color("1a1230")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")
const COL_BOLT := Color("d9c8ff")
const COL_BOLT_GLOW := Color("8a5cff")

## Seconds per step at normal speed.
const BOLT_GAP := 0.2
const WAVE_GAP := 0.35
const SPEEDS := [1.0, 2.0, 4.0]

var _root: Control
var _flash: ColorRect
var _fx: Node2D
var _wave_label: Label
var _sub_label: Label
var _team_row: HBoxContainer
var _controls: HBoxContainer
var _speed_button: OrnateButton

var _units: Array = []        # CombatUnit
var _cards: Array = []        # Control per unit
var _bars: Array = []         # Control per unit (HP bar)
var _speed := 1.0
var _skipping := false
var _survived := 0


static func open(host: Node) -> TribulationScene:
	var scene := TribulationScene.new()
	host.get_tree().root.add_child(scene)
	return scene


func _ready() -> void:
	layer = LAYER
	Tribulation.begin()
	_units = Tribulation.make_team()
	_build()
	_run.call_deferred()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.draw.connect(_draw_sky)

	# Storm clouds
	var clouds: Control
	if ResourceLoader.exists(CLOUD_ART):
		var tex := TextureRect.new()
		tex.texture = load(CLOUD_ART) as Texture2D
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		clouds = tex
	else:
		clouds = Control.new()
		clouds.draw.connect(_draw_clouds.bind(clouds))
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(clouds)
	clouds.anchor_right = 1.0
	clouds.anchor_bottom = 0.0
	clouds.offset_bottom = 520

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 14)
	_root.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 70
	v.offset_bottom = -60

	v.add_child(_label("Tribulation Lightning", 44, COL_TITLE, true))
	v.add_child(_label("Best: %d waves" % Tribulation.best(), 20, COL_DIM))

	var gap := Control.new()
	gap.custom_minimum_size.y = 260
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)

	_wave_label = _label("The heavens gather...", 56, Color("e8dcff"), true)
	v.add_child(_wave_label)
	_sub_label = _label("", 24, COL_GOLD)
	v.add_child(_sub_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)

	_team_row = HBoxContainer.new()
	_team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_team_row.add_theme_constant_override("separation", 10)
	_team_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_team_row)
	for unit in _units:
		_team_row.add_child(_unit_card(unit))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 40
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer2)

	_controls = HBoxContainer.new()
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls.add_theme_constant_override("separation", 20)
	v.add_child(_controls)
	_speed_button = OrnateButton.new()
	_speed_button.text = "Speed x1"
	_speed_button.variant = OrnateButton.Variant.DARK
	_speed_button.custom_minimum_size = Vector2(220, 60)
	_speed_button.pressed.connect(_toggle_speed)
	_controls.add_child(_speed_button)
	var skip := OrnateButton.new()
	skip.text = "Skip"
	skip.variant = OrnateButton.Variant.DARK
	skip.custom_minimum_size = Vector2(220, 60)
	skip.pressed.connect(_skip)
	_controls.add_child(skip)

	# Lightning bolts and the white flash sit on top
	_fx = Node2D.new()
	add_child(_fx)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unit_card(unit: CombatUnit) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 160
	card.add_theme_constant_override("separation", 4)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(160, 210)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = unit.sprite_texture
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)

	var name_l := _label(unit.display_name, 17, unit.name_color)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size.x = 160
	card.add_child(name_l)

	var bar := Control.new()
	bar.custom_minimum_size = Vector2(150, 14)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		var fill := clampf(float(unit.current_hp) / maxf(float(unit.max_hp), 1.0), 0.0, 1.0)
		bar.draw_rect(Rect2(0, 0, w, 14), Color(0, 0, 0, 0.6))
		bar.draw_rect(Rect2(0, 0, w * fill, 14), COL_OK.lerp(COL_BAD, 1.0 - fill))
		bar.draw_rect(Rect2(0, 0, w, 14), Color(COL_GOLD, 0.5), false, 1.0)
	)
	card.add_child(bar)

	_cards.append(card)
	_bars.append(bar)
	return card


# ---------------------------------------------------------
# THE STORM
# ---------------------------------------------------------

func _run() -> void:
	await _wait(1.0)
	var wave := 0
	while wave < Tribulation.MAX_WAVES and _alive_count() > 0:
		wave += 1
		_wave_label.text = "Wave %d / %d" % [wave, Tribulation.MAX_WAVES]
		var power := Tribulation.bolt_power(wave)

		if Tribulation.is_great(wave):
			_sub_label.text = "Great Tribulation!"
			await _wait(0.5)
			for i in _units.size():
				if _is_alive(i):
					_strike(i, power * Tribulation.GREAT_MULT, true)
			await _wait(BOLT_GAP * 2.0)
		else:
			_sub_label.text = "%d bolt%s" % [Tribulation.bolts_in(wave), "" if Tribulation.bolts_in(wave) == 1 else "s"]
			for _b in Tribulation.bolts_in(wave):
				var target := _random_alive()
				if target < 0:
					break
				_strike(target, power, false)
				await _wait(BOLT_GAP)

		if _alive_count() <= 0:
			break
		_survived = wave

		# Survivors draw on the storm's Qi
		for i in _units.size():
			if _is_alive(i):
				var unit: CombatUnit = _units[i]
				unit.current_hp = mini(unit.max_hp, unit.current_hp + floori(float(unit.max_hp) * Tribulation.HEAL_SHARE))
				_update_card(i)
		await _wait(WAVE_GAP)

	_end()


func _strike(index: int, power: float, great: bool) -> void:
	var unit: CombatUnit = _units[index]
	var dmg := Tribulation.damage_to(unit, power)
	unit.take_damage(dmg)
	_update_card(index)
	if _skipping:
		return
	_draw_bolt(index, great)
	_float_number(index, dmg)
	if Settings.is_on("screen_effects"):
		var tw := create_tween()
		_flash.color.a = 0.45 if great else 0.25
		tw.tween_property(_flash, "color:a", 0.0, 0.3 / _speed)


func _update_card(index: int) -> void:
	var bar: Control = _bars[index]
	bar.queue_redraw()
	var card: Control = _cards[index]
	card.modulate = Color(0.35, 0.35, 0.4) if not _is_alive(index) else Color.WHITE


func _draw_bolt(index: int, great: bool) -> void:
	var card: Control = _cards[index]
	var rect := card.get_global_rect()
	var target := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.35)
	var start := Vector2(target.x + randf_range(-120, 120), 140)
	var points := PackedVector2Array([start])
	var steps := 9
	for s in range(1, steps):
		var t := float(s) / float(steps)
		var p := start.lerp(target, t)
		p.x += randf_range(-40, 40)
		points.append(p)
	points.append(target)

	for layer_i in 2:
		var line := Line2D.new()
		line.points = points
		line.width = (24.0 if layer_i == 0 else 7.0) * (1.4 if great else 1.0)
		line.default_color = Color(COL_BOLT_GLOW, 0.45) if layer_i == 0 else COL_BOLT
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		_fx.add_child(line)
		var tw := line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.35 / _speed)
		tw.tween_callback(line.queue_free)

	# Shake the struck card
	if not Settings.is_on("screen_effects"):
		return
	var home := card.position
	var shake := card.create_tween()
	for _k in 4:
		shake.tween_property(card, "position", home + Vector2(randf_range(-8, 8), randf_range(-4, 4)), 0.03 / _speed)
	shake.tween_property(card, "position", home, 0.03 / _speed)


func _float_number(index: int, amount: int) -> void:
	var card: Control = _cards[index]
	var rect := card.get_global_rect()
	var l := _label("-%s" % NumberFormat.short(amount), 30, Color("e8dcff"))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.2, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	_root.add_child(l)
	l.size = Vector2(rect.size.x, 40)
	l.global_position = rect.position + Vector2(0, rect.size.y * 0.2)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.8 / _speed)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4 / _speed).set_delay(0.4 / _speed)
	tw.tween_callback(l.queue_free)


func _is_alive(index: int) -> bool:
	var unit: CombatUnit = _units[index]
	return unit.current_hp > 0


func _alive_count() -> int:
	var n := 0
	for i in _units.size():
		if _is_alive(i):
			n += 1
	return n


func _random_alive() -> int:
	var alive: Array = []
	for i in _units.size():
		if _is_alive(i):
			alive.append(i)
	return -1 if alive.is_empty() else int(alive.pick_random())


func _wait(seconds: float) -> void:
	if _skipping:
		return
	await get_tree().create_timer(seconds / _speed).timeout


func _toggle_speed() -> void:
	var at := SPEEDS.find(_speed)
	_speed = float(SPEEDS[(at + 1) % SPEEDS.size()])
	_speed_button.text = "Speed x%d" % int(_speed)


func _skip() -> void:
	_skipping = true
	_controls.visible = false


# ---------------------------------------------------------
# RESULT
# ---------------------------------------------------------

func _end() -> void:
	_controls.visible = false
	var got := Tribulation.finish(_survived)
	_wave_label.text = "Survived %d wave%s" % [_survived, "" if _survived == 1 else "s"]
	_sub_label.text = "New best!" if bool(got["new_best"]) else "Best: %d waves" % Tribulation.best()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("120c24")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = 700
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_label("Tribulation Weathered" if _survived > 0 else "Struck Down", 38, COL_TITLE, true))
	v.add_child(_label("%d / %d waves survived" % [_survived, Tribulation.MAX_WAVES], 24, COL_TEXT))
	if bool(got["new_best"]):
		v.add_child(_label("New personal best!", 22, COL_OK))

	var lines := PackedStringArray()
	if int(got["qi"]) > 0:
		lines.append("+%s Qi" % NumberFormat.short(int(got["qi"])))
	if int(got["stones"]) > 0:
		lines.append("+%s Spirit Stones" % NumberFormat.short(int(got["stones"])))
	if int(got["jade"]) > 0:
		lines.append("+%s Immortal Jade" % NumberFormat.short(int(got["jade"])))
	var items: Dictionary = got["items"]
	for id in items:
		lines.append("+%s %s" % [NumberFormat.short(int(items[id])), ItemDB.get_item(id).get("name", id)])
	if lines.is_empty():
		lines.append("The heavens give nothing to those who fall at once.")
	for line in lines:
		v.add_child(_label(line, 22, COL_OK if line.begins_with("+") else COL_DIM))

	var next := _next_milestone()
	if next > 0:
		v.add_child(_label("Next milestone: wave %d" % next, 18, COL_DIM))

	var done := OrnateButton.new()
	done.text = "Claim"
	done.custom_minimum_size = Vector2(260, 62)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close)
	v.add_child(done)


func _next_milestone() -> int:
	var best_wave := Tribulation.best()
	var keys: Array = Tribulation.MILESTONES.keys()
	keys.sort()
	for k in keys:
		if int(k) > best_wave:
			return int(k)
	return 0


func _close() -> void:
	finished.emit()
	queue_free()


# ---------------------------------------------------------
# DRAWING
# ---------------------------------------------------------

func _draw_sky() -> void:
	var s := _root.size
	_root.draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_SKY_TOP, COL_SKY_TOP, COL_SKY_BOTTOM, COL_SKY_BOTTOM]))
	# Mountain peak the team stands on
	_root.draw_colored_polygon(PackedVector2Array([
		Vector2(0, s.y), Vector2(0, s.y * 0.86), Vector2(s.x * 0.3, s.y * 0.8),
		Vector2(s.x * 0.5, s.y * 0.76), Vector2(s.x * 0.7, s.y * 0.8), Vector2(s.x, s.y * 0.86), Vector2(s.x, s.y)]),
		Color("0d0a18"))


## Fallback clouds when there's no cloud art yet.
func _draw_clouds(c: Control) -> void:
	var w := c.size.x
	for i in 14:
		var x := w * (float(i) / 13.0)
		var y := 60.0 + sin(float(i) * 1.7) * 40.0
		c.draw_circle(Vector2(x, y), 120.0 + float(i % 3) * 30.0, Color("1c1330"))
	for i in 10:
		var x := w * (float(i) / 9.0) + 40.0
		c.draw_circle(Vector2(x, 170.0 + cos(float(i)) * 30.0), 90.0, Color("241840", 0.9))


func _label(text_value: String, font_size: int, color: Color, glow := false) -> Label:
	var l := Label.new()
	l.text = text_value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(0.55, 0.35, 1.0, 0.45))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 12)
	return l
