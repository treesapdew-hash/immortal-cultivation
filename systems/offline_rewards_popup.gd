class_name OfflineRewardsPopup
extends CanvasLayer

# =========================================================
# "Closed-Door Cultivation": what you earned while away.
#   OfflineRewardsPopup.open(self)
# Does nothing if there's nothing to claim.
#
# A rewarded ad (placement "offline_double", 3/day) doubles the
# haul before it is claimed: it multiplies GameState.pending_offline
# in place, so the existing claim path grants the larger amounts.
# =========================================================

signal claimed(rewards: Dictionary)

const GOLD := Color("e2c27a")
const TITLE := Color("f2d98a")
const TEXT := Color("c9d4e3")
const DIM := Color("7f8ea3")
const QI := Color("8ff0ff")
const STONES := Color("b9d4ff")

const AD_PLACEMENT := "offline_double"

var _root: Control
var _panel: PanelContainer
var _claim: OrnateButton
var _double: OrnateButton
var _double_note: Label
var _value_labels: Dictionary = {}   # total title -> Label showing the amount
var _item_slots: Dictionary = {}     # item id -> ItemSlot
var _doubled := false
var _busy := false


static func open(host: Node) -> OfflineRewardsPopup:
	if not GameState.has_offline_rewards():
		return null
	var popup := OfflineRewardsPopup.new()
	host.get_tree().root.add_child.call_deferred(popup)
	return popup


func _ready() -> void:
	layer = 65
	# The fake test ad counts down off this node's delta, so keep
	# processing even if something else pauses the tree meanwhile.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_show()


func _build() -> void:
	var r: Dictionary = GameState.pending_offline

	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(880, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(34)
	sb.shadow_color = Color(GOLD, 0.2)
	sb.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.resized.connect(func(): _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_panel.add_child(v)

	v.add_child(_label("Closed-Door Cultivation", 40, TITLE, true))

	var away := "You meditated for %s" % Loot.format_duration(r["seconds"])
	if r["capped"]:
		away += "  (rewards count up to %s)" % Loot.format_duration(r["counted_seconds"])
	var away_label := _label(away, 22, DIM)
	away_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(away_label)

	v.add_child(_line())

	# Qi and Spirit Stones
	var totals := HBoxContainer.new()
	totals.alignment = BoxContainer.ALIGNMENT_CENTER
	totals.add_theme_constant_override("separation", 60)
	v.add_child(totals)
	totals.add_child(_total("Qi", r["qi"], QI))
	totals.add_child(_total("Spirit Stones", r["stones"], STONES))

	# Materials
	var items: Dictionary = r["items"]
	if not items.is_empty():
		v.add_child(_label("Materials gathered", 24, TEXT))
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		var holder := CenterContainer.new()
		holder.add_child(grid)
		v.add_child(holder)

		var ids := items.keys()
		ids.sort_custom(func(a, b):
			return ItemDB.get_item(a).get("grade", 0) > ItemDB.get_item(b).get("grade", 0))
		for id in ids:
			var slot := ItemSlot.new()
			slot.custom_minimum_size = Vector2(104, 104)
			slot.disabled = true
			slot.setup_item(id, int(items[id]))
			grid.add_child(slot)
			_item_slots[id] = slot

	v.add_child(_line())

	v.add_child(_label("%d battles fought while you were away" % r["battles"], 20, DIM))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)

	# The doubling ad sits above Claim: claiming closes the popup, so
	# the offer has to be seen first.
	if Ads.can_watch(AD_PLACEMENT):
		_double = OrnateButton.new()
		_double.text = "Double Rewards - Watch Ad"
		_double.variant = OrnateButton.Variant.CRIMSON
		_double.custom_minimum_size = Vector2(440, 76)
		_double.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_double.add_theme_font_size_override("font_size", 26)
		_double.pressed.connect(_on_double)
		buttons.add_child(_double)

		_double_note = _label(_ads_left_text(), 18, DIM)
		_double_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buttons.add_child(_double_note)

	_claim = OrnateButton.new()
	_claim.text = "Claim"
	_claim.custom_minimum_size = Vector2(320, 80)
	_claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_claim.add_theme_font_size_override("font_size", 30)
	_claim.pressed.connect(_on_claim)
	buttons.add_child(_claim)


func _ads_left_text() -> String:
	var n := Ads.left(AD_PLACEMENT)
	var per_day := int(Ads.PLACEMENTS[AD_PLACEMENT][1])
	return "%d of %d left today" % [n, per_day]


func _total(title: String, amount: int, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var n := _label("+" + NumberFormat.short(amount), 44, color, true)
	box.add_child(n)
	box.add_child(_label(title, 20, DIM))
	_value_labels[title] = n
	return box


func _show() -> void:
	_root.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	var t := create_tween().set_parallel(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.25)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------
# DOUBLING
# ---------------------------------------------------------

func _on_double() -> void:
	if _busy or _doubled:
		return
	_busy = true
	_set_buttons_enabled(false)

	var ok: bool = await Ads.watch(self, AD_PLACEMENT)

	# The popup can be gone by the time the ad finishes.
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_busy = false

	if not ok or GameState.pending_offline.is_empty():
		_set_buttons_enabled(true)
		return

	_doubled = true
	_double_pending()
	_refresh_values()
	if _double != null:
		_double.visible = false
	if _double_note != null:
		_double_note.text = "Rewards doubled"
		_double_note.add_theme_color_override("font_color", TITLE)
	_set_buttons_enabled(true)


## Multiplies the pending haul in place, so claim_offline() grants it.
func _double_pending() -> void:
	var r: Dictionary = GameState.pending_offline
	if r.is_empty():
		return
	r["qi"] = int(r["qi"]) * 2
	r["stones"] = int(r["stones"]) * 2
	var items: Dictionary = r["items"]
	for id in items:
		items[id] = int(items[id]) * 2
	r["items"] = items
	GameState.pending_offline = r


func _refresh_values() -> void:
	var r: Dictionary = GameState.pending_offline
	if r.is_empty():
		return
	_set_value("Qi", int(r["qi"]))
	_set_value("Spirit Stones", int(r["stones"]))
	var items: Dictionary = r["items"]
	for id in items:
		if _item_slots.has(id):
			var slot: ItemSlot = _item_slots[id]
			slot.setup_item(str(id), int(items[id]))


func _set_value(title: String, amount: int) -> void:
	if not _value_labels.has(title):
		return
	var lbl: Label = _value_labels[title]
	lbl.text = "+" + NumberFormat.short(amount)
	lbl.pivot_offset = lbl.size * 0.5
	var t := create_tween()
	t.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _set_buttons_enabled(on: bool) -> void:
	if _claim != null:
		_claim.disabled = not on
	if _double != null:
		_double.disabled = not on


# ---------------------------------------------------------
# CLAIM
# ---------------------------------------------------------

func _on_claim() -> void:
	if _busy:
		return
	var got := GameState.claim_offline()
	claimed.emit(got)
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func _line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(GOLD, 0.0), Color(GOLD, 0.7), Color(GOLD, 0.0)]), 1.5, true)
	)
	return line


func _label(text: String, font_size: int, color: Color, glow := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(color, 0.3))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
