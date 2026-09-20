class_name Trials

# =========================================================
# Daily Rotating Trial. Save as
#   res://systems/trials.gd
#
# Each weekday opens one themed trial; on Sunday every trial
# is open. A trial is a tower of tiers, fought on the home
# battlefield like a dungeon floor. One Dao gets a bonus in
# each trial, so the best team changes day to day.
#   - Challenge: fight the next tier. Only a WIN uses an entry.
#   - Sweep: collect your highest cleared tier again.
# Entries are shared by all trials: ENTRIES_PER_DAY a day.
#
# Saved in GameState.trials:
#   day   day the entries are counted for
#   used  entries used that day
#   best  {trial id: highest tier cleared}
#
# Fights go through the dungeon flow in home_battle.gd, marked
# "kind": "trial", and come back here in finish().
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

const ENTRIES_PER_DAY := 2
const UNLOCK_STAGE := 30
const MAX_TIER := 200

## Tier n fights like main stage BASE + (n - 1) x STEP.
const STAGE_BASE := 20
const STAGE_STEP := 15
## A boss every 5 tiers, double rewards every 10 (as dungeons).
const MILESTONE_EVERY := 10

## HP and ATK bonus (%) for the day's Dao in its trial.
## A trial with "dao": "ALL" gives ALL_DAO_PCT to everyone.
const DAO_PCT := 20
const ALL_DAO_PCT := 10

## weekday: 0 = Sunday ... 6 = Saturday. Sunday opens them all.
## dao: an Enums.Path name, or "ALL".
## emblem: drawn fallback (star, claw, sword, chest); art goes in
## assets/ui/dungeons/<id>.png like the dungeon emblems.
const LIST := [
	{"id": "beast_tide", "name": "Beast Tide", "weekday": 1, "dao": "MARTIAL",
		"desc": "A tide of spirit beasts floods the valley. Rewards pill herbs and beast cores.",
		"color": Color("ff9a5a"), "emblem": "claw"},
	{"id": "sword_tomb", "name": "Sword Tomb", "weekday": 2, "dao": "SWORD",
		"desc": "Broken blades of fallen sword saints still hunger. Rewards Refining Ore.",
		"color": Color("9fd0ff"), "emblem": "sword"},
	{"id": "soul_spring", "name": "Soul Spring", "weekday": 3, "dao": "SPIRIT",
		"desc": "Wraiths guard a spring of pure soul essence. Rewards Lifebound Essence.",
		"color": Color("ff9ad8"), "emblem": "star"},
	{"id": "forge_ember", "name": "Forge Ember", "weekday": 4, "dao": "DIVINE",
		"desc": "Fire spirits of an ancient forge awaken. Rewards Artifact Cores.",
		"color": Color("ffb84d"), "emblem": "sword"},
	{"id": "starfall", "name": "Starfall Terrace", "weekday": 5, "dao": "MYSTIC",
		"desc": "Falling stars carry fragments of fate. Rewards Star-up Pills.",
		"color": Color("ffe07a"), "emblem": "star"},
	{"id": "treasure_mirage", "name": "Treasure Mirage", "weekday": 6, "dao": "ALL",
		"desc": "A mirage of a lost treasury. Rewards Treasure Dust and Array Flags.",
		"color": Color("c79bff"), "emblem": "chest"},
]

## Rewards per tier: base + tier x per (x2 on milestone tiers).
const JADE_BASE := 5
const JADE_PER := 1
const HERBS_BASE := 8
const HERBS_PER := 2.0
const CORES_BASE := 4
const CORES_PER := 1.0
const ORE_BASE := 4
const ORE_PER := 0.6
const HEAVENLY_FROM := 40
const ESSENCE_BASE := 20
const ESSENCE_PER := 6.0
const CORE_BASE := 20
const CORE_PER := 6.0
const PILL_BASE := 5
const PILL_PER := 1.5
const DUST_BASE := 20
const DUST_PER := 8.0
const FLAG_BASE := 1
const FLAG_PER := 0.05


# ---------------------------------------------------------
# WHAT'S OPEN
# ---------------------------------------------------------

static func get_def(id: String) -> Dictionary:
	for def in LIST:
		if def["id"] == id:
			return def
	return {}


## DEV: act as if it's this weekday (0-6); -1 = the real day.
## Set from dev_cheats.gd; not saved.
static var debug_weekday := -1


static func weekday() -> int:
	if debug_weekday >= 0:
		return debug_weekday
	return int(GameState.now_dict()["weekday"])


static func is_free_day() -> bool:
	return weekday() == 0


## Trials open today (all of them on Sunday).
static func open_today() -> Array:
	if is_free_day():
		return LIST.duplicate()
	var out: Array = []
	for def in LIST:
		if int(def["weekday"]) == weekday():
			out.append(def)
	return out


static func is_open(def: Dictionary) -> bool:
	return is_free_day() or int(def["weekday"]) == weekday()


static func is_unlocked() -> bool:
	return GameState.highest_stage >= UNLOCK_STAGE


## "Sword Dao +20% HP and ATK" / "Every Dao +10% HP and ATK"
static func dao_text(def: Dictionary) -> String:
	var dao := str(def["dao"])
	if dao == "ALL":
		return "Every Dao  +%d%% HP and ATK" % ALL_DAO_PCT
	return "%s Dao  +%d%% HP and ATK" % [dao.capitalize(), DAO_PCT]


# ---------------------------------------------------------
# PROGRESS AND ENTRIES
# ---------------------------------------------------------

static func _state() -> Dictionary:
	var t := GameState.trials
	var today := GameState.today()
	if int(t.get("day", 0)) != today:
		t["day"] = today
		t["used"] = 0
	if not t.has("best"):
		t["best"] = {}
	return t


static func highest(def: Dictionary) -> int:
	var best: Dictionary = _state()["best"]
	return int(best.get(def["id"], 0))


static func next_tier(def: Dictionary) -> int:
	return mini(highest(def) + 1, MAX_TIER)


static func entries_left() -> int:
	return maxi(0, ENTRIES_PER_DAY - int(_state()["used"]))


static func _use_entry() -> void:
	var t := _state()
	t["used"] = int(t["used"]) + 1


# ---------------------------------------------------------
# FIGHTS AND REWARDS
# ---------------------------------------------------------

static func stage_equiv(tier: int) -> int:
	return STAGE_BASE + (tier - 1) * STAGE_STEP


static func is_boss_tier(tier: int) -> bool:
	return Dungeons.is_boss_floor(tier)


static func enemies_for(tier: int) -> Array:
	# Same lineup rules as dungeon floors
	return Dungeons.enemies_for({"base": STAGE_BASE, "step": STAGE_STEP}, tier)


## What a tier gives: {item id: count}, Jade under Dungeons.JADE_KEY.
static func rewards_for(def: Dictionary, tier: int) -> Dictionary:
	var mult := 2 if tier % MILESTONE_EVERY == 0 else 1
	var items := {}
	items[Dungeons.JADE_KEY] = (JADE_BASE + tier * JADE_PER) * mult
	match str(def["id"]):
		"beast_tide":
			var region := Loot.region_for(stage_equiv(tier))
			var major: int = Loot.REGIONS[region][1]
			items[ItemDB.material_id(major, "herb_common")] = _amount(HERBS_BASE, HERBS_PER, tier) * mult
			items[ItemDB.material_id(major, "core_common")] = _amount(CORES_BASE, CORES_PER, tier) * mult
			items[ItemDB.material_id(major, "herb_rare")] = (1 + floori(tier / 4.0)) * mult
			if tier >= 6:
				items[ItemDB.material_id(major, "core_rare")] = floori(tier / 6.0) * mult
		"sword_tomb":
			items["refining_ore"] = _amount(ORE_BASE, ORE_PER, tier) * mult
			if tier >= HEAVENLY_FROM:
				items["heavenly_ore"] = (1 + floori((tier - HEAVENLY_FROM) / 15.0)) * mult
		"soul_spring":
			items[Lifebound.ESSENCE_ID] = _amount(ESSENCE_BASE, ESSENCE_PER, tier) * mult
		"forge_ember":
			items[Artifacts.CORE_ID] = _amount(CORE_BASE, CORE_PER, tier) * mult
		"starfall":
			items["starup_pill"] = _amount(PILL_BASE, PILL_PER, tier) * mult
		"treasure_mirage":
			items["treasure_dust"] = _amount(DUST_BASE, DUST_PER, tier) * mult
			items[BattleArray.FLAG_ID] = _amount(FLAG_BASE, FLAG_PER, tier) * mult
	BattleArray.convert_spare_flags(items)
	return items


static func _amount(base: int, per: float, tier: int) -> int:
	return base + floori(per * float(tier))


## Battle modifiers for home_battle: which Dao gets how much.
static func mods_for(def: Dictionary) -> Dictionary:
	var dao := str(def["dao"])
	if dao == "ALL":
		return {"dao": -1, "all": true, "pct": ALL_DAO_PCT}
	return {"dao": int(Enums.Path.get(dao, -1)), "all": false, "pct": DAO_PCT}


## Starts the next tier. Returns "" if the fight started.
static func challenge(from: Node, def: Dictionary) -> String:
	if not is_unlocked():
		return "Reach Stage %d to enter trials." % UNLOCK_STAGE
	if not is_open(def):
		return "This trial isn't open today."
	if entries_left() <= 0:
		return "No trial entries left today."
	if highest(def) >= MAX_TIER:
		return "Every tier cleared!"
	var battle := Dungeons.find_battle(from)
	if battle == null:
		return "Battle area not found."
	if battle.call("is_in_dungeon"):
		return "A fight is already waiting."

	var tier := next_tier(def)
	var request := {
		"kind": "trial",
		"trial": str(def["id"]),
		"tier": tier,
		"enemies": enemies_for(tier),
		"title": "%s  T%d" % [str(def["name"]).to_upper(), tier],
		"subtitle": "%s  ·  Tier %d" % [def["name"], tier],
		"rewards": rewards_for(def, tier),
		"mods": mods_for(def),
	}
	if not battle.call("start_dungeon", request):
		return "A fight is already waiting."

	var router := from
	while router != null and not router.has_method("open_tab"):
		router = router.get_parent()
	if router != null:
		router.call("open_tab", "Home")
	return ""


## Called by home_battle when a trial fight is won.
static func finish(request: Dictionary) -> void:
	var id := str(request["trial"])
	var best: Dictionary = _state()["best"]
	best[id] = maxi(int(best.get(id, 0)), int(request["tier"]))
	_use_entry()
	Dungeons._grant({}, int(request["tier"]), request["rewards"])
	GameState.save_game()


## Collects the highest cleared tier again. Returns the rewards ({} if not possible).
static func sweep(def: Dictionary) -> Dictionary:
	var top := highest(def)
	if top <= 0 or entries_left() <= 0 or not is_open(def) or not is_unlocked():
		return {}
	var rewards := rewards_for(def, top)
	_use_entry()
	Dungeons._grant({}, top, rewards)
	GameState.save_game()
	return rewards
