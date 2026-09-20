extends PanelContainer

# =========================================================
# Growth screen, built in code. Save as
#   res://ui/screens/growth_screen.gd
#
# Tabs: Abode (Alchemy Furnace) and God Path (coming later).
# The furnace lists breakthrough pill recipes up to a little
# past the MC's realm. The MC's next pill is highlighted.
# Pill and ingredient icons open ItemInfoPopup when tapped.
# =========================================================

const TABS := ["Abode", "Forge", "Expeditions", "Array", "God Path"]
const ICON := 92.0
const INGREDIENT := 62.0

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_SHORT := Color("ff7a7a")
const COL_STONES := Color("b9d4ff")

var _tab := "Abode"
var _tab_buttons := {}
var _list: VBoxContainer
var _toast_holder: Control
var _dirty := true
var _last_signature := ""


func _ready() -> void:
	name = "GrowthScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	_build()
	GameState.currency_changed.connect(_on_changed)
	GameState.artifacts_updated.connect(_on_changed)
	GameState.expeditions_updated.connect(_on_changed)
	GameState.lifebound_updated.connect(_on_changed)
	GameState.roster_changed.connect(_on_changed)
	GameState.array_changed.connect(_on_changed)
	GameState.formation_changed.connect(_on_changed)
	GameState.gear_updated.connect(_on_changed)
	_rebuild()


func on_opened() -> void:
	if _dirty:
		_rebuild()


## Rebuild only when something the recipes show actually changed.
func _on_changed() -> void:
	var sig := _signature()
	if sig == _last_signature:
		return
	_dirty = true
	if is_visible_in_tree():
		_rebuild.call_deferred()


func _signature() -> String:
	var mc := GameState.get_mc()
	return "%s|%d|%d|%s|%d|%d" % [str(GameState.items), GameState.spirit_stones,
		mc.realm_index if mc != null else 0, str(GameState.known_recipes),
		GameState.artifacts.size(), GameState.expeditions.size() + GameState.lifebound_seeds.size()] \
		+ "|%s|%d|%s|%s" % [str(GameState.battle_array), GameState.array_level,
		str(GameState.formation), str(BattleArray.bonus())] + "|%s" % str(GameState.gods)


# ---------------------------------------------------------
# BUILD
# ---------------------------------------------------------

func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var titles := VBoxContainer.new()
	v.add_child(titles)
	titles.add_child(_label("Abode", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	titles.add_child(_label("Growth", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for tab in TABS:
		var b := _make_tab(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons[tab] = b

	v.add_child(_fade_line())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	# Padding: room above the first heading (so its glow isn't clipped)
	# and on the right so the scroll bar never covers anything
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	pad.add_child(_list)

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


var _clock := 0.0


## Expedition timers tick, so refresh that tab once a second.
func _process(delta: float) -> void:
	if _tab != "Expeditions" or not is_visible_in_tree():
		return
	if Expeditions.running().is_empty():
		return
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_rebuild()


func _select_tab(tab: String) -> void:
	if not Unlocks.place_open("growth:" + tab):
		Unlocks.toast(self, Unlocks.requirement_text(Unlocks.feature_at("growth:" + tab)))
		return
	_tab = tab
	_rebuild()


# ---------------------------------------------------------
# CONTENT
# ---------------------------------------------------------

func _rebuild() -> void:
	_dirty = false
	_last_signature = _signature()
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		b.add_theme_color_override("font_color", Color("ffe6a8") if key == _tab else COL_DIM)
		b.queue_redraw()

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	match _tab:
		"God Path":
			_build_god_path()
		"Forge":
			_build_forge()
		"Expeditions":
			_build_expeditions()
		"Array":
			_build_array()
		_:
			_build_furnace()


# ---------------------------------------------------------
# SPIRIT FORGE
# ---------------------------------------------------------

func _build_forge() -> void:
	var head := HBoxContainer.new()
	_list.add_child(head)
	var t := _label("Spirit Forge", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Artifact Cores  %s" % NumberFormat.short(GameState.get_item_count(Artifacts.CORE_ID)),
		20, Color("9fd8ff"), HORIZONTAL_ALIGNMENT_RIGHT))

	var help := _label("Forge artifacts from Artifact Cores. Each holds one trait: a rule that changes how a partner fights. "
		+ "The trait is fixed at the forge, so every forging is a gamble. Tempering raises the grade.", 19, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(help)

	var enough_cores := GameState.get_item_count(Artifacts.CORE_ID) >= Artifacts.FORGE_CORE_COST

	var forge := OrnateButton.new()
	forge.text = "Forge Artifact  (%d Cores)" % Artifacts.FORGE_CORE_COST
	forge.custom_minimum_size = Vector2(520, 70)
	forge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	forge.disabled = not enough_cores
	forge.pressed.connect(_on_forge.bind(""))
	_list.add_child(forge)

	# Formulas you own set a floor on the grade
	for id in Artifacts.FORMULAS:
		var count := GameState.get_item_count(id)
		if count <= 0:
			continue
		var floor_grade: int = Artifacts.FORMULAS[id]
		var with_formula := OrnateButton.new()
		with_formula.text = "Forge with %s  (x%d)  ·  at least %s" % [
			ItemDB.get_item(id).get("name", id), count, ItemDB.grade_name(floor_grade)]
		with_formula.variant = OrnateButton.Variant.DARK
		with_formula.custom_minimum_size = Vector2(520, 56)
		with_formula.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		with_formula.add_theme_font_size_override("font_size", 17)
		with_formula.disabled = not enough_cores
		with_formula.pressed.connect(_on_forge.bind(id))
		_list.add_child(with_formula)

	_list.add_child(_label("Formulas are sold in the Treasure Pavilion (More tab).", 17, COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT))

	# --- Lifebound Seeds ---
	_list.add_child(_fade_line())
	var seed_head := HBoxContainer.new()
	_list.add_child(seed_head)
	var sh := _label("Lifebound Seeds", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_head.add_child(sh)
	seed_head.add_child(_label("Essence  %s" % NumberFormat.short(GameState.get_item_count(Lifebound.ESSENCE_ID)),
		19, Color("ff9ad8"), HORIZONTAL_ALIGNMENT_RIGHT))

	var seed_help := _label("Craft a seed, merge seeds into higher stars, then bond one to a partner. "
		+ "Stars raise every line of their Lifebound Artifact.", 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	seed_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(seed_help)

	var craft := OrnateButton.new()
	craft.text = "Craft Seed  (%s Essence + %d Cores)" % [
		NumberFormat.short(Lifebound.SEED_ESSENCE_COST), Lifebound.SEED_CORE_COST]
	craft.custom_minimum_size = Vector2(520, 62)
	craft.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	craft.add_theme_font_size_override("font_size", 19)
	craft.pressed.connect(_on_craft_seed)
	_list.add_child(craft)

	var any_seeds := false
	for star in range(1, Lifebound.MAX_STARS + 1):
		var count := Lifebound.seed_count(star)
		if count <= 0:
			continue
		any_seeds = true
		_list.add_child(_seed_row(star, count))
	if not any_seeds:
		_list.add_child(_label("No seeds yet.", 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	_list.add_child(_fade_line())
	_list.add_child(_label("Your artifacts", 22, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))

	if GameState.artifacts.is_empty():
		_list.add_child(_label("None yet. Send expeditions for cores, then forge.", 19, COL_DIM))
		return

	var items: Array = GameState.artifacts.duplicate()
	items.sort_custom(func(a, b): return int(a["grade"]) > int(b["grade"]))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var holder := CenterContainer.new()
	holder.add_child(grid)
	_list.add_child(holder)
	for a in items:
		var icon := ArtifactIcon.new()
		icon.custom_minimum_size = Vector2(104, 104)
		icon.setup(a)
		icon.pressed.connect(_open_artifact.bind(int(a["uid"])))
		grid.add_child(icon)


func _seed_row(star: int, count: int) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_color = Color("2c4466")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var icon := LifeboundIcon.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.disabled = true
	icon.setup({"grade": 0, "stars": star, "lines": []})
	h.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(texts)
	texts.add_child(_label("%d-star seed  x%d" % [star, count], 21, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	if star < Lifebound.MAX_STARS:
		texts.add_child(_label("%d make one %d-star seed" % [Lifebound.merge_count(star), star + 1],
			17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	if star < Lifebound.MAX_STARS:
		var merge := OrnateButton.new()
		merge.text = "Merge"
		merge.variant = OrnateButton.Variant.DARK
		merge.custom_minimum_size = Vector2(150, 52)
		merge.disabled = count < Lifebound.merge_count(star)
		merge.pressed.connect(_on_merge_seed.bind(star))
		h.add_child(merge)
	return row


func _on_craft_seed() -> void:
	var error := Lifebound.craft_seed()
	if error != "":
		_toast(error, COL_SHORT)
	else:
		_toast("Forged a 1-star Lifebound Seed.", COL_OK)
	_rebuild()


func _on_merge_seed(star: int) -> void:
	var error := Lifebound.merge_seeds(star)
	if error != "":
		_toast(error, COL_SHORT)
	else:
		_toast("Merged into a %d-star seed." % (star + 1), COL_OK)
	_rebuild()


func _on_forge(formula_id := "") -> void:
	var made := Artifacts.forge(formula_id)
	if made.is_empty():
		_toast("Not enough Artifact Cores.", COL_SHORT)
		return
	var ceremony := ForgeCeremony.play(self, made)
	ceremony.finished.connect(_rebuild)


func _open_artifact(uid: int) -> void:
	ArtifactPopup.open_details(self, uid)


# ---------------------------------------------------------
# SECRET REALM EXPEDITIONS
# ---------------------------------------------------------

func _build_expeditions() -> void:
	var head := HBoxContainer.new()
	_list.add_child(head)
	var t := _label("Secret Realm Expeditions", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("%d / %d away  ·  %d sends left today" % [
		Expeditions.running().size(), Expeditions.MAX_RUNNING, Expeditions.sends_left()],
		19, COL_DIM if Expeditions.sends_left() > 0 else COL_SHORT, HORIZONTAL_ALIGNMENT_RIGHT))

	var help := _label("Send partners into a secret realm for Artifact Cores, Lifebound Essence and Jade. "
		+ "They keep fighting in your team while away, and the rewards keep coming while the game is closed.",
		19, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(help)

	# Trips under way
	for trip in Expeditions.running():
		_list.add_child(_trip_row(trip))
	if not Expeditions.running().is_empty():
		var collect := OrnateButton.new()
		collect.text = "Collect All"
		collect.custom_minimum_size = Vector2(420, 58)
		collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		collect.pressed.connect(_on_collect_all)
		_list.add_child(collect)

	_list.add_child(_fade_line())

	var offers_head := HBoxContainer.new()
	_list.add_child(offers_head)
	var o := _label("Realms open to you", 22, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers_head.add_child(o)
	var reroll := OrnateButton.new()
	if Expeditions.rerolls_left() > 0:
		reroll.text = "Reroll (%d free)" % Expeditions.rerolls_left()
	elif Expeditions.rerolls_left_total() > 0:
		reroll.text = "Reroll (%d Jade)" % Expeditions.REROLL_JADE
	else:
		reroll.text = "No rerolls left"
	reroll.disabled = Expeditions.rerolls_left_total() <= 0
	reroll.variant = OrnateButton.Variant.DARK
	reroll.custom_minimum_size = Vector2(210, 46)
	reroll.add_theme_font_size_override("font_size", 17)
	reroll.pressed.connect(_on_reroll)
	offers_head.add_child(reroll)

	for offer in Expeditions.offers():
		_list.add_child(_offer_row(offer))


func _trip_row(trip: Dictionary) -> Control:
	var done := Expeditions.is_done(trip)
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.08) if done else Color(1, 1, 1, 0.03)
	sb.border_color = COL_GOLD if done else Color("2c4466")
	sb.set_border_width_all(2 if done else 1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	texts.add_child(_label(str(trip["name"]), 22, Expeditions.grade_color(int(trip["grade"])),
		HORIZONTAL_ALIGNMENT_LEFT))
	var names := PackedStringArray()
	for id in trip["partners"]:
		names.append(_partner_name(str(id)))
	texts.add_child(_label("%dh  ·  %s" % [int(trip["hours"]), ", ".join(names)], 17, COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(_label(_reward_text(trip["rewards"]), 17, COL_OK, HORIZONTAL_ALIGNMENT_LEFT))

	if done:
		var collect := OrnateButton.new()
		collect.text = "Collect"
		collect.custom_minimum_size = Vector2(170, 54)
		collect.pressed.connect(_on_collect.bind(trip))
		h.add_child(collect)
	else:
		var left := VBoxContainer.new()
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(left)
		left.add_child(_label(Loot.format_duration(Expeditions.seconds_left(trip)), 22, COL_TEXT))
		var rush := OrnateButton.new()
		rush.text = "Rush (%s Jade)" % NumberFormat.short(Expeditions.rush_cost(trip))
		rush.variant = OrnateButton.Variant.DARK
		rush.custom_minimum_size = Vector2(190, 44)
		rush.add_theme_font_size_override("font_size", 16)
		rush.pressed.connect(_on_rush.bind(trip))
		left.add_child(rush)
	return row


func _offer_row(offer: Dictionary) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_color = Color(Expeditions.grade_color(int(offer["grade"])), 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	texts.add_child(_label(str(offer["name"]), 24, Expeditions.grade_color(int(offer["grade"])),
		HORIZONTAL_ALIGNMENT_LEFT, true))
	texts.add_child(_label("%dh  ·  %s" % [int(offer["hours"]), ItemDB.grade_name(int(offer["grade"]))],
		17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(_label(_reward_text(Expeditions.rewards_for(offer, _team_ids())), 17, COL_OK,
		HORIZONTAL_ALIGNMENT_LEFT))

	var send := OrnateButton.new()
	send.text = "Send Team"
	send.custom_minimum_size = Vector2(190, 56)
	send.disabled = Expeditions.running().size() >= Expeditions.MAX_RUNNING \
		or Expeditions.sends_left() <= 0
	send.pressed.connect(_on_send.bind(offer))
	h.add_child(send)
	return row


## Your formation, which is who goes on the expedition.
func _team_ids() -> Array:
	var ids: Array = []
	for partner in GameState.get_formation_partners():
		if partner != null and ids.size() < Expeditions.PARTNER_SLOTS:
			ids.append(partner.partner_id)
	return ids


func _partner_name(partner_id: String) -> String:
	if partner_id == GameState.MC_ID:
		return GameState.mc_name
	var data = PartnerDatabase.get_partner(partner_id)
	return data.display_name if data != null else partner_id


func _reward_text(rewards: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in rewards:
		if key == "jade":
			parts.append("%s Jade" % NumberFormat.short(int(rewards[key])))
		else:
			parts.append("%s %s" % [NumberFormat.short(int(rewards[key])),
				ItemDB.get_item(key).get("name", key)])
	return "  ·  ".join(parts)


func _on_send(offer: Dictionary) -> void:
	var error := Expeditions.send(offer, _team_ids())
	if error != "":
		_toast(error, COL_SHORT)
	else:
		_toast("%s expedition set out." % offer["name"], COL_OK)
	_rebuild()


func _on_collect(trip: Dictionary) -> void:
	var got := Expeditions.collect(trip)
	if not got.is_empty():
		_toast(_reward_text(got), COL_OK)
	_rebuild()


func _on_collect_all() -> void:
	var got := Expeditions.collect_all()
	if got.is_empty():
		_toast("Nothing has returned yet.", COL_DIM)
	else:
		_toast(_reward_text(got), COL_OK)
	_rebuild()


func _on_rush(trip: Dictionary) -> void:
	var error := Expeditions.rush(trip)
	if error != "":
		_toast(error, COL_SHORT)
	_rebuild()


func _on_reroll() -> void:
	var error := Expeditions.reroll()
	if error != "":
		_toast(error, COL_SHORT)
	_rebuild()


# ---------------------------------------------------------
# BATTLE ARRAY
# ---------------------------------------------------------

func _build_array() -> void:
	var head := HBoxContainer.new()
	_list.add_child(head)
	var t := _label("Battle Array", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Level %d / %d" % [BattleArray.level(), BattleArray.LEVELS.size()],
		22, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT))

	var help := _label("Partners resting in the array lend part of their HP, ATK and DEF to every unit "
		+ "in your team. Stronger partners lend more, so ascending, starring up and gearing them still pays off. "
		+ "Partners in your formation can't be placed here.", 19, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(help)

	_list.add_child(_array_bonus_panel())

	# Slots
	var ids := BattleArray.slots()
	for i in BattleArray.max_slots():
		if i < ids.size():
			_list.add_child(_array_slot_row(i, str(ids[i])))
		else:
			var locked := _label("Slot %d  ·  opens at array Level %d" % [i + 1, BattleArray.level_for_slot(i)],
				18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
			locked.custom_minimum_size.y = 34
			_list.add_child(locked)

	var fill := OrnateButton.new()
	fill.text = "Auto-fill Empty Slots"
	fill.variant = OrnateButton.Variant.DARK
	fill.custom_minimum_size = Vector2(420, 56)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fill.disabled = not ids.has("") or BattleArray.candidates().is_empty()
	fill.pressed.connect(_on_array_autofill)
	_list.add_child(fill)

	_list.add_child(_fade_line())
	_list.add_child(_array_upgrade_panel())


## What the whole array adds to every unit right now.
func _array_bonus_panel() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_GOLD, 0.06)
	sb.border_color = Color(COL_GOLD, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(_label("Every unit in your team gains", 18, COL_DIM))
	var b := BattleArray.bonus()
	v.add_child(_label("+%s HP     +%s ATK     +%s DEF" % [NumberFormat.short(int(b["hp"])),
		NumberFormat.short(int(b["atk"])), NumberFormat.short(int(b["def"]))], 26, COL_OK, HORIZONTAL_ALIGNMENT_CENTER, true))

	var line := "Each array partner lends %s%% of their stats" % _pct(float(BattleArray.level_def(BattleArray.level())["share"]))
	var extra := BattleArray.dao_extra()
	if extra > 0.0:
		var harmony := BattleArray.dao_harmony()
		line += "  ·  +%s%% Dao harmony (%d of one Dao)" % [_pct(extra), int(harmony[1])]
	var share_l := _label(line, 17, COL_GOLD)
	share_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(share_l)
	var tiers := PackedStringArray()
	for need in BattleArray.DAO_BONUS:
		tiers.append("%d same Dao: +%s%%" % [int(need), _pct(float(BattleArray.DAO_BONUS[need]))])
	v.add_child(_label("  ·  ".join(tiers), 15, COL_DIM))
	return panel


func _array_slot_row(slot: int, partner_id: String) -> Control:
	var p: OwnedPartner = GameState.find_owned(partner_id) if partner_id != "" else null
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.border_color = Color("2c4466")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	h.add_child(_label("%d" % (slot + 1), 22, COL_GOLD))

	if p == null:
		var empty := _label("Empty slot", 21, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size.y = 72
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(empty)
		var place := OrnateButton.new()
		place.text = "Place"
		place.custom_minimum_size = Vector2(150, 52)
		place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		place.disabled = BattleArray.candidates().is_empty()
		place.pressed.connect(_open_array_picker.bind(slot))
		h.add_child(place)
		return row

	# Portrait and text: tap to manage the partner
	var info := Button.new()
	info.flat = true
	info.focus_mode = Control.FOCUS_NONE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size.y = 84
	for state in ["normal", "hover", "focus"]:
		info.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var info_down := StyleBoxFlat.new()
	info_down.bg_color = Color(COL_GOLD, 0.08)
	info_down.set_corner_radius_all(8)
	info.add_theme_stylebox_override("pressed", info_down)
	info.pressed.connect(_open_array_partner.bind(partner_id))
	h.add_child(info)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(info_row)
	info_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_row.add_child(_partner_portrait(p, 72.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(texts)
	texts.add_child(_partner_title(p))
	texts.add_child(_contribution_label(p, BattleArray.share()))

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	h.add_child(buttons)
	# Main action: gear up, ascend, awaken
	var manage := OrnateButton.new()
	manage.text = "Manage"
	manage.custom_minimum_size = Vector2(170, 52)
	manage.add_theme_font_size_override("font_size", 20)
	manage.pressed.connect(_open_array_partner.bind(partner_id))
	buttons.add_child(manage)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 6)
	buttons.add_child(small)
	var swap := OrnateButton.new()
	swap.text = "Swap"
	swap.variant = OrnateButton.Variant.DARK
	swap.custom_minimum_size = Vector2(82, 40)
	swap.add_theme_font_size_override("font_size", 15)
	swap.disabled = BattleArray.candidates().is_empty()
	swap.pressed.connect(_open_array_picker.bind(slot))
	small.add_child(swap)
	var remove := OrnateButton.new()
	remove.text = "Remove"
	remove.variant = OrnateButton.Variant.DARK
	remove.custom_minimum_size = Vector2(82, 40)
	remove.add_theme_font_size_override("font_size", 15)
	remove.pressed.connect(_on_array_remove.bind(slot))
	small.add_child(remove)
	return row


func _array_upgrade_panel() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_label("Upgrade the Array", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))

	if BattleArray.is_max_level():
		v.add_child(_label("The array is at its highest level.", 19, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		return v

	var now := BattleArray.level_def(BattleArray.level())
	var next := BattleArray.level_def(BattleArray.level() + 1)
	v.add_child(_label("Level %d:  %d slots  ·  %s%% share   →   Level %d:  %d slots  ·  %s%% share" % [
		BattleArray.level(), int(now["slots"]), _pct(float(now["share"])),
		BattleArray.level() + 1, int(next["slots"]), _pct(float(next["share"]))],
		18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))

	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 18)
	v.add_child(costs)

	# Array Flags: tappable icon + have/need
	var flag_box := HBoxContainer.new()
	flag_box.add_theme_constant_override("separation", 8)
	costs.add_child(flag_box)
	var flag := ItemSlot.new()
	flag.custom_minimum_size = Vector2(INGREDIENT, INGREDIENT)
	flag.show_count = false
	flag.setup_item(BattleArray.FLAG_ID, 0)
	flag.pressed.connect(_open_item.bind(BattleArray.FLAG_ID, int(next["flags"]), ""))
	flag_box.add_child(flag)
	var have_flags := GameState.get_item_count(BattleArray.FLAG_ID)
	var flags_l := _label("%s / %s" % [NumberFormat.short(have_flags), NumberFormat.short(int(next["flags"]))], 19,
		COL_OK if have_flags >= int(next["flags"]) else COL_SHORT)
	flags_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flag_box.add_child(flags_l)

	var stones_l := _label("%s Spirit Stones" % NumberFormat.short(int(next["stones"])), 19,
		COL_STONES if GameState.spirit_stones >= int(next["stones"]) else COL_SHORT)
	stones_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	costs.add_child(stones_l)

	var mc := GameState.get_mc()
	var need_realm := int(next["realm"])
	var realm_ok := mc != null and mc.realm_index >= need_realm
	var realm_name: String = Realms.get_label(need_realm, 1)
	v.add_child(_label("Requires your MC at %s" % realm_name, 17,
		COL_OK if realm_ok else COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT))

	var up := OrnateButton.new()
	up.text = "Upgrade to Level %d" % (BattleArray.level() + 1)
	up.custom_minimum_size = Vector2(420, 64)
	up.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	up.disabled = BattleArray.can_upgrade() != ""
	up.pressed.connect(_on_array_upgrade)
	v.add_child(up)
	return v


## Picker: every free partner, strongest first, with what they'd lend.
func _open_array_picker(slot: int) -> void:
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
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_label("Choose a partner for slot %d" % (slot + 1), 28, COL_TITLE, HORIZONTAL_ALIGNMENT_CENTER, true))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(820, 900)
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	var pool := BattleArray.candidates()
	if pool.is_empty():
		rows.add_child(_label("No free partners. Partners in your formation can't join the array.", 19, COL_DIM))
	var pct: float = float(BattleArray.level_def(BattleArray.level())["share"]) + BattleArray.dao_extra()
	for p in pool:
		var pick := Button.new()
		pick.flat = true
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(0, 88)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(1, 1, 1, 0.04)
		normal.border_color = Color("2c4466")
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(10)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.border_color = COL_GOLD
		for state in ["normal", "focus"]:
			pick.add_theme_stylebox_override(state, normal)
		for state in ["hover", "pressed"]:
			pick.add_theme_stylebox_override(state, hover)
		pick.pressed.connect(_on_array_pick.bind(slot, str(p.partner_id), layer))
		rows.add_child(pick)

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pick.add_child(h)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -10
		h.add_child(_partner_portrait(p, 72.0))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(texts)
		texts.add_child(_partner_title(p))
		texts.add_child(_contribution_label(p, pct))

	var close := OrnateButton.new()
	close.text = "Close"
	close.variant = OrnateButton.Variant.DARK
	close.custom_minimum_size = Vector2(240, 58)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	v.add_child(close)


## Your normal partner panel (gear, treasures, artifacts, Ascend,
## Awaken) in a popup, showing one array partner.
const PARTNER_PANEL_SCENE := "res://ui/partner_panel.tscn"
const PARTNER_POPUP_LAYER := 55   # under gear (62) and breakthrough (60) popups
## The area the panel fills on the home screen (1080 x 1920 minus 1240).
const PARTNER_PANEL_SIZE := Vector2(1040, 680)


func _open_array_partner(partner_id: String) -> void:
	var p := GameState.find_owned(partner_id)
	var scene := load(PARTNER_PANEL_SCENE) as PackedScene
	if p == null or scene == null:
		return

	var layer := CanvasLayer.new()
	layer.layer = PARTNER_POPUP_LAYER
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_array_partner(layer)
	)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Solid framed popup: the panel has no background of its own
	# (on the home screen it sits on the shared lower-panel art)
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("0b1629")
	fsb.border_color = COL_GOLD
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(14)
	fsb.content_margin_left = 10
	fsb.content_margin_right = 10
	fsb.content_margin_top = 14
	fsb.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(frame)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	frame.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("Battle Array  ·  Slot %d" % (BattleArray.slots().find(partner_id) + 1),
		24, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	v.add_child(_fade_line())

	var panel := scene.instantiate()
	panel.set("standalone", true)
	panel.set("fixed_partner", p)
	if panel is Control:
		# Same room the panel gets on the home screen, so nothing spills out
		var panel_ctrl: Control = panel
		panel_ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel_ctrl.custom_minimum_size = PARTNER_PANEL_SIZE
		panel_ctrl.clip_contents = true
	v.add_child(panel)
	v.add_child(_fade_line())

	var lends: Label = _contribution_label(p, BattleArray.share())
	lends.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lends.add_theme_font_size_override("font_size", 20)
	v.add_child(lends)
	# Keep "Lends" up to date while the partner is being geared up
	var update := func():
		if is_instance_valid(lends):
			var lent := BattleArray.contribution(p, BattleArray.share())
			lends.text = "Lends  +%s HP  ·  +%s ATK  ·  +%s DEF" % [NumberFormat.short(int(lent["hp"])),
				NumberFormat.short(int(lent["atk"])), NumberFormat.short(int(lent["def"]))]
	var sigs: Array[Signal] = [GameState.gear_updated, GameState.roster_changed,
		GameState.treasures_updated, GameState.artifacts_updated, GameState.lifebound_updated]
	for sig in sigs:
		sig.connect(update)
	layer.tree_exiting.connect(func():
		for sig in sigs:
			if sig.is_connected(update):
				sig.disconnect(update)
	)

	var close := OrnateButton.new()
	close.text = "Done"
	close.custom_minimum_size = Vector2(260, 60)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_array_partner.bind(layer))
	v.add_child(close)


func _close_array_partner(layer: CanvasLayer) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	_rebuild()


func _partner_portrait(p: OwnedPartner, side: float) -> Control:
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(side, side)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data = p.get_data()
	if data != null:
		var art = data.get("card_texture")
		if art == null:
			art = data.sprite_texture
		tex.texture = art
	return tex


func _partner_title(p: OwnedPartner) -> Control:
	var data = p.get_data()
	var col: Color = data.get_rarity_color() if data != null else COL_TEXT
	return _label("%s   ·   %s   ·   %d★" % [p.get_display_name(), p.get_realm_text(), p.stars],
		20, col, HORIZONTAL_ALIGNMENT_LEFT)


func _contribution_label(p: OwnedPartner, share_pct: float) -> Label:
	var c := BattleArray.contribution(p, share_pct)
	return _label("Lends  +%s HP  ·  +%s ATK  ·  +%s DEF" % [NumberFormat.short(int(c["hp"])),
		NumberFormat.short(int(c["atk"])), NumberFormat.short(int(c["def"]))], 17, COL_OK, HORIZONTAL_ALIGNMENT_LEFT)


## "3", "4.5"
func _pct(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


func _on_array_pick(slot: int, partner_id: String, layer: CanvasLayer) -> void:
	var error := BattleArray.place(slot, partner_id)
	if error != "":
		_toast(error, COL_SHORT)
	layer.queue_free()
	_rebuild()


func _on_array_remove(slot: int) -> void:
	BattleArray.remove(slot)
	_rebuild()


func _on_array_autofill() -> void:
	var n := BattleArray.auto_fill()
	if n > 0:
		_toast("%d partner%s joined the array." % [n, "" if n == 1 else "s"], COL_OK)
	_rebuild()


func _on_array_upgrade() -> void:
	var error := BattleArray.upgrade()
	if error != "":
		_toast(error, COL_SHORT)
	else:
		_toast("Battle Array reached Level %d!" % BattleArray.level(), COL_OK)
	_rebuild()


# ---------------------------------------------------------
# GOD PATH
# ---------------------------------------------------------

func _build_god_path() -> void:
	if not Gods.is_unlocked():
		var realm: String = Realms.get_label(Gods.UNLOCK_REALM, 1)
		_list.add_child(_coming_soon("God Path",
			"Choose a god for team power, a blessing and a divine skill. "
			+ "Opens when your MC reaches %s." % realm))
		return

	var head := HBoxContainer.new()
	_list.add_child(head)
	var t := _label("God Path", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Divinity Level %d" % Gods.level(), 22, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT))

	# Divinity EXP bar
	var need := Gods.exp_to_next(Gods.level())
	var fill := 1.0 if Gods.is_max() else clampf(float(Gods.exp_now()) / maxf(float(need), 1.0), 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 2, w, 14), Color(0, 0, 0, 0.5))
		bar.draw_rect(Rect2(0, 2, w * fill, 14), Color("ffd36b"))
		bar.draw_rect(Rect2(0, 2, w, 14), Color(COL_GOLD, 0.5), false, 1.0)
	)
	_list.add_child(bar)
	_list.add_child(_label("MAX" if Gods.is_max() else "Divinity EXP  %s / %s" % [
		NumberFormat.short(Gods.exp_now()), NumberFormat.short(need)], 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var how := _label("Divinity Level is permanent: it powers up whichever god you follow. "
		+ "Earn Divinity EXP and Divine Essence from the Fallen God (Events > Daily, three times a day).",
		16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(how)

	if not Gods.has_chosen():
		_list.add_child(_fade_line())
		_list.add_child(_label("Choose Your God", 26, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
		var note := _label("Every god fights differently, none is simply stronger. Choose with care: you can "
			+ "follow another god later, but all training resets when you do.", 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(note)
		_list.add_child(_god_picker())
		return

	# Your god only; changing goes back through the selection page
	_list.add_child(_god_card(Gods.active()))
	_list.add_child(_god_training())
	_list.add_child(_fade_line())
	var change := OrnateButton.new()
	change.text = "Change God"
	change.variant = OrnateButton.Variant.DARK
	change.custom_minimum_size = Vector2(300, 58)
	change.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	change.pressed.connect(_on_change_god)
	_list.add_child(change)
	_list.add_child(_label("Changing god resets your Blessing and Divine Skill training.",
		15, COL_DIM))


func _god_picker() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for a in Gods.AVATARS:
		row.add_child(_god_pick(a))
	return row


## Blessing and Divine Skill training for the chosen god.
func _god_training() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.border_color = Color("2c4466")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var t := _label("Training", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var ess := ItemSlot.new()
	ess.custom_minimum_size = Vector2(48, 48)
	ess.show_count = false
	ess.setup_item(Gods.ESSENCE_ID, 0)
	ess.pressed.connect(_open_item.bind(Gods.ESSENCE_ID, -1, ""))
	head.add_child(ess)
	var have := _label(NumberFormat.short(GameState.get_item_count(Gods.ESSENCE_ID)), 22, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(have)

	var avatar := Gods.active()
	v.add_child(_train_row("blessing", "Blessing  Lv %d / %d" % [Gods.train_level("blessing"), Gods.TRAIN_MAX],
		Gods.blessing_training_text(avatar)))
	v.add_child(_train_row("skill", "Divine Skill  Lv %d / %d" % [Gods.train_level("skill"), Gods.TRAIN_MAX],
		Gods.skill_training_text(avatar)))
	return panel


func _train_row(track: String, title: String, detail: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	texts.add_child(_label(title, 20, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var detail_l := _label(detail, 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	detail_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail_l)

	var lv := Gods.train_level(track)
	var btn := OrnateButton.new()
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 17)
	if lv >= Gods.TRAIN_MAX:
		btn.text = "Mastered"
		btn.disabled = true
	else:
		btn.text = "Train  (%s)" % NumberFormat.short(Gods.train_cost(lv))
		btn.disabled = Gods.can_train(track) != ""
	btn.pressed.connect(_on_train.bind(track))
	h.add_child(btn)
	return h


func _on_train(track: String) -> void:
	var error := Gods.train(track)
	if error != "":
		_toast(error, COL_SHORT)
	else:
		_toast("%s trained to Lv %d" % ["Blessing" if track == "blessing" else "Divine Skill",
			Gods.train_level(track)], COL_OK)
	_rebuild()


## The active Avatar: portrait, stats, blessing and divine skill.
func _god_card(avatar: Dictionary) -> Control:
	var color: Color = avatar.get("color", COL_GOLD)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.07)
	sb.border_color = Color(color, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.clip_contents = true

	# God Path background behind the whole card, dimmed
	var bg_path := Gods.ART_DIR + "god_path_bg.png"
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.texture = load(bg_path) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.modulate = Color(0.42, 0.42, 0.5, 0.9)
		card.add_child(bg)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(320, 480)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = Gods.art("avatar", avatar)
	if portrait.texture == null:
		portrait.texture = Gods.art("emblem", avatar)
	h.add_child(portrait)

	# The text sits on its own dark glass panel so it's always readable
	var glass := PanelContainer.new()
	glass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.02, 0.03, 0.08, 0.78)
	gsb.border_color = Color(color, 0.35)
	gsb.set_border_width_all(1)
	gsb.set_corner_radius_all(10)
	gsb.set_content_margin_all(16)
	glass.add_theme_stylebox_override("panel", gsb)
	h.add_child(glass)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	glass.add_child(v)
	v.add_child(_god_label(str(avatar["name"]), 32, color.lightened(0.3), true))
	v.add_child(_god_label(str(avatar["inspired"]), 18, Color("b8c2d4")))
	v.add_child(_god_label("YOUR GOD", 17, COL_OK))
	v.add_child(_fade_line())

	v.add_child(_god_label("Team Bonus", 21, COL_GOLD))
	var b := Gods.team_bonus()
	var names := {"hp_pct": "HP", "atk_pct": "ATK", "def_pct": "DEF", "spd_pct": "SPD", "crit": "Crit chance", "crit_dmg": "Crit damage"}
	for key in names:
		var val := float(b.get(key, 0.0))
		if val > 0.0:
			v.add_child(_god_label("+%s%%  %s" % [_pct(val), names[key]], 20, COL_TEXT))

	v.add_child(_god_label("Blessing", 21, COL_GOLD))
	v.add_child(_god_label(Gods.blessing_text(avatar), 19, COL_TEXT))

	var skill: Dictionary = avatar["skill"]
	v.add_child(_god_label("Divine Skill", 21, COL_GOLD))
	v.add_child(_god_label(str(skill["name"]), 20, color.lightened(0.35)))
	v.add_child(_god_label(str(skill["desc"]), 18, COL_TEXT))
	if Gods.skill_unlocked():
		v.add_child(_god_label("Takes its own turn after every %d rounds, striking with %s%% of your team's ATK." % [
			Gods.DESCEND_AFTER_ROUNDS, _pct(Gods.god_atk_mult() * 100.0)], 16, Color("9aa7bd")))
	else:
		v.add_child(_god_label("Unlocks at Divinity Level %d" % Gods.DESCEND_LEVEL, 17, COL_SHORT))
	return card


## Card text: left-aligned, wrapping, with a dark outline for contrast.
func _god_label(value: String, font_size: int, color: Color, glow := false) -> Label:
	var l := _label(value, font_size, color, HORIZONTAL_ALIGNMENT_LEFT, glow)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.03, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l


## One god in the picker: emblem, name, and its state.
func _god_pick(avatar: Dictionary) -> Control:
	var unlocked := Gods.is_avatar_unlocked(avatar)
	var is_active := str(Gods.active().get("id", "")) == str(avatar["id"])
	var color: Color = avatar.get("color", COL_GOLD)

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 290)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.12) if is_active else Color(1, 1, 1, 0.03)
	sb.border_color = color if is_active else Color("2c4466")
	sb.set_border_width_all(3 if is_active else 1)
	sb.set_corner_radius_all(12)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(_on_god_pick.bind(str(avatar["id"])))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var emblem := TextureRect.new()
	emblem.custom_minimum_size = Vector2(150, 150)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.texture = Gods.art("emblem", avatar)
	if not unlocked:
		emblem.modulate = Color(0.35, 0.37, 0.42)
	v.add_child(emblem)

	var name_l := _label(str(avatar["name"]), 17, color.lightened(0.2) if unlocked else COL_DIM)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 210
	v.add_child(name_l)
	if is_active:
		v.add_child(_label("Your god", 16, COL_OK))
	elif not unlocked:
		v.add_child(_label("Divinity Lv %d" % int(avatar["unlock"]), 15, COL_SHORT))
	else:
		v.add_child(_label("Tap to choose", 15, COL_DIM))
	return b


func _on_god_pick(id: String) -> void:
	var avatar := Gods.get_avatar(id)
	if not Gods.is_avatar_unlocked(avatar):
		_toast("Reaches you at Divinity Level %d." % int(avatar["unlock"]), COL_SHORT)
		return
	var body := "%s\n\nBlessing: %s\nDivine skill: %s — %s\n\nYou can change god later, but all training resets." % [
		str(avatar["inspired"]), Gods.blessing_text(avatar),
		str(avatar["skill"]["name"]), str(avatar["skill"]["desc"])]
	_confirm(str(avatar["name"]), body, "Follow this god", avatar.get("color", COL_GOLD), func():
		var error := Gods.set_active(id)
		if error != "":
			_toast(error, COL_SHORT)
		else:
			_toast("You now follow the %s." % str(avatar["name"]), COL_OK)
		_rebuild()
	)


## Change God: confirm, then training resets and it's back to choosing.
func _on_change_god() -> void:
	var avatar := Gods.active()
	if avatar.is_empty():
		return
	var lost := Gods.essence_invested()
	var body := "You will stop following the %s.\n\nYour Blessing and Divine Skill training resets to level 1" % str(avatar["name"])
	if lost > 0:
		body += ", and the %s Divine Essence spent on it is lost" % NumberFormat.short(lost)
	body += ".\n\nYour Divinity Level is kept. You'll choose a god again next."
	_confirm("Change God?", body, "Change God", Color("ff8a7a"), func():
		Gods.abandon()
		_toast("Choose your new god.", COL_GOLD)
		_rebuild()
	)


## A small confirm dialog with Cancel and an action button.
func _confirm(title: String, body: String, ok_text: String, color: Color, on_ok: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 760
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label(title, 32, color.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, true))
	var body_l := _label(body, 19, COL_TEXT)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body_l)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var cancel := OrnateButton.new()
	cancel.text = "Cancel"
	cancel.variant = OrnateButton.Variant.DARK
	cancel.custom_minimum_size = Vector2(220, 60)
	cancel.pressed.connect(layer.queue_free)
	row.add_child(cancel)
	var ok := OrnateButton.new()
	ok.text = ok_text
	ok.custom_minimum_size = Vector2(260, 60)
	ok.pressed.connect(func():
		layer.queue_free()
		on_ok.call()
	)
	row.add_child(ok)


func _build_furnace() -> void:
	var head := HBoxContainer.new()
	_list.add_child(head)
	var t := _label("Alchemy Furnace", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Spirit Stones  %s" % NumberFormat.short(GameState.spirit_stones),
		20, COL_STONES, HORIZONTAL_ALIGNMENT_RIGHT))

	var help := _label("Refine breakthrough pills from herbs and beast cores. Each craft makes %d pills. " % Alchemy.PILLS_PER_CRAFT
		+ "Each pill adds +%d%% to a breakthrough (use several at once). Pills are used up either way." % GameState.BREAKTHROUGH_PILL_BONUS,
		19, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(help)

	var mc := GameState.get_mc()
	var next_target := (mc.realm_index + 1) if mc != null else 1

	# Newest recipes first
	var known := GameState.known_recipes.duplicate()
	known.reverse()
	for target in known:
		_list.add_child(_recipe_row(target, target == next_target))

	var hint := "Buy pill recipes in the Treasure Pavilion (More tab)."
	if known.is_empty():
		hint = "You don't know any pill recipes yet. " + hint
	elif not GameState.has_recipe(Alchemy.buyable_up_to()):
		hint = "A new recipe is available. " + hint
	var hint_l := _label(hint, 19, COL_GOLD)
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(hint_l)


## One recipe: pill icon and name, ingredients, cost, craft buttons.
func _recipe_row(target: int, is_next: bool) -> Control:
	var recipe := Alchemy.recipe_for(target)
	var pill_id: String = recipe["pill"]
	var item := ItemDB.get_item(pill_id)
	var grade: int = item.get("grade", 0)
	var can := Alchemy.max_craftable(recipe)

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035) if not is_next else Color(COL_GOLD, 0.07)
	sb.border_color = Color(COL_GOLD, 0.8) if is_next else Color("2c4466")
	sb.set_border_width_all(2 if is_next else 1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)

	var icon := ItemSlot.new()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.setup_item(pill_id, GameState.get_item_count(pill_id))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.pressed.connect(_open_item.bind(pill_id, -1,
		"Refined here in the Alchemy Furnace, %d pills per craft." % Alchemy.PILLS_PER_CRAFT))
	h.add_child(icon)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	h.add_child(mid)

	var name_row := HBoxContainer.new()
	mid.add_child(name_row)
	var name_l := _label(item.get("name", pill_id), 22, ItemDB.grade_color(grade).lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
	name_l.clip_text = true
	name_l.custom_minimum_size.y = 32
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_l)
	if is_next:
		name_row.add_child(_label("YOUR NEXT", 15, COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT))

	# Ingredients
	var ings := HBoxContainer.new()
	ings.add_theme_constant_override("separation", 8)
	mid.add_child(ings)
	var mats: Dictionary = recipe["materials"]
	for id in mats:
		ings.add_child(_ingredient(id, int(mats[id])))

	var stones: int = recipe["stones"]
	var enough_stones := GameState.spirit_stones >= stones
	var stones_l := _label("%s Spirit Stones each" % NumberFormat.short(stones), 17,
		COL_STONES if enough_stones else COL_SHORT, HORIZONTAL_ALIGNMENT_LEFT)
	stones_l.custom_minimum_size.y = 26
	stones_l.text = "%s Spirit Stones per %d pills" % [NumberFormat.short(stones), Alchemy.PILLS_PER_CRAFT]
	mid.add_child(stones_l)

	# Buttons
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	h.add_child(buttons)

	var one := OrnateButton.new()
	one.text = "Craft ×%d" % Alchemy.PILLS_PER_CRAFT
	one.custom_minimum_size = Vector2(150, 54)
	one.disabled = can < 1
	one.pressed.connect(_on_craft.bind(target, 1))
	buttons.add_child(one)

	var many := OrnateButton.new()
	many.text = "Max ×%d" % (can * Alchemy.PILLS_PER_CRAFT) if can > 1 else "Max"
	many.variant = OrnateButton.Variant.DARK
	many.custom_minimum_size = Vector2(150, 46)
	many.add_theme_font_size_override("font_size", 18)
	many.disabled = can < 2
	many.pressed.connect(_on_craft.bind(target, can))
	buttons.add_child(many)

	return row


## Small material slot with "have / need" underneath.
func _ingredient(id: String, need: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var slot := ItemSlot.new()
	slot.custom_minimum_size = Vector2(INGREDIENT, INGREDIENT)
	slot.show_count = false
	slot.setup_item(id, 0)
	slot.pressed.connect(_open_item.bind(id, need, ""))
	box.add_child(slot)
	var have := GameState.get_item_count(id)
	var l := _label("%s/%s" % [NumberFormat.short(have), NumberFormat.short(need)], 15,
		COL_OK if have >= need else COL_SHORT)
	l.custom_minimum_size.y = 22
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


## Tap a pill or ingredient to see what it is and where to get it.
func _open_item(id: String, need: int, source: String) -> void:
	ItemInfoPopup.open(self, id, need, source)


func _on_craft(target: int, times: int) -> void:
	var made := Alchemy.craft(target, times)
	if made > 0:
		var pill_name: String = ItemDB.get_item(ItemDB.realm_pill_id(target)).get("name", "Pill")
		_toast("Refined %d × %s" % [made, pill_name], COL_OK)
	_rebuild()


func _coming_soon(title: String, text: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.y = 300
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_label(title, 30, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var l := _label(text, 22, COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(_label("Coming soon", 20, COL_GOLD))
	return box


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _draw_backdrop() -> void:
	var s := size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.4), false, 2.0)
	# Faint furnace glow at the top
	for i in 5:
		draw_circle(Vector2(s.x * 0.5, s.y * 0.15), s.x * (0.35 - i * 0.05), Color(1.0, 0.55, 0.2, 0.012))
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
