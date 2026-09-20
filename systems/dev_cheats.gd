extends CanvasLayer

# =========================================================
# DEV CHEATS -- testing only.
#
# Add this script to a node in home_screen (or make it an
# autoload). A small "DEV" button appears in the corner.
#
# TURN IT OFF BEFORE RELEASE: set ENABLED to false, or remove
# the node. It also hides itself automatically in exported
# release builds.
# =========================================================

## Safe to leave on: _ready() also frees the panel unless this is a
## debug build or the editor, so a RELEASE export never carries it.
## That guard is the only thing keeping it out of a shipped build —
## never hand out a DEBUG export with this true.
const ENABLED := true

const COL_PANEL := Color(0.05, 0.07, 0.12, 0.96)
const COL_GOLD := Color("e2c27a")
const COL_TEXT := Color("d8e2f0")
const COL_DIM := Color("7f8ea3")

const DAY_NAMES := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

var _panel: PanelContainer
var _open := false
var _status: Label


func _ready() -> void:
	layer = 90
	if not ENABLED or (not OS.is_debug_build() and not OS.has_feature("editor")):
		queue_free()
		return
	_build()


func _build() -> void:
	var toggle := Button.new()
	toggle.text = "DEV"
	toggle.position = Vector2(12, 120)
	toggle.size = Vector2(90, 48)
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.pressed.connect(_toggle)
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 176)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)
	outer.add_child(_label("DEV CHEATS", 22, COL_GOLD))
	_status = _label("", 16, COL_TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(600, 44)
	outer.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, 1150)
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	_section(v, "Resources", [
		["+1M Qi, Stones, Jade", _rich],
		["+100K Pills & Ore", _materials],
		["+500 every material", _all_materials],
		["Learn all recipes", _recipes],
		["Give 5 strong gear", _gear],
		["+10 random partners", _partners],
		["+10 Summon Scrolls & 2 Bundles", _summon_scrolls],
		["+1 of each Selection Scroll", _selection_scrolls],
		["+300 Fate Points", _fate_points],
		["+1 of each Premium Scroll", _premium_scrolls],
		["+Essence & fragments (evolve)", _premium_mats],
	])
	_section(v, "Battle", [
		["Team power x10", _power_10],
		["Team power x100", _power_100],
		["Team power normal", _power_off],
		["Win this battle", _win_now],
	])
	_section(v, "Progress", [
		["+10 stages", _stage_10],
		["+100 stages", _stage_100],
		["+1000 stages", _stage_1000],
		["MC: free breakthrough", _breakthrough],
		["MC: +1 star", _star],
		["Simulate 8h offline", _offline_8h],
	])
	_section(v, "Daily resets", [
		["NEW DAY (reset all)", _new_day],
		["New week (missions)", _new_week],
		["Reset Tribulation", _reset_tribulation],
		["Reset trial entries", _reset_trials],
		["Trial day: next", _next_trial_day],
		["Trial day: real", _real_trial_day],
		["Reset dungeon entries", _entries],
		["Reset shop & expeditions", _reset_shop],
	])
	_section(v, "Systems", [
		["Finish all missions", _finish_missions],
		["Reset achievements", _reset_achievements],
		["Finish expeditions now", _finish_expeditions],
		["Battle Array: max", _array_max],
		["Battle Array: level 1", _array_reset],
		["+10K Divinity EXP", _divinity_10k],
		["Divinity +10 levels", _divinity_levels],
		["+2,000 Divine Essence", _essence],
		["MC: jump to Ascendant", _mc_ascendant],
		["Fallen God: open now", _fallen_open],
		["Fallen God: reset attacks", _fallen_reset],
		["Tame every Spirit Beast", _tame_all],
		["Codex: discover everything", _codex_all],
		["Titles: unlock every one", _titles_all],
		["Titles: clear all", _titles_clear],
		["Cloud: upload save now", _cloud_upload],
		["Cloud: restore save", _cloud_restore],
		["FRESH START (sign out + wipe save)", _fresh_start],
		["+6 random spirit rings", _beast_rings],
		["+1000 Beast Cores", _beast_cores],
		["Beast Forest: reset hunts", _beast_reset],
	])


func _section(parent: VBoxContainer, title: String, entries: Array) -> void:
	var head := _label(title, 17, COL_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for entry in entries:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(296, 48)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(entry[1])
		grid.add_child(b)


func _toggle() -> void:
	_open = not _open
	_panel.visible = _open


func _say(message: String) -> void:
	_status.text = message


func _refresh_all() -> void:
	GameState.save_game()
	GameState.currency_changed.emit()
	GameState.roster_changed.emit()
	GameState.achievements_changed.emit()
	GameState.stage_changed.emit()


# ---------------------------------------------------------
# RESOURCES
# ---------------------------------------------------------

func _rich() -> void:
	GameState.add_qi(1_000_000)
	GameState.add_spirit_stones(1_000_000)
	GameState.add_immortal_jade(1_000_000)
	GameState.save_game()
	_say("Qi, Spirit Stones and Jade added.")


func _materials() -> void:
	GameState.add_starup_pills(100_000)
	GameState.add_items({"refining_ore": 100_000})
	GameState.save_game()
	_say("Star-up Pills and Refining Ore added.")


func _all_materials() -> void:
	var drops := {}
	for id in ItemDB.ids_in(ItemDB.Category.MATERIAL):
		drops[id] = 500
	for i in range(1, Realms.count()):
		drops[ItemDB.realm_pill_id(i)] = 100
	GameState.add_items(drops)
	GameState.save_game()
	_say("500 of every material (Array Flags included) and 100 of every pill.")


func _recipes() -> void:
	for i in range(1, Realms.count()):
		GameState.learn_recipe(i)
	GameState.save_game()
	GameState.currency_changed.emit()
	_say("All pill recipes learned.")


func _gear() -> void:
	for i in 5:
		GameState.add_gear(Gear.make(i % 4, 20 + randi_range(0, 4)))
	GameState.gear_changed()
	_say("5 high-grade pieces added (Inventory > Equipment).")


## Random White to Purple partners, for testing the array and salvage.
func _partners() -> void:
	var tiers := [Enums.Rarity.WHITE, Enums.Rarity.BLUE, Enums.Rarity.GREEN, Enums.Rarity.PURPLE]
	var got := 0
	for _i in 10:
		if Achievements._give_card(int(tiers.pick_random())) != "":
			got += 1
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("%d partners added (duplicates become Soul Fragments)." % got)


func _summon_scrolls() -> void:
	GameState.add_items({SummonSystem.SCROLL_ID: 10, SummonSystem.BUNDLE_ID: 2})
	GameState.save_game()
	_say("+10 Summon Scrolls and 2 Scroll Bundles.")


func _premium_scrolls() -> void:
	var drops := {SummonSystem.PREMIUM_SCROLL: 1}
	for g in SummonSystem.PREMIUM_GROUPS:
		drops[SummonSystem.premium_scroll_id(str(g))] = 1
	GameState.add_items(drops)
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("+1 Premium Selection Scroll and +1 of each group scroll.")


## Everything an evolution needs: Essence to forge with, and enough
## Soul Fragments on every partner to reach their star cap.
func _premium_mats() -> void:
	GameState.add_items({GameState.PREMIUM_ESSENCE_ID: 1000})
	var touched := 0
	for p in GameState.roster:
		if p.is_mc():
			continue
		GameState.partner_copies[p.partner_id] = GameState.get_copies(p.partner_id) + 40
		touched += 1
	GameState.starup_pills += 100000000
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("+1000 Premium Soul Essence, +40 Soul Fragments on %d partners, +100M Star-up Pills." % touched)


func _fate_points() -> void:
	GameState.fate_points += SummonSystem.FATE_COST
	GameState.save_game()
	GameState.currency_changed.emit()
	_say("+%d Fate Points (enough for one featured Red)." % SummonSystem.FATE_COST)


func _selection_scrolls() -> void:
	var drops := {}
	for tier in SummonSystem.SELECT_SCROLLS:
		drops[SummonSystem.SELECT_SCROLLS[tier]] = 1
	GameState.add_items(drops)
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("+1 Purple, Red, Gold and Prismatic Selection Scroll.")


# ---------------------------------------------------------
# BATTLE
# ---------------------------------------------------------

func _power_10() -> void:
	GameState.debug_power_mult = 10.0
	_say("Your team fights at 10x power from the next battle.")


func _power_100() -> void:
	GameState.debug_power_mult = 100.0
	_say("Your team fights at 100x power from the next battle.")


func _power_off() -> void:
	GameState.debug_power_mult = 1.0
	_say("Power boost off.")


## Kills every enemy in the running battle.
func _win_now() -> void:
	var battle = _find_battle()
	if battle == null or battle.core == null:
		_say("No battle running.")
		return
	for unit in battle.core.enemy_units:
		unit.current_hp = 0
	_say("Enemies wiped out.")


# ---------------------------------------------------------
# PROGRESS
# ---------------------------------------------------------

func _stage_10() -> void:
	_add_stages(10)


func _stage_100() -> void:
	_add_stages(100)


func _stage_1000() -> void:
	_add_stages(1000)


func _add_stages(n: int) -> void:
	GameState.current_stage += n
	# Trials, Tribulation and dungeons unlock from the highest stage
	GameState.highest_stage = maxi(GameState.highest_stage, GameState.current_stage)
	GameState.save_game()
	GameState.stage_changed.emit()
	_say("Now on stage %d." % GameState.current_stage)


func _breakthrough() -> void:
	var mc := GameState.get_mc()
	if mc == null:
		return
	mc.tier = Realms.LEVELS_PER_MINOR
	var result := GameState.attempt_breakthrough(mc, 0)
	# Force it through even if the roll failed
	if result.get("ok", false) and not result["success"]:
		mc.breakthrough()
		GameState.sync_mc_tier()
		GameState.save_game()
		GameState.roster_changed.emit()
		GameState.realm_changed.emit()
	_say("MC is now %s." % mc.get_realm_text())


func _star() -> void:
	var mc := GameState.get_mc()
	if mc == null:
		return
	mc.add_star()
	GameState.sync_mc_tier()
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("MC now has %d stars." % mc.stars)


## Pretends the game was closed for 8 hours, then shows the popup.
func _offline_8h() -> void:
	GameState._compute_offline(GameState.now_unix() - 8 * 3600)
	if not GameState.has_offline_rewards():
		_say("No offline rewards (is the MC created?).")
		return
	OfflineRewardsPopup.open(self)
	_say("8 hours of closed-door cultivation waiting.")


# ---------------------------------------------------------
# DAILY RESETS
# ---------------------------------------------------------

## Everything that resets at midnight starts over.
func _new_day() -> void:
	GameState.shop_day = 0
	GameState.shop_bought.clear()
	GameState.dungeon_day = 0
	GameState.dungeon_entries.clear()
	GameState.trials["day"] = 0
	GameState.tribulation["day"] = 0
	GameState.missions["day"] = 0
	Missions.refresh()
	_refresh_all()
	GameState.expeditions_updated.emit()
	_say("New day: shop, dungeons, trials, Tribulation, expeditions and daily missions reset.")


func _new_week() -> void:
	GameState.missions["week"] = 0
	GameState.missions["day"] = 0
	Missions.refresh()
	_refresh_all()
	_say("New week: weekly and daily missions reset.")


func _reset_tribulation() -> void:
	GameState.tribulation["day"] = 0
	_refresh_all()
	_say("Tribulation can be faced again (best wave kept).")


func _reset_trials() -> void:
	GameState.trials["day"] = 0
	_refresh_all()
	_say("Trial entries reset.")


## Opens the next weekday's trial, to test every theme today.
func _next_trial_day() -> void:
	var day := Trials.weekday()
	Trials.debug_weekday = (day + 1) % 7
	_refresh_all()
	_say("Trials now act like %s." % DAY_NAMES[Trials.debug_weekday])


func _real_trial_day() -> void:
	Trials.debug_weekday = -1
	_refresh_all()
	_say("Trials follow the real day again (%s)." % DAY_NAMES[Trials.weekday()])


func _entries() -> void:
	GameState.dungeon_entries.clear()
	GameState.save_game()
	_say("Dungeon entries reset.")


func _reset_shop() -> void:
	GameState.shop_day = 0
	GameState.shop_bought.clear()
	GameState.save_game()
	GameState.currency_changed.emit()
	GameState.expeditions_updated.emit()
	_say("Shop stock, expedition sends and rerolls reset.")


# ---------------------------------------------------------
# SYSTEMS
# ---------------------------------------------------------

## Every daily and weekly mission becomes ready to claim.
func _finish_missions() -> void:
	Missions.refresh()
	for weekly in [false, true]:
		var base: Dictionary = GameState.missions["week_base" if weekly else "day_base"]
		for mission in Missions.list(weekly):
			var track := str(mission["track"])
			if track == "login":
				continue
			var needed := int(GameState.stats.get(track, 0)) - int(mission["goal"])
			base[track] = mini(int(base.get(track, 0)), needed)
	_refresh_all()
	_say("All daily and weekly missions are ready to claim.")


func _reset_achievements() -> void:
	GameState.claimed_achievements.clear()
	_refresh_all()
	_say("Achievements unclaimed (progress kept).")


## Grants all 46, permanently, so every banner and the full stacked
## bonus can be looked at. Granted with no expiry even for the ones
## that normally lapse: a standing that ran out mid-test would look
## like a bug rather than the point.
func _titles_all() -> void:
	# Stops the next server sync taking the Arena, tester and sect
	# ones straight back off, since the server has not granted them.
	Titles.dev_all_unlocked = true
	for id in Titles.LIST:
		GameState.titles_owned[str(id)] = 0
	Titles.refresh_bonus()
	_refresh_all()
	GameState.titles_changed.emit()
	_say("All %d titles unlocked. Codex > Titles to wear one." % Titles.LIST.size())


## Back to nothing, so the earning path can be tested from clean.
## The worn one goes too, or it would sit there unowned.
func _titles_clear() -> void:
	Titles.dev_all_unlocked = false
	GameState.titles_owned.clear()
	GameState.title_worn = ""
	Titles.refresh_bonus()
	_refresh_all()
	GameState.titles_changed.emit()
	if Backend.is_configured():
		Backend.update_profile()
	_say("Titles cleared. They come back as their conditions are met again.")


func _finish_expeditions() -> void:
	for trip in GameState.expeditions:
		trip["ends_at"] = 0
	GameState.expeditions_changed()
	_say("All expeditions have returned.")


func _array_max() -> void:
	GameState.array_level = BattleArray.LEVELS.size()
	BattleArray._pad()
	GameState.save_game()
	GameState.array_changed.emit()
	_say("Battle Array at Level %d (%d slots)." % [BattleArray.level(), BattleArray.slot_count()])


func _array_reset() -> void:
	GameState.array_level = 1
	# Drop partners from slots that are closed again
	if GameState.battle_array.size() > BattleArray.slot_count():
		GameState.battle_array.resize(BattleArray.slot_count())
	GameState.save_game()
	GameState.array_changed.emit()
	_say("Battle Array back to Level 1.")


func _divinity_10k() -> void:
	var up := Gods.add_exp(10_000)
	_say("+10,000 Divinity EXP (%d level%s up). Divinity Level %d." % [up, "" if up == 1 else "s", Gods.level()])


func _divinity_levels() -> void:
	var need := 0
	var lv := Gods.level()
	for i in 10:
		if lv + i >= Gods.MAX_LEVEL:
			break
		need += Gods.exp_to_next(lv + i)
	var up := Gods.add_exp(maxi(need - Gods.exp_now(), 0))
	_say("Divinity Level %d (+%d)." % [Gods.level(), up])


func _essence() -> void:
	GameState.add_items({Gods.ESSENCE_ID: 2000})
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("+2,000 Divine Essence (trains your god's Blessing and Divine Skill).")


## Test the first-launch flow again: signs out (forgets this device's
## login), wipes the local save, then closes the game. Press Play again
## and you get the welcome screen. The online account itself is kept.
func _fresh_start() -> void:
	var backend = get_node_or_null("/root/Backend")
	if backend != null and backend.is_configured():
		# Sign out first, so the wiped save isn't uploaded over the cloud one
		await backend.log_out()
	GameState.reset_account()
	_say("Fresh start ready. Closing the game: press Play again.")
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()


func _cloud_upload() -> void:
	var backend = get_node_or_null("/root/Backend")
	if backend == null or not backend.is_configured():
		_say("Backend not set up (autoload + URL/key).")
		return
	if not await backend.ensure_session():
		_say("Can't reach Supabase: check the URL/key and internet.")
		return
	backend.note_saved()
	await backend.upload_save()
	_say("Uploaded. Account: %s" % str(backend.user_id))


func _cloud_restore() -> void:
	var backend = get_node_or_null("/root/Backend")
	if backend == null or not backend.is_configured():
		_say("Backend not set up (autoload + URL/key).")
		return
	var error: String = await backend.restore_cloud_save()
	_say("Cloud save restored: restart the game." if error == "" else error)


func _codex_all() -> void:
	for id in PartnerDatabase.get_all_ids():
		Codex.discover_partner(str(id))
	for id in Treasures.LIST:
		Codex.discover_treasure(str(id), 2)
	for species in Beasts.SPECIES:
		var e: Dictionary = GameState.beast_codex.get(species, {"slain": 0, "tamed": 0})
		e["tamed"] = maxi(1, int(e.get("tamed", 0)))
		e["slain"] = maxi(1, int(e.get("slain", 0)))
		GameState.beast_codex[species] = e
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("Everything discovered in the Codex (no partners or items added).")


func _tame_all() -> void:
	for species in Beasts.SPECIES:
		Beasts.tame(str(species))
		var e: Dictionary = GameState.beast_codex.get(species, {"slain": 0, "tamed": 0})
		e["tamed"] = int(e.get("tamed", 0)) + 1
		GameState.beast_codex[species] = e
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("Tamed one of all %d Spirit Beasts as Soul Spirits." % Beasts.SPECIES.size())


func _beast_rings() -> void:
	var species: Array = Beasts.SPECIES.keys()
	for i in 6:
		GameState.beast_rings.append(Beasts.make_ring(str(species.pick_random()), mini(i + 1, 6)))
	GameState.save_game()
	GameState.roster_changed.emit()
	_say("+6 spirit rings (100-Year up to Divine).")


func _beast_cores() -> void:
	GameState.add_items({Beasts.CORE_ID: 1000})
	GameState.save_game()
	_say("+1000 Beast Cores.")


func _beast_reset() -> void:
	GameState.beast_forest["used"] = 0
	GameState.beast_forest["refreshes"] = 0
	_refresh_all()
	_say("Beast Forest hunts reset.")


func _fallen_open() -> void:
	FallenGod.debug_open = not FallenGod.debug_open
	_refresh_all()
	_say("Fallen God window forced %s (not saved)." % ("OPEN" if FallenGod.debug_open else "back to real times"))


func _fallen_reset() -> void:
	GameState.fallen_god["used"] = {}
	_refresh_all()
	_say("Fallen God attacks reset for today.")


## Puts the MC at Ascendant 1 so God Path opens.
func _mc_ascendant() -> void:
	var mc := GameState.get_mc()
	if mc == null:
		return
	if mc.realm_index < Gods.UNLOCK_REALM:
		mc.realm_index = Gods.UNLOCK_REALM
		mc.tier = 1
		GameState.sync_mc_tier()
	_refresh_all()
	GameState.realm_changed.emit()
	_say("MC is now %s. God Path is open." % mc.get_realm_text())


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _find_battle():
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "", true, false):
		if node.has_method("start_dungeon"):
			return node
	return null


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
