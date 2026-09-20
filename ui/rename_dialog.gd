class_name RenameDialog
extends CanvasLayer

# =========================================================
# Popup for renaming the MC. No scene needed:
#
#   RenameDialog.open(self)                       # defaults
#   RenameDialog.open(self, ui_font, jade_icon)   # match your UI
#
# The first rename is free, later ones cost Immortal Jade
# (see GameState.MC_RENAME_COST).
#
# Tap outside the panel or press Cancel / Esc to close.
# =========================================================

signal name_changed(new_name: String)
signal closed

const COL_PANEL     := Color("0e1c34")
const COL_DIM       := Color("2a4262")
const COL_TEXT      := Color("e8eef7")
const COL_TEXT_DIM  := Color("8a9bb4")
const COL_GOLD      := Color("e0b85a")
const COL_GOLD_TEXT := Color("ffe6a8")
const COL_ERROR     := Color("ff7a7a")
const COL_FREE      := Color("7dffa8")

## Only one rename popup at a time.
static var _instance: RenameDialog = null

var _font: Font
var _jade_icon: Texture2D
var _cost := 0
var _accent := Color("7fd4ff")
var _closing := false

var _root: Control
var _dim: ColorRect
var _panel: PanelContainer
var _edit: LineEdit
var _hint: Label
var _counter: Label
var _confirm: Button
var _cost_amount: Label


static func open(host: Node, font: Font = null, jade_icon: Texture2D = null) -> RenameDialog:
	if is_instance_valid(_instance):
		return _instance

	var d := RenameDialog.new()
	d._font = font
	d._jade_icon = jade_icon
	d._accent = Enums.PATH_COLORS.get(GameState.mc_path, d._accent)
	_instance = d

	# Deferred so it's safe to call from input handlers.
	host.get_tree().root.add_child.call_deferred(d)
	return d


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cost = GameState.get_rename_cost()
	_build()
	_on_text_changed(_edit.text)
	_show()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_fill(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	if _font != null:
		th.default_font = _font
	th.default_font_size = 32
	_root.theme = th
	add_child(_root)

	# Dark backdrop. Tapping it closes the popup.
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_fill(_dim)
	_dim.gui_input.connect(_on_dim_input)
	_root.add_child(_dim)

	var center := CenterContainer.new()
	_fill(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	var sb := _box(COL_PANEL, _accent, 3, 18)
	sb.set_content_margin_all(36)
	sb.shadow_color = Color(_accent, 0.3)
	sb.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.resized.connect(func(): _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	_panel.add_child(v)

	v.add_child(_label("◆   Rename   ◆", 40, COL_GOLD))
	v.add_child(_label("Current name:  " + GameState.mc_name, 26, COL_TEXT_DIM))

	# Name box + Random
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(COL_DIM, 0.35)
	normal.border_width_bottom = 3
	normal.border_color = COL_DIM
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)

	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_width_bottom = 3
	focus.border_color = _accent
	focus.set_corner_radius_all(12)

	_edit = LineEdit.new()
	_edit.text = GameState.mc_name
	_edit.placeholder_text = "Enter a new name"
	_edit.max_length = GameState.MC_NAME_MAX
	_edit.select_all_on_focus = true
	_edit.custom_minimum_size = Vector2(540, 92)
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.add_theme_font_size_override("font_size", 38)
	_edit.add_theme_stylebox_override("normal", normal)
	_edit.add_theme_stylebox_override("focus", focus)
	_edit.add_theme_color_override("font_color", COL_TEXT)
	_edit.add_theme_color_override("font_placeholder_color", COL_TEXT_DIM)
	_edit.add_theme_color_override("caret_color", _accent)
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(func(_t): _on_confirm())
	row.add_child(_edit)

	var random_button := Button.new()
	random_button.text = "Random"
	random_button.custom_minimum_size = Vector2(180, 92)
	_style_plain(random_button)
	random_button.pressed.connect(_on_random)
	row.add_child(random_button)

	# Error on the left, letter count on the right
	var info := HBoxContainer.new()
	v.add_child(info)

	_hint = _label("", 24, COL_ERROR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_hint)

	_counter = _label("", 24, COL_TEXT_DIM)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(_counter)

	v.add_child(_build_cost_row())

	# Buttons
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	v.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(300, 96)
	_style_plain(cancel)
	cancel.pressed.connect(_close)
	buttons.add_child(cancel)

	_confirm = Button.new()
	_confirm.text = "Confirm"
	_confirm.custom_minimum_size = Vector2(300, 96)
	_style_gold(_confirm)
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)


## "First rename is free!" or "Cost: [jade] 200  (You have 950)"
func _build_cost_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	if _cost == 0:
		row.add_child(_label("First rename is free!", 30, COL_FREE))
		return row

	row.add_child(_label("Cost:", 30, COL_TEXT))

	if _jade_icon != null:
		var icon := TextureRect.new()
		icon.texture = _jade_icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(44, 44)
		row.add_child(icon)

	_cost_amount = _label("", 30, COL_GOLD_TEXT)
	row.add_child(_cost_amount)
	if _jade_icon == null:
		row.add_child(_label("Immortal Jade", 30, COL_GOLD_TEXT))

	row.add_child(_label("(You have %s)" % NumberFormat.short(GameState.immortal_jade), 24, COL_TEXT_DIM))
	return row


func _can_afford() -> bool:
	return GameState.immortal_jade >= _cost


# ---------------------------------------------------------
# OPEN / CLOSE
# ---------------------------------------------------------

func _show() -> void:
	_root.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)

	var t := create_tween().set_parallel(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.18)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Focus the box so the keyboard opens and the old name is selected.
	_edit.grab_focus()


func _close() -> void:
	if _closing:
		return
	_closing = true
	_edit.release_focus()

	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.15)
	t.tween_callback(func():
		closed.emit()
		queue_free()
	)


# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------

func _on_dim_input(event) -> void:
	# Touch is also sent as a mouse click, so this covers phones too.
	if event is InputEventMouseButton and event.pressed:
		_close()


func _on_text_changed(_text: String) -> void:
	var n := GameState.clean_mc_name(_edit.text)
	var error := GameState.validate_mc_name(n)

	_counter.text = "%d / %d" % [n.length(), GameState.MC_NAME_MAX]
	_hint.text = error if n != "" else ""

	if _cost_amount != null:
		_cost_amount.text = NumberFormat.short(_cost)
		_cost_amount.add_theme_color_override(
			"font_color", COL_GOLD_TEXT if _can_afford() else COL_ERROR)
		if error == "" and not _can_afford():
			_hint.text = "Not enough Immortal Jade."

	_confirm.disabled = error != "" or n == GameState.mc_name or not _can_afford()


func _on_random() -> void:
	var pick := GameState.random_mc_name()
	for i in 5:
		if pick != _edit.text:
			break
		pick = GameState.random_mc_name()

	# Setting text in code doesn't fire text_changed.
	_edit.text = pick
	_edit.caret_column = pick.length()
	_on_text_changed(pick)


func _on_confirm() -> void:
	if _closing or _confirm.disabled:
		return

	var n := GameState.clean_mc_name(_edit.text)

	var error := GameState.try_rename_mc(n)
	if error != "":
		_hint.text = error
		return

	name_changed.emit(n)
	_close()


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


func _style_gold(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	var normal := _box(Color("5a3f12"), COL_GOLD, 3, 16)
	normal.shadow_color = Color(COL_GOLD, 0.35)
	normal.shadow_size = 10
	var down := _box(Color("7a5818"), COL_GOLD_TEXT, 3, 16)
	var off := _box(Color("151a24"), Color("323845"), 2, 16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", COL_GOLD_TEXT)
	b.add_theme_color_override("font_hover_color", COL_GOLD_TEXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("4d5462"))
