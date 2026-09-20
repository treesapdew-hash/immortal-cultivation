extends PanelContainer

# =========================================================
# Formation screen, built in code. Save as
#   res://ui/screens/formation_screen.gd
#
# Shows every partner you own. Slot 1 is always the MC.
# Team members can't be removed, only swapped:
#   Tap a partner           -> add to the first free slot
#   Drag partner -> slot    -> put it there (whoever was there
#                              goes back to the list)
#   Drag slot -> slot       -> swap positions
#   Drag slot -> this list  -> snaps back, with a hint to swap
# The formation row above updates by itself.
# =========================================================

const CARD_SIZE := Vector2(128, 171)
const COLUMNS := 5

const COL_PANEL  := Color(0.05, 0.1, 0.19, 0.92)
const COL_BORDER := Color("3a5a80")
const COL_TITLE  := Color("f2d98a")
const COL_TEXT   := Color("c9d4e3")
const COL_DIM    := Color("7f8ea3")
const COL_TEAM   := Color("7dffa8")
const COL_ERROR  := Color("ff7a7a")
const COL_GOLD   := Color("e0b85a")
const COL_GOLD_TX := Color("ffe6a8")

## Card frame colours by tier (WHITE ... PRISMATIC)
const TIER_COLORS := [
	Color("d9dde3"), Color("4d9bff"), Color("3fcf6a"), Color("a864f2"),
	Color("f24d4d"), Color("ffc93c"), Color("aef2ff"),
]

var _team_label: Label
var _stuck_time := 0.0
var _hint: Label
var _grid: GridContainer
var _empty_box: Control
var _dirty := true

var _slots: Array[Control] = []    # formation row slots, index 0 = MC
var _drag_glow := false
var _lifted: Control               # the card or slot being dragged (faded)


func _ready() -> void:
	name = "FormationScreen"
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20)
	add_theme_stylebox_override("panel", sb)

	SummonCard.find_frames(self)
	_build()
	_setup_drag_and_drop()
	GameState.roster_changed.connect(_mark_dirty)
	GameState.formation_changed.connect(_mark_dirty)
	_rebuild()


func on_opened() -> void:
	_hint.text = ""
	if _dirty:
		_rebuild()


func _mark_dirty() -> void:
	_dirty = true
	if is_visible_in_tree():
		_rebuild()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)

	var title := _label("Formation", 40, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	_team_label = _label("", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_team_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_team_label)

	var help := _label("Tap a partner to fill an empty slot, or drag one onto a slot to swap. Team members can't be removed, only swapped. Slot 1 is you.",
		22, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)

	_hint = _label("", 22, COL_ERROR, HORIZONTAL_ALIGNMENT_LEFT)
	_hint.custom_minimum_size.y = 26
	v.add_child(_hint)

	var center := CenterContainer.new()
	v.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	center.add_child(_grid)

	# Shown when you don't own any partners yet
	var empty := VBoxContainer.new()
	empty.add_theme_constant_override("separation", 16)
	empty.custom_minimum_size = Vector2(0, 260)
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(empty)
	_empty_box = empty

	empty.add_child(_label("You have no partners yet.", 30, COL_TEXT))
	empty.add_child(_label("Summon to recruit your first companions.", 24, COL_DIM))

	var go := Button.new()
	go.text = "Go to Summon"
	go.custom_minimum_size = Vector2(300, 90)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_gold(go)
	go.pressed.connect(_go_to_summon)
	empty.add_child(go)


# ---------------------------------------------------------
# ROSTER GRID
# ---------------------------------------------------------

func _rebuild() -> void:
	_dirty = false

	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()

	_team_label.text = "Team  %d / %d" % [GameState.get_team_size(), GameState.FORMATION_SIZE]

	# Every partner except the MC (roster index 0)
	var entries: Array = []
	for i in range(1, GameState.roster.size()):
		var p: OwnedPartner = GameState.roster[i]
		var data := p.get_data()
		if data == null:
			continue
		entries.append({"index": i, "partner": p, "data": data,
			"slot": GameState.get_slot_of(i)})

	# Team members first, then by tier (highest first), then by strength
	entries.sort_custom(func(a, b):
		var a_in: bool = a["slot"] > 0
		var b_in: bool = b["slot"] > 0
		if a_in != b_in:
			return a_in
		if a["data"].rarity != b["data"].rarity:
			return a["data"].rarity > b["data"].rarity
		return a["partner"].get_power() > b["partner"].get_power()
	)

	_empty_box.visible = entries.is_empty()
	_grid.visible = not entries.is_empty()

	for e in entries:
		_grid.add_child(_make_card(e))


func _make_card(e: Dictionary) -> Control:
	var p: OwnedPartner = e["partner"]
	var data = e["data"]
	var slot: int = e["slot"]
	var in_team := slot > 0
	var card_size := SummonCard.size_for_width(CARD_SIZE.x)

	var card := Button.new()
	card.flat = true
	card.custom_minimum_size = card_size
	card.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	card.pressed.connect(_on_card_pressed.bind(e["index"]))
	card.set_drag_forwarding(
		_card_drag_data.bind(card, e["index"]),
		_list_can_drop, _list_drop)

	# Your tier frame with the fitted art
	var face := SummonCard.new()
	face.setup({"partner_id": p.partner_id}, data.rarity, card_size)
	face.show_front()
	if not in_team:
		face.modulate = Color(0.85, 0.85, 0.9)
	card.add_child(face)

	var name_label := _label(data.display_name, 14, Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(6, card_size.y * 0.74)
	name_label.size = Vector2(card_size.x - 12, card_size.y * 0.1)
	card.add_child(name_label)

	# Realm instead of Power (Power is only for PvP)
	var realm := _label(p.get_realm_text(), 11, COL_GOLD_TX)
	realm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	realm.add_theme_constant_override("outline_size", 4)
	realm.clip_text = true
	realm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	realm.position = Vector2(6, card_size.y * 0.83)
	realm.size = Vector2(card_size.x - 12, card_size.y * 0.09)
	card.add_child(realm)

	if in_team:
		var tag := _label("SLOT %d" % (slot + 1), 15, COL_TEAM)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 5)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.position = Vector2(0, card_size.y * 0.07)
		tag.size = Vector2(card_size.x, 22)
		card.add_child(tag)

		# Soft green glow around team members
		card.draw.connect(func():
			for i in 3:
				var g := 2.0 + i * 2.0
				card.draw_rect(Rect2(Vector2(-g, -g), card_size + Vector2(g, g) * 2.0),
					Color(COL_TEAM, 0.35 - i * 0.1), false, 2.0)
		)

	return card


func _on_card_pressed(roster_index: int) -> void:
	_hint.text = ""
	if GameState.get_slot_of(roster_index) > 0:
		# Team members stay: they can only be swapped out
		_hint.text = "Already in your team. Drag another partner onto their slot to swap."
	elif not GameState.add_to_formation(roster_index):
		_hint.text = "Team is full. Drag this partner onto a slot to swap."


# ---------------------------------------------------------
# DRAG AND DROP
# Drag data: {"type": "partner", "roster_index": i, "from_slot": s}
# from_slot is -1 when dragged from the list.
# ---------------------------------------------------------

func _setup_drag_and_drop() -> void:
	# Dropping anywhere on this screen removes a dragged team member.
	set_drag_forwarding(Callable(), _list_can_drop, _list_drop)

	var row: Node = null
	var scene := get_tree().current_scene
	if scene != null:
		row = scene.find_child("SlotRow", true, false)
	if row == null:
		push_warning("FormationScreen: SlotRow not found, drag and drop to slots disabled")
		return

	for child in row.get_children():
		if child is Control and child.has_method("set_partner"):
			_slots.append(child)

	for i in _slots.size():
		var slot := _slots[i]
		slot.set_drag_forwarding(
			_slot_drag_data.bind(slot, i),
			_slot_can_drop.bind(i),
			_slot_drop.bind(i))
		# Let drops reach the slot even when hovering its art.
		for node in slot.find_children("*", "Control", true, false):
			if node.mouse_filter == Control.MOUSE_FILTER_STOP and not node is BaseButton:
				node.mouse_filter = Control.MOUSE_FILTER_PASS


func _card_drag_data(_at: Vector2, card: Control, roster_index: int) -> Variant:
	_lift(card)
	card.set_drag_preview(_make_preview(roster_index))
	var from_slot := GameState.get_slot_of(roster_index)
	if from_slot > 0:
		_hint.text = "Drop on another slot to swap places. Team members can't be removed."
	return {"type": "partner", "roster_index": roster_index, "from_slot": from_slot}


func _slot_drag_data(_at: Vector2, slot: Control, slot_index: int) -> Variant:
	if slot_index <= 0:
		return null   # the MC stays put
	var roster_index: int = GameState.formation[slot_index]
	if roster_index < 0:
		return null
	_lift(slot)
	slot.set_drag_preview(_make_preview(roster_index))
	_hint.text = "Drop on another slot to swap places. Team members can't be removed."
	return {"type": "partner", "roster_index": roster_index, "from_slot": slot_index}


## Fades whatever was picked up; restored when the drag ends.
func _lift(node: Control) -> void:
	_drop_lifted()
	_lifted = node
	node.modulate.a = 0.35


func _drop_lifted() -> void:
	if is_instance_valid(_lifted):
		_lifted.modulate.a = 1.0
	_lifted = null


func _is_partner_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "partner"


func _slot_can_drop(_at: Vector2, data: Variant, slot_index: int) -> bool:
	return slot_index > 0 and _is_partner_drag(data)


func _slot_drop(_at: Vector2, data: Variant, slot_index: int) -> void:
	var roster_index: int = data["roster_index"]
	var from_slot: int = data["from_slot"]
	if from_slot == slot_index:
		return

	var occupant: int = GameState.formation[slot_index]

	# Moves the partner here (and clears its old slot, if any).
	GameState.set_formation_slot(slot_index, roster_index)

	# Slot to slot: whoever was here takes the old slot.
	if from_slot > 0 and occupant >= 0:
		GameState.set_formation_slot(from_slot, occupant)

	_hint.text = ""


## Team members can't be dropped back on the list (no unequipping):
## refusing the drop lets Godot fly the card back by itself.
func _list_can_drop(_at: Vector2, _data: Variant) -> bool:
	return false


## Team members can't be removed: the drag snaps back with a hint.
func _list_drop(_at: Vector2, _data: Variant) -> void:
	_drop_lifted()
	_hint.text = "Team members can't be removed. Drag another partner onto their slot to swap."


## A full little card that floats above the finger, pops in and sways.
func _make_preview(roster_index: int) -> Control:
	var p: OwnedPartner = GameState.roster[roster_index]
	var data := p.get_data()
	var card_size := SummonCard.size_for_width(CARD_SIZE.x * 1.1)

	# The holder sits exactly on the finger; the card floats above it.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card := SummonCard.new()
	card.setup({"partner_id": p.partner_id}, data.rarity if data != null else 0, card_size)
	card.show_front()
	card.position = Vector2(-card_size.x * 0.5, -card_size.y * 0.85)
	card.pivot_offset = Vector2(card_size.x * 0.5, card_size.y * 0.85)

	# Drop shadow behind the lifted card (added first so it's underneath)
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = card.position + Vector2(8, 12)
	shadow.size = card_size
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.0)
	ssb.shadow_color = Color(0, 0, 0, 0.55)
	ssb.shadow_size = 18
	shadow.add_theme_stylebox_override("panel", ssb)
	holder.add_child(shadow)
	holder.add_child(card)

	# Pop in
	card.scale = Vector2(0.85, 0.85)
	var pop := card.create_tween()
	pop.tween_property(card, "scale", Vector2(1.05, 1.05), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Sway toward the direction of movement
	var last := [get_global_mouse_position()]
	var sway := func():
		if not is_instance_valid(card) or not card.is_inside_tree():
			return
		var m := card.get_global_mouse_position()
		var dx: float = m.x - last[0].x
		last[0] = m
		var target := clampf(dx * 0.015, -0.3, 0.3)
		card.rotation = lerpf(card.rotation, target, 0.2)
	get_tree().process_frame.connect(sway)
	holder.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(sway):
			get_tree().process_frame.disconnect(sway)
	)

	return holder


## While dragging: slots you can drop on glow, and the one under
## the finger grows. Everything resets when the drag ends.
func _process(delta: float) -> void:
	var dragging := get_viewport().gui_is_dragging() \
		and _is_partner_drag(get_viewport().gui_get_drag_data())

	# Safety net: a drag released somewhere Godot doesn't expect (off the
	# panel, on the battlefield) can stay "stuck" with its card floating.
	# If nothing is actually held down any more, cancel it.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stuck_time += delta
		if _stuck_time > 0.25:
			_stuck_time = 0.0
			get_viewport().gui_cancel_drag()
			_drop_lifted()
			return
	else:
		_stuck_time = 0.0

	if dragging:
		var mouse := get_global_mouse_position()
		for i in range(1, _slots.size()):
			var slot := _slots[i]
			slot.pivot_offset = slot.size * 0.5
			var hovered := slot.get_global_rect().has_point(mouse)
			var target := Vector2(1.1, 1.1) if hovered else Vector2.ONE
			slot.scale = slot.scale.lerp(target, 0.3)

	if dragging == _drag_glow:
		return
	_drag_glow = dragging

	if not dragging:
		_drop_lifted()

	for i in range(1, _slots.size()):
		var slot := _slots[i]
		if dragging:
			var t := slot.create_tween().set_loops()
			t.tween_property(slot, "self_modulate", Color(1.3, 1.3, 1.1), 0.45)
			t.tween_property(slot, "self_modulate", Color.WHITE, 0.45)
			slot.set_meta("glow_tween", t)
		else:
			if slot.has_meta("glow_tween"):
				var t: Tween = slot.get_meta("glow_tween")
				if t != null and t.is_valid():
					t.kill()
				slot.remove_meta("glow_tween")
			slot.self_modulate = Color.WHITE
			slot.scale = Vector2.ONE


func _go_to_summon() -> void:
	# The router is an ancestor (the screen sits inside a wrapper)
	var router := get_parent()
	while router != null and not router.has_method("open_quick"):
		router = router.get_parent()
	if router != null:
		router.call("open_quick", "Summon")


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

## Stretches a label across the card between two heights (0-1).
func _pin(l: Label, top: float, bottom: float) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = top
	l.anchor_bottom = bottom


func _label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _style_gold(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("5a3f12")
	normal.border_color = COL_GOLD
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(16)
	var down: StyleBoxFlat = normal.duplicate()
	down.bg_color = Color("7a5818")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", COL_GOLD_TX)


func _fmt(value: int) -> String:
	return NumberFormat.short(value)
