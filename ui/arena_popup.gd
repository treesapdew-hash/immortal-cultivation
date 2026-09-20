class_name ArenaPopup
extends CanvasLayer

# =========================================================
# The Arena. Save as res://ui/arena_popup.gd
#   ArenaPopup.open(self)
#
# Opened from the Events tab. Shows your standing, the opponents
# in your realm bracket, and the board.
#
# Fighting hands the opponent's stored team to the normal battle
# request, so an Arena duel runs on the same combat as everything
# else. The result comes back through `finished`.
# =========================================================

signal fight_requested(opponent: Dictionary)

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")
const COL_NPC := Color("9aa6b8")

var _root: Control
var _panel: PanelContainer
var _body: VBoxContainer
var _standing: Label
var _bracket_art: TextureRect
var _attacks: Label
var _toast_holder: Control

var _busy := false
var _state := {}
var _opponents: Array = []
var _tab := "Duel"


static func open(host: Node) -> ArenaPopup:
	if not Arena.available():
		return null
	var p := ArenaPopup.new()
	host.get_tree().root.add_child.call_deferred(p)
	return p


func _ready() -> void:
	layer = 64
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
	dim.color = Color(0, 0, 0, 0.7)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	_root.add_child(dim)

	var away := Button.new()
	away.flat = true
	away.focus_mode = Control.FOCUS_NONE
	away.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	away.pressed.connect(_close)
	_root.add_child(away)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(960, 1260)
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

	# Header: bracket emblem, standing, close
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)

	_bracket_art = TextureRect.new()
	_bracket_art.custom_minimum_size = Vector2(76, 76)
	_bracket_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bracket_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bracket_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_bracket_art)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	titles.add_child(_label("Arena", 32, COL_TITLE))
	_standing = _label("", 19, COL_DIM)
	titles.add_child(_standing)

	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 28)
	close.add_theme_color_override("font_color", COL_DIM)
	close.pressed.connect(_close)
	head.add_child(close)

	_attacks = _label("", 20, COL_TEXT)
	_attacks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_attacks)

	v.add_child(_line())

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in ["Duel", "Board"]:
		tabs.add_child(_tab_button(t))

	v.add_child(_line())

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


func _tab_button(title: String) -> Button:
	var b := Button.new()
	b.text = title
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", COL_TITLE if title == _tab else COL_DIM)
	b.pressed.connect(func(): _set_tab(title))
	return b


func _set_tab(title: String) -> void:
	if _tab == title:
		return
	_tab = title
	_render()


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
	# Register first: without a snapshot there is nothing to fight.
	await Arena.sync()
	var s := await Arena.state()
	var opp := await Arena.opponents(int(s.get("points", 1000)))
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_state = s
	_opponents = opp
	_render()


func _render() -> void:
	for c in _body.get_children():
		c.queue_free()

	var bracket := int(_state.get("bracket", Arena.bracket()))
	_bracket_art.texture = load(Arena.bracket_art(bracket))
	_standing.text = "%s  ·  Rank %d of %d  ·  %d points  ·  %dW %dL" % [
		Arena.bracket_name(bracket), int(_state.get("rank", 1)),
		int(_state.get("in_bracket", 1)), int(_state.get("points", 0)),
		int(_state.get("wins", 0)), int(_state.get("losses", 0))]

	var left := int(_state.get("attacks_left", 0))
	var bought := int(_state.get("extra_bought", 0))
	_attacks.text = "%d duels left today." % left
	if bought < Arena.MAX_EXTRA:
		_attacks.text += "  One more costs %d Jade." % Arena.extra_cost(bought)

	if _tab == "Board":
		_render_board()
	else:
		_render_duel(left, bought)


func _render_duel(left: int, bought: int) -> void:
	if left <= 0 and bought < Arena.MAX_EXTRA:
		var buy := OrnateButton.new()
		buy.text = "Buy a duel  ·  %d Jade" % Arena.extra_cost(bought)
		buy.custom_minimum_size = Vector2(360, 60)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		buy.pressed.connect(_on_buy)
		_body.add_child(buy)
		_body.add_child(_line())

	if _opponents.is_empty():
		_body.add_child(_note("No cultivators to face right now. Try again shortly."))
		return

	for o in _opponents:
		_body.add_child(_opponent_row(o, left))


func _opponent_row(o: Dictionary, left: int) -> Control:
	var is_npc := bool(o.get("npc", false))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.05)
	sb.border_color = Color(COL_NPC if is_npc else COL_GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(texts)

	texts.add_child(_label(str(o.get("name", "Cultivator")), 22,
		COL_NPC if is_npc else COL_TEXT))
	texts.add_child(_label("%d points  ·  Power %s  ·  %dW %dL" % [
		int(o.get("points", 0)), NumberFormat.short(int(o.get("power", 0))),
		int(o.get("wins", 0)), int(o.get("losses", 0))], 16, COL_DIM))

	var fight := OrnateButton.new()
	fight.text = "Duel"
	fight.custom_minimum_size = Vector2(150, 56)
	fight.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fight.disabled = left <= 0
	var on_fight := func() -> void:
		_on_fight(o)
	fight.pressed.connect(on_fight)
	h.add_child(fight)

	return panel


func _render_board() -> void:
	_body.add_child(_label("Top of %s" % Arena.bracket_name(int(_state.get("bracket", 0))),
		22, COL_GOLD))
	var rows := await Arena.board(20)
	if not is_instance_valid(self) or _tab != "Board":
		return
	if rows.is_empty():
		_body.add_child(_note("Nobody has entered this bracket yet. Be the first."))
		return
	var place := 1
	for r in rows:
		var line := _label("%d.  %s  —  %d points  (%dW %dL)" % [
			place, str(r.get("name", "Cultivator")), int(r.get("points", 0)),
			int(r.get("wins", 0)), int(r.get("losses", 0))], 19, COL_TEXT)
		_body.add_child(line)
		place += 1


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

## Hands the duel to whoever opened this (the Events screen), which
## runs it on the normal battle scene and calls settle() after.
func _on_fight(o: Dictionary) -> void:
	if _busy:
		return
	fight_requested.emit(o)
	_close()


## Called back with the result once the duel has been fought.
func settle(o: Dictionary, won: bool) -> void:
	var r := await Arena.report(o, won)
	if not r["ok"]:
		_toast(str(r["error"]), COL_BAD)
		return
	var delta := int(r.get("delta", 0))
	if bool(r.get("npc", false)):
		_toast("Practice duel: %s" % ("won" if won else "lost"), COL_OK if won else COL_DIM)
	else:
		_toast("%s  %+d points" % ["Victory!" if won else "Defeat.", delta],
			COL_OK if won else COL_BAD)
	_reload()


func _on_buy() -> void:
	if _busy:
		return
	_busy = true
	var r := await Arena.buy_attack(int(_state.get("extra_bought", 0)))
	_busy = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if not r["ok"]:
		_toast(str(r["error"]), COL_BAD)
		return
	_toast("One more duel bought.", COL_OK)
	_reload()


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _note(message: String) -> Label:
	var l := _label(message, 18, COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _toast(message: String, colour: Color) -> void:
	var l := _label(message, 24, colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_holder.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 260
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
