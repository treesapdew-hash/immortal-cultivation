extends PanelContainer

# =========================================================
# "More" tab: the Treasure Pavilion (shop). Save as
#   res://ui/screens/more_screen.gd
#
# Tabs: Materials, Pills, Recipes. Offers and prices are in shop.gd.
# =========================================================

const TABS := ["Top Up", "Materials", "Pills", "Recipes"]
const COLUMNS := 3
const CARD_SIZE := Vector2(300, 276)

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_SHORT := Color("ff7a7a")
const COL_STONES := Color("b9d4ff")
const COL_JADE := Color("7dffa8")
const COL_QI := Color("8ff0ff")

var _tab := "Top Up"
var _tab_buttons := {}
var _reset_label: Label
var _grid: GridContainer
var _note: Label
var _toast_holder: Control
var _dirty := true
var _clock := 0.0
var _scroll: ScrollContainer
var _stones_anchor: Control
var _pending_anchor := ""
## Currency art borrowed from the top bar's pills (see _currency_texture).
var _currency_icons := {}


func _ready() -> void:
	name = "MoreScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	_build()
	GameState.currency_changed.connect(_mark_dirty)
	GameState.stage_changed.connect(_mark_dirty)
	GameState.realm_changed.connect(_mark_dirty)
	_rebuild()


func on_opened() -> void:
	GameState.refresh_shop_day()
	_rebuild()


## Qi changes every kill, so only rebuild when something shown here changed.
func _mark_dirty() -> void:
	if _signature() != _last_signature:
		_dirty = true


var _last_signature := ""


func _signature() -> String:
	var mc := GameState.get_mc()
	var stage_part := GameState.current_stage if _tab == "Pills" else Loot.region_for(GameState.current_stage)
	return "%s|%d|%d|%d|%d|%s|%s" % [_tab, GameState.spirit_stones, GameState.immortal_jade,
		stage_part, mc.realm_index if mc != null else 0,
		str(GameState.shop_bought), str(GameState.known_recipes) + str(GameState.bought_packs)]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_reset_label.text = "Restocks in %s" % Shop.time_until_reset()
		if _dirty:
			_rebuild()


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_label("Treasure Pavilion", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	titles.add_child(_label("Shop", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_reset_label = _label("", 18, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_reset_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_reset_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for tab in TABS:
		var b := _make_tab(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons[tab] = b

	v.add_child(_fade_line())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	var scroll := _scroll

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	_note = _label("", 19, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_note)

	var center := CenterContainer.new()
	content.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(_grid)

	_toast_holder = Control.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_holder.top_level = true
	add_child(_toast_holder)


func _make_tab(tab: String) -> Button:
	var b := Button.new()
	b.text = tab
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_select_tab.bind(tab))
	b.draw.connect(func():
		if tab != _tab:
			return
		var w := b.size.x
		var y := b.size.y - 4.0
		b.draw_rect(Rect2(0, 0, w, b.size.y), Color(COL_GOLD, 0.05))
		b.draw_rect(Rect2(w * 0.12, y - 1.0, w * 0.76, 3.0), COL_GOLD)
		var c := Vector2(w * 0.5, y)
		b.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), Color("ffe6a8"))
	)
	return b


func _select_tab(tab: String) -> void:
	_tab = tab
	_rebuild()


## Opens a section from outside (e.g. the + buttons in the top bar).
## anchor "stones" scrolls down to the Spirit Stone exchange.
func open_section(tab: String, anchor := "") -> void:
	if tab in TABS:
		_pending_anchor = anchor
		_select_tab(tab)


## Scrolls to the part the player asked for.
func _apply_anchor() -> void:
	if _pending_anchor == "":
		return
	var anchor := _pending_anchor
	_pending_anchor = ""
	await get_tree().process_frame
	if anchor == "stones" and is_instance_valid(_stones_anchor) and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_stones_anchor.position.y) + int(_stones_anchor.get_parent().position.y)
	elif is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0


## The Jade / Spirit Stone art used by the top bar, so the shop matches.
func _currency_texture(currency: int) -> Texture2D:
	if _currency_icons.has(currency):
		return _currency_icons[currency]
	var tex: Texture2D = null
	var scene := get_tree().current_scene
	if scene != null:
		for node in scene.find_children("*", "Control", true, false):
			if not node.has_signal("plus_pressed"):
				continue
			var kind = node.get("currency")
			if kind == null or int(kind) != currency:
				continue
			for child in node.find_children("*", "TextureRect", true, false):
				if child.texture != null:
					tex = child.texture
					break
			if tex != null:
				break
	_currency_icons[currency] = tex
	return tex


# ---------------------------------------------------------
# CONTENT
# ---------------------------------------------------------

func _rebuild() -> void:
	_dirty = false
	_last_signature = _signature()
	_reset_label.text = "Restocks in %s" % Shop.time_until_reset()
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		b.add_theme_color_override("font_color", Color("ffe6a8") if key == _tab else COL_DIM)
		b.queue_redraw()

	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()

	var offers: Array = []
	match _tab:
		"Top Up":
			offers = Shop.jade_pack_offers() + Shop.stone_exchange_offers()
			_note.text = "Immortal Jade packs (first purchase of each pack gives double Jade), and Spirit Stones for Jade."
			if Payments.TEST_MODE:
				_note.text += "\nTEST MODE: purchases are simulated and free."
		"Materials":
			offers = Shop.material_offers()
			var region: int = Loot.region_for(GameState.current_stage)
			_note.text = "Herbs and beast cores from the %s. Rarer ones appear as you push deeper. Stock resets daily." \
				% ["Mortal lands", "Spirit lands", "Sovereign lands", "Immortal lands"][region]
		"Pills":
			offers = Shop.pill_offers()
			_note.text = "Star-up Pills for awakening, and elixirs that grant Qi based on your current stage."
		"Recipes":
			offers = Shop.recipe_offers() + Shop.formula_offers()
			_note.text = "Pill recipes are revealed one realm at a time (Mortal Realm ones cost Spirit Stones, " \
				+ "later ones Immortal Jade). Forging formulas set the lowest grade a forged artifact can be."
			if Shop.recipe_offers().is_empty():
				_note.text += "\n\nYou know every pill recipe available for now."

	_stones_anchor = null
	for offer in offers:
		var card := _offer_card(offer)
		_grid.add_child(card)
		if _stones_anchor == null and offer["kind"] == "stones":
			_stones_anchor = card
	_apply_anchor()


func _offer_card(offer: Dictionary) -> Control:
	var locked: bool = offer.get("locked", false)
	var left := Shop.left_today(offer)
	var sold_out := left <= 0
	var item := ItemDB.get_item(offer["item_id"]) if offer["item_id"] != "" else {}
	var grade: int = item.get("grade", 3)

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.border_color = Color(ItemDB.grade_color(grade), 0.55) if not locked else Color("2c3a50")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	if locked or sold_out:
		card.modulate = Color(0.7, 0.7, 0.75)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	# Icon
	var icon := ItemSlot.new()
	icon.custom_minimum_size = Vector2(92, 92)
	icon.disabled = true
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var currency_kind := -1
	if offer["kind"] == "jade_pack":
		currency_kind = 1        # ResourcePill.Currency.IMMORTAL_JADE
	elif offer["kind"] == "stones":
		currency_kind = 0        # ResourcePill.Currency.SPIRIT_STONES
	var art := _currency_texture(currency_kind) if currency_kind >= 0 else null

	match offer["kind"]:
		"jade_pack", "stones":
			if art != null:
				icon.visible = false
			else:
				icon.setup_item("beast_core_1", 0)
				icon.show_count = false
				icon.grade = 4 if offer["kind"] == "jade_pack" else 2
				icon.icon_color = COL_JADE if offer["kind"] == "jade_pack" else COL_STONES
		"recipe":
			icon.setup_recipe(offer["item_id"])
		"qi":
			icon.setup_item("starup_pill", 0)
			icon.grade = 3
			icon.icon_color = COL_QI
			icon.pattern = 1
			icon.show_count = false
		_:
			icon.setup_item(offer["item_id"], offer["amount"])
	v.add_child(icon)

	# Your own Jade / Spirit Stone art, bigger for bigger packs
	if art != null:
		var art_size := 74.0
		if offer["kind"] == "jade_pack":
			var step := Shop.JADE_PACKS.map(func(p): return p[0]).find(offer["sku"])
			art_size = 62.0 + maxi(step, 0) * 7.0
		var art_rect := TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_rect.custom_minimum_size = Vector2(CARD_SIZE.x - 24, art_size)
		art_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(art_rect)

	# Name: always two lines tall so every card lines up
	var name_text: String = offer["title"]
	if offer["kind"] == "recipe":
		name_text = item.get("name", name_text)
	var title_color := COL_QI
	if item.size() > 0:
		title_color = ItemDB.grade_color(grade).lightened(0.25)
	elif offer["kind"] == "jade_pack":
		title_color = COL_JADE
	elif offer["kind"] == "stones":
		title_color = COL_STONES
	var title := _label(name_text, 19, title_color)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(CARD_SIZE.x - 24, 52)
	v.add_child(title)

	# Info line and limit line (fixed heights)
	var sub := ""
	var extra := ""
	var extra_color := COL_DIM
	match offer["kind"]:
		"jade_pack":
			if offer["bonus"] > 0:
				sub = "+%s Bonus" % NumberFormat.short(offer["bonus"])
			if offer["first_bonus"]:
				extra = "First purchase: double Jade!"
				extra_color = COL_GOLD
		"stones":
			sub = "+%s Spirit Stones" % NumberFormat.short(offer["amount"])
		"qi":
			sub = "+%s Qi" % NumberFormat.short(offer["amount"])
		"recipe":
			sub = "Pill Recipe"
			if locked:
				extra = "Reach %s first" % Realms.get_minor_name(offer["target"] - 1)
				extra_color = COL_SHORT
			else:
				extra = "Crafts ×%d per batch" % Alchemy.PILLS_PER_CRAFT
		_:
			sub = "×%s" % NumberFormat.short(offer["amount"])
	if offer["kind"] != "recipe" and offer["kind"] != "jade_pack":
		var limit: int = offer["limit"]
		extra = "Left today  %d / %d" % [left, limit]
		extra_color = COL_SHORT if sold_out else COL_DIM

	var sub_l := _label(sub, 17, COL_TEXT)
	sub_l.custom_minimum_size.y = 24
	v.add_child(sub_l)
	var extra_l := _label(extra, 15, extra_color)
	extra_l.custom_minimum_size.y = 22
	extra_l.clip_text = true
	v.add_child(extra_l)

	# Push the button to the bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Price button
	var jade: bool = offer["currency"] == "jade"
	var buy := OrnateButton.new()
	buy.custom_minimum_size = Vector2(0, 52)
	buy.add_theme_font_size_override("font_size", 19)
	if offer["kind"] == "jade_pack":
		buy.text = offer["price_label"]
		buy.variant = OrnateButton.Variant.GOLD
		buy.pressed.connect(_on_buy_pack.bind(offer, buy))
		v.add_child(buy)
		return card
	if locked:
		buy.text = "Locked"
		buy.disabled = true
	elif sold_out:
		buy.text = "Sold Out"
		buy.disabled = true
	else:
		buy.text = "%s %s" % [NumberFormat.short(offer["price"]), "Jade" if jade else "Stones"]
		buy.variant = OrnateButton.Variant.GOLD if jade else OrnateButton.Variant.DARK
		buy.disabled = not Shop.can_afford(offer)
	buy.pressed.connect(_on_buy.bind(offer))
	v.add_child(buy)

	return card


func _on_buy_pack(offer: Dictionary, button: OrnateButton) -> void:
	button.disabled = true
	button.text = "Processing..."
	Shop.buy_jade_pack(self, offer, func(success: bool, jade: int):
		if success:
			_toast("+%s Immortal Jade" % NumberFormat.short(jade), COL_JADE)
		else:
			_toast("Purchase didn't go through.", COL_SHORT)
		_rebuild()
	)


func _on_buy(offer: Dictionary) -> void:
	var error := Shop.buy(offer)
	if error != "":
		_toast(error, COL_SHORT)
		return
	match offer["kind"]:
		"recipe":
			_toast("Learned: %s" % offer["title"], COL_OK)
		"qi":
			_toast("+%s Qi" % NumberFormat.short(offer["amount"]), COL_QI)
		"stones":
			_toast("+%s Spirit Stones" % NumberFormat.short(offer["amount"]), COL_STONES)
		_:
			_toast("+%s %s" % [NumberFormat.short(offer["amount"]), offer["title"]], COL_OK)
	_rebuild()


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

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


func _toast(text: String, color: Color) -> void:
	var l := _label(text, 28, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	_toast_holder.add_child(l)
	var r := get_global_rect()
	l.size = Vector2(r.size.x, 40)
	l.global_position = Vector2(r.position.x, r.position.y + r.size.y * 0.4)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_callback(l.queue_free)


func _label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, glow := false) -> Label:
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
