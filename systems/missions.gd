class_name Missions

# =========================================================
# Daily and weekly missions. Save as
#   res://systems/missions.gd
#
# Missions give activity points. Points open 4 milestone
# chests. Daily resets at local midnight, weekly on Monday.
#
# Progress is "counter now minus counter at the reset", using
# GameState.stats (see GameState.bump). Nothing else needs to
# know about missions.
#
# Saved in GameState.missions:
#   day, week                 when each list last reset
#   day_base, week_base       copies of GameState.stats then
#   day_done, week_done       claimed mission ids
#   day_chests, week_chests   opened chests ("c0".."c3")
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

## What a mission counts (GameState.stats keys):
##   login         always done (daily only)
##   login_days    days logged in this week
##   stages        stages cleared
##   summons       summons
##   dungeon_runs  dungeon entries used (wins and sweeps)
##   expeditions   expeditions sent
##   craft         pills refined
##   forge         artifacts forged
##   shop_buys     shop purchases
##   offline       closed-door rewards collected
##   daily_full    days the last daily chest was opened
##   chat_sent     chat messages sent (any channel) — Chat
##   friends_added friend requests accepted — Friends
##   gifts_sent    friend gifts sent — Friends
##   gifts_claimed friend gifts collected — Friends
const DAILY := [
	{"id": "login", "desc": "Log in today", "track": "login", "goal": 1, "points": 10},
	{"id": "stages_10", "desc": "Clear 10 stages", "track": "stages", "goal": 10, "points": 15},
	{"id": "stages_30", "desc": "Clear 30 stages", "track": "stages", "goal": 30, "points": 15},
	{"id": "summon", "desc": "Summon once", "track": "summons", "goal": 1, "points": 10},
	{"id": "dungeon", "desc": "Enter dungeons 2 times", "track": "dungeon_runs", "goal": 2, "points": 20},
	{"id": "expedition", "desc": "Send an expedition", "track": "expeditions", "goal": 1, "points": 10},
	{"id": "craft", "desc": "Refine 5 pills", "track": "craft", "goal": 5, "points": 10},
	{"id": "shop", "desc": "Buy something in the shop", "track": "shop_buys", "goal": 1, "points": 10},
	{"id": "offline", "desc": "Collect closed-door cultivation", "track": "offline", "goal": 1, "points": 10},
	{"id": "chat", "desc": "Speak in chat", "track": "chat_sent", "goal": 1, "points": 10},
	{"id": "gift_send", "desc": "Send gifts to 3 fellow cultivators", "track": "gifts_sent", "goal": 3, "points": 10},
	{"id": "gift_claim", "desc": "Collect gifts from friends", "track": "gifts_claimed", "goal": 1, "points": 10},
]

const WEEKLY := [
	{"id": "login_5", "desc": "Log in on 5 days", "track": "login_days", "goal": 5, "points": 15},
	{"id": "stages_150", "desc": "Clear 150 stages", "track": "stages", "goal": 150, "points": 15},
	{"id": "summon_20", "desc": "Summon 20 times", "track": "summons", "goal": 20, "points": 15},
	{"id": "dungeon_15", "desc": "Enter dungeons 15 times", "track": "dungeon_runs", "goal": 15, "points": 15},
	{"id": "expedition_20", "desc": "Send 20 expeditions", "track": "expeditions", "goal": 20, "points": 10},
	{"id": "craft_50", "desc": "Refine 50 pills", "track": "craft", "goal": 50, "points": 10},
	{"id": "forge_3", "desc": "Forge 3 artifacts", "track": "forge", "goal": 3, "points": 10},
	{"id": "daily_full_5", "desc": "Open the last daily chest on 5 days", "track": "daily_full",
		"goal": 5, "points": 20},
	{"id": "friends_3", "desc": "Befriend 3 cultivators", "track": "friends_added", "goal": 3, "points": 10},
	{"id": "gifts_30", "desc": "Send 30 friend gifts", "track": "gifts_sent", "goal": 30, "points": 10},
	{"id": "chat_10", "desc": "Speak in chat 10 times", "track": "chat_sent", "goal": 10, "points": 10},
]

## Points needed to fill the bar. Both lists offer 140 points, so
## filling it takes about 93% of them — the same slack as before the
## social missions (110 offered, 100 needed). Raise this if you add
## more missions, or the bar gets easier every time.
const MAX_POINTS := 130

## Chest rewards. Besides "jade", "stones", "qi", items by id,
## "card" and "card_choice" (a rarity), chests can hold:
##   "stones_hours": h  Spirit Stones of h hours of closed-door cultivation
##   "qi_hours": h      Qi of h hours of closed-door cultivation
##   "loot_hours": h    stage drops of h hours of closed-door cultivation
##   "pill_mats": x     x crafts' worth of ingredients for the MC's next pill
## so chests keep up with the player's stage and realm.
## Chest Qi can't exceed this many of the MC's next-breakthrough costs
## per chest-hour. Early on (cheap breakthroughs, fast Qi) this stops a
## chest from skipping whole realms; later it doesn't bite at all.
const QI_STEPS_PER_HOUR := 0.75

## Thresholds stay at 25 / 50 / 75 / 100% of MAX_POINTS, so the
## rewards pace exactly as they did before MAX_POINTS changed.
const DAILY_CHESTS := [
	{"points": 33, "rewards": {"stones_hours": 2, "qi_hours": 2}},
	{"points": 65, "rewards": {"jade": 50, "loot_hours": 2, "array_flag": 5}},
	{"points": 98, "rewards": {"starup_pill": 15, "artifact_core": 40}},
	{"points": 130, "rewards": {"jade": 100, "pill_mats": 0.5, "treasure_dust": 40}},
]

const WEEKLY_CHESTS := [
	{"points": 33, "rewards": {"stones_hours": 8, "qi_hours": 8}},
	{"points": 65, "rewards": {"jade": 200, "loot_hours": 8, "lifebound_essence": 200}},
	{"points": 98, "rewards": {"starup_pill": 80, "artifact_core": 200, "treasure_dust": 200, "array_flag": 30}},
	{"points": 130, "rewards": {"jade": 300, "pill_mats": 2.0, "card_choice": Enums.Rarity.PURPLE}},
]


# ---------------------------------------------------------
# RESETS
# ---------------------------------------------------------

## Starts a new day or week when due. Safe to call often.
static func refresh() -> void:
	var m := GameState.missions
	var week := _week_id()
	if int(m.get("week", 0)) != week:
		m["week"] = week
		m["week_base"] = GameState.stats.duplicate()
		m["week_done"] = []
		m["week_chests"] = []
	var day := GameState.today()
	if int(m.get("day", 0)) != day:
		m["day"] = day
		m["day_base"] = GameState.stats.duplicate()
		m["day_done"] = []
		m["day_chests"] = []
		# After the daily snapshot, so it counts for the week only
		GameState.bump("login_days")


## Monday of this week, as a day number (local time).
static func _week_id() -> int:
	var t := Time.get_datetime_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": t["year"], "month": t["month"], "day": t["day"],
		"hour": 0, "minute": 0, "second": 0})
	var day_num := floori(float(unix) / 86400.0)
	# 1 Jan 1970 was a Thursday
	return day_num - posmod(day_num + 3, 7)


## Seconds until the list resets.
static func seconds_to_reset(weekly: bool) -> int:
	var t := Time.get_datetime_dict_from_system()
	var left := 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))
	if weekly:
		var to_monday := posmod(8 - int(t["weekday"]), 7)
		if to_monday == 0:
			to_monday = 7
		left += (to_monday - 1) * 86400
	return left


## "Resets in 5h 12m" / "Resets in 3d 4h"
static func reset_text(weekly: bool) -> String:
	var secs := seconds_to_reset(weekly)
	var days := floori(float(secs) / 86400.0)
	var hours := floori(float(secs % 86400) / 3600.0)
	var minutes := floori(float(secs % 3600) / 60.0)
	if days > 0:
		return "Resets in %dd %dh" % [days, hours]
	if hours > 0:
		return "Resets in %dh %dm" % [hours, minutes]
	return "Resets in %dm" % maxi(minutes, 1)


# ---------------------------------------------------------
# MISSIONS
# ---------------------------------------------------------

static func list(weekly: bool) -> Array:
	return WEEKLY if weekly else DAILY


static func chests(weekly: bool) -> Array:
	return WEEKLY_CHESTS if weekly else DAILY_CHESTS


static func get_mission(id: String, weekly: bool) -> Dictionary:
	for mission in list(weekly):
		if mission["id"] == id:
			return mission
	return {}


static func progress(mission: Dictionary, weekly: bool) -> int:
	refresh()
	var track := str(mission["track"])
	if track == "login":
		return 1
	var base: Dictionary = GameState.missions["week_base" if weekly else "day_base"]
	return maxi(0, int(GameState.stats.get(track, 0)) - int(base.get(track, 0)))


static func is_done(mission: Dictionary, weekly: bool) -> bool:
	return progress(mission, weekly) >= int(mission["goal"])


static func is_claimed(mission: Dictionary, weekly: bool) -> bool:
	refresh()
	var done: Array = GameState.missions["week_done" if weekly else "day_done"]
	return done.has(str(mission["id"]))


## Activity points earned so far.
static func points(weekly: bool) -> int:
	var total := 0
	for mission in list(weekly):
		if is_claimed(mission, weekly):
			total += int(mission["points"])
	return total


## Claims a mission. Returns the points gained (0 if not ready).
static func claim(id: String, weekly: bool) -> int:
	var mission := get_mission(id, weekly)
	if mission.is_empty() or not is_done(mission, weekly) or is_claimed(mission, weekly):
		return 0
	var done: Array = GameState.missions["week_done" if weekly else "day_done"]
	done.append(id)
	GameState.save_game()
	GameState.achievements_changed.emit()
	return int(mission["points"])


# ---------------------------------------------------------
# CHESTS
# ---------------------------------------------------------

static func is_chest_open(index: int, weekly: bool) -> bool:
	refresh()
	var opened: Array = GameState.missions["week_chests" if weekly else "day_chests"]
	return opened.has("c%d" % index)


static func is_chest_ready(index: int, weekly: bool) -> bool:
	var chest: Dictionary = chests(weekly)[index]
	return points(weekly) >= int(chest["points"]) and not is_chest_open(index, weekly)


## Opens a chest. Returns what was given, or {} if it isn't ready.
static func open_chest(index: int, weekly: bool) -> Dictionary:
	if index < 0 or index >= chests(weekly).size() or not is_chest_ready(index, weekly):
		return {}
	var given := _open(index, weekly)
	GameState.save_game()
	GameState.achievements_changed.emit()
	return given


## What a chest holds, in the same shape as a claim result.
## Stage loot is random, so it shows as "loot_hours" here.
static func preview(index: int, weekly: bool) -> Dictionary:
	var chest: Dictionary = chests(weekly)[index]
	return _resolve(chest["rewards"], false)


static func _open(index: int, weekly: bool) -> Dictionary:
	var opened: Array = GameState.missions["week_chests" if weekly else "day_chests"]
	opened.append("c%d" % index)
	if not weekly and index == DAILY_CHESTS.size() - 1:
		GameState.bump("daily_full")

	var chest: Dictionary = chests(weekly)[index]
	var got := _resolve(chest["rewards"], true)
	if got.has("jade"):
		GameState.add_immortal_jade(int(got["jade"]))
	if got.has("stones"):
		GameState.add_spirit_stones(int(got["stones"]))
	if got.has("qi"):
		GameState.add_qi(int(got["qi"]))
	if got.has("items"):
		GameState.add_items(got["items"])
	if got.has("card_choice"):
		var tier := int(got["card_choice"])
		var options := Achievements.card_options(tier)
		if options.is_empty():
			got.erase("card_choice")
		else:
			GameState.pending_card_choices.append({"tier": tier, "options": options,
				"from": "Weekly Chest" if weekly else "Daily Chest"})
	if got.has("card"):
		var partner := Achievements._give_card(int(got["card"]))
		if partner == "":
			got.erase("card")
		else:
			got["card"] = partner
	return got


## Turns chest rewards into real amounts for the player's stage and realm.
static func _resolve(rewards: Dictionary, roll_loot: bool) -> Dictionary:
	var out := {}
	var items := {}
	for key in rewards:
		match key:
			"jade", "stones", "qi":
				out[key] = int(out.get(key, 0)) + int(rewards[key])
			"stones_hours":
				out["stones"] = int(out.get("stones", 0)) + int(_offline(float(rewards[key]), false)["stones"])
			"qi_hours":
				var hours := float(rewards[key])
				var qi := int(_offline(hours, false)["qi"])
				var mc := GameState.get_mc()
				if mc != null:
					var step := mc.get_ascend_cost()
					if step > 0:
						qi = mini(qi, int(float(step) * hours * QI_STEPS_PER_HOUR))
				out["qi"] = int(out.get("qi", 0)) + qi
			"loot_hours":
				if roll_loot:
					var loot: Dictionary = _offline(float(rewards[key]), true)["items"]
					Loot.merge(items, loot)
				else:
					out["loot_hours"] = int(rewards[key])
			"pill_mats":
				var mats := _pill_mats(float(rewards[key]))
				Loot.merge(items, mats)
			"card", "card_choice":
				out[key] = int(rewards[key])
			_:
				items[key] = int(items.get(key, 0)) + int(rewards[key])
	BattleArray.convert_spare_flags(items)
	if not items.is_empty():
		out["items"] = items
	return out


## Closed-door rewards for some hours on the current stage.
static func _offline(hours: float, with_items: bool) -> Dictionary:
	var result := Loot.roll_offline(GameState.current_stage, hours * 3600.0)
	if not with_items:
		result["items"] = {}
	return result


## Ingredients for the MC's next pill: `crafts` crafts' worth, rounded up.
static func _pill_mats(crafts: float) -> Dictionary:
	var mc := GameState.get_mc()
	if mc == null:
		return {}
	var recipe := Alchemy.recipe_for(mc.realm_index + 1)
	var mats: Dictionary = recipe["materials"]
	var out := {}
	for id in mats:
		out[id] = maxi(1, ceili(float(mats[id]) * crafts))
	return out


# ---------------------------------------------------------
# COUNTS AND CLAIM ALL
# ---------------------------------------------------------

## Missions and chests waiting to be claimed.
static func claimable_count(weekly: bool) -> int:
	var n := 0
	for mission in list(weekly):
		if is_done(mission, weekly) and not is_claimed(mission, weekly):
			n += 1
	# Chests that points already reached, or will once claimed
	var pts := points(weekly)
	for mission in list(weekly):
		if is_done(mission, weekly) and not is_claimed(mission, weekly):
			pts += int(mission["points"])
	for i in chests(weekly).size():
		if pts >= int(chests(weekly)[i]["points"]) and not is_chest_open(i, weekly):
			n += 1
	return n


## Daily plus weekly, for the Mission tab's red dot.
static func total_claimable() -> int:
	return claimable_count(false) + claimable_count(true)


## Claims every finished mission, then opens every chest now
## reached. Returns {"points": gained, "chests": n, "got": rewards}.
static func claim_all(weekly: bool) -> Dictionary:
	var gained := 0
	var done: Array = []
	for mission in list(weekly):
		if is_done(mission, weekly) and not is_claimed(mission, weekly):
			done.append(str(mission["id"]))
			gained += int(mission["points"])
	var claimed: Array = GameState.missions["week_done" if weekly else "day_done"]
	claimed.append_array(done)

	var opened := 0
	var total := {}
	for i in chests(weekly).size():
		if is_chest_ready(i, weekly):
			_merge_given(total, _open(i, weekly))
			opened += 1

	if gained > 0 or opened > 0:
		GameState.save_game()
		GameState.achievements_changed.emit()
	return {"points": gained, "chests": opened, "got": total}


static func _merge_given(into: Dictionary, add: Dictionary) -> void:
	for key in add:
		if key == "items":
			if not into.has("items"):
				into["items"] = {}
			Loot.merge(into["items"], add["items"])
		elif key == "card":
			into["card"] = str(add["card"])
		else:
			into[key] = int(into.get(key, 0)) + int(add[key])
