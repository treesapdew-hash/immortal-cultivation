class_name ChatBox
extends CanvasLayer

# =========================================================
# The floating chat box on Home.
#   ChatBox.attach(self)
#
# Collapsed it is a thin bar showing the newest message. Tapping
# it opens a panel with three channels: World, Sect and Whispers.
#
# Only polls the server while it is OPEN (Chat.POLL_SECONDS).
# Every player polling forever adds up fast on a free-tier project,
# so closing the box stops the traffic completely.
#
# Hidden on every tab except Home, following ScreenRouter.tab_opened.
# =========================================================

const GOLD := Color("e2c27a")
const TITLE := Color("f2d98a")
const TEXT := Color("c9d4e3")
const DIM := Color("7f8ea3")
const WORLD_NAME := Color("8ff0ff")
const SECT_NAME := Color("b9d4ff")
const WHISPER_NAME := Color("e0a8ff")
const ALERT := Color("e08a6a")

const BAR_HEIGHT := 64
const PANEL_HEIGHT := 620
const SIDE_MARGIN := 12
const BOTTOM_MARGIN := 150   # clears the bottom nav

var _expanded := false
var _channel: int = Chat.Channel.WORLD
var _sect_id := ""
var _whisper_target := ""
var _whisper_name := ""
var _unread := 0

## Newest id seen per channel, so polls only fetch what is new.
var _last_id := {}

var _poll_left := 0.0
var _send_cooldown := 0.0
var _busy := false

var _root: Control
var _bar: PanelContainer
var _bar_label: Label
var _bar_dot: Control
var _panel: PanelContainer
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit
var _send: OrnateButton
var _tab_buttons := {}
var _hint: Label


static func attach(host: Node) -> ChatBox:
	if not Chat.available():
		return null
	var box := ChatBox.new()
	host.get_tree().root.add_child.call_deferred(box)
	return box


func _ready() -> void:
	layer = 55          # under popups (65+), over the home screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_id = {Chat.Channel.WORLD: 0, Chat.Channel.SECT: 0, Chat.Channel.WHISPER: 0}
	_build()
	_follow_router()
	_refresh_sect()
	_refresh_unread()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_bar()
	_build_panel()
	_panel.visible = false


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.anchor_left = 0.0
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = SIDE_MARGIN
	_bar.offset_right = -SIDE_MARGIN
	_bar.offset_top = -BOTTOM_MARGIN - BAR_HEIGHT
	_bar.offset_bottom = -BOTTOM_MARGIN
	_bar.add_theme_stylebox_override("panel", _panel_style(0.82))
	_root.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bar.add_child(row)

	var icon := _speech_icon()
	row.add_child(icon)

	_bar_label = _label("Tap to chat", 22, DIM)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_label.clip_text = true
	row.add_child(_bar_label)

	_bar_dot = _unread_dot()
	row.add_child(_bar_dot)

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(_toggle)
	_bar.add_child(hit)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = SIDE_MARGIN
	_panel.offset_right = -SIDE_MARGIN
	_panel.offset_top = -BOTTOM_MARGIN - PANEL_HEIGHT
	_panel.offset_bottom = -BOTTOM_MARGIN
	_panel.add_theme_stylebox_override("panel", _panel_style(0.95))
	_root.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)

	# Channel tabs + close
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
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
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_color_override("font_color", DIM)
	close.pressed.connect(_toggle)
	tabs.add_child(close)

	v.add_child(_line())

	_hint = _label("", 18, DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.visible = false
	v.add_child(_hint)

	# Messages
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)

	v.add_child(_line())

	# Input
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
	_send.custom_minimum_size = Vector2(130, 60)
	_send.add_theme_font_size_override("font_size", 22)
	_send.pressed.connect(_on_send)
	entry.add_child(_send)


func _tab_button(title: String, channel: int) -> Button:
	var b := Button.new()
	b.text = title
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func(): _set_channel(channel))
	return b


# ---------------------------------------------------------
# VISIBILITY
# ---------------------------------------------------------

## The box belongs to Home: follow the router's tab changes.
func _follow_router() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var router := scene.find_child("LowerStack", true, false)
	if router == null:
		return
	if router.has_signal("tab_opened"):
		router.tab_opened.connect(_on_tab_opened)


func _on_tab_opened(tab: String) -> void:
	var home := tab == "Home"
	_root.visible = home
	if not home and _expanded:
		_collapse()


func _toggle() -> void:
	if _expanded:
		_collapse()
	else:
		_expand()


func _expand() -> void:
	_expanded = true
	_panel.visible = true
	_bar.visible = false
	_poll_left = 0.0
	_apply_tab_look()
	_reload()


func _collapse() -> void:
	_expanded = false
	_panel.visible = false
	_bar.visible = true
	_input.release_focus()
	_refresh_unread()


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
		b.add_theme_color_override("font_color", TITLE if on else DIM)
		b.disabled = int(key) == Chat.Channel.SECT and _sect_id == ""


# ---------------------------------------------------------
# LOADING
# ---------------------------------------------------------

func _refresh_sect() -> void:
	var m = await Sects.my_membership()
	if m is Dictionary and not (m as Dictionary).is_empty():
		_sect_id = str(m["sect_id"])
	else:
		_sect_id = ""
	if is_instance_valid(self):
		_apply_tab_look()


func _target_for(channel: int) -> String:
	match channel:
		Chat.Channel.SECT:
			return _sect_id
		Chat.Channel.WHISPER:
			return _whisper_target
		_:
			return ""


## Clears and refetches the current channel from scratch.
func _reload() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_last_id[_channel] = 0
	_update_hint()
	await _poll(true)


func _update_hint() -> void:
	if _channel == Chat.Channel.SECT and _sect_id == "":
		_hint.text = "Join a sect to use this channel."
		_hint.visible = true
	elif _channel == Chat.Channel.WHISPER and _whisper_target == "":
		_hint.text = "Tap a cultivator's name in World chat to whisper them."
		_hint.visible = true
	elif _channel == Chat.Channel.WHISPER:
		_hint.text = "Whispering %s" % _whisper_name
		_hint.visible = true
	else:
		_hint.visible = false
	_input.editable = not (_channel == Chat.Channel.SECT and _sect_id == "") \
		and not (_channel == Chat.Channel.WHISPER and _whisper_target == "")


func _poll(force := false) -> void:
	if _busy:
		return
	var channel := _channel
	var target := _target_for(channel)
	if channel == Chat.Channel.SECT and target == "":
		return
	if channel == Chat.Channel.WHISPER and target == "":
		return
	_busy = true
	var after := int(_last_id[channel])
	var rows := await Chat.messages(channel, after, target)
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# The player may have switched tabs while this was in flight.
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

	var text := _label(body, 20, TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)

	if not _expanded:
		_bar_label.text = "%s: %s" % [who, body]


func _add_system(message: String) -> void:
	var l := _label(message, 18, DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


func _name_colour(channel: int) -> Color:
	match channel:
		Chat.Channel.SECT:
			return SECT_NAME
		Chat.Channel.WHISPER:
			return WHISPER_NAME
		_:
			return WORLD_NAME


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
# PLAYER ACTIONS (whisper / block / report)
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
	menu.position = Vector2i(get_viewport().get_mouse_position())
	menu.popup()


func _do_action(id: int, user_id: String, who: String, body: String) -> void:
	match id:
		0:
			_whisper_target = user_id
			_whisper_name = who
			_set_channel(Chat.Channel.WHISPER)
			if _channel == Chat.Channel.WHISPER:
				_reload()
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

	if not _root.visible:
		return

	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = Chat.POLL_SECONDS

	if _expanded:
		_poll()
	else:
		# Collapsed: only the cheap unread check, not the message list.
		_refresh_unread()


func _refresh_unread() -> void:
	var n := await Chat.unread_count()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_unread = n
	_bar_dot.visible = n > 0
	_bar_dot.queue_redraw()


# ---------------------------------------------------------
# DRAWING HELPERS
# ---------------------------------------------------------

func _panel_style(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color("0b1629"), alpha)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb


## A small speech bubble, drawn rather than an imported icon.
func _speech_icon() -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		var w := icon.size.x
		var h := icon.size.y * 0.72
		icon.draw_rect(Rect2(0, 0, w, h), Color(GOLD, 0.25), true)
		icon.draw_rect(Rect2(0, 0, w, h), GOLD, false, 1.5)
		icon.draw_polygon(
			PackedVector2Array([Vector2(w * 0.25, h), Vector2(w * 0.45, h),
				Vector2(w * 0.28, icon.size.y)]),
			PackedColorArray([GOLD, GOLD, GOLD]))
	)
	return icon


func _unread_dot() -> Control:
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	dot.draw.connect(func():
		dot.draw_circle(dot.size * 0.5, 6.0, ALERT)
	)
	return dot


func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(GOLD, 0.0), Color(GOLD, 0.6), Color(GOLD, 0.0)]), 1.5, true)
	)
	return line


func _label(value: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	return l
