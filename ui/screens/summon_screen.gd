extends PanelContainer

# =========================================================
# Summon screen: the Summoning Altar. Save as
#   res://ui/screens/summon_screen.gd
# (the screen router opens it from the Summon tab).
#
# Rules are in summon_system.gd. Scrolls are used before Jade.
# Optional art: assets/ui/summon/summon_banner.png behind the
# showcase (drawn glow if missing).
# =========================================================

const BANNER_ART := "res://assets/ui/summon/summon_banner.png"
const SHOWCASE_CARD := 210.0
const RESULT_CARD := 150.0

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")
const COL_JADE := Color("7dffa8")
const COL_PITY := Color("b476ff")

var _body: VBoxContainer
var _hint: Label
var _busy := false
var _last_results: Array = []
var _showcase: Array = []


func _ready() -> void:
	name = "SummonScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	pad.add_child(_body)

	GameState.currency_changed.connect(_refresh)
	GameState.roster_changed.connect(_refresh)
	_refresh()


## Called by the router each time the tab opens.
func on_opened() -> void:
	_refresh()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _refresh() -> void:
	if _body == null or _busy:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	_body.add_child(_header())
	_body.add_child(_banner())
	_body.add_child(_pity_bar())
	_body.add_child(_fate_panel())
	_body.add_child(_pull_buttons())
	if Ads.can_watch("free_summon"):
		var ad := OrnateButton.new()
		ad.text = "Watch Ad: Free Summon ×1  (%d left today)" % Ads.left("free_summon")
		ad.variant = OrnateButton.Variant.DARK
		ad.custom_minimum_size = Vector2(0, 58)
		ad.add_theme_font_size_override("font_size", 19)
		ad.disabled = _busy
		ad.pressed.connect(_on_ad_summon)
		_body.add_child(ad)
	_hint = _label("", 20, COL_BAD)
	_body.add_child(_hint)

	var scrolls := SummonSystem.owned_selection_scrolls()
	if not scrolls.is_empty():
		_body.add_child(_fade_line())
		_body.add_child(_label("Selection Scrolls", 24, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
		for entry in scrolls:
			_body.add_child(_scroll_row(entry))

	if not _last_results.is_empty():
		_body.add_child(_fade_line())
		_body.add_child(_label("Last Summon", 24, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
		_body.add_child(_results_grid())


func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(titles)
	titles.add_child(_label("Summoning Altar", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	titles.add_child(_label("Summon", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	h.add_child(_chip_text("Jade", GameState.immortal_jade, COL_JADE))
	h.add_child(_chip_item(SummonSystem.SCROLL_ID))
	h.add_child(_chip_item(SummonSystem.BUNDLE_ID))

	var rates := OrnateButton.new()
	rates.text = "Rates"
	rates.variant = OrnateButton.Variant.DARK
	rates.custom_minimum_size = Vector2(120, 48)
	rates.add_theme_font_size_override("font_size", 18)
	rates.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rates.pressed.connect(_open_rates)
	h.add_child(rates)
	return h


## Showcase of the best summonable cards, fanned out and glowing.
func _banner() -> Control:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0a1224")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", sb)
	frame.clip_contents = true
	frame.custom_minimum_size = Vector2(0, 440)

	if ResourceLoader.exists(BANNER_ART):
		var art := TextureRect.new()
		art.texture = load(BANNER_ART) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(0.75, 0.75, 0.8)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(art)

	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stage)
	stage.draw.connect(func():
		var c := Vector2(stage.size.x * 0.5, stage.size.y * 0.5)
		for i in 6:
			stage.draw_circle(c, stage.size.y * (0.55 - i * 0.07), Color(1.0, 0.8, 0.4, 0.035))
	)

	# The showcase cards
	var ids := _showcase_ids()
	# Frames come from the scene; ask with a node that's already on screen
	SummonCard.find_frames(self)
	var card_size := SummonCard.size_for_width(SHOWCASE_CARD)
	var angles := [-9.0, 0.0, 9.0]
	var offsets := [-0.25, 0.0, 0.25]
	var order := [0, 2, 1]   # middle card drawn last, on top
	var holders: Array = []
	for k in order:
		if k >= ids.size():
			continue
		var data = PartnerDatabase.get_partner(str(ids[k]))
		if data == null:
			continue
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size = card_size
		holder.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
		holder.rotation = deg_to_rad(float(angles[k]))
		var card := SummonCard.new()
		card.setup({"partner_id": str(ids[k])}, data.rarity, card_size)
		card.show_front()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(card)
		stage.add_child(holder)
		holders.append([holder, float(offsets[k]), k == 1])

	stage.resized.connect(func():
		for entry in holders:
			var node: Control = entry[0]
			var cx: float = stage.size.x * (0.5 + float(entry[1]))
			var lift := 16.0 if bool(entry[2]) else 0.0
			node.position = Vector2(cx - card_size.x * 0.5, stage.size.y * 0.5 - card_size.y * 0.5 - lift)
	)

	# Dark fade along the bottom so the caption reads over any art
	var shade := Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)
	shade.draw.connect(func():
		var w := shade.size.x
		var h := shade.size.y
		var top := h * 0.62
		shade.draw_polygon(
			PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.01, 0.02, 0.05, 0.88), Color(0.01, 0.02, 0.05, 0.88)]))
	)
	shade.resized.connect(shade.queue_redraw)

	# Caption on its own dark plaque, readable over any art
	var cap_holder := VBoxContainer.new()
	cap_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_holder.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(cap_holder)
	var plaque := PanelContainer.new()
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.02, 0.03, 0.08, 0.86)
	psb.border_color = Color(COL_GOLD, 0.75)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(22)
	psb.content_margin_left = 34
	psb.content_margin_right = 34
	psb.content_margin_top = 8
	psb.content_margin_bottom = 10
	psb.shadow_color = Color(0, 0, 0, 0.5)
	psb.shadow_size = 10
	plaque.add_theme_stylebox_override("panel", psb)
	cap_holder.add_child(plaque)
	var cap := VBoxContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_constant_override("separation", 0)
	plaque.add_child(cap)
	var title := _label("Heavenly Fate", 34, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.95))
	title.add_theme_constant_override("outline_size", 6)
	cap.add_child(title)
	var sub := _label("Red  %s%%   ·   a Purple in every ×10" % String.num(SummonSystem.RATES[Enums.Rarity.RED]),
		20, Color("f0e6d2"))
	cap.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_holder.add_child(spacer)
	return frame


## Up to three of the best summonable partners (same ones until you pull).
func _showcase_ids() -> Array:
	if not _showcase.is_empty():
		return _showcase
	var pools := SummonSystem._build_pools()
	var tiers: Array = pools.keys()
	tiers.sort()
	tiers.reverse()
	var ids: Array = []
	for tier in tiers:
		var src: Array = pools[tier]
		var pool := src.duplicate()
		pool.shuffle()
		for id in pool:
			if ids.size() >= 3:
				break
			ids.append(id)
		if ids.size() >= 3:
			break
	_showcase = ids
	return ids


func _pity_bar() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var left := SummonSystem.pulls_until_pity()
	v.add_child(_label("Purple guaranteed in  %d  summon%s" % [left, "" if left == 1 else "s"], 20, COL_TEXT))
	var fill := clampf(float(GameState.summon_pity) / float(SummonSystem.PITY_LIMIT), 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 2, w, 12), Color(0, 0, 0, 0.55))
		bar.draw_rect(Rect2(0, 2, w * fill, 12), COL_PITY)
		bar.draw_rect(Rect2(0, 2, w * fill, 4), Color(1, 1, 1, 0.18))
		bar.draw_rect(Rect2(0, 2, w, 12), Color(COL_GOLD, 0.5), false, 1.0)
	)
	v.add_child(bar)
	return v


## Fate Points bar, this rotation's featured Reds, and the Exchange button.
func _fate_panel() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.06)
	sb.border_color = Color(COL_GOLD, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var pts := GameState.fate_points
	v.add_child(_label("Fate Points   %s / %d" % [NumberFormat.short(pts), SummonSystem.FATE_COST], 20, COL_TITLE,
		HORIZONTAL_ALIGNMENT_LEFT))
	var fill := clampf(float(pts) / float(SummonSystem.FATE_COST), 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 1, w, 12), Color(0, 0, 0, 0.55))
		bar.draw_rect(Rect2(0, 1, w * fill, 12), Color("ffcf4a"))
		bar.draw_rect(Rect2(0, 1, w * fill, 4), Color(1, 1, 1, 0.2))
		bar.draw_rect(Rect2(0, 1, w, 12), Color(COL_GOLD, 0.5), false, 1.0)
	)
	v.add_child(bar)
	var names := PackedStringArray()
	for id in SummonSystem.featured_ids():
		var data = PartnerDatabase.get_partner(str(id))
		if data != null:
			names.append(data.display_name)
	var days := SummonSystem.days_to_rotation()
	var featured := _label("Featured Reds: %s  ·  new in %d day%s" % [", ".join(names), days, "" if days == 1 else "s"],
		15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	featured.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(featured)

	var ex := OrnateButton.new()
	ex.text = "Fate Exchange"
	ex.custom_minimum_size = Vector2(220, 60)
	ex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.disabled = SummonSystem.featured_ids().is_empty()
	ex.pressed.connect(_open_fate_exchange)
	h.add_child(ex)
	return panel


func _open_fate_exchange() -> void:
	var options := SummonSystem.featured_ids()
	var enough := GameState.fate_points >= SummonSystem.FATE_COST
	var note := "Choose a featured Red for %d Fate Points." % SummonSystem.FATE_COST if enough \
		else "You need %d more Fate Points. Every summon gives %d." % [
			SummonSystem.FATE_COST - GameState.fate_points, SummonSystem.FATE_PER_PULL]
	var popup := CardChoicePopup.open(self, "Fate Exchange  ·  %s / %d Fate Points" % [
		NumberFormat.short(GameState.fate_points), SummonSystem.FATE_COST], options, Enums.Rarity.RED, note)
	popup.chosen.connect(func(partner_id: String):
		if SummonSystem.exchange(partner_id):
			var data = PartnerDatabase.get_partner(partner_id)
			_toast("%s answers your call!" % (data.display_name if data != null else "A partner"), COL_OK)
		else:
			_toast("Not enough Fate Points yet.", COL_BAD)
		_refresh()
	)


func _pull_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for count in [1, 10]:
		var b := OrnateButton.new()
		b.variant = OrnateButton.Variant.CRIMSON if count == 10 else OrnateButton.Variant.GOLD
		b.text = "Summon ×%d\n%s" % [count, SummonSystem.cost_text(count)]
		b.custom_minimum_size = Vector2(420, 112)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = _busy or not SummonSystem.can_afford(count)
		b.pressed.connect(_on_pull.bind(count))
		row.add_child(b)
	return row


func _scroll_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var tier := int(entry["tier"])
	var grade_col: Color = ItemDB.grade_color(Realms.tier_index(tier))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(grade_col, 0.08)
	sb.border_color = Color(grade_col, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)

	var icon := ItemSlot.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.setup_item(str(entry["item_id"]), int(entry["count"]))
	icon.disabled = true
	h.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(texts)
	texts.add_child(_label(str(ItemDB.get_item(str(entry["item_id"])).get("name", "")), 22,
		grade_col.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(_label("Choose 1 of %d partners  ·  you own %d" % [Achievements.CHOICE_SIZE, int(entry["count"])],
		16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	var open := OrnateButton.new()
	open.text = "Open"
	open.custom_minimum_size = Vector2(170, 56)
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(_open_selection.bind(tier, str(entry["item_id"])))
	h.add_child(open)
	return panel


func _results_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	SummonCard.find_frames(self)
	var card_size := SummonCard.size_for_width(RESULT_CARD)
	for r in _last_results:
		var data = PartnerDatabase.get_partner(str(r["partner_id"]))
		var holder := Control.new()
		holder.custom_minimum_size = card_size
		var card := SummonCard.new()
		card.setup(r, data.rarity if data != null else int(r["tier"]), card_size)
		card.show_front()
		holder.add_child(card)
		var tag := _label("NEW" if r["is_new"] else "+1", 16, COL_OK if r["is_new"] else COL_TEXT)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 5)
		tag.position = Vector2(0, card_size.y * 0.05)
		tag.size = Vector2(card_size.x, 22)
		holder.add_child(tag)
		grid.add_child(holder)
	var center := CenterContainer.new()
	center.add_child(grid)
	return center


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _on_pull(count: int) -> void:
	if _busy:
		return
	if not SummonSystem.can_afford(count):
		_hint.text = "Not enough Summon Scrolls or Immortal Jade."
		return
	var results := SummonSystem.pull(count)
	if results.is_empty():
		_hint.text = "No partners available to summon."
		return

	_busy = true
	var again := [0]
	var ceremony := SummonCeremony.open(self, results, count)
	ceremony.summon_again.connect(func(n: int): again[0] = n)
	await ceremony.finished

	_last_results = results
	_showcase = []
	_busy = false
	_refresh()
	# During the first-steps tutorial, move straight on after the free summon
	if again[0] > 0 and Tutorial.active_id() != "intro":
		_on_pull(again[0])


## Rewarded ad: a free ×1 summon (as a Summon Scroll, used straight away).
func _on_ad_summon() -> void:
	if _busy:
		return
	if await Ads.watch(self, "free_summon"):
		GameState.add_items({SummonSystem.SCROLL_ID: 1})
		GameState.save_game()
		_on_pull(1)
	else:
		_refresh()


func _open_selection(tier: int, item_id: String) -> void:
	var options := SummonSystem.options_for_scroll(item_id)
	var name_text := str(ItemDB.get_item(item_id).get("name", "Selection Scroll"))
	var popup := CardChoicePopup.open(self, name_text, options, tier)
	popup.chosen.connect(func(partner_id: String):
		if SummonSystem.choose_from_scroll(item_id, partner_id):
			var data = PartnerDatabase.get_partner(partner_id)
			_toast("%s joined you!" % (data.display_name if data != null else "A partner"), COL_OK)
		_refresh()
	)


func _open_rates() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free()
	)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = 640
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_label("Summon Rates", 32, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))
	for tier in SummonSystem.RATES:
		var row := HBoxContainer.new()
		var tier_name := str(Enums.Rarity.keys()[tier]).capitalize()
		var col: Color = ItemDB.grade_color(Realms.tier_index(int(tier)))
		var n := _label(tier_name, 22, col.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(_label("%s%%" % String.num(SummonSystem.RATES[tier]), 22, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(row)
	v.add_child(_fade_line())
	for line in [
		"Every ×10 summon includes at least one Purple.",
		"A Purple is guaranteed within %d summons (%s%% chance it's Red instead)." % [
			SummonSystem.PITY_LIMIT, String.num(SummonSystem.GUARANTEE_RATES[Enums.Rarity.RED])],
		"Gold and Prismatic partners can't be summoned.",
		"Duplicates become Soul Fragments.",
		"Every summon gives %d Fate Point. %d Fate Points buy a featured Red (the list changes every %d days)." % [
			SummonSystem.FATE_PER_PULL, SummonSystem.FATE_COST, SummonSystem.ROTATION_DAYS],
	]:
		var l := _label(str(line), 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(220, 56)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _chip_text(title: String, amount: int, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(NumberFormat.short(amount), 22, color))
	v.add_child(_label(title, 13, COL_DIM))
	return v


func _chip_item(item_id: String) -> Control:
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_theme_constant_override("separation", 4)
	var icon := ItemSlot.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.show_count = false
	icon.setup_item(item_id, 0)
	icon.pressed.connect(func(): ItemInfoPopup.open(self, item_id))
	h.add_child(icon)
	var n := _label(NumberFormat.short(GameState.get_item_count(item_id)), 22, COL_TEXT)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	return h


func _draw_backdrop() -> void:
	var s := size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.4), false, 2.0)
	var m := 10.0
	var arm := 46.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(m + corner.x * (s.x - m * 2.0), m + corner.y * (s.y - m * 2.0))
		var dx := arm * (1.0 if corner.x == 0 else -1.0)
		var dy := arm * (1.0 if corner.y == 0 else -1.0)
		draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), Color(COL_GOLD, 0.7), 2.0, true)


func _fade_line() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		var y := line.size.y * 0.5
		var w := line.size.x
		line.draw_polyline_colors(
			PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]),
			PackedColorArray([Color(COL_GOLD, 0.0), Color(COL_GOLD, 0.7), Color(COL_GOLD, 0.0)]), 1.5, true)
	)
	return line


func _toast(message: String, color: Color) -> void:
	var l := _label(message, 26, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.top_level = true
	add_child(l)
	var r := get_global_rect()
	l.size = Vector2(r.size.x, 40)
	l.global_position = Vector2(r.position.x, r.position.y + r.size.y * 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)


func _label(value: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, glow := false) -> Label:
	var l := Label.new()
	l.text = value
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
