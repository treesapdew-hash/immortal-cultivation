class_name SettingsPopup
extends CanvasLayer

# =========================================================
# Settings screen, built in code. Save as
#   res://ui/settings_popup.gd
#
#   SettingsPopup.open(self)
#
# Values live in settings.gd (their own file, not the save).
# =========================================================

const LAYER := 58

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")

var _body: VBoxContainer
var _toast_holder: Control


static func open(host: Node) -> SettingsPopup:
	var p := SettingsPopup.new()
	host.get_tree().root.add_child(p)
	return p


func _ready() -> void:
	layer = LAYER
	_build()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			queue_free()
	)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(960, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("Settings", 38, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(160, 52)
	close.pressed.connect(queue_free)
	head.add_child(close)
	v.add_child(_line())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 1250)
	v.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 6)
	scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	pad.add_child(_body)

	_toast_holder = Control.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_holder)
	_toast_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	_section("Gameplay")
	_toggle_row("Damage numbers", "Numbers that pop up when units are hit.", "damage_numbers")
	_toggle_row("Screen flashes & shake", "Flashes and shaking in Tribulation and breakthroughs.", "screen_effects")
	_choice_row("Stage clear banner", "The banner after each stage.", "stage_banner",
		[["Full", "full"], ["Short", "short"], ["Off", "off"]])
	_choice_row("Breakthrough ceremony", "Fast skips straight to the result.", "fast_ceremony",
		[["Full", false], ["Fast", true]])
	_choice_row("God's turn", "Short shows only the strike.", "short_god",
		[["Full", false], ["Short", true]])

	_section("Audio")
	_slider_row("Music", "music_volume")
	_slider_row("Sound effects", "sfx_volume")
	_toggle_row("Mute all", "", "mute")

	_section("Performance")
	_choice_row("Frame rate", "30 saves battery.", "fps", [["30 FPS", 30], ["60 FPS", 60]])

	_section("Account")
	_info_row("Name", GameState.mc_name)
	# The online account ID when signed in: quote it for support or deletion requests
	_info_row("Player ID", Backend.user_id if Backend.user_id != "" else str(Settings.get_value("player_id")))
	_info_row("Version", Settings.VERSION)
	_action_row("Report a bug", "Copies your version, stage and recent log. Paste it in your message.",
		"Copy Report", OrnateButton.Variant.GOLD, _on_report)
	_action_row("Login & Cloud Save", _account_status(), "Manage", OrnateButton.Variant.GOLD, _on_account)
	_redeem_row()
	_action_row("Replay tutorials", "Elder Yunhe guides you through each feature again.",
		"Replay", OrnateButton.Variant.DARK, _on_replay_tutorials)
	_soon_row("Language")
	_action_row("Reset account", "Deletes ALL progress and starts over. Cannot be undone.",
		"Reset", OrnateButton.Variant.CRIMSON, _on_reset)

	_section("Community")
	_action_row("Discord", "News, codes and help from other cultivators.",
		"Join", OrnateButton.Variant.GOLD, func(): OS.shell_open(Settings.DISCORD_URL))

	_section("About")
	var credits := _label("Immortal Cultivation\nFont: Trajan Pro\nMade with Godot Engine", 17, COL_DIM)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.add_child(credits)
	_action_row("Privacy policy", "", "Open", OrnateButton.Variant.DARK, func(): OS.shell_open(Settings.PRIVACY_URL))
	_action_row("Terms of service", "", "Open", OrnateButton.Variant.DARK, func(): OS.shell_open(Settings.TERMS_URL))


# ---------------------------------------------------------
# ROWS
# ---------------------------------------------------------

func _section(title: String) -> void:
	if _body.get_child_count() > 0:
		_body.add_child(_line())
	_body.add_child(_label(title, 26, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))


func _row(title: String, sub: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(texts)
	texts.add_child(_label(title, 21, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	if sub != "":
		var s := _label(sub, 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(s)
	_body.add_child(h)
	return h


func _toggle_row(title: String, sub: String, key: String) -> void:
	var h := _row(title, sub)
	var on := Settings.is_on(key)
	var b := OrnateButton.new()
	b.text = "On" if on else "Off"
	b.variant = OrnateButton.Variant.GOLD if on else OrnateButton.Variant.DARK
	b.custom_minimum_size = Vector2(150, 52)
	b.pressed.connect(func():
		Settings.set_value(key, not Settings.is_on(key))
		_rebuild()
	)
	h.add_child(b)


## options: [[label, value], ...]
func _choice_row(title: String, sub: String, key: String, options: Array) -> void:
	var h := _row(title, sub)
	var current = Settings.get_value(key)
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	h.add_child(group)
	for opt in options:
		var picked: bool = str(opt[1]) == str(current)
		var b := OrnateButton.new()
		b.text = str(opt[0])
		b.variant = OrnateButton.Variant.GOLD if picked else OrnateButton.Variant.DARK
		b.custom_minimum_size = Vector2(118, 52)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func():
			Settings.set_value(key, opt[1])
			_rebuild()
		)
		group.add_child(b)


func _slider_row(title: String, key: String) -> void:
	var h := _row(title, "")
	var value := int(Settings.get_value(key))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.5)
	track.border_color = Color(COL_GOLD, 0.5)
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = COL_GOLD
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	h.add_child(slider)
	var num := _label("%d" % value, 20, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	num.custom_minimum_size.x = 56
	h.add_child(num)
	slider.value_changed.connect(func(v: float):
		num.text = "%d" % int(v)
		Settings.set_value(key, int(v))
	)


func _info_row(title: String, value: String) -> void:
	var h := _row(title, "")
	h.add_child(_label(value, 20, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT))


func _soon_row(title: String) -> void:
	var h := _row(title, "")
	h.add_child(_label("Coming soon", 18, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT))


## Code entry, inline rather than its own popup: it is a single field.
## The server decides what a code is worth and whether it was used.
func _redeem_row() -> void:
	var h := _row("Redeem code", "Codes from events and the Discord server.")

	var field := LineEdit.new()
	field.placeholder_text = "Enter code"
	field.max_length = Redeem.MAX_LENGTH
	field.custom_minimum_size = Vector2(230, 54)
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_theme_font_size_override("font_size", 20)
	h.add_child(field)

	var button := OrnateButton.new()
	button.text = "Redeem"
	button.variant = OrnateButton.Variant.GOLD
	button.custom_minimum_size = Vector2(170, 54)
	h.add_child(button)

	var submit := func() -> void:
		if button.disabled:
			return
		button.disabled = true
		var r := await Redeem.claim(field.text)
		# The panel rebuilds on some actions, which frees these.
		if not is_instance_valid(button) or not is_instance_valid(field):
			return
		button.disabled = false
		if bool(r["ok"]):
			field.text = ""
			_toast(str(r["text"]), COL_OK)
		else:
			_toast(str(r["error"]), COL_BAD)

	button.pressed.connect(submit)
	var on_enter := func(_t: String) -> void:
		submit.call()
	field.text_submitted.connect(on_enter)


func _action_row(title: String, sub: String, button_text: String, variant: OrnateButton.Variant, action: Callable) -> void:
	var h := _row(title, sub)
	var b := OrnateButton.new()
	b.text = button_text
	b.variant = variant
	b.custom_minimum_size = Vector2(200, 54)
	b.pressed.connect(action)
	h.add_child(b)


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _account_status() -> String:
	if not Backend.is_configured():
		return "Offline build."
	if Backend.is_guest:
		return "Guest: your progress is only on this device. Link an account to keep it safe."
	return "Linked to %s. Your progress is saved to the cloud." % Backend.email


func _on_account() -> void:
	var popup := AccountPopup.open_account(self)
	popup.tree_exited.connect(func():
		if is_instance_valid(self):
			_rebuild()
	)


func _on_report() -> void:
	DisplayServer.clipboard_set(Settings.bug_report())
	_toast("Bug report copied. Paste it in your message.", COL_OK)


## Forgets which tutorials are finished and restarts the intro.
## Settings closes first: the tutorial spotlights the game behind it,
## so leaving this panel up would cover what it is pointing at.
func _on_replay_tutorials() -> void:
	var start_again := func() -> void:
		var scene := get_tree().current_scene
		queue_free()
		if scene != null:
			Tutorial.replay(scene)
	_confirm("Replay tutorials?",
		"Elder Yunhe will guide you through each feature again as you reach it.\n"
		+ "Your progress is not affected.", "Replay", start_again)


## Two confirmations before wiping the account.
## Wipes the save. The online account stays, so anything the server
## remembers about it has to be let go here or it outlives the
## character it belonged to — redeem codes being the one testers hit.
func _do_reset() -> void:
	await Redeem.reset_claims()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	GameState.reset_account()
	queue_free()
	get_tree().reload_current_scene()


func _on_reset() -> void:
	_confirm("Reset account?", "This deletes ALL your progress: stages, partners, gear, everything, "
		+ "including your cloud save, Arena standing and leaderboard places.\n"
		+ "Your settings are kept.", "Continue", func():
		_confirm("Are you absolutely sure?", "There is no way to undo this.", "Delete Everything", _do_reset)
	)


func _confirm(title: String, body: String, ok_text: String, on_ok: Callable) -> void:
	var holder := Control.new()
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	holder.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a0c0c")
	sb.border_color = COL_BAD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = 720
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_label(title, 30, COL_BAD, HORIZONTAL_ALIGNMENT_CENTER, true))
	var b := _label(body, 19, COL_TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var cancel := OrnateButton.new()
	cancel.text = "Cancel"
	cancel.variant = OrnateButton.Variant.DARK
	cancel.custom_minimum_size = Vector2(200, 58)
	cancel.pressed.connect(holder.queue_free)
	row.add_child(cancel)
	var ok := OrnateButton.new()
	ok.text = ok_text
	ok.variant = OrnateButton.Variant.CRIMSON
	ok.custom_minimum_size = Vector2(260, 58)
	ok.pressed.connect(func():
		holder.queue_free()
		on_ok.call()
	)
	row.add_child(ok)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(COL_GOLD, 0.0), Color(COL_GOLD, 0.7), Color(COL_GOLD, 0.0)]), 1.5, true)
	)
	return line


func _toast(message: String, color: Color) -> void:
	var l := _label(message, 26, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	_toast_holder.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 220
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.tween_callback(l.queue_free)


func _label(value: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, glow := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(COL_GOLD, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
