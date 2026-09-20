class_name SectTrial

# =========================================================
# Sect Trial: an endless ladder of guardians the whole sect
# climbs together. Save as res://systems/sect_trial.gd
#
# The server (supabase_setup_4.sql) keeps the stage, the shared
# HP pool (in "Might"), attacks (3 a day) and rewards.
# An attack is a ROUNDS-round fight on the home battlefield
# ("kind": "sect_trial"); the damage dealt, measured against the
# player's OWN progress (like the Fallen God), becomes Might, so
# every member contributes fairly.
# Each stage the guardian hits harder and the pool grows 15%.
# =========================================================

const ROUNDS := 10
const ATTACKS_PER_DAY := 3
## Might = MIGHT_SCALE x ratio ^ MIGHT_POWER (at most MIGHT_CAP, server-capped too).
## ratio = damage / an ordinary enemy's HP at your highest stage.
const MIGHT_SCALE := 3.0
const MIGHT_POWER := 0.8
const MIGHT_CAP := 60
## Guardian ATK / DEF grow this much per trial stage (on top of a
## major boss at your highest stage).
const STRENGTH_PER_STAGE := 0.04

## Guardians rotate every stage: [art id, name, colour]
const GUARDIANS := [
	["stone_guardian", "Stone Temple Guardian", "c8b89a"],
	["flame_qilin", "Flame Qilin", "ff7a3a"],
	["frost_dragon", "Frost Dragon", "9fe4ff"],
	["demon_lord", "Demon Lord", "c04a6a"],
	["heavenly_general", "Heavenly General", "ffd36b"],
]
const ART_DIR := "res://assets/monsters/sect/"
const HP := 9_000_000_000_000_000


## Shared HP (Might) of a stage, same as the server's trial_hp().
static func stage_hp(stage: int) -> int:
	return int(round(300.0 * pow(1.15, stage - 1)))


static func guardian(stage: int) -> Array:
	return GUARDIANS[posmod(stage - 1, GUARDIANS.size())]


static func guardian_art(stage: int) -> Texture2D:
	var path := ART_DIR + str(guardian(stage)[0]) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Items for clearing a stage, for the PREVIEW text only: the server
## (trial_stage_items in supabase_setup_5.sql) decides what's given.
static func stage_rewards(stage: int) -> Dictionary:
	var items := {"beast_core": 20 + 2 * stage}
	if stage % 5 == 0:
		items["summon_scroll"] = 1
	if stage % 10 == 0:
		items[Gods.ESSENCE_ID] = 10
	return items


static func stage_contribution(stage: int) -> int:
	return 30 + 5 * stage


# ---------------------------------------------------------
# SERVER
# ---------------------------------------------------------

## {stage, hp_left, hp_max, attacks_used, my_might, claimed, cleared} or {}.
static func state() -> Dictionary:
	var r: Dictionary = await Backend.call_fn("sect_trial_state", {})
	return r["data"] if r["ok"] and r["data"] is Dictionary else {}


## This week's Might per member, highest first.
static func ranking(sect_id: String) -> Array:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"sect_trial_damage?select=user_id,might,profiles(display_name)&sect_id=eq." + sect_id
		+ "&week=eq." + _week_start() + "&order=might.desc")
	return r["data"] if r["ok"] and r["data"] is Array else []


## Claims every cleared stage's rewards: Contribution on the server,
## items here. Returns {ok, error, from, to, contribution, items}.
static func claim() -> Dictionary:
	var r: Dictionary = await Backend.call_fn("sect_trial_claim", {})
	if not r["ok"]:
		return {"ok": false, "error": Sects._error_text(r)}
	var d: Dictionary = r["data"]
	# The server calculated the items; give exactly those
	var total := {}
	var items = d.get("items", {})
	if items is Dictionary:
		for id in items:
			total[str(id)] = int(items[id])
	GameState.add_items(total)
	GameState.save_game()
	return {"ok": true, "error": "", "from": int(d["from"]), "to": int(d["to"]),
		"contribution": int(d["contribution"]), "items": total}


# ---------------------------------------------------------
# THE FIGHT
# ---------------------------------------------------------

static func enemies(stage: int) -> Array:
	var top := maxi(GameState.highest_stage, 1)
	var m := EnemyGenerator.atk_multiplier(top) * (1.0 + STRENGTH_PER_STAGE * float(stage - 1))
	var g := guardian(stage)
	var tex := guardian_art(stage)
	if tex == null:
		tex = MonsterDB.pick_boss(top, false)["sprite"]
	var team: Array = []
	team.resize(EnemyGenerator.TEAM_SIZE)
	team[EnemyGenerator.BOSS_SLOT] = {
		"name": str(g[1]),
		"monster_id": str(g[0]),
		"immune": false,
		"hp": HP,
		"atk": int(float(EnemyGenerator.BASE_ATK) * m * 2.5),
		"def": int(float(EnemyGenerator.BASE_DEF) * m * 2.0),
		"mdef": int(float(EnemyGenerator.BASE_DEF) * m * 2.0),
		"spd": int(float(EnemyGenerator.BASE_SPD) * 1.1),
		"is_boss": true,
		"sprite": tex,
		"color": Color(str(g[2])),
	}
	return team


## Starts an attack on the home battlefield. "" if it began.
static func challenge(from: Node, stage: int) -> String:
	var battle := Dungeons.find_battle(from)
	if battle == null:
		return "Battle area not found."
	if battle.call("is_in_dungeon"):
		return "A fight is already waiting."
	var request := {
		"kind": "sect_trial",
		"stage": stage,
		"enemies": enemies(stage),
		"title": "SECT TRIAL",
		"subtitle": "Stage %d  ·  %s" % [stage, guardian(stage)[1]],
		"rewards": {},
		"mods": {"max_rounds": ROUNDS},
	}
	if not battle.call("start_dungeon", request):
		return "A fight is already waiting."
	var router := from
	while router != null and not router.has_method("open_tab"):
		router = router.get_parent()
	if router != null:
		router.call("open_tab", "Home")
	return ""


static func might_for(damage: int) -> int:
	if damage <= 0:
		return 0
	var ratio := float(damage) / maxf(FallenGod.reference_hp(), 1.0)
	return clampi(int(round(MIGHT_SCALE * pow(ratio, MIGHT_POWER))), 1, MIGHT_CAP)


## After an attack: sends the Might to the server.
## Returns {ok, error, might, stage, cleared}.
static func finish(damage: int) -> Dictionary:
	var might := might_for(damage)
	var r: Dictionary = await Backend.call_fn("sect_trial_attack", {"p_might": might})
	if not r["ok"]:
		return {"ok": false, "error": Sects._error_text(r), "might": might}
	var d: Dictionary = r["data"]
	GameState.bump("sect_trial")
	return {"ok": true, "error": "", "might": int(d["might"]), "stage": int(d["stage"]),
		"cleared": bool(d["cleared"])}


## Monday of this week (UTC), as the server stores it: "2026-09-21".
static func _week_start() -> String:
	var days := floori(float(GameState.now_unix()) / 86400.0)
	var monday := days - posmod(days + 3, 7)
	return Time.get_date_string_from_unix_time(monday * 86400)
