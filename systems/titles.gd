class_name Titles

# =========================================================
# Titles. Save as res://systems/titles.gd
#
# Earned from the leaderboard, achievements, login, progression and
# testing. See docs/titles.md for the design and the banner art list.
#
# EVERY title you own adds its bonus, whether or not you wear it.
# The worn one is what others see beside your name in chat, in the
# inspect popup and on the Arena board.
#
# Because they stack, each is small and they are spread across six
# stats, so a full set lifts everything a little rather than one
# stat enormously.
#
# LIST: id -> {
#   name    what it reads as
#   tier    0 Common ... 6 Heaven-Defying (ItemDB.GRADE_NAMES)
#   stat    which stat it lifts (a Gear bonus key)
#   how     the line shown under it in the Codex
#   track   a progress counter, with `goal`; omitted when server-granted
#   goal    the number that earns it
#   server  true = only the server can grant it (placements, testers)
#   days    how long it lasts before lapsing; absent = kept for good
# }
#
# ON EXPIRY. A title only really expires if the thing that earned it
# can stop being true. Standings can: you held rank one last week and
# this week you do not, so those run out. A streak can: miss a day and
# it is gone. But "cleared stage 500" cannot go back to being false,
# so putting a clock on it would do nothing except re-grant it a
# moment later. Those are kept, and are the reason `days` is optional
# rather than a number on every line.
#
# Local titles renew themselves: refresh() pushes the clock forward
# every time it sees the condition still holding, so a title lapses
# only once you stop meeting it.
# =========================================================

## Banner art, by title id. Falls back to a drawn plate.
const ART_DIR := "res://assets/ui/titles/"

## Set by the dev cheat that grants everything. While it is on, a
## server sync stops taking server-held titles away — otherwise the
## Arena and tester ones would be stripped the moment the Codex page
## refreshed, seconds after unlocking them. Session only: never
## saved, and gone on the next launch.
static var dev_all_unlocked := false

## What each tier is worth, as a percentage. Small on purpose.
const TIER_BONUS := [0.5, 1.0, 1.5, 2.5, 4.0, 6.0, 10.0]

const LIST := {
	# --- Arena -------------------------------------------------
	"arena_challenger": {"name": "Arena Challenger", "tier": 0, "stat": "atk_pct",
		"track": "arena_fights", "goal": 1, "how": "Enter the Arena."},
	"arena_duelist": {"name": "Arena Duelist", "tier": 1, "stat": "atk_pct",
		"track": "arena_wins", "goal": 10, "how": "Win 10 duels."},
	"arena_veteran": {"name": "Arena Veteran", "tier": 2, "stat": "atk_pct",
		"track": "arena_wins", "goal": 100, "how": "Win 100 duels."},
	"arena_unfallen": {"name": "The Unfallen", "tier": 4, "stat": "crit",
		"server": true, "days": 7, "how": "Win 20 duels without a loss between them."},
	"arena_top_ten": {"name": "Among the Ten", "tier": 3, "stat": "crit",
		"server": true, "days": 7, "how": "Finish a week in your bracket's top ten."},
	"arena_champion": {"name": "Bracket Champion", "tier": 5, "stat": "atk_pct",
		"server": true, "days": 7, "how": "Finish a week at rank one."},
	"arena_sovereign": {"name": "Sovereign of the Ring", "tier": 6, "stat": "crit",
		"server": true, "days": 30, "how": "Hold rank one for three weeks running."},

	# --- Achievements ------------------------------------------
	"ach_diligent": {"name": "Diligent", "tier": 0, "stat": "crit_dmg",
		"track": "achievements", "goal": 10, "how": "Claim 10 achievements."},
	"ach_accomplished": {"name": "Accomplished", "tier": 2, "stat": "crit_dmg",
		"track": "achievements", "goal": 50, "how": "Claim 50 achievements."},
	"ach_completionist": {"name": "Completionist", "tier": 4, "stat": "hp_pct",
		"track": "achievements", "goal": 150, "how": "Claim 150 achievements."},
	"ach_ledger": {"name": "Heaven's Ledger", "tier": 6, "stat": "hp_pct",
		"track": "achievements", "goal": 300, "how": "Claim 300 achievements."},

	# --- Login -------------------------------------------------
	"login_returning": {"name": "Returning Disciple", "tier": 0, "stat": "mdef_pct",
		"track": "login_days", "goal": 7, "how": "Log in on 7 days."},
	"login_faithful": {"name": "The Faithful", "tier": 1, "stat": "mdef_pct",
		"track": "login_days", "goal": 30, "how": "Log in on 30 days."},
	"login_devoted": {"name": "Devoted Cultivator", "tier": 2, "stat": "hp_pct",
		"track": "login_days", "goal": 100, "how": "Log in on 100 days."},
	"login_vigil": {"name": "Unbroken Vigil", "tier": 3, "stat": "mdef_pct",
		"track": "login_streak", "goal": 30, "days": 2,
		"how": "Log in 30 days in a row. Lost when the streak breaks."},
	"login_eternal": {"name": "Eternal Presence", "tier": 5, "stat": "mdef_pct",
		"track": "login_days", "goal": 365, "how": "Log in on 365 days."},

	# --- Testing -----------------------------------------------
	"tester_alpha": {"name": "Alpha Tester", "tier": 6, "stat": "atk_pct",
		"server": true, "how": "Walked the path before it was paved."},
	"tester_beta": {"name": "Beta Tester", "tier": 5, "stat": "hp_pct",
		"server": true, "how": "Tempered the path for those who followed."},
	"founding": {"name": "Founding Cultivator", "tier": 6, "stat": "def_pct",
		"server": true, "how": "Among the first hundred to ascend."},

	# --- Progression -------------------------------------------
	"realm_foundation": {"name": "Foundation Builder", "tier": 0, "stat": "hp_pct",
		"track": "realm", "goal": 2, "how": "Reach Foundation Establishment."},
	"realm_core": {"name": "Core Formed", "tier": 1, "stat": "hp_pct",
		"track": "realm", "goal": 3, "how": "Reach Core Formation."},
	"realm_nascent": {"name": "Nascent Soul", "tier": 2, "stat": "def_pct",
		"track": "realm", "goal": 4, "how": "Reach Nascent Soul."},
	"realm_ascendant": {"name": "The Ascendant", "tier": 3, "stat": "def_pct",
		"track": "realm", "goal": 9, "how": "Reach Ascendant."},
	"realm_immortal": {"name": "Immortal Ascended", "tier": 5, "stat": "hp_pct",
		"track": "realm", "goal": 20, "how": "Reach the Immortal realms."},
	"stage_breaker": {"name": "Stage Breaker", "tier": 1, "stat": "atk_pct",
		"track": "stage", "goal": 500, "how": "Clear stage 500."},
	"stage_thousand": {"name": "Thousandfold", "tier": 2, "stat": "atk_pct",
		"track": "stage", "goal": 1000, "how": "Clear stage 1000."},
	"stage_veil": {"name": "Beyond the Veil", "tier": 4, "stat": "atk_pct",
		"track": "stage", "goal": 5000, "how": "Clear stage 5000."},

	# --- Collection --------------------------------------------
	"codex_collector": {"name": "Collector", "tier": 1, "stat": "def_pct",
		"track": "codex", "goal": 50, "how": "Record 50 Codex entries."},
	"codex_archivist": {"name": "Archivist", "tier": 2, "stat": "def_pct",
		"track": "codex", "goal": 150, "how": "Record 150 Codex entries."},
	"codex_keeper": {"name": "Keeper of Records", "tier": 6, "stat": "def_pct",
		"track": "codex", "goal": 200, "how": "Record every partner in the Codex."},
	"beast_tamer": {"name": "Beast Tamer", "tier": 1, "stat": "hp_pct",
		"track": "tamed", "goal": 20, "how": "Tame 20 spirit beasts."},
	"beast_soul_master": {"name": "Soul Master", "tier": 4, "stat": "hp_pct",
		"track": "tamed", "goal": 45, "how": "Tame all 45 spirit beasts."},

	# --- Sect --------------------------------------------------
	"sect_disciple": {"name": "Sect Disciple", "tier": 0, "stat": "def_pct",
		"server": true, "days": 30, "how": "Join a sect."},
	"sect_elder": {"name": "Sect Elder", "tier": 2, "stat": "def_pct",
		"server": true, "days": 30, "how": "Rise to Elder of your sect."},
	"sect_master": {"name": "Sect Master", "tier": 4, "stat": "hp_pct",
		"server": true, "days": 30, "how": "Lead a sect."},
	"sect_vanguard": {"name": "Trial Vanguard", "tier": 5, "stat": "crit",
		"server": true, "days": 7, "how": "Lead your sect's Trial contribution."},

	# --- Trials and gods ---------------------------------------
	"trial_daily": {"name": "Trialgoer", "tier": 0, "stat": "crit_dmg",
		"track": "daily_full", "goal": 1, "how": "Finish a full day of duties."},
	"trib_endurer": {"name": "Lightning Endurer", "tier": 2, "stat": "def_pct",
		"track": "tribulation", "goal": 1, "how": "Endure the heavens' lightning."},
	"god_slayer": {"name": "God Slayer", "tier": 4, "stat": "crit",
		"track": "fallen_god", "goal": 1, "how": "Strike down the Fallen God."},
	"god_defier": {"name": "Heaven Defier", "tier": 6, "stat": "crit",
		"server": true, "days": 30, "how": "Top the Fallen God ranking."},
	"forge_master": {"name": "Forge Master", "tier": 1, "stat": "atk_pct",
		"track": "refine", "goal": 50, "how": "Refine a piece to +50."},
	"alchemy_sage": {"name": "Alchemy Sage", "tier": 1, "stat": "crit_dmg",
		"track": "craft", "goal": 100, "how": "Brew 100 pills."},
	"expedition_lead": {"name": "Expedition Leader", "tier": 1, "stat": "mdef_pct",
		"track": "expeditions", "goal": 50, "how": "Complete 50 expeditions."},
	"summon_fated": {"name": "Fate-Touched", "tier": 2, "stat": "crit",
		"track": "summons", "goal": 300, "how": "Call on fate 300 times."},
	"evolve_first": {"name": "Awakener", "tier": 3, "stat": "atk_pct",
		"track": "evolved", "goal": 1, "how": "Evolve a Premium Red."},
	"evolve_prismatic": {"name": "Prismatic Sovereign", "tier": 6, "stat": "atk_pct",
		"track": "prismatic", "goal": 1, "how": "Raise a partner to Prismatic."},
}


# ---------------------------------------------------------
# LOOKING THINGS UP
# ---------------------------------------------------------

static func get_title(id: String) -> Dictionary:
	return LIST.get(id, {})


static func title_name(id: String) -> String:
	var t: Dictionary = LIST.get(id, {})
	return str(t.get("name", id))


static func tier_of(id: String) -> int:
	var t: Dictionary = LIST.get(id, {})
	return clampi(int(t.get("tier", 0)), 0, ItemDB.GRADE_COLORS.size() - 1)


static func colour_of(id: String) -> Color:
	return ItemDB.grade_color(tier_of(id))


static func tier_name(id: String) -> String:
	return ItemDB.grade_name(tier_of(id))


## The banner behind the name. Its own art if that exists, otherwise
## the frame for its tier, otherwise null and the Codex draws a plain
## plate.
##
## The tier frames are what make this shippable: seven images dress
## all forty-six, and a title that later gets art of its own picks it
## up without anything being rewired.
static func art_of(id: String) -> Texture2D:
	var path := ART_DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var tier_path := ART_DIR + "tier_%d.png" % tier_of(id)
	return load(tier_path) as Texture2D if ResourceLoader.exists(tier_path) else null


static func bonus_text(id: String) -> String:
	var t: Dictionary = LIST.get(id, {})
	var stat := str(t.get("stat", "atk_pct"))
	var label: String = Gear.STAT_NAMES.get(stat, stat)
	return "+%s%% %s" % [_num(TIER_BONUS[tier_of(id)]), label]


static func _num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")


# ---------------------------------------------------------
# OWNING AND WEARING
# ---------------------------------------------------------

## When a held title lapses, as a unix time. 0 = never.
static func expires_at(id: String) -> int:
	return int(GameState.titles_owned.get(id, 0))


static func owns(id: String) -> bool:
	if not GameState.titles_owned.has(id):
		return false
	var until := expires_at(id)
	return until <= 0 or until > int(Time.get_unix_time_from_system())


## How long a title has left, for the Codex ("6 days left"). "" when
## it is kept for good or already gone.
static func remaining_text(id: String) -> String:
	var until := expires_at(id)
	if until <= 0 or not owns(id):
		return ""
	var left := until - int(Time.get_unix_time_from_system())
	if left >= 172800:
		return "%d days left" % int(left / 86400.0)
	if left >= 7200:
		return "%d hours left" % int(left / 3600.0)
	return "less than an hour left"


static func owned_ids() -> Array:
	var out: Array = []
	for id in LIST:
		if owns(str(id)):
			out.append(str(id))
	return out


## Drops anything that has run out. Returns the ids that lapsed.
static func prune() -> Array:
	var gone: Array = []
	for id in GameState.titles_owned.keys():
		var key := str(id)
		if not owns(key):
			GameState.titles_owned.erase(key)
			gone.append(key)
	if not gone.is_empty():
		if gone.has(str(GameState.title_worn)):
			GameState.title_worn = ""
		refresh_bonus()
	return gone


static func worn() -> String:
	var id := str(GameState.title_worn)
	return id if id != "" and owns(id) else ""


## Wears a title, or clears it with "". Only one shows at a time.
##
## The profile goes up at once rather than waiting for the next cloud
## save. A message carries the sender's title stamped on at the moment
## it is sent, so anything said in the minute after changing it would
## otherwise go out under the old one and stay that way.
static func wear(id: String) -> void:
	if id != "" and not owns(id):
		return
	GameState.title_worn = id
	GameState.save_game()
	GameState.titles_changed.emit()
	if Backend.is_configured():
		Backend.update_profile()


# ---------------------------------------------------------
# EARNING
# ---------------------------------------------------------

## How far along a title is. Server-granted ones report 0 until they
## arrive, since nothing local can measure them.
static func progress(id: String) -> int:
	var t: Dictionary = LIST.get(id, {})
	if bool(t.get("server", false)) or not t.has("track"):
		return 1 if owns(id) else 0
	return _progress(str(t["track"]))


static func goal(id: String) -> int:
	var t: Dictionary = LIST.get(id, {})
	return int(t.get("goal", 1))


static func _progress(track: String) -> int:
	match track:
		"achievements":
			return GameState.claimed_achievements.size()
		"login_streak":
			return int(GameState.login_streak)
		"evolved":
			return int(GameState.stats.get("evolved", 0))
		"prismatic":
			var n := 0
			for p in GameState.roster:
				if p != null:
					var data = p.get_data()
					if data != null and int(data.rarity) == int(Enums.Rarity.PRISMATIC):
						n += 1
			return n
		_:
			# Everything else is a counter the achievements already
			# understand, which falls through to GameState.stats.
			return Achievements.progress(track)


## When a title earned now would lapse. 0 for the ones kept for good.
static func _until(id: String) -> int:
	var t: Dictionary = LIST.get(id, {})
	if not t.has("days"):
		return 0
	return int(Time.get_unix_time_from_system()) + int(t["days"]) * 86400


## Grants any local title whose condition is met, and pushes the clock
## forward on the ones still being met. Clears anything that has run
## out. Returns the ids that were newly earned.
static func refresh() -> Array:
	var fresh: Array = []
	var touched := not prune().is_empty()
	for id in LIST:
		var key := str(id)
		var t: Dictionary = LIST[key]
		if bool(t.get("server", false)) or not t.has("track"):
			continue
		if _progress(str(t["track"])) < int(t.get("goal", 1)):
			continue
		var held := owns(key)
		if held and not t.has("days"):
			continue
		# Still earning it, so the clock starts again from now.
		GameState.titles_owned[key] = _until(key)
		touched = true
		if not held:
			fresh.append(key)
	if touched:
		refresh_bonus()
		GameState.save_game()
		GameState.titles_changed.emit()
	return fresh


## Grants a title the server says the player has earned. `until` is a
## unix time, or 0 to keep it for good; left out, the title's own
## `days` decides. Returns true if it is new to them.
static func grant(id: String, until := -1) -> bool:
	if not LIST.has(id):
		return false
	var was := owns(id)
	GameState.titles_owned[id] = _until(id) if until < 0 else until
	refresh_bonus()
	GameState.save_game()
	GameState.titles_changed.emit()
	return not was


## Replaces the server-held set with what the server just said, so a
## placement that has run out there stops counting here too. Rows are
## {id, expires} or plain ids. Returns the ids that are new.
static func sync_server(rows: Array) -> Array:
	var sent := {}
	for row in rows:
		if row is Dictionary:
			var id := str(row.get("id", ""))
			if LIST.has(id):
				sent[id] = int(row.get("expires", 0))
		elif LIST.has(str(row)):
			sent[str(row)] = 0

	var fresh: Array = []
	for id in LIST:
		var key := str(id)
		if not bool(LIST[key].get("server", false)):
			continue
		if sent.has(key):
			if not owns(key):
				fresh.append(key)
			GameState.titles_owned[key] = int(sent[key])
		elif not dev_all_unlocked:
			GameState.titles_owned.erase(key)
	if GameState.title_worn != "" and not owns(str(GameState.title_worn)):
		GameState.title_worn = ""
	refresh_bonus()
	GameState.save_game()
	GameState.titles_changed.emit()
	return fresh


# ---------------------------------------------------------
# THE BONUS
# ---------------------------------------------------------

## Every owned title added up, by stat. Cached in GameState.title_bonus
## because _gear() reads it on every stat lookup.
static func totals() -> Dictionary:
	var out := {}
	for id in GameState.titles_owned:
		var key := str(id)
		var t: Dictionary = LIST.get(key, {})
		# owns() rather than mere presence: a lapsed title is still in
		# the dictionary until something prunes it, and it must not
		# keep paying out in the meantime.
		if t.is_empty() or not owns(key):
			continue
		var stat := str(t.get("stat", "atk_pct"))
		out[stat] = float(out.get(stat, 0.0)) + TIER_BONUS[tier_of(key)]
	return out


static func refresh_bonus() -> void:
	GameState.title_bonus = totals()
