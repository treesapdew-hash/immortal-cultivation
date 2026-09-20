class_name FriendsPopup
extends CanvasLayer

# =========================================================
# Friends: requests, the list, and the daily gift exchange.
#   FriendsPopup.open(self)
#
# Opened from the Friends button in the chat panel.
#
# The server owns everything here (supabase_setup_7.sql): who is
# whose friend, who has been gifted today, and what a claimed gift
# is worth. This only shows it and calls the actions.
# =========================================================

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")
const COL_NAME := Color("8ff0ff")

signal whisper_requested(user_id: String, who: String)

var _root: Control
var _panel: PanelContainer
var _body: VBoxContainer
var _search: LineEdit
var _count_label: Label
var _send_all: OrnateButton
var _claim: OrnateButton
var _toast_holder: Control

var _busy := false
var _state := {}


static func open(host: Node) -> FriendsPopup:
	if not Friends.available():
		return null
	var p := FriendsPopup.new()
	host.get_tree().root.add_child.call_deferred(p)
	return p


func _ready() -> void:
	layer = 62          # above the chat panel (60), below popups (65+)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_show()
	_reload()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
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

	# Title row
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)

	_count_label = _label("Friends", 28, COL_TITLE)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_count_label)

	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 28)
	close.add_theme_color_override("font_color", COL_DIM)
	close.pressed.connect(_close)
	head.add_child(close)

	# Gift row
	var gifts := HBoxContainer.new()
	gifts.add_theme_constant_override("separation", 10)
	v.add_child(gifts)

	_send_all = OrnateButton.new()
	_send_all.text = "Send All Gifts"
	_send_all.custom_minimum_size = Vector2(280, 60)
	_send_all.add_theme_font_size_override("font_size", 20)
	_send_all.pressed.connect(_on_send_all)
	gifts.add_child(_send_all)

	_claim = OrnateButton.new()
	_claim.text = "Claim Gifts"
	_claim.variant = OrnateButton.Variant.CRIMSON
	_claim.custom_minimum_size = Vector2(280, 60)
	_claim.add_theme_font_size_override("font_size", 20)
	_claim.pressed.connect(_on_claim)
	gifts.add_child(_claim)

	var gift_note := _label("Each gift gives " + Friends.gift_text(), 16, COL_DIM)
	gift_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gift_note)

	v.add_child(_line())

	# Add friend
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 8)
	v.add_child(add)

	_search = LineEdit.new()
	_search.placeholder_text = "Search by name..."
	_search.max_length = 20
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override("font_size", 20)
	var on_submit := func(_t: String) -> void:
		_on_search()
	_search.text_submitted.connect(on_submit)
	add.add_child(_search)

	var find := OrnateButton.new()
	find.text = "Find"
	find.variant = OrnateButton.Variant.DARK
	find.custom_minimum_size = Vector2(150, 56)
	find.add_theme_font_size_override("font_size", 20)
	find.pressed.connect(_on_search)
	add.add_child(find)

	v.add_child(_line())

	# Scrolling body: requests, then friends (or search results)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	_toast_holder = Control.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_toast_holder)


func _show() -> void:
	_root.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.2)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


# ---------------------------------------------------------
# LOADING
# ---------------------------------------------------------

func _reload() -> void:
	if _busy:
		return
	_busy = true
	var s := await Friends.state()
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_state = s
	_render()


func _render() -> void:
	for child in _body.get_children():
		child.queue_free()

	var friends: Array = _state["friends"] if _state.get("friends", null) is Array else []
	var requests: Array = _state["requests"] if _state.get("requests", null) is Array else []
	var unclaimed := int(_state.get("unclaimed", 0))

	_count_label.text = "Friends  %d / %d" % [friends.size(), Friends.MAX_FRIENDS]
	_claim.text = "Claim Gifts (%d)" % unclaimed if unclaimed > 0 else "Claim Gifts"
	_claim.disabled = unclaimed <= 0

	var to_send := 0
	for f in friends:
		if not bool(f.get("sent_today", false)):
			to_send += 1
	_send_all.disabled = to_send <= 0
	_send_all.text = "Send All Gifts (%d)" % to_send if to_send > 0 else "All Gifts Sent"

	if not requests.is_empty():
		_body.add_child(_label("Requests", 22, COL_GOLD))
		for r in requests:
			_request_row(r)
		_body.add_child(_line())

	if friends.is_empty():
		_body.add_child(_note("No friends yet. Search for a cultivator above, or tap a name in World chat."))
		return

	_body.add_child(_label("Your friends", 22, COL_GOLD))
	for f in friends:
		_friend_row(f)


func _request_row(req: Dictionary) -> void:
	var uid := str(req.get("id", ""))
	var who := str(req.get("name", "Cultivator"))
	var h := _person_row(who, int(req.get("realm", 0)), -1)

	var accept := OrnateButton.new()
	accept.text = "Accept"
	accept.custom_minimum_size = Vector2(140, 50)
	accept.add_theme_font_size_override("font_size", 18)
	var on_accept := func() -> void:
		var r := await Friends.accept(uid)
		_act(r, "%s is now your friend." % who)
	accept.pressed.connect(on_accept)
	h.add_child(accept)

	var reject := OrnateButton.new()
	reject.text = "Decline"
	reject.variant = OrnateButton.Variant.DARK
	reject.custom_minimum_size = Vector2(140, 50)
	reject.add_theme_font_size_override("font_size", 18)
	var on_reject := func() -> void:
		var r := await Friends.reject(uid)
		_act(r, "Request declined.")
	reject.pressed.connect(on_reject)
	h.add_child(reject)


func _friend_row(f: Dictionary) -> void:
	var uid := str(f.get("id", ""))
	var who := str(f.get("name", "Cultivator"))
	var sent := bool(f.get("sent_today", false))
	var h := _person_row(who, int(f.get("realm", 0)), int(f.get("power", 0)))

	var gift := OrnateButton.new()
	gift.text = "Sent" if sent else "Gift"
	gift.variant = OrnateButton.Variant.DARK if sent else OrnateButton.Variant.GOLD
	gift.disabled = sent
	gift.custom_minimum_size = Vector2(120, 50)
	gift.add_theme_font_size_override("font_size", 18)
	var on_gift := func() -> void:
		var r := await Friends.send_gift(uid)
		_act(r, "Gift sent to %s." % who)
	gift.pressed.connect(on_gift)
	h.add_child(gift)

	var more := Button.new()
	more.text = "..."
	more.flat = true
	more.focus_mode = Control.FOCUS_NONE
	more.add_theme_font_size_override("font_size", 24)
	more.add_theme_color_override("font_color", COL_DIM)
	more.custom_minimum_size = Vector2(56, 50)
	more.pressed.connect(func(): _open_actions(uid, who))
	h.add_child(more)


func _result_row(p: Dictionary) -> void:
	var uid := str(p.get("id", ""))
	var who := str(p.get("name", "Cultivator"))
	var h := _person_row(who, int(p.get("realm", 0)), int(p.get("power", 0)))

	var add := OrnateButton.new()
	add.text = "Add"
	add.custom_minimum_size = Vector2(140, 50)
	add.add_theme_font_size_override("font_size", 18)
	var on_add := func() -> void:
		var r := await Friends.request(uid)
		_act(r, "Request sent to %s." % who)
	add.pressed.connect(on_add)
	h.add_child(add)


## Name, realm and power on the left; buttons get added on the right.
func _person_row(who: String, realm: int, power: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(h)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(texts)

	texts.add_child(_label(who, 21, COL_NAME))
	var sub := str(Realms.get_label(realm, 1)) if realm >= 0 else ""
	if power > 0:
		sub += "   Power %s" % NumberFormat.short(power)
	if sub != "":
		texts.add_child(_label(sub, 16, COL_DIM))
	return h


func _note(message: String) -> Label:
	var l := _label(message, 18, COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

## Runs an action, toasts the result, reloads. The coroutine is
## passed in already started.
func _act(result: Dictionary, success: String) -> void:
	if result["ok"]:
		_toast(success, COL_OK)
		_reload()
	else:
		_toast(str(result["error"]), COL_BAD)


func _on_send_all() -> void:
	if _busy:
		return
	_busy = true
	var r := await Friends.send_all()
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if not r["ok"]:
		_toast(str(r["error"]), COL_BAD)
		return
	var n := int(r["data"]) if r["data"] != null else 0
	_toast("Sent %d gift%s." % [n, "" if n == 1 else "s"], COL_OK)
	_reload()


func _on_claim() -> void:
	if _busy:
		return
	_busy = true
	var r := await Friends.claim()
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if not r["ok"]:
		_toast(str(r["error"]), COL_BAD)
		return
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	var n := int(d.get("count", 0))
	if n <= 0:
		_toast("Nothing to claim.", COL_DIM)
		return
	_toast("Claimed %d gift%s: +%d Jade, +%d Beast Cores"
		% [n, "" if n == 1 else "s", int(d.get("jade", 0)), int(d.get("beast_core", 0))], COL_OK)
	_reload()


func _on_search() -> void:
	if _busy:
		return
	var term := _search.text.strip_edges()
	if term == "":
		_reload()
		return
	_busy = true
	var rows := await Friends.find(term)
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	for child in _body.get_children():
		child.queue_free()
	_body.add_child(_label("Search results", 22, COL_GOLD))
	if rows.is_empty():
		_body.add_child(_note("No cultivator found by that name."))
		return
	for p in rows:
		_result_row(p)


func _open_actions(user_id: String, who: String) -> void:
	var menu := PopupMenu.new()
	menu.add_item("Whisper " + who, 0)
	menu.add_separator()
	menu.add_item("Remove friend", 1)
	menu.add_item("Block " + who, 2)
	add_child(menu)
	menu.id_pressed.connect(func(id: int): _do_action(id, user_id, who))
	menu.popup_hide.connect(menu.queue_free)
	menu.popup_centered()


func _do_action(id: int, user_id: String, who: String) -> void:
	match id:
		0:
			whisper_requested.emit(user_id, who)
			_close()
		1:
			var r := await Friends.remove(user_id)
			_act(r, "%s is no longer your friend." % who)
		2:
			var r2 := await Chat.block(user_id)
			_act(r2, "%s is blocked." % who)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _toast(message: String, colour: Color) -> void:
	var l := _label(message, 24, colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_holder.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 240
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.tween_callback(l.queue_free)


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
