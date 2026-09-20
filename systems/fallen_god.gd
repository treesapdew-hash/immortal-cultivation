class_name FallenGod

# =========================================================
# Descent of the Fallen God, a daily boss. Save as
#   res://systems/fallen_god.gd
#
# The Fallen God descends three times a day (WINDOWS). While a
# window is open the player gets ATTACKS_PER_WINDOW attacks. Each
# is a ROUNDS-round fight he can't die in: the damage dealt is
# the score, and pays Divinity EXP and Divine Essence.
# The best attack of the day is ranked against everyone else who
# faced him today;
# yesterday's rank reward is claimed from the Events card.
#
# He scales with the player's highest stage. Fights run through
# the dungeon flow in home_battle.gd ("kind": "fallen_god").
#
# Saved in GameState.fallen_god:
#   day, used {window id: attacks}, best, best_ratio
#   prev_day, prev_ratio, prev_claimed
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

## Local start hours of each descent, and how long it stays.
const WINDOWS := [12, 18, 21]
const WINDOW_HOURS := 2
const ATTACKS_PER_WINDOW := 3
## Rounds per attack (he can't be killed, so the fight always times out).
const ROUNDS := 12

const ART := "res://assets/monsters/boss/fallen_god.png"

## His ATK / DEF as a major boss of the player's highest stage, times these.
const ATK_MULT := 1.0
const DEF_MULT := 1.0
## HP is effectively endless.
const HP := 9_000_000_000_000_000

## Rewards scale with "ratio": damage / an ordinary enemy's HP at the
## player's highest stage, so they stay steady as you progress.
## EXP = EXP_BASE x ratio ^ EXP_POWER (at most EXP_MAX), same for Essence.
const EXP_BASE := 60.0
const EXP_POWER := 0.6
const EXP_MAX := 800
const ESSENCE_BASE := 8.0
const ESSENCE_POWER := 0.5
const ESSENCE_MAX := 120

## Daily ranking, against whoever else fought him today
## (setup_18_boards.sql). It used to be 29 invented cultivators,
## which pushed every real player 29 places down a table that pays
## by rank.
## [best rank this applies up to, jade, divine essence]
const RANK_REWARDS := [
	[1, 300, 200],
	[3, 200, 150],
	[10, 120, 100],
	[20, 60, 50],
	[999, 30, 20],
]


# ---------------------------------------------------------
# TIME AND STATE
# ---------------------------------------------------------

static func is_unlocked() -> bool:
	return Gods.is_unlocked()


static func _state() -> Dictionary:
	var s := GameState.fallen_god
	var today := GameState.today()
	if int(s.get("day", 0)) != today:
		# Yesterday's best becomes the rank to claim
		if int(s.get("day", 0)) != 0 and float(s.get("best_ratio", 0.0)) > 0.0:
			s["prev_day"] = int(s["day"])
			s["prev_ratio"] = float(s["best_ratio"])
			s["prev_claimed"] = false
		s["day"] = today
		s["used"] = {}
		s["best"] = 0
		s["best_ratio"] = 0.0
	return s


static func _now() -> Dictionary:
	return GameState.now_dict()


## DEV: treat the first window as open whatever the time (dev_cheats.gd).
static var debug_open := false


## Index of the open window, or -1.
static func open_window() -> int:
	if debug_open:
		return 0
	var t := _now()
	var hour := int(t["hour"])
	for i in WINDOWS.size():
		var start := int(WINDOWS[i])
		if hour >= start and hour < start + WINDOW_HOURS:
			return i
	return -1


## Seconds until the open window closes (0 if none open).
static func seconds_left_in_window() -> int:
	var i := open_window()
	if i < 0:
		return 0
	if debug_open:
		return 3600
	var t := _now()
	var end_sec := (int(WINDOWS[i]) + WINDOW_HOURS) * 3600
	return end_sec - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))


## Seconds until the next window opens.
static func seconds_to_next_window() -> int:
	var t := _now()
	var now_sec := int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"])
	for start in WINDOWS:
		var s := int(start) * 3600
		if s > now_sec:
			return s - now_sec
	return 86400 - now_sec + int(WINDOWS[0]) * 3600


static func next_window_hour() -> int:
	var t := _now()
	for start in WINDOWS:
		if int(start) > int(t["hour"]):
			return int(start)
	return int(WINDOWS[0])


static func attacks_left() -> int:
	var i := open_window()
	if i < 0:
		return 0
	var used: Dictionary = _state()["used"]
	return maxi(0, ATTACKS_PER_WINDOW - int(used.get(str(i), 0)))


static func best_today() -> int:
	return int(_state()["best"])


## "1h 12m" / "35m"
static func time_text(seconds: int) -> String:
	var h := floori(float(seconds) / 3600.0)
	var m := floori(float(seconds % 3600) / 60.0)
	return "%dh %dm" % [h, m] if h > 0 else "%dm" % maxi(m, 1)


# ---------------------------------------------------------
# THE BOSS
# ---------------------------------------------------------

## HP of an ordinary enemy at the player's highest stage (reward scale).
static func reference_hp() -> float:
	return float(EnemyGenerator.BASE_HP) * EnemyGenerator.hp_multiplier(maxi(GameState.highest_stage, 1))


static func enemies() -> Array:
	var stage := maxi(GameState.highest_stage, 1)
	var base_atk := float(EnemyGenerator.BASE_ATK) * EnemyGenerator.atk_multiplier(stage)
	var tex: Texture2D = load(ART) as Texture2D if ResourceLoader.exists(ART) else null
	var team: Array = []
	team.resize(EnemyGenerator.TEAM_SIZE)
	team[EnemyGenerator.BOSS_SLOT] = {
		"name": "Fallen God",
		"monster_id": "fallen_god",
		"immune": false,
		"hp": HP,
		"atk": int(base_atk * 2.5 * ATK_MULT),
		"def": int(EnemyGenerator.BASE_DEF * EnemyGenerator.atk_multiplier(stage) * 2.0 * DEF_MULT),
		"mdef": int(EnemyGenerator.BASE_DEF * EnemyGenerator.atk_multiplier(stage) * 2.0 * DEF_MULT),
		"spd": int(EnemyGenerator.BASE_SPD * 1.1),
		"is_boss": true,
		"sprite": tex,
		"color": Color("ffd36b"),
	}
	return team


## "" if an attack can start now, otherwise why not.
static func can_attack() -> String:
	if not is_unlocked():
		return "Reach %s to face the Fallen God." % str(Realms.get_label(Gods.UNLOCK_REALM, 1))
	if open_window() < 0:
		return "He descends again at %02d:00." % next_window_hour()
	if attacks_left() <= 0:
		return "No attacks left this descent. He returns at %02d:00." % next_window_hour()
	return ""


## Starts an attack on the home battlefield. Returns "" if it began.
static func challenge(from: Node) -> String:
	var error := can_attack()
	if error != "":
		return error
	var battle := Dungeons.find_battle(from)
	if battle == null:
		return "Battle area not found."
	if battle.call("is_in_dungeon"):
		return "A fight is already waiting."
	var request := {
		"kind": "fallen_god",
		"window": open_window(),
		"enemies": enemies(),
		"title": "FALLEN GOD",
		"subtitle": "Descent of the Fallen God",
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


# ---------------------------------------------------------
# REWARDS
# ---------------------------------------------------------

static func rewards_for(damage: int) -> Dictionary:
	var ratio := float(damage) / maxf(reference_hp(), 1.0)
	return {
		"ratio": ratio,
		"exp": mini(EXP_MAX, int(EXP_BASE * pow(maxf(ratio, 0.0), EXP_POWER))),
		"essence": mini(ESSENCE_MAX, int(ESSENCE_BASE * pow(maxf(ratio, 0.0), ESSENCE_POWER))),
	}


## Called by home_battle after an attack. Pays out and records the best.
static func finish(window: int, damage: int) -> Dictionary:
	var s := _state()
	var used: Dictionary = s["used"]
	used[str(window)] = int(used.get(str(window), 0)) + 1
	var got := rewards_for(damage)
	got["new_best"] = damage > int(s["best"])
	if damage > int(s["best"]):
		s["best"] = damage
		s["best_ratio"] = float(got["ratio"])
	# A new best goes up straight away, so the table is right for
	# everyone else looking at it today. Quiet: a failure here costs
	# nothing and is picked up by the next refresh().
	if bool(got["new_best"]) and available():
		refresh()
	if int(got["exp"]) > 0:
		Gods.add_exp(int(got["exp"]))
	if int(got["essence"]) > 0:
		GameState.add_items({Gods.ESSENCE_ID: int(got["essence"])})
	GameState.bump("fallen_god")
	GameState.save_game()
	return got


# ---------------------------------------------------------
# RANKING
# ---------------------------------------------------------

## Today's challengers, as last fetched. Cached and returned
## synchronously, because the Events card asks while being built.
static var _cache: Array = []


static func available() -> bool:
	return Backend.is_configured()


## Sends today's best up and brings the table back. Returns true if
## it changed, so a screen can redraw.
static func refresh() -> bool:
	if not available():
		return false
	var s := _state()
	var mine := float(s.get("best_ratio", 0.0))
	if mine > 0.0 and int(s.get("day", 0)) == GameState.today():
		await Backend.call_fn("submit_fallen_god", {"p_ratio": mine})
	var r: Dictionary = await Backend.call_fn("fallen_god_board", {"p_limit": 30})
	if not r["ok"] or not (r["data"] is Array):
		return false
	# Compared as text rather than with !=, which on arrays of
	# dictionaries is not dependable enough to drive a redraw.
	var before := JSON.stringify(_cache)
	_cache = r["data"]
	return before != JSON.stringify(_cache)


## Board for a day with the player in it, best first. `day` is kept
## in the signature so callers read the same as before; the server
## only holds today's.
static func board(_day: int, player_ratio: float) -> Array:
	var rows: Array = []
	for row in _cache:
		# Our own server row is replaced by the live local one below,
		# which is fresher than whatever was last uploaded.
		if str(row.get("id", "")) == Backend.user_id:
			continue
		rows.append({
			"name": str(row.get("name", "Cultivator")),
			"ratio": float(row.get("ratio", 0.0)),
		})
	rows.append({"name": str(GameState.mc_name) + " (You)", "ratio": player_ratio, "you": true})
	rows.sort_custom(func(a, b): return float(a["ratio"]) > float(b["ratio"]))
	return rows


static func rank_of(day: int, player_ratio: float) -> int:
	var rows := board(day, player_ratio)
	for i in rows.size():
		if bool(rows[i].get("you", false)):
			return i + 1
	return rows.size()


static func today_rank() -> int:
	var s := _state()
	if float(s["best_ratio"]) <= 0.0:
		return 0
	return rank_of(int(s["day"]), float(s["best_ratio"]))


static func rank_reward(rank: int) -> Array:
	for row in RANK_REWARDS:
		if rank <= int(row[0]):
			return [int(row[1]), int(row[2])]
	return [0, 0]


## Yesterday's rank if its reward is waiting, else 0.
static func claimable_rank() -> int:
	var s := _state()
	if not s.has("prev_day") or bool(s.get("prev_claimed", true)):
		return 0
	return rank_of(int(s["prev_day"]), float(s["prev_ratio"]))


static func claim_rank_reward() -> Array:
	var rank := claimable_rank()
	if rank <= 0:
		return []
	var reward := rank_reward(rank)
	_state()["prev_claimed"] = true
	GameState.add_immortal_jade(int(reward[0]))
	GameState.add_items({Gods.ESSENCE_ID: int(reward[1])})
	GameState.save_game()
	return [rank, reward[0], reward[1]]
