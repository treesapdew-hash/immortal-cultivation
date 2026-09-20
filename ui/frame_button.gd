extends Button

# Framed button.
# - Normal style: the resting look.
# - Hover style (optional): the bright "active" look, used on hover,
#   while held, and on the selected tab.
# Sibling buttons with the same Tab Group name act as tabs:
# only one stays selected.

@export var tab_group := ""             # e.g. "quick_menu"; empty = normal button
@export var start_selected := false     # the tab selected at the start

@export_group("Tints")
@export var hover_tint := Color(1.1, 1.1, 1.1)         # used if there's no Hover style
@export var pressed_tint := Color(0.85, 0.85, 0.85)
@export var disabled_tint := Color(0.5, 0.5, 0.5, 0.7)
@export var press_scale := 0.97

var _normal: StyleBox
var _active: StyleBox
var _held := false


func _ready() -> void:
	_normal = get_theme_stylebox("normal")
	_active = get_theme_stylebox("hover") if has_theme_stylebox_override("hover") else null

	# No focus box, and no focus at all
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	focus_mode = Control.FOCUS_NONE

	# Keep the text colour the same in every state
	var font_color := get_theme_color("font_color")
	for c in ["font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, font_color)

	# Tabs: handled by hand, so no ButtonGroup is needed
	button_group = null
	toggle_mode = tab_group != ""
	if toggle_mode:
		toggled.connect(_on_toggled)
		if start_selected:
			set_pressed_no_signal(true)
			_unselect_siblings()

	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_update_pivot)
	_update_pivot()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


# ---------------------------------------------------------
# TABS
# ---------------------------------------------------------

func _tab_siblings() -> Array:
	var result := []
	if get_parent() == null:
		return result
	for node in get_parent().get_children():
		if node != self and node is Button and node.get("tab_group") == tab_group:
			result.append(node)
	return result


func _unselect_siblings() -> void:
	for tab in _tab_siblings():
		tab.set_pressed_no_signal(false)


func _on_toggled(on: bool) -> void:
	if on:
		_unselect_siblings()
		return

	# Clicking the selected tab again keeps it selected
	var any_on := false
	for tab in _tab_siblings():
		if tab.button_pressed:
			any_on = true
	if not any_on:
		set_pressed_no_signal(true)


# ---------------------------------------------------------
# LOOK
# ---------------------------------------------------------

func _refresh() -> void:
	var selected := toggle_mode and button_pressed
	var hovering := is_hovered() and not disabled
	var use_active := _active != null and (selected or hovering or _held)

	var style: StyleBox = _active if use_active else _normal
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled",
			"normal_mirrored", "hover_mirrored", "pressed_mirrored",
			"hover_pressed_mirrored", "disabled_mirrored"]:
		if get_theme_stylebox(s) != style:
			add_theme_stylebox_override(s, style)

	var tint := Color.WHITE
	if disabled:
		tint = disabled_tint
	elif _held:
		tint = pressed_tint
	elif hovering and _active == null:
		tint = hover_tint

	if self_modulate != tint:
		self_modulate = tint


func _on_button_down() -> void:
	_held = true
	scale = Vector2.ONE * press_scale


func _on_button_up() -> void:
	_held = false
	scale = Vector2.ONE


func _update_pivot() -> void:
	pivot_offset = size / 2.0
