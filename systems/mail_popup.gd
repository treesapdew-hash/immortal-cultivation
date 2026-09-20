class_name MailPopup
extends CanvasLayer

# =========================================================
# The mailbox.
#   MailPopup.open(host)
#
# MailPopup.make_button() gives you the envelope icon with the
# unread badge (used at the top right of the battle area).
# =========================================================

## Your mail icon. Falls back to a drawn envelope if it's missing.
const ICON_PATH := "res://assets/ui/mail.png"
## Button size in pixels. Raise or lower to taste.
const ICON_SIZE := 108.0

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")

var _list: VBoxContainer
var _claim_all: OrnateButton
var _toast: Label


static func open(host: Node) -> MailPopup:
	var p := MailPopup.new()
	host.get_tree().root.add_child.call_deferred(p)
	return p


## Mail button with the unread badge. Uses your icon when it exists.
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
	else:
		b.draw.connect(_draw_envelope.bind(b))

	# Hover and press feedback, on the button so it covers both cases.
	IconFX.attach(b)

	# Badge drawn on top of the icon
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.draw.connect(_draw_badge.bind(badge))
	b.add_child(badge)

	b.pressed.connect(func(): MailPopup.open(b))
	GameState.mail_changed.connect(badge.queue_redraw)
	return b


## Red dot with the unread count, top-right of the icon.
static func _draw_badge(c: Control) -> void:
	var unread := Mail.unread_count()
	if unread <= 0:
		return
	var s := c.size
	var r := s.x * 0.15
	var p := Vector2(s.x - r - 4.0, r + 4.0)
	c.draw_circle(p, r + 2.0, Color(0, 0, 0, 0.55))
	c.draw_circle(p, r, Color("ff4d4d"))
	c.draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.26, Color(1, 1, 1, 0.6))

	var font := c.get_theme_default_font()
	var text := str(mini(unread, 99))
	var fs := int(r * 1.25)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, p + Vector2(-w * 0.5, fs * 0.38), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Fallback drawing, used only if the icon file is missing.
static func _draw_envelope(b: Button) -> void:
	var s := b.size
	var w := s.x * 0.62
	var h := w * 0.66
	var r := Rect2(Vector2((s.x - w) * 0.5, (s.y - h) * 0.5), Vector2(w, h))
	var gold := Color("e2c27a")
	b.draw_rect(r.grow(2), Color(0, 0, 0, 0.35))
	b.draw_rect(r, Color("13233d"))
	b.draw_rect(r, gold, false, 2.0)
	b.draw_polyline(PackedVector2Array([
		r.position, r.position + Vector2(w * 0.5, h * 0.55), r.position + Vector2(w, 0)
	]), gold, 2.0, true)


func _ready() -> void:
	layer = 63
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			queue_free()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_label("Mail", 38, COL_TITLE, true))
	_toast = _label("", 20, COL_OK)
	_toast.custom_minimum_size.y = 26
	v.add_child(_toast)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	v.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	v.add_child(buttons)

	_claim_all = OrnateButton.new()
	_claim_all.text = "Claim All"
	_claim_all.custom_minimum_size = Vector2(260, 70)
	_claim_all.pressed.connect(_on_claim_all)
	buttons.add_child(_claim_all)

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 70)
	close.pressed.connect(queue_free)
	buttons.add_child(close)

	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	if GameState.mail.is_empty():
		_list.add_child(_label("Your mailbox is empty.", 22, COL_DIM))
	else:
		for message in GameState.mail:
			_list.add_child(_message_row(message))

	var pending := 0
	for m in GameState.mail:
		if not m["claimed"]:
			pending += 1
	_claim_all.disabled = pending == 0
	_claim_all.text = "Claim All (%d)" % pending if pending > 0 else "Claim All"


func _message_row(message: Dictionary) -> Control:
	var claimed: bool = message["claimed"]
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03) if claimed else Color(COL_GOLD, 0.07)
	sb.border_color = Color("2c4466") if claimed else Color(COL_GOLD, 0.7)
	sb.set_border_width_all(1 if claimed else 2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)

	texts.add_child(_label(str(message["title"]), 24,
		COL_TITLE if not claimed else COL_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	var body := _label(str(message["body"]), 19, COL_TEXT if not claimed else COL_DIM,
		false, HORIZONTAL_ALIGNMENT_LEFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(body)

	var rewards := PackedStringArray()
	if int(message["jade"]) > 0:
		rewards.append("%s Jade" % NumberFormat.short(int(message["jade"])))
	for id in message["items"]:
		rewards.append("%s %s" % [NumberFormat.short(int(message["items"][id])),
			ItemDB.get_item(id).get("name", id)])
	if not rewards.is_empty():
		texts.add_child(_label("  ·  ".join(rewards), 19, COL_OK if not claimed else COL_DIM,
			false, HORIZONTAL_ALIGNMENT_LEFT))

	if not claimed:
		var claim := OrnateButton.new()
		claim.text = "Claim"
		claim.custom_minimum_size = Vector2(160, 56)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim.pressed.connect(_on_claim.bind(int(message["id"])))
		h.add_child(claim)
	else:
		Mail.mark_read(int(message["id"]))

	return row


func _on_claim(id: int) -> void:
	var got := Mail.claim(id)
	if not got.is_empty():
		_show_gain(int(got["jade"]), got["items"])
	_rebuild()


func _on_claim_all() -> void:
	var got := Mail.claim_all()
	_show_gain(int(got["jade"]), got["items"])
	_rebuild()


func _show_gain(jade: int, items: Dictionary) -> void:
	var parts := PackedStringArray()
	if jade > 0:
		parts.append("+%s Jade" % NumberFormat.short(jade))
	for id in items:
		parts.append("+%s %s" % [NumberFormat.short(int(items[id])), ItemDB.get_item(id).get("name", id)])
	_toast.text = "  ·  ".join(parts)


func _label(text: String, font_size: int, color: Color, glow := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
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
