class_name ChatBox
extends CanvasLayer

# =========================================================
# Chat: World, Sect and Whispers.
#   var button := ChatBox.make_button()   # round icon
#   ChatBox.open(self)                    # the panel itself
#
# Built like MailPopup: a small icon button on the battle screen
# with an unread badge, opening a panel when tapped.
#
# Only polls messages while the panel is OPEN (Chat.POLL_SECONDS).
# The button itself checks the unread count far more slowly
# (BADGE_SECONDS) — every player polling forever adds up fast on a
# free-tier project.
# =========================================================

## Your chat icon. Falls back to a drawn speech bubble if it's missing.
const ICON_PATH := "res://assets/ui/chat.png"
## Button size in pixels. Raise or lower to taste.
const ICON_SIZE := 108.0

## How often the button rechecks the unread count, in seconds.
const BADGE_SECONDS := 30.0

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_WORLD := Color("8ff0ff")
const COL_SECT := Color("b9d4ff")
const COL_WHISPER := Color("e0a8ff")
const COL_ALERT := Color("ff4d4d")

var _channel: int = Chat.Channel.WORLD
var _sect_id := ""
var _whisper_target := ""
var _whisper_name := ""

## Newest id seen per channel, so polls only fetch what is new.
var _last_id := {}

var _poll_left := 0.0
var _send_cooldown := 0.0
var _busy := false

var _root: Control
var _panel: PanelContainer
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit
var _send: OrnateButton
var _tab_buttons := {}
var _hint: Label


static func open(host: Node) -> ChatBox:
	if not Chat.available():
		return null
	var box := ChatBox.new()
	host.get_tree().root.add_child.call_deferred(box)
	return box


## Round chat icon with the unread badge. Uses your icon when it exists.
static func make_button() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	if ResourceLoader.exists(ICON_PATH):
		var art := TextureRect.new()
		art.texture = load(ICON_PATH)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(art)
		b.button_down.connect(func(): art.modulate = Color(0.82, 0.82, 0.88))
		b.button_up.connect(func(): art.modulate = Color.WHITE)
	else:
		b.draw.connect(_draw_bubble.bind(b))

	# Unread badge drawn on top of the icon
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.set_meta("unread", 0)
	badge.draw.connect(_draw_badge.bind(badge))
	b.add_child(badge)

	# There is no "you have mail" signal for chat, so the badge asks
	# the server now and then. Only the count, never the messages.
	var timer := Timer.new()
	timer.wait_time = BADGE_SECONDS
	timer.autostart = true
	timer.timeout.connect(func(): _refresh_badge(badge))
	b.add_child(timer)
	_refresh_badge(badge)

	b.pressed.connect(func(): ChatBox.open(b))
	return b


static func _refresh_badge(badge: Control) -> void:
	if not Chat.available():
		return
	var n := await Chat.unread_count()
	if not is_instance_valid(badge):
		return
	badge.set_meta("unread", n)
	badge.queue_redraw()


## Red dot with the unread count, top-right of the icon.
static func _draw_badge(c: Control) -> void:
	var n := int(c.get_meta("unread", 0))
	if n <= 0:
		return
	var r := c.size.x * 0.16
	var p := Vector2(c.size.x - r - 4.0, r + 4.0)
	c.draw_circle(p, r + 2.0, Color(0, 0, 0, 0.55))
	c.draw_circle(p, r, COL_ALERT)
	c.draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.26, Color(1, 1, 1, 0.6))
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.1)
	var text := str(n) if n < 100 else "99+"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, p + Vector2(-w * 0.5, fs * 0.38), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Fallback icon: a rounded speech bubble in the game's gold.
static func _draw_bubble(b: Button) -> void:
	var s := b.size
	var pad := s.x * 0.12
	var body := Rect2(pad, pad, s.x - pad * 2.0, s.y * 0.58)
	var radius := body.size.y * 0.32

	b.draw_circle(s * 0.5, s.x * 0.46, Color(0, 0, 0, 0.35))
	_draw_round_rect(b, body.grow(2.0), radius + 2.0, Color(0, 0, 0, 0.45))
	_draw_round_rect(b, body, radius, Color("13233d"))

	# Tail
	var tail := PackedVector2Array([
		Vector2(body.position.x + body.size.x * 0.24, body.end.y - 2.0),
		Vector2(body.position.x + body.size.x * 0.46, body.end.y - 2.0),
		Vector2(body.position.x + body.size.x * 0.26, body.end.y + s.y * 0.2)])
	b.draw_colored_polygon(tail, Color("13233d"))

	# Three dots, so it reads as chat at a glance
	var dot_y := body.position.y + body.size.y * 0.5
	var gap := body.size.x * 0.2
	for i in 3:
		b.draw_circle(Vector2(body.get_center().x + (i - 1) * gap, dot_y),
			body.size.y * 0.1, COL_GOLD)


static func _draw_round_rect(c: CanvasItem, r: Rect2, radius: float, colour: Color) -> void:
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	c.draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), colour)
	c.draw_rect(Rect2(r.position.x, r.position.y + rad, rad, r.size.y - rad * 2.0), colour)
	c.draw_rect(Rect2(r.end.x - rad, r.position.y + rad, rad, r.size.y - rad * 2.0), colour)
	c.draw_circle(Vector2(r.position.x + rad, r.position.y + rad), rad, colour)
	c.draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, colour)
	c.draw_circle(Vector2(r.position.x + rad, r.end.y - rad), rad, colour)
	c.draw_circle(Vector2(r.end.x - rad, r.end.y - rad), rad, colour)


# ---------------------------------------------------------
# PANEL
# ---------------------------------------------------------

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_id = {Chat.Channel.WORLD: 0, Chat.Channel.SECT: 0, Chat.Channel.WHISPER: 0}
	_build()
	_show()
	_refresh_sect()
	_reload()


func _build() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	_root.add_child(dim)

	var close_away := Button.new()
	close_away.flat = true
	close_away.focus_mode = Control.FOCUS_NONE
	close_away.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_away.pressed.connect(_close)
	_root.add_child(close_away)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(940, 1180)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(COL_GOLD, 0.2)
	sb.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.resized.connect(func(): _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)

	# Channel tabs + close
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for channel in [Chat.Channel.WORLD, Chat.Channel.SECT, Chat.Channel.WHISPER]:
		var b := _tab_button(str(Chat.CHANNEL_NAMES[channel]), channel)
		tabs.add_child(b)
		_tab_buttons[channel] = b

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(spacer)

	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 28)
	close.add_theme_color_override("font_color", COL_DIM)
	close.pressed.connect(_close)
	tabs.add_child(close)

	v.add_child(_line())

	_hint = _label("", 18, COL_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.visible = false
	v.add_child(_hint)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)

	v.add_child(_line())

	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 8)
	v.add_child(entry)

	_input = LineEdit.new()
	_input.placeholder_text = "Say something..."
	_input.max_length = Chat.MAX_LENGTH
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 22)
	_input.text_submitted.connect(func(_t: String): _on_send())
	entry.add_child(_input)

	_send = OrnateButton.new()
	_send.text = "Send"
	_send.custom_minimum_size = Vector2(150, 64)
	_send.add_theme_font_size_override("font_size", 22)
	_send.pressed.connect(_on_send)
	entry.add_child(_send)

	_apply_tab_look()


func _show() -> void:
	_root.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.2)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	_input.release_focus()
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


func _tab_button(title: String, channel: int) -> Button:
	var b := Button.new()
	b.text = title
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func(): _set_channel(channel))
	return b


func _set_channel(channel: int) -> void:
	if _channel == channel:
		return
	_channel = channel
	_apply_tab_look()
	_reload()


func _apply_tab_look() -> void:
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		var on := int(key) == _channel
		b.add_theme_color_override("font_color", COL_TITLE if on else COL_DIM)
		b.disabled = int(key) == Chat.Channel.SECT and _sect_id == ""


# ---------------------------------------------------------
# LOADING
# ---------------------------------------------------------

func _refresh_sect() -> void:
	var m = await Sects.my_membership()
	if not is_instance_valid(self):
		return
	if m is Dictionary and not (m as Dictionary).is_empty():
		_sect_id = str(m["sect_id"])
	else:
		_sect_id = ""
	_apply_tab_look()


func _target_for(channel: int) -> String:
	match channel:
		Chat.Channel.SECT:
			return _sect_id
		Chat.Channel.WHISPER:
			return _whisper_target
		_:
			return ""


func _reload() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_last_id[_channel] = 0
	_update_hint()
	await _poll(true)


func _update_hint() -> void:
	var no_sect := _channel == Chat.Channel.SECT and _sect_id == ""
	var no_target := _channel == Chat.Channel.WHISPER and _whisper_target == ""
	if no_sect:
		_hint.text = "Join a sect to use this channel."
	elif no_target:
		_hint.text = "Tap a cultivator's name in World chat to whisper them."
	elif _channel == Chat.Channel.WHISPER:
		_hint.text = "Whispering %s" % _whisper_name
	_hint.visible = no_sect or no_target or _channel == Chat.Channel.WHISPER
	_input.editable = not no_sect and not no_target


func _poll(force := false) -> void:
	if _busy:
		return
	var channel := _channel
	var target := _target_for(channel)
	if channel != Chat.Channel.WORLD and target == "":
		return
	_busy = true
	var after := int(_last_id[channel])
	var rows := await Chat.messages(channel, after, target)
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# The player may have switched channels while this was in flight.
	if channel != _channel:
		return
	if rows.is_empty():
		if force:
			_add_system("No messages yet. Say hello.")
		return
	for row in rows:
		_add_message(channel, row)
		_last_id[channel] = maxi(int(_last_id[channel]), int(row["id"]))
	_trim()
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## Keeps the list from growing without limit during a long session.
func _trim() -> void:
	var extra := _rows.get_child_count() - 120
	var i := 0
	while i < extra:
		_rows.get_child(0).queue_free()
		i += 1


# ---------------------------------------------------------
# MESSAGE ROWS
# ---------------------------------------------------------

func _add_message(channel: int, row: Dictionary) -> void:
	var who := ""
	var user_id := ""
	if channel == Chat.Channel.WHISPER:
		who = str(row.get("from_name", "Cultivator"))
		user_id = str(row.get("from_id", ""))
	else:
		who = str(row.get("name", "Cultivator"))
		user_id = str(row.get("user_id", ""))
	var body := str(row.get("body", ""))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(line)

	var name_button := Button.new()
	name_button.text = who + ":"
	name_button.flat = true
	name_button.focus_mode = Control.FOCUS_NONE
	name_button.add_theme_font_size_override("font_size", 20)
	name_button.add_theme_color_override("font_color", _name_colour(channel))
	name_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if user_id != "" and user_id != Backend.user_id:
		name_button.pressed.connect(func(): _open_actions(user_id, who, body))
	line.add_child(name_button)

	var text := _label(body, 20, COL_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)


func _add_system(message: String) -> void:
	var l := _label(message, 18, COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


func _name_colour(channel: int) -> Color:
	match channel:
		Chat.Channel.SECT:
			return COL_SECT
		Chat.Channel.WHISPER:
			return COL_WHISPER
		_:
			return COL_WORLD


# ---------------------------------------------------------
# SENDING
# ---------------------------------------------------------

func _on_send() -> void:
	if _busy or _send_cooldown > 0.0:
		return
	var body := _input.text.strip_edges()
	if body == "":
		return
	_busy = true
	_send.disabled = true
	var r := await Chat.send(_channel, body, _target_for(_channel))
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_send.disabled = false
	if not r["ok"]:
		_add_system(str(r["error"]))
		return
	_input.text = ""
	_send_cooldown = Chat.cooldown(_channel)
	await _poll()


# ---------------------------------------------------------
# PLAYER ACTIONS (whisper / friend / block / report)
# ---------------------------------------------------------

func _open_actions(user_id: String, who: String, body: String) -> void:
	var menu := PopupMenu.new()
	menu.add_item("Whisper " + who, 0)
	menu.add_item("Add friend", 1)
	menu.add_separator()
	menu.add_item("Block " + who, 2)
	menu.add_item("Report message", 3)
	add_child(menu)
	menu.id_pressed.connect(func(id: int): _do_action(id, user_id, who, body))
	menu.popup_hide.connect(menu.queue_free)
	# Centred rather than at the cursor: there is no mouse on a phone.
	var screen := get_viewport().get_visible_rect().size
	menu.popup_centered()
	menu.position = Vector2i(screen * 0.5 - Vector2(menu.size) * 0.5)


func _do_action(id: int, user_id: String, who: String, body: String) -> void:
	match id:
		0:
			_whisper_target = user_id
			_whisper_name = who
			if _channel == Chat.Channel.WHISPER:
				_reload()
			else:
				_set_channel(Chat.Channel.WHISPER)
		1:
			var r := await Friends.request(user_id)
			_add_system(("Friend request sent to %s." % who) if r["ok"] else str(r["error"]))
		2:
			var r2 := await Chat.block(user_id)
			if r2["ok"]:
				_add_system("%s is blocked. Their messages are hidden." % who)
				_reload()
			else:
				_add_system(str(r2["error"]))
		3:
			var r3 := await Chat.report(user_id, _channel, body)
			_add_system("Report sent." if r3["ok"] else str(r3["error"]))


# ---------------------------------------------------------
# POLLING
# ---------------------------------------------------------

func _process(delta: float) -> void:
	if _send_cooldown > 0.0:
		_send_cooldown = maxf(0.0, _send_cooldown - delta)
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = Chat.POLL_SECONDS
	_poll()


# ---------------------------------------------------------
# DRAWING HELPERS
# ---------------------------------------------------------

func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(COL_GOLD, 0.0), Color(COL_GOLD, 0.6), Color(COL_GOLD, 0.0)]), 1.5, true)
	)
	return line


func _label(value: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	return l
