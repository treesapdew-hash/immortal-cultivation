extends VBoxContainer

# =========================================================
# Attach to: LowerStack
#
# Swaps the lower half of the home screen. The battle and top
# bar always stay visible.
#
# Nav tabs (bottom bar):
#   Home      -> quick menu + whatever quick tab is selected
#   Other tab -> that tab's screen
#
# Quick menu tabs (Formation, Summon, Partner, Inventory, Guild):
#   Partner   -> formation row + partner panel
#   Formation -> formation row + formation screen (pick your team)
#   Others    -> that tab's screen, under the quick menu
#
# Screens are loaded from res://ui/screens/<tab>_screen.tscn, or
# <tab>_screen.gd for screens built in code. If neither exists,
# a simple placeholder is shown, so every tab works today.
# =========================================================

signal tab_opened(tab: String)
## A feature just unlocked (see Unlocks); the tutorial listens for this.
signal unlocked(feature_id: String)

const TABS := ["Home", "Growth", "Mission", "Codex", "Events", "More"]
const QUICK_TABS := ["Formation", "Summon", "Partner", "Inventory", "Guild"]

## Which of the normal Home nodes each quick tab keeps visible.
## Tabs not listed hide them all. A tab also gets its own screen
## unless it's in NO_SCREEN.
const KEEP_NODES := {
	"Formation": ["FormationPanel"],
	"Partner": ["FormationPanel", "PartnerPanelHolder"],
}
const NO_SCREEN := ["Partner"]

const SCREENS_FOLDER := "res://ui/screens/"

## Found automatically if left empty.
@export var nav_bar: Node

## Tab screens end exactly where the normal Home content (the
## partner panel) ends, measured when the game starts. These add
## extra space on top of that if you want it.
@export var screen_top_gap := 0
@export var screen_bottom_gap := 0
@export var screen_side_gap := 0

## Extra space kept above the bottom nav bar.
@export var nav_clearance := 10

var _measured_bottom := 0.0     # space to keep free at the bottom, in pixels

@export_group("Placeholder Look")
@export var panel_color := Color(0.05, 0.1, 0.19, 0.92)
@export var border_color := Color("3a5a80")
@export var title_color := Color("f2d98a")
@export var text_color := Color("c9d4e3")
@export var dim_color := Color("7f8ea3")

var _quick_menu: Control                 # QuickMenuPanel, stays on Home
var _home_nodes: Array[Control] = []     # formation row, partner panel
var _screens := {}          # "nav:Growth" / "quick:Summon" -> wrapper Control
var _screen_inner := {}     # same keys -> the actual screen
var _nav_buttons := {}      # tab name -> Node
var _current := "Home"
var _quick := "Partner"
var _fade: Tween


func _ready() -> void:
	# Everything already in LowerStack is the Home content.
	for child in get_children():
		if not child is Control:
			continue
		if child.name == "QuickMenuPanel":
			_quick_menu = child
		else:
			_home_nodes.append(child)

	if _quick_menu != null:
		# Keep the quick menu at its own height when the content below is swapped.
		_quick_menu.size_flags_vertical = Control.SIZE_FILL
		_connect_quick_tabs()

	if nav_bar == null and get_tree().current_scene != null:
		nav_bar = get_tree().current_scene.find_child("NavBar", true, false)

	if nav_bar == null:
		push_warning("ScreenRouter: NavBar not found")
	else:
		_connect_nav_buttons()

	_update_nav_highlight()
	_measure_home_bottom()

	# Feature locks: dim locked tabs, announce new unlocks as you progress
	unlocked.connect(func(id: String): Tutorial.start_unlock(id, self))
	# Tutorials cut short last time (app closed, disconnect) continue
	get_tree().create_timer(1.5).timeout.connect(func(): Tutorial.resume(self))
	GameState.stage_changed.connect(_refresh_locks)
	GameState.roster_changed.connect(_refresh_locks)
	_refresh_locks.call_deferred()


## Waits for the layout, then works out how much of LowerStack's
## bottom is covered (by the bottom nav, which overlaps it) or unused
## (below the partner panel), so tab screens stop at the same line.
func _measure_home_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_remeasure()
	if not resized.is_connected(_queue_remeasure):
		resized.connect(_queue_remeasure)


# Guards against a layout feedback loop: new margins resize this
# container, which fires `resized`, which re-measures again... A
# screen whose size wobbles (e.g. a label growing) could make that
# endless and hang the game. So re-measuring is queued (at most once
# per frame), only re-applies when the result really changed, and
# stops if it keeps flipping.
var _remeasure_queued := false
var _last_applied := -1.0
var _apply_times: Array = []
const MAX_APPLIES_PER_SECOND := 4


func _queue_remeasure() -> void:
	if _remeasure_queued:
		return
	_remeasure_queued = true
	_remeasure.call_deferred()


func _remeasure() -> void:
	_remeasure_queued = false
	var bottom := get_global_rect().end.y
	var free := 0.0

	# 1. The bottom nav panel overlapping LowerStack
	var scene := get_tree().current_scene
	var nav_panel = null
	if scene != null:
		nav_panel = scene.find_child("BottomNavPanel", true, false)
	if nav_panel == null:
		nav_panel = nav_bar
	if nav_panel is Control and nav_panel.is_visible_in_tree():
		var nav_top: float = nav_panel.get_global_rect().position.y
		if nav_top < bottom:
			free = maxf(free, bottom - nav_top + nav_clearance)

	# 2. Where the Home content (partner panel) stops, if it's higher
	var home_end := 0.0
	for node in _home_nodes:
		if node.visible:
			home_end = maxf(home_end, node.get_global_rect().end.y)
	if home_end > 0.0:
		free = maxf(free, bottom - home_end)

	# Nothing really changed: leave the margins alone
	if _last_applied >= 0.0 and absf(free - _last_applied) < 1.0:
		return

	# Flipping back and forth: keep the current layout instead of looping
	var now := Time.get_ticks_msec()
	_apply_times = _apply_times.filter(func(t): return now - int(t) < 1000)
	if _apply_times.size() >= MAX_APPLIES_PER_SECOND:
		push_warning("ScreenRouter: layout kept changing, stopped re-measuring to avoid a loop "
			+ "(a screen's size is probably changing as it lays out).")
		return
	_apply_times.append(now)

	_last_applied = free
	_measured_bottom = free
	for key in _screens:
		_apply_gaps(_screens[key])


func _apply_gaps(wrapper: MarginContainer) -> void:
	wrapper.add_theme_constant_override("margin_top", screen_top_gap)
	wrapper.add_theme_constant_override("margin_bottom", int(_measured_bottom) + screen_bottom_gap)
	wrapper.add_theme_constant_override("margin_left", screen_side_gap)
	wrapper.add_theme_constant_override("margin_right", screen_side_gap)


func _unhandled_input(event: InputEvent) -> void:
	# Back button / Esc returns to Home
	if _current != "Home" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		open_tab("Home")


# ---------------------------------------------------------
# NAV BUTTONS
# ---------------------------------------------------------

## Finds the nodes named Home, Growth, ... under NavBar and
## listens for taps on them (or on the button inside them).
func _connect_nav_buttons() -> void:
	for node in nav_bar.find_children("*", "", true, false):
		var tab := str(node.name)
		if not tab in TABS or _nav_buttons.has(tab):
			continue

		var button := node
		if not node.has_signal("pressed"):
			var inner := node.find_children("*", "BaseButton", true, false)
			if inner.is_empty():
				push_warning("ScreenRouter: no button inside " + tab)
				continue
			button = inner[0]

		button.connect("pressed", open_tab.bind(tab))
		_nav_buttons[tab] = node

	for tab in TABS:
		if not _nav_buttons.has(tab):
			push_warning("ScreenRouter: no nav button named " + tab)


## Quick menu tabs are named FormationTab, SummonTab, ...
func _connect_quick_tabs() -> void:
	for tab in QUICK_TABS:
		var node := _quick_menu.find_child(tab + "Tab", true, false)
		if node == null:
			push_warning("ScreenRouter: no quick tab named %sTab" % tab)
			continue
		if node.has_signal("pressed"):
			node.connect("pressed", open_quick.bind(tab))


## Dims tabs whose feature is still locked, and announces new unlocks.
func _refresh_locks() -> void:
	for tab in _nav_buttons:
		var node = _nav_buttons[tab]
		if node is CanvasItem:
			(node as CanvasItem).modulate = Color.WHITE if Unlocks.place_open("nav:" + str(tab)) \
				else Color(0.45, 0.45, 0.5)
	if _quick_menu != null:
		for tab in QUICK_TABS:
			var q := _quick_menu.find_child(tab + "Tab", true, false) as CanvasItem
			if q != null:
				q.modulate = Color.WHITE if Unlocks.place_open("quick:" + tab) else Color(0.45, 0.45, 0.5)
	var fresh := Unlocks.check_new()
	if not fresh.is_empty():
		_announce_queue.append_array(fresh)
		if not _announcing:
			_announce_next()


var _announce_queue: Array = []
var _announcing := false


## New-unlock banners one at a time (several can open at once).
func _announce_next() -> void:
	_announcing = true
	while not _announce_queue.is_empty():
		var id := str(_announce_queue.pop_front())
		Unlocks.announce(self, id)
		unlocked.emit(id)
		await get_tree().create_timer(3.0).timeout
	_announcing = false


## Tells each nav button whether it's the active one, if it supports that.
func _update_nav_highlight() -> void:
	for tab in _nav_buttons:
		var node = _nav_buttons[tab]
		var active: bool = tab == _current
		if node.has_method("set_active"):
			node.call("set_active", active)
		elif node is BaseButton and node.toggle_mode:
			node.set_pressed_no_signal(active)


# ---------------------------------------------------------
# SWITCHING
# ---------------------------------------------------------

func open_tab(tab: String) -> void:
	if tab == _current:
		return
	# Locked feature: say what opens it instead
	if not Unlocks.place_open("nav:" + tab):
		Unlocks.toast(self, Unlocks.requirement_text(Unlocks.feature_at("nav:" + tab)))
		return
	_current = tab
	_apply()
	_update_nav_highlight()
	tab_opened.emit(tab)


## Opens the More tab at a section, e.g. open_more("Top Up").
func open_more(section: String, anchor := "") -> void:
	open_tab("More")
	var inner = _screen_inner.get("nav:More")
	if inner != null and inner.has_method("open_section"):
		inner.call("open_section", section, anchor)


func open_quick(tab: String) -> void:
	if not Unlocks.place_open("quick:" + tab):
		Unlocks.toast(self, Unlocks.requirement_text(Unlocks.feature_at("quick:" + tab)))
		return
	# Tapping a quick tab always brings you back to Home.
	var changed := tab != _quick or _current != "Home"
	_quick = tab
	_current = "Home"
	if changed:
		_apply()
		_update_nav_highlight()


## Shows exactly what the current nav tab + quick tab call for.
func _apply() -> void:
	var on_home := _current == "Home"
	var keep: Array = KEEP_NODES.get(_quick, [])

	if _quick_menu != null:
		_quick_menu.visible = on_home
	for node in _home_nodes:
		node.visible = on_home and str(node.name) in keep
	for key in _screens:
		_screens[key].visible = false

	var screen: Control = null
	if not on_home:
		screen = _get_screen("nav", _current)
	elif not _quick in NO_SCREEN:
		screen = _get_screen("quick", _quick)

	if screen != null:
		screen.visible = true
		var inner: Control = _screen_inner.get(_last_key, screen)
		if inner.has_method("on_opened"):
			inner.call("on_opened")

	_fade_in(self)


func _fade_in(node: CanvasItem) -> void:
	if _fade != null:
		_fade.kill()
	node.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(node, "modulate:a", 1.0, 0.15)


## Loads the tab's screen the first time it's opened, or builds a placeholder.
var _last_key := ""


func _get_screen(kind: String, tab: String) -> Control:
	var key := kind + ":" + tab
	_last_key = key
	if _screens.has(key):
		return _screens[key]

	var screen: Control
	var base := SCREENS_FOLDER + tab.to_lower() + "_screen"
	if ResourceLoader.exists(base + ".tscn"):
		screen = (load(base + ".tscn") as PackedScene).instantiate()
	elif ResourceLoader.exists(base + ".gd"):
		screen = (load(base + ".gd") as GDScript).new()
	else:
		screen = _build_placeholder(tab)

	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Wrap it so it keeps clear of the frame around the lower panel
	var wrapper := MarginContainer.new()
	wrapper.name = tab + "Wrapper"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_gaps(wrapper)
	wrapper.add_child(screen)
	wrapper.visible = false
	add_child(wrapper)

	_screens[key] = wrapper
	_screen_inner[key] = screen
	return wrapper


# ---------------------------------------------------------
# PLACEHOLDERS
# ---------------------------------------------------------

func _build_placeholder(tab: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = tab + "Screen"
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel_color
	sb.border_color = border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	v.add_child(_label(_title_for(tab), 44, title_color))
	v.add_child(_divider())

	match tab:
		"Growth":
			v.add_child(_label("Strengthen your whole sect.", 26, dim_color))
			v.add_child(_feature_card("Abode", "Build and upgrade your cultivation abode."))
			v.add_child(_feature_card("God Path", "Walk a path of the gods for lasting bonuses."))
		"Codex":
			var owned := GameState.roster.size() - 1   # minus the MC
			var total := PartnerDatabase.get_all_ids().size()
			v.add_child(_label("Partners discovered:  %d / %d" % [owned, total], 30, text_color))
			v.add_child(_label("Full collection view coming soon.", 26, dim_color))
		"Guild":
			v.add_child(_label("Join a sect and cultivate together.", 28, text_color))
			v.add_child(_label("Coming soon.", 26, dim_color))
		"Summon", "Formation", "Inventory":
			v.add_child(_label("Put %s_screen.gd in res://ui/screens/" % tab.to_lower(), 26, dim_color))
		"Mission":
			v.add_child(_label("Daily and weekly missions will appear here.", 28, text_color))
			v.add_child(_label("Coming soon.", 26, dim_color))
		"Events":
			v.add_child(_label("Limited-time events and login rewards.", 28, text_color))
			v.add_child(_label("Coming soon.", 26, dim_color))
		_:
			v.add_child(_label("Settings, mail, friends and more.", 28, text_color))
			v.add_child(_label("Coming soon.", 26, dim_color))

	return panel


func _title_for(tab: String) -> String:
	match tab:
		"Mission":
			return "Missions"
		_:
			return tab


func _feature_card(title: String, description: String) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(border_color, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_label(title, 34, text_color, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := _label(description, 24, dim_color, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)
	h.add_child(texts)

	var soon := _label("Soon", 24, dim_color)
	soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(soon)

	return card


func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(border_color, 0.7)
	line.custom_minimum_size = Vector2(0, 2)
	return line


func _label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
