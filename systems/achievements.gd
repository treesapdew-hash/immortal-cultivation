class_name Achievements

# =========================================================
# Achievements as endless tier chains. Save as
#   res://systems/achievements.gd
#
# Each chain watches one thing (stage, forges, summons...).
# Only its next unclaimed tier is shown. Claiming it rolls
# the chain on to the next tier with a bigger goal.
#
# The handwritten tiers come first (generous early, since a
# new player has no Jade, no pulls and no gear). After the
# last one the chain keeps going on its own, using the
# chain's growth/step and "endless" rewards, until max_goal
# (0 = never ends).
#
# Tier ids are "<chain id>_<goal>", e.g. forge_20, forge_40.
# Claimed ids live in GameState.claimed_achievements, so saves
# from before tiers still count.
# Counters live in GameState.stats (see GameState.bump).
#
# Rewards can hold:
#   "jade", "stones", "qi", items by id,
#   "card": tier        -- a random partner of that tier
#   "card_choice": tier -- pick one of several partners of that tier
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

## Endless tiers: item, Stone and Qi rewards grow by this much
## per tier. Jade stays flat so the economy can't run away.
## Endless tiers never give Star-up Pills: those should come
## from salvage and duplicates, or stars get too cheap.
## Handwritten tiers cover roughly 35% of a full team's pills
## to 5 stars early, 17% to 10 stars mid-game and 7% to 15
## stars late (costs from owned_partner.gd).
const REWARD_GROWTH := 1.15

## Safety limit when walking a chain.
const MAX_SCAN := 500

## What a chain watches (track):
##   stage      highest stage reached
##   realm      MC's realm index (0-27)
##   summons    total summons
##   partners   partners owned
##   dungeon    best floor across all dungeons
##   craft      pills crafted
##   forge      artifacts forged
##   refine     highest refine level on any gear
##   stars      MC's stars
##   tamed          spirit beast species tamed
##   codex          partners discovered in the Codex
##   codex_sets     Codex collection sets completed
##   tribulation_best  best Tribulation Lightning wave
##   divinity       God Path Divinity Level
##   any GameState.stats counter: beast_hunts, fallen_god,
##     sect_trial, ads_watched, expeditions, login_days...
##
## Chain fields:
##   id          tier id prefix
##   name, desc  title and goal text for endless tiers (%s = goal)
##   growth      next goal = max(goal + step, goal x growth).
##   step        Goals above 1.0 growth are rounded to tidy numbers.
##   max_goal    last goal (0 = endless)
##   endless     rewards of the first endless tier
##   card_every  every Nth endless tier also gives a "card" of tier card
##   tiers       the handwritten tiers, in order
const CHAINS := [
	# --- stages ---
	{"id": "stage", "track": "stage", "name": "Endless Ascent", "desc": "Reach Stage %s",
		"growth": 1.2, "step": 250, "max_goal": 10000, "card_every": 4, "card": Enums.Rarity.PURPLE,
		"endless": {"jade": 3000, "stones": 100000, "lifebound_essence": 300},
		"tiers": [
			{"goal": 5, "name": "The Road Begins", "desc": "Reach Stage 5",
				"rewards": {"jade": 300, "starup_pill": 20}},
			{"goal": 10, "name": "First Steps", "desc": "Reach Stage 10",
				"rewards": {"jade": 500, "starup_pill": 30, "stones": 5000}},
			{"goal": 20, "name": "Finding Your Footing", "desc": "Reach Stage 20",
				"rewards": {"jade": 600, "starup_pill": 40}},
			{"goal": 30, "name": "Steady Climb", "desc": "Reach Stage 30",
				"rewards": {"jade": 700, "stones": 12000}},
			{"goal": 50, "name": "Hardened Cultivator", "desc": "Reach Stage 50",
				"rewards": {"jade": 900, "card": Enums.Rarity.GREEN, "starup_pill": 60}},
			{"goal": 75, "name": "No Turning Back", "desc": "Reach Stage 75",
				"rewards": {"jade": 900, "starup_pill": 80}},
			{"goal": 100, "name": "Century Climber", "desc": "Reach Stage 100",
				"rewards": {"jade": 1200, "card_choice": Enums.Rarity.PURPLE, "stones": 30000}},
			{"goal": 150, "name": "Rising Name", "desc": "Reach Stage 150",
				"rewards": {"jade": 1200, "starup_pill": 250}},
			{"goal": 200, "name": "Beyond the Foothills", "desc": "Reach Stage 200",
				"rewards": {"jade": 1500, "card": Enums.Rarity.PURPLE, "refining_ore": 200}},
			{"goal": 250, "name": "Unshaken", "desc": "Reach Stage 250",
				"rewards": {"jade": 1500, "starup_pill": 400}},
			{"goal": 300, "name": "Veteran of Three Hundred", "desc": "Reach Stage 300",
				"rewards": {"jade": 1800, "card": Enums.Rarity.PURPLE, "artifact_core": 150}},
			{"goal": 400, "name": "Cloudpiercer", "desc": "Reach Stage 400",
				"rewards": {"jade": 2000, "starup_pill": 700, "treasure_dust": 300}},
			{"goal": 500, "name": "Halfway to the Clouds", "desc": "Reach Stage 500",
				"rewards": {"jade": 2500, "card_choice": Enums.Rarity.RED, "artifact_core": 300}},
			{"goal": 650, "name": "Sky Wanderer", "desc": "Reach Stage 650",
				"rewards": {"jade": 2500, "starup_pill": 1500, "lifebound_essence": 400}},
			{"goal": 800, "name": "Storm Treader", "desc": "Reach Stage 800",
				"rewards": {"jade": 3000, "card": Enums.Rarity.PURPLE, "heavenly_ore": 100}},
			{"goal": 1000, "name": "One Thousand Trials", "desc": "Reach Stage 1,000",
				"rewards": {"jade": 4000, "card_choice": Enums.Rarity.RED, "lifebound_essence": 800}},
			{"goal": 1250, "name": "Unbroken", "desc": "Reach Stage 1,250",
				"rewards": {"jade": 4000, "artifact_core": 800, "heavenly_ore": 200}},
			{"goal": 1500, "name": "Peak of the Mortal Road", "desc": "Reach Stage 1,500",
				"rewards": {"jade": 6000, "card_choice": Enums.Rarity.RED, "starup_pill": 5000}},
		]},

	# --- cultivation ---
	{"id": "realm", "track": "realm", "name": "Path of Heaven", "desc": "",
		"growth": 1.0, "step": 1, "max_goal": 29,
		"endless": {"jade": 2000, "stones": 80000, "heavenly_ore": 60},
		"tiers": [
			{"goal": 1, "name": "Foundation Laid", "desc": "Break into Foundation Establishment",
				"rewards": {"jade": 400, "starup_pill": 40}},
			{"goal": 3, "name": "Nascent Soul", "desc": "Reach the Nascent Soul realm",
				"rewards": {"jade": 900, "stones": 20000}},
			{"goal": 6, "name": "Body Integration", "desc": "Reach the Body Integration realm",
				"rewards": {"jade": 1500, "card": Enums.Rarity.PURPLE}},
			{"goal": 9, "name": "Ascendant", "desc": "Step into the Spirit Realm",
				"rewards": {"jade": 3000, "card_choice": Enums.Rarity.RED}},
		]},

	# --- summoning ---
	{"id": "summon", "track": "summons", "name": "Weaver of Fate", "desc": "Summon %s times",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 1500, "stones": 60000},
		"tiers": [
			{"goal": 1, "name": "First Fate", "desc": "Summon once",
				"rewards": {"jade": 500, "starup_pill": 20}},
			{"goal": 10, "name": "Ten Threads of Fate", "desc": "Summon 10 times",
				"rewards": {"jade": 900, "starup_pill": 30}},
			{"goal": 50, "name": "Gathering Companions", "desc": "Summon 50 times",
				"rewards": {"jade": 1500, "card": Enums.Rarity.PURPLE}},
			{"goal": 200, "name": "Bound by Destiny", "desc": "Summon 200 times",
				"rewards": {"jade": 3000, "card": Enums.Rarity.RED}},
		]},

	# --- partners owned ---
	{"id": "partners", "track": "partners", "name": "Great Sect", "desc": "Own %s partners",
		"growth": 1.4, "step": 10, "max_goal": 200,
		"endless": {"jade": 800, "stones": 50000},
		"tiers": [
			{"goal": 5, "name": "A Small Sect", "desc": "Own 5 partners",
				"rewards": {"jade": 600, "starup_pill": 30}},
			{"goal": 15, "name": "A Growing Sect", "desc": "Own 15 partners",
				"rewards": {"jade": 1200, "stones": 40000}},
		]},

	# --- dungeons ---
	{"id": "dungeon", "track": "dungeon", "name": "Abyss Walker", "desc": "Reach floor %s in any dungeon",
		"growth": 1.0, "step": 10, "max_goal": 0,
		"endless": {"jade": 1200, "treasure_dust": 400},
		"tiers": [
			{"goal": 1, "name": "Into the Depths", "desc": "Clear a dungeon floor",
				"rewards": {"jade": 500, "starup_pill": 30}},
			{"goal": 10, "name": "Delver", "desc": "Reach floor 10 in any dungeon",
				"rewards": {"jade": 1000, "artifact_core": 200}},
			{"goal": 25, "name": "Deep Runner", "desc": "Reach floor 25 in any dungeon",
				"rewards": {"jade": 1800, "treasure_dust": 500, "heavenly_ore": 80}},
		]},

	# --- alchemy ---
	{"id": "craft", "track": "craft", "name": "Furnace Sage", "desc": "Craft %s pills",
		"growth": 2.0, "step": 50, "max_goal": 0,
		"endless": {"jade": 800, "stones": 50000},
		"tiers": [
			{"goal": 1, "name": "First Refinement", "desc": "Craft a pill",
				"rewards": {"jade": 400, "spirit_grass": 150}},
			{"goal": 50, "name": "Master of the Furnace", "desc": "Craft 50 pills",
				"rewards": {"jade": 1200, "stones": 40000}},
		]},

	# --- forging ---
	{"id": "forge", "track": "forge", "name": "Forge Master", "desc": "Forge %s artifacts",
		"growth": 2.0, "step": 20, "max_goal": 0,
		"endless": {"jade": 1200, "artifact_core": 400},
		"tiers": [
			{"goal": 1, "name": "First Forging", "desc": "Forge an artifact",
				"rewards": {"jade": 600, "artifact_core": 150}},
			{"goal": 20, "name": "Forge Master", "desc": "Forge 20 artifacts",
				"rewards": {"jade": 1800, "artifact_core": 500}},
		]},

	# --- refining ---
	{"id": "refine", "track": "refine", "name": "Honed Edge", "desc": "Refine a piece of gear to +%s",
		"growth": 1.0, "step": 10, "max_goal": 100,
		"endless": {"jade": 1500, "heavenly_ore": 150},
		"tiers": [
			{"goal": 10, "name": "Sharpened", "desc": "Refine a piece of gear to +10",
				"rewards": {"jade": 900, "refining_ore": 300}},
			{"goal": 30, "name": "Honed to Perfection", "desc": "Refine a piece of gear to +30",
				"rewards": {"jade": 2000, "heavenly_ore": 150}},
		]},

	# --- awakening ---
	{"id": "stars", "track": "stars", "name": "Starborn", "desc": "Awaken to %s stars",
		"growth": 1.0, "step": 1, "max_goal": 20,
		"endless": {"jade": 1500, "refining_ore": 300},
		"tiers": [
			{"goal": 5, "name": "Five Stars", "desc": "Awaken to 5 stars",
				"rewards": {"jade": 1500, "starup_pill": 300}},
		]},

	# --- spirit beasts ---
	{"id": "hunts", "track": "beast_hunts", "name": "Beast Hunter", "desc": "Win %s Beast Forest hunts",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 1000, "beast_core": 200},
		"tiers": [
			{"goal": 1, "name": "First Hunt", "desc": "Win a Beast Forest hunt",
				"rewards": {"jade": 200, "beast_core": 30}},
			{"goal": 10, "name": "Tracker", "desc": "Win 10 Beast Forest hunts",
				"rewards": {"jade": 400, "beast_core": 100}},
			{"goal": 50, "name": "Forest Stalker", "desc": "Win 50 Beast Forest hunts",
				"rewards": {"jade": 800, "summon_scroll": 1}},
			{"goal": 150, "name": "Terror of the Wilds", "desc": "Win 150 Beast Forest hunts",
				"rewards": {"jade": 1500, "card_choice": Enums.Rarity.PURPLE}},
		]},
	{"id": "tamed", "track": "tamed", "name": "Spirit Tamer", "desc": "Tame %s kinds of spirit beast",
		"growth": 1.0, "step": 5, "max_goal": 45,
		"endless": {"jade": 1500, "beast_core": 300},
		"tiers": [
			{"goal": 1, "name": "A Bond Is Formed", "desc": "Tame your first spirit beast",
				"rewards": {"jade": 300, "beast_core": 50}},
			{"goal": 5, "name": "Beast Friend", "desc": "Tame 5 kinds of spirit beast",
				"rewards": {"jade": 600, "beast_core": 150}},
			{"goal": 15, "name": "Keeper of Spirits", "desc": "Tame 15 kinds of spirit beast",
				"rewards": {"jade": 1200, "summon_scroll": 2}},
			{"goal": 30, "name": "Lord of Beasts", "desc": "Tame 30 kinds of spirit beast",
				"rewards": {"jade": 2500, "card_choice": Enums.Rarity.RED}},
		]},

	# --- codex ---
	{"id": "codex", "track": "codex", "name": "Chronicler", "desc": "Discover %s partners",
		"growth": 1.0, "step": 25, "max_goal": 200,
		"endless": {"jade": 1500, "summon_scroll": 1},
		"tiers": [
			{"goal": 10, "name": "Curious Mind", "desc": "Discover 10 partners in the Codex",
				"rewards": {"jade": 300}},
			{"goal": 25, "name": "Record Keeper", "desc": "Discover 25 partners in the Codex",
				"rewards": {"jade": 600, "summon_scroll": 1}},
			{"goal": 50, "name": "Archivist", "desc": "Discover 50 partners in the Codex",
				"rewards": {"jade": 1200, "summon_scroll": 2}},
			{"goal": 100, "name": "Keeper of Legends", "desc": "Discover 100 partners in the Codex",
				"rewards": {"jade": 2500, "card_choice": Enums.Rarity.RED}},
		]},
	{"id": "sets", "track": "codex_sets", "name": "Collector of Legends", "desc": "Complete %s Codex sets",
		"growth": 1.0, "step": 5, "max_goal": 0,
		"endless": {"jade": 1500, "stones": 60000},
		"tiers": [
			{"goal": 1, "name": "A Set Complete", "desc": "Complete a Codex collection set",
				"rewards": {"jade": 500}},
			{"goal": 5, "name": "Dedicated Collector", "desc": "Complete 5 Codex sets",
				"rewards": {"jade": 1000, "summon_scroll": 1}},
			{"goal": 15, "name": "Grand Collector", "desc": "Complete 15 Codex sets",
				"rewards": {"jade": 2000, "card_choice": Enums.Rarity.PURPLE}},
		]},

	# --- the heavens ---
	{"id": "tribulation", "track": "tribulation_best", "name": "Lightning Walker", "desc": "Survive wave %s of Tribulation Lightning",
		"growth": 1.0, "step": 10, "max_goal": 100,
		"endless": {"jade": 1200, "stones": 50000},
		"tiers": [
			{"goal": 5, "name": "Struck but Standing", "desc": "Survive wave 5 of Tribulation Lightning",
				"rewards": {"jade": 400}},
			{"goal": 10, "name": "First Great Tribulation", "desc": "Survive wave 10 of Tribulation Lightning",
				"rewards": {"jade": 800, "stones": 20000}},
			{"goal": 30, "name": "Heaven's Defiance", "desc": "Survive wave 30 of Tribulation Lightning",
				"rewards": {"jade": 2000, "card_choice": Enums.Rarity.PURPLE}},
		]},
	{"id": "divinity", "track": "divinity", "name": "Rising Divinity", "desc": "Reach Divinity Level %s",
		"growth": 1.0, "step": 10, "max_goal": 100,
		"endless": {"jade": 1500, "divinity_essence": 100},
		"tiers": [
			{"goal": 5, "name": "Touched by the Divine", "desc": "Reach Divinity Level 5",
				"rewards": {"jade": 500, "divinity_essence": 50}},
			{"goal": 10, "name": "Divine Vessel", "desc": "Reach Divinity Level 10",
				"rewards": {"jade": 1000, "divinity_essence": 100}},
		]},
	{"id": "fallen", "track": "fallen_god", "name": "God Slayer", "desc": "Attack the Fallen God %s times",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 1000, "divinity_essence": 80},
		"tiers": [
			{"goal": 1, "name": "Facing a God", "desc": "Attack the Fallen God",
				"rewards": {"jade": 300, "divinity_essence": 30}},
			{"goal": 20, "name": "Unafraid", "desc": "Attack the Fallen God 20 times",
				"rewards": {"jade": 800, "divinity_essence": 80}},
			{"goal": 100, "name": "Bane of the Fallen", "desc": "Attack the Fallen God 100 times",
				"rewards": {"jade": 2000, "card_choice": Enums.Rarity.PURPLE}},
		]},

	# --- sect ---
	{"id": "sect_trial", "track": "sect_trial", "name": "Pillar of the Sect", "desc": "Attack in the Sect Trial %s times",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 1000, "beast_core": 150},
		"tiers": [
			{"goal": 1, "name": "For the Sect", "desc": "Attack in the Sect Trial",
				"rewards": {"jade": 300}},
			{"goal": 30, "name": "Loyal Disciple", "desc": "Attack in the Sect Trial 30 times",
				"rewards": {"jade": 800, "summon_scroll": 1}},
			{"goal": 150, "name": "Sect Pillar", "desc": "Attack in the Sect Trial 150 times",
				"rewards": {"jade": 2000, "card_choice": Enums.Rarity.PURPLE}},
		]},

	# --- daily life ---
	{"id": "expeditions", "track": "expeditions", "name": "Wanderer", "desc": "Send %s expeditions",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 800, "stones": 40000},
		"tiers": [
			{"goal": 1, "name": "Into the Unknown", "desc": "Send an expedition",
				"rewards": {"jade": 200}},
			{"goal": 25, "name": "Seasoned Explorer", "desc": "Send 25 expeditions",
				"rewards": {"jade": 600, "stones": 20000}},
			{"goal": 100, "name": "Pathfinder", "desc": "Send 100 expeditions",
				"rewards": {"jade": 1500, "summon_scroll": 1}},
		]},
	{"id": "login", "track": "login_days", "name": "Devoted Cultivator", "desc": "Log in on %s days",
		"growth": 1.0, "step": 60, "max_goal": 0,
		"endless": {"jade": 1500, "summon_scroll": 1},
		"tiers": [
			{"goal": 3, "name": "Returning Cultivator", "desc": "Log in on 3 days",
				"rewards": {"jade": 300}},
			{"goal": 7, "name": "A Week of Practice", "desc": "Log in on 7 days",
				"rewards": {"jade": 700, "summon_scroll": 1}},
			{"goal": 30, "name": "A Month on the Path", "desc": "Log in on 30 days",
				"rewards": {"jade": 2000, "card_choice": Enums.Rarity.PURPLE}},
			{"goal": 100, "name": "Hundred-Day Devotion", "desc": "Log in on 100 days",
				"rewards": {"jade": 4000, "card_choice": Enums.Rarity.RED}},
		]},
	{"id": "ads", "track": "ads_watched", "name": "Heaven's Favour", "desc": "Receive %s heavenly gifts",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 600, "beast_core": 100},
		"tiers": [
			{"goal": 5, "name": "Blessed", "desc": "Receive 5 heavenly gifts from ads",
				"rewards": {"jade": 200}},
			{"goal": 50, "name": "Favoured by Heaven", "desc": "Receive 50 heavenly gifts from ads",
				"rewards": {"jade": 600, "summon_scroll": 1}},
			{"goal": 200, "name": "Heaven's Chosen", "desc": "Receive 200 heavenly gifts from ads",
				"rewards": {"jade": 1500, "card_choice": Enums.Rarity.PURPLE}},
		]},
	# --- arena ---
	{"id": "arena_fights", "track": "arena_fights", "name": "Trial by Combat", "desc": "Duel %s times",
		"growth": 1.5, "step": 100, "max_goal": 0,
		"endless": {"jade": 500, "arena_token": 150},
		"tiers": [
			{"goal": 1, "name": "First Blood", "desc": "Fight your first Arena duel",
				"rewards": {"arena_token": 50}},
			{"goal": 25, "name": "Contender", "desc": "Fight 25 Arena duels",
				"rewards": {"jade": 300, "arena_token": 150}},
			{"goal": 100, "name": "Veteran of the Ring", "desc": "Fight 100 Arena duels",
				"rewards": {"jade": 800, "arena_token": 400}},
			{"goal": 300, "name": "Undying Challenger", "desc": "Fight 300 Arena duels",
				"rewards": {"jade": 1500, "arena_token": 900, "card_choice": Enums.Rarity.PURPLE}},
		]},
	{"id": "arena_wins", "track": "arena_wins", "name": "Unbroken", "desc": "Win %s duels",
		"growth": 1.5, "step": 50, "max_goal": 0,
		"endless": {"jade": 800, "arena_token": 250},
		"tiers": [
			{"goal": 1, "name": "First Victory", "desc": "Win an Arena duel",
				"rewards": {"jade": 200, "arena_token": 80}},
			{"goal": 10, "name": "Rising Name", "desc": "Win 10 Arena duels",
				"rewards": {"jade": 500, "arena_token": 200}},
			{"goal": 50, "name": "Feared in the Ring", "desc": "Win 50 Arena duels",
				"rewards": {"jade": 1200, "arena_token": 600, "summon_scroll": 3}},
			{"goal": 150, "name": "Realm Champion", "desc": "Win 150 Arena duels",
				"rewards": {"jade": 2500, "arena_token": 1500, "card_choice": Enums.Rarity.RED}},
		]},
]


# ---------------------------------------------------------
# CHAINS AND TIERS
# ---------------------------------------------------------

static func get_chain(chain_id: String) -> Dictionary:
	for chain in CHAINS:
		if chain["id"] == chain_id:
			return chain
	return {}


## The tier at a position in a chain, or {} past the chain's end.
## Returned keys: id, chain, index, track, goal, name, desc, rewards.
static func get_tier(chain: Dictionary, index: int) -> Dictionary:
	var goal := _goal_at(chain, index)
	var max_goal := int(chain.get("max_goal", 0))
	if max_goal > 0 and goal > max_goal:
		return {}
	var t := {
		"id": "%s_%d" % [chain["id"], goal],
		"chain": str(chain["id"]),
		"index": index,
		"track": str(chain["track"]),
		"goal": goal,
	}
	var tiers: Array = chain["tiers"]
	if index < tiers.size():
		var hand: Dictionary = tiers[index]
		t["name"] = str(hand["name"])
		t["desc"] = str(hand["desc"])
		t["rewards"] = hand["rewards"]
	else:
		var endless_n := index - tiers.size() + 1
		t["name"] = str(chain["name"])
		t["desc"] = _endless_desc(chain, goal)
		t["rewards"] = _endless_rewards(chain, endless_n)
	return t


## Finds a tier by id ("forge_40"), or {}.
static func get_def(id: String) -> Dictionary:
	var cut := id.rfind("_")
	if cut <= 0:
		return {}
	var chain := get_chain(id.substr(0, cut))
	if chain.is_empty():
		return {}
	var goal := id.substr(cut + 1).to_int()
	for i in MAX_SCAN:
		var t := get_tier(chain, i)
		if t.is_empty() or int(t["goal"]) > goal:
			return {}
		if int(t["goal"]) == goal:
			return t
	return {}


## Position of the chain's first unclaimed tier, or -1 when it's finished.
static func current_index(chain: Dictionary) -> int:
	for i in MAX_SCAN:
		var t := get_tier(chain, i)
		if t.is_empty():
			return -1
		if not is_claimed(t):
			return i
	return -1


## The next unclaimed tier of every unfinished chain.
static func current() -> Array:
	var out: Array = []
	for chain in CHAINS:
		var i := current_index(chain)
		if i >= 0:
			out.append(get_tier(chain, i))
	return out


## Number of tiers in a chain, or 0 if it never ends.
static func tier_count(chain: Dictionary) -> int:
	if int(chain.get("max_goal", 0)) <= 0:
		return 0
	for i in MAX_SCAN:
		if get_tier(chain, i).is_empty():
			return i
	return MAX_SCAN


## "Tier 4 / 12", or "Tier 19" for endless chains.
static func tier_label(t: Dictionary) -> String:
	var total := tier_count(get_chain(str(t["chain"])))
	if total > 0:
		return "Tier %d / %d" % [int(t["index"]) + 1, total]
	return "Tier %d" % (int(t["index"]) + 1)


## How many tiers in a row are done and waiting in one chain.
static func ready_in_chain(chain: Dictionary) -> int:
	var n := 0
	var start := current_index(chain)
	if start < 0:
		return 0
	for i in range(start, start + MAX_SCAN):
		var t := get_tier(chain, i)
		if t.is_empty() or not is_done(t):
			break
		if not is_claimed(t):
			n += 1
	return n


static func _goal_at(chain: Dictionary, index: int) -> int:
	var tiers: Array = chain["tiers"]
	if index < tiers.size():
		return int(tiers[index]["goal"])
	var goal := int(tiers[tiers.size() - 1]["goal"])
	for _i in range(tiers.size(), index + 1):
		goal = _next_goal(chain, goal)
	return goal


static func _next_goal(chain: Dictionary, goal: int) -> int:
	var step := int(chain.get("step", 1))
	var growth := float(chain.get("growth", 1.0))
	var next := maxi(goal + step, ceili(float(goal) * growth))
	if growth > 1.0:
		next = _round_up(next)
	var max_goal := int(chain.get("max_goal", 0))
	if max_goal > 0 and goal < max_goal:
		next = mini(next, max_goal)
	return maxi(next, goal + 1)


static func _endless_desc(chain: Dictionary, goal: int) -> String:
	if str(chain["track"]) == "realm":
		var realm: String = Realms.get_label(goal, 1)
		return "Reach %s" % realm
	return str(chain["desc"]) % _commas(goal)


static func _endless_rewards(chain: Dictionary, endless_n: int) -> Dictionary:
	var base: Dictionary = chain["endless"]
	var mult := pow(REWARD_GROWTH, float(endless_n - 1))
	var out := {}
	for key in base:
		if key == "jade":
			out[key] = int(base[key])
		else:
			out[key] = _round_nearest(int(float(base[key]) * mult))
	var every := int(chain.get("card_every", 0))
	if every > 0 and endless_n % every == 0:
		out["card"] = int(chain["card"])
	return out


## Rounds up to a tidy goal: multiples of 5 under 100, then two
## significant figures (1,750 -> 1,800).
static func _round_up(n: int) -> int:
	if n < 100:
		return ceili(float(n) / 5.0) * 5
	var mag := int(pow(10.0, float(str(n).length() - 2)))
	return ceili(float(n) / float(mag)) * mag


## Rounds a reward to two significant figures.
static func _round_nearest(n: int) -> int:
	if n < 100:
		return n
	var mag := int(pow(10.0, float(str(n).length() - 2)))
	return roundi(float(n) / float(mag)) * mag


static func _commas(n: int) -> String:
	var digits := str(n)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


# ---------------------------------------------------------
# PROGRESS
# ---------------------------------------------------------

## Where a counter currently stands.
static func progress(track: String) -> int:
	match track:
		"stage":
			return maxi(GameState.highest_stage, GameState.current_stage)
		"realm":
			var mc := GameState.get_mc()
			return mc.realm_index if mc != null else 0
		"stars":
			var mc2 := GameState.get_mc()
			return mc2.stars if mc2 != null else 0
		"partners":
			return maxi(GameState.roster.size() - 1, 0)
		"dungeon":
			var best := 0
			for def in Dungeons.LIST:
				best = maxi(best, Dungeons.highest(def))
			return best
		"refine":
			var best_refine := 0
			for item in GameState.gear:
				best_refine = maxi(best_refine, int(item.get("refine", 0)))
			return best_refine
		"tamed":
			var n := 0
			for sp in Beasts.SPECIES:
				if Codex.beast_tamed(str(sp)):
					n += 1
			return n
		"codex":
			return GameState.codex_partners.size()
		"codex_sets":
			var done := 0
			for group in [Codex.partner_sets(), Codex.beast_sets(), Codex.treasure_sets()]:
				for set_info in group:
					if bool(set_info["done"]):
						done += 1
			return done
		"tribulation_best":
			return Tribulation.best()
		"divinity":
			return Gods.level()
		_:
			return int(GameState.stats.get(track, 0))


static func is_done(a: Dictionary) -> bool:
	return progress(str(a["track"])) >= int(a["goal"])


static func is_claimed(a: Dictionary) -> bool:
	return GameState.claimed_achievements.has(str(a["id"]))


## How many tiers are waiting to be claimed (for the tab's red dot).
static func claimable_count() -> int:
	var n := 0
	for chain in CHAINS:
		n += ready_in_chain(chain)
	return n


# ---------------------------------------------------------
# CLAIMING
# ---------------------------------------------------------

## Claims one tier. Returns what was given, or {} if it isn't ready.
static func claim(id: String) -> Dictionary:
	var a := get_def(id)
	if a.is_empty() or not is_done(a) or is_claimed(a):
		return {}
	var given := _give(a)
	GameState.save_game()
	GameState.achievements_changed.emit()
	return given


## Claims every finished tier, several per chain if the player
## raced ahead. Saves once at the end.
static func claim_all() -> Array:
	var claimed: Array = []
	for chain in CHAINS:
		for _i in MAX_SCAN:
			var index := current_index(chain)
			if index < 0:
				break
			var t := get_tier(chain, index)
			if not is_done(t):
				break
			claimed.append({"achievement": t, "got": _give(t)})
	if not claimed.is_empty():
		GameState.save_game()
		GameState.achievements_changed.emit()
	return claimed


## Marks a tier claimed and hands out its rewards (no save).
static func _give(a: Dictionary) -> Dictionary:
	GameState.claimed_achievements.append(str(a["id"]))

	var rewards: Dictionary = a["rewards"]
	var items := {}
	var given := {}
	for key in rewards:
		match key:
			"jade":
				GameState.add_immortal_jade(int(rewards[key]))
				given["jade"] = int(rewards[key])
			"stones":
				GameState.add_spirit_stones(int(rewards[key]))
				given["stones"] = int(rewards[key])
			"qi":
				GameState.add_qi(int(rewards[key]))
				given["qi"] = int(rewards[key])
			"card":
				var partner := _give_card(int(rewards[key]))
				if partner != "":
					given["card"] = partner
			"card_choice":
				var options := card_options(int(rewards[key]))
				if not options.is_empty():
					GameState.pending_card_choices.append({
						"tier": int(rewards[key]), "options": options, "from": str(a["name"])})
					given["card_choice"] = int(rewards[key])
			_:
				items[key] = int(rewards[key])
	if not items.is_empty():
		GameState.add_items(items)
		given["items"] = items
	return given


# ---------------------------------------------------------
# PARTNER CARDS
# ---------------------------------------------------------

## How many partners a choice offers.
const CHOICE_SIZE := 4


## The partners offered by a card choice of this tier.
static func card_options(tier: int) -> Array:
	var pool: Array = PartnerDatabase.get_by_rarity(tier)
	if pool.is_empty():
		for lower in range(tier - 1, -1, -1):
			pool = PartnerDatabase.get_by_rarity(lower)
			if not pool.is_empty():
				break
	if pool.is_empty():
		return []
	var ids: Array = []
	for data in pool:
		# Premium Reds only come from Premium Selection Scrolls
		if not SummonSystem.is_premium(str(data.partner_id)):
			ids.append(str(data.partner_id))
	ids.shuffle()
	return ids.slice(0, mini(CHOICE_SIZE, ids.size()))


## Takes the chosen card from a pending choice.
static func choose_card(index: int, partner_id: String) -> bool:
	if index < 0 or index >= GameState.pending_card_choices.size():
		return false
	var choice: Dictionary = GameState.pending_card_choices[index]
	if not partner_id in choice["options"]:
		return false
	GameState.add_partner(partner_id)
	GameState.pending_card_choices.remove_at(index)
	GameState.save_game()
	GameState.achievements_changed.emit()
	return true


## A random partner card of a tier. Returns the partner id.
static func _give_card(tier: int) -> String:
	var pool: Array = PartnerDatabase.get_by_rarity(tier)
	if pool.is_empty():
		# Nothing at that tier yet: hand out the best lower tier instead
		for lower in range(tier - 1, -1, -1):
			pool = PartnerDatabase.get_by_rarity(lower)
			if not pool.is_empty():
				break
	if pool.is_empty():
		return ""
	var pick = pool.pick_random()
	GameState.add_partner(pick.partner_id)
	return str(pick.partner_id)
