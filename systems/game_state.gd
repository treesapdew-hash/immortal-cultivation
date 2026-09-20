extends Node

# =========================================================
# AUTOLOAD. Register in Project Settings as "GameState".
#
# Everything the player owns and has progressed. This is the
# save file.
#
# The Main Character (MC) is roster[0] and always sits in
# formation slot 0. The account's realm IS the MC's realm.
# The MC's tier (White ... Prismatic) follows its stars.
# =========================================================


signal currency_changed
signal formation_changed
signal stage_changed
signal roster_changed
signal realm_changed
signal mc_changed        # MC created or renamed (new name, look or Dao)
signal gear_updated      # equipment added, removed, equipped or refined
signal treasures_updated # a treasure was gained, equipped or merged
signal artifacts_updated # an artifact was forged, equipped or tempered
signal lifebound_updated # a Lifebound Artifact changed
signal expeditions_updated # expeditions started, finished or rerolled
@warning_ignore("unused_signal")   # emitted by Mail, not in this file
signal mail_changed      # a message arrived or was claimed
signal achievements_changed  # a milestone was reached or claimed
signal titles_changed     # a title was earned, or a different one worn
signal array_changed      # Battle Array partners placed, removed or upgraded


const SAVE_PATH := "user://save_game.json"
const SAVE_VERSION := 2

const FORMATION_SIZE := 6
const MAX_STAGE := 10000

const MC_ID := "mc"
const MC_SLOT := 0

## MC art lives in res://assets/mc/<gender>_<dao>/
## Files can be named <gender>_<dao>_card.png or just card.png
const MC_ART_FOLDER := "res://assets/mc/"

## MC name rules, shared by character creation and rename.
const MC_NAME_MIN := 2
const MC_NAME_MAX := 12

## Immortal Jade per rename. The first rename is free.
const MC_RENAME_COST := 200

const MC_RANDOM_NAMES := {
	"male": [
		"Mo Tianxing", "Lu Changfeng", "Shen Yuheng", "Qin Wuya",
		"Gu Chenyuan", "Han Jue", "Yan Mingxu", "Zhao Lingfeng",
	],
	"female": [
		"Su Qingyi", "Liu Ruoxi", "Bai Lianyue", "Yun Shuang",
		"Lan Xiyao", "Mu Wanqing", "Xue Yining", "Hua Lingyu",
	],
}


# ---------------------------------------------------------
# MAIN CHARACTER
# ---------------------------------------------------------

var mc_name: String = "GAYEST MIN"
var mc_gender: String = "male"                 # "male" or "female"
var mc_path: Enums.Path = Enums.Path.SWORD     # locked after creation
var mc_rarity: Enums.Rarity = Enums.Rarity.WHITE

## How many times the MC has been renamed (first one is free).
var mc_rename_count: int = 0

## False until the player finishes character creation.
## The home screen shows the creation screen while this is false.
var mc_created: bool = false

# Old name kept so other scripts still work.
var player_name: String:
	get: return mc_name
	set(value): mc_name = value

## The account's cultivation = the MC's cultivation.
var realm_index: int:
	get: return get_mc().realm_index if get_mc() != null else 0
	set(value):
		if get_mc() != null:
			get_mc().realm_index = value

var tier: int:
	get: return get_mc().tier if get_mc() != null else 1
	set(value):
		if get_mc() != null:
			get_mc().tier = value


# ---------------------------------------------------------
# PROGRESS AND CURRENCY
# ---------------------------------------------------------

var highest_stage: int = 1
var current_stage: int = 1

var spirit_stones: int = 1000
var immortal_jade: int = 1000

## Earned by killing enemies; spent on breakthroughs.
var qi: int = 0

## Testing only: multiplies your team's stats in battle (see dev_cheats.gd).
var debug_power_mult := 1.0

## Artifacts (see Artifacts): {uid, trait, grade, owner, locked}
var artifacts: Array = []
var next_artifact_uid: int = 1

## Lifebound Artifacts (see Lifebound): partner id -> {grade, stars, lines}
var lifebound: Dictionary = {}
## Unbonded Lifebound Seeds: stars -> count
var lifebound_seeds: Dictionary = {}

## Secret Realm expeditions (see Expeditions)
var expeditions: Array = []
var expedition_offers: Array = []

## Treasures (see Treasures). Each is a Dictionary with a unique "uid".
var treasures: Array = []
var next_treasure_uid: int = 1

## Equipment pieces (see Gear). Each is a Dictionary with a unique "uid".
var gear: Array = []
var next_gear_uid: int = 1

## A boss stage that defeated you. You drop back a stage and can
## challenge it again from the battle area. 0 = none pending.
var pending_boss: int = 0

## Counters for achievements: summons, craft, forge and so on.
var stats: Dictionary = {}
## Milestones already claimed (see Achievements).
var claimed_achievements: Array = []
## Titles earned (see Titles): {id: expiry unix, 0 = kept for good}.
## Every one still in date adds its bonus.
var titles_owned: Dictionary = {}
## The title shown beside your name, or "" for none.
var title_worn: String = ""
## Days logged in back to back, and the day the streak last counted.
## Missing a day sends the streak back to 1.
var login_streak: int = 0
var login_streak_day: int = 0
## Card choices waiting to be picked: [{tier, options, from}]
var pending_card_choices: Array = []
## Daily and weekly missions (see Missions): reset days, stat
## snapshots, claimed missions and opened chests.
var missions: Dictionary = {}
## Battle Array (see BattleArray): upgrade level, and the partner id
## in each unlocked slot ("" = empty). Ids, not roster indices, so
## salvaging other partners never shifts them.
var array_level: int = 1
var battle_array: Array = []
## Daily Rotating Trial (see Trials): {day, used, best: {trial id: tier}}.
var trials: Dictionary = {}
## Tribulation Lightning (see Tribulation): {day, done, best}.
var tribulation: Dictionary = {}
## God Path (see Gods): {level, exp, active}.
var gods: Dictionary = {}
## Fate Points from summoning (see SummonSystem): spent on featured Reds.
var fate_points: int = 0
## Descent of the Fallen God (see FallenGod): attacks, best, rank reward.
var fallen_god: Dictionary = {}
## Spirit rings (see Beasts): every ring owned, in a spirit or not.
var beast_rings: Array = []
## Tamed Soul Spirits: [{uid, species, partner}].
var soul_spirits: Array = []
## Beast Codex: {species: {slain, tamed}}.
var beast_codex: Dictionary = {}
## Codex (see Codex): every partner and treasure ever found.
var codex_partners: Dictionary = {}
var codex_treasures: Dictionary = {}
## Sect Research bonus for every partner (see Sects.refresh_bonus),
## kept locally so it also applies offline.
var sect_bonus: Dictionary = {}

## Path Resonance for the current formation (see Paths). Cached
## rather than recomputed, because _gear() runs on every stat read.
## Rebuilt by refresh_path_bonus() whenever the formation changes.
var path_bonus: Dictionary = {}
## Every earned title added up (see Titles). Cached for the same
## reason; rebuilt by Titles.refresh_bonus().
var title_bonus: Dictionary = {}
## Sect Shop weekly purchases: {week, bought {item: count}}.
var sect_shop: Dictionary = {}
## Unlocked features already announced (see Unlocks).
var unlocks_seen: Dictionary = {}
## The very first summon is guaranteed Purple or better.
var first_summon_done := false
## Tutorials already shown (see Tutorial).
var tutorials_done: Dictionary = {}
## Tutorials started but not finished, and the step each was on:
## they resume on the next launch (see Tutorial.resume).
var tutorials_pending: Array = []
var tutorial_step: Dictionary = {}
## Rewarded ads watched today, per placement (see Ads).
var ads_state: Dictionary = {}
## Beast Forest: {day, used, refreshes}.
var beast_forest: Dictionary = {}

## Mailbox (see Mail) and the day rankings were last paid out.
var mail: Array = []
var next_mail_id: int = 1
var ranking_day: int = 0

## Dungeons: highest floor cleared, and entries used today.
var dungeon_progress: Dictionary = {}
var dungeon_entries: Dictionary = {}
var dungeon_day: int = 0

## Jade packs bought at least once (for the first-purchase bonus).
var bought_packs: Array[String] = []

## Pill recipes the player has bought (target realm indices).
var known_recipes: Array[int] = []

## Shop daily stock: which day it's for, and how many of each offer were bought.
var shop_day: int = 0
var shop_bought: Dictionary = {}

## Rewards earned while the game was closed, waiting to be claimed.
## Empty when there's nothing to claim. See Loot.roll_offline().
var pending_offline: Dictionary = {}

## Stackable items (see ItemDB): item id -> count.
## Star-up Pills are kept in starup_pills instead.
var items: Dictionary = {}

## Pulls since the last Gold-or-better summon (see SummonSystem).
var summon_pity: int = 0

## Used for Awaken (partners and MC). Later from salvaging partners.
var starup_pills: int = 0

## Duplicate copies waiting to be used for Awaken: partner_id -> count
var partner_copies: Dictionary = {}


# ---------------------------------------------------------
# QI REWARDS  -- tune these freely
# ---------------------------------------------------------

const QI_PER_KILL_BASE := 5
const QI_PER_KILL_PER_STAGE := 2
const QI_BOSS_MULT := 5
const QI_CLEAR_PER_STAGE := 10
## Qi also grows with enemy strength: x EnemyGenerator.strength(stage) ^ this.
## Breakthrough costs grow fast, so linear income alone would take
## decades to reach Transcendence. 0.35 was tested against a 4-year
## path (stage 1,000 by week 2, 2,500 by month 3, 6,000 by year 1.5,
## 10,000 by year 4) with a team of 6 cultivating: Transcendence
## around day 1,390. Higher = faster. Early stages barely change.
const QI_STRENGTH_EXP := 0.35


func get_qi_per_kill(stage: int, boss: bool) -> int:
	var amount := QI_PER_KILL_BASE + stage * QI_PER_KILL_PER_STAGE
	return int(float(amount * (QI_BOSS_MULT if boss else 1)) * qi_scale(stage))


func get_qi_stage_bonus(stage: int) -> int:
	return int(float(stage * QI_CLEAR_PER_STAGE) * qi_scale(stage))


## How much more Qi a stage gives because its enemies are stronger.
func qi_scale(stage: int) -> float:
	return pow(EnemyGenerator.strength(stage), QI_STRENGTH_EXP)


# ---------------------------------------------------------
# ROSTER AND FORMATION
# ---------------------------------------------------------

## roster[0] is always the MC.
var roster: Array[OwnedPartner] = []

## Six slots holding roster indices, or -1 for empty.
var formation: Array[int] = [-1, -1, -1, -1, -1, -1]


func _ready():
	if not load_game():
		_create_new_account()

	# Anything that changes a unit might change the MC's realm.
	roster_changed.connect(func(): realm_changed.emit())

	# Path Resonance depends on who is in the formation, so it is
	# rebuilt whenever that (or the roster behind it) changes.
	formation_changed.connect(refresh_path_bonus)
	roster_changed.connect(refresh_path_bonus)
	refresh_path_bonus()


## Recomputes the formation's Path Resonance into path_bonus.
## Cheap, but not free, so it is cached rather than read live by
## OwnedPartner._gear(), which runs on every stat lookup.
func refresh_path_bonus() -> void:
	path_bonus = Paths.active()


# ---------------------------------------------------------
# MAIN CHARACTER
# ---------------------------------------------------------

func get_mc() -> OwnedPartner:
	if roster.is_empty():
		return null
	return roster[0]


## Builds the MC's card data from name, gender, Dao and tier,
## and registers it so the MC works like any other partner.
func _register_mc_data() -> void:
	var data := PartnerData.new()

	data.partner_id = MC_ID
	data.display_name = mc_name
	data.form_name = ""
	data.series = ""
	data.rarity = mc_rarity
	data.path = mc_path

	# Slightly stronger than a White partner.
	data.base_hp = 1200
	data.base_atk = 120
	data.base_def = 70
	data.base_mdef = 70
	data.base_spd = 105

	var dao_name := str(Enums.Path.keys()[mc_path]).to_lower()
	var combo := "%s_%s" % [mc_gender, dao_name]
	var folder := MC_ART_FOLDER + combo + "/"

	data.card_texture = _load_first([folder + combo + "_card.png", folder + "card.png"])
	data.sprite_texture = _load_first([folder + combo + "_sprite.png", folder + "sprite.png"])

	PartnerDatabase.register_special(data)


## Loads the first path that exists.
func _load_first(paths: Array) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	push_warning("GameState: missing MC art, tried " + str(paths))
	return null


## Trims the ends and squashes double spaces.
func clean_mc_name(raw: String) -> String:
	var n := raw.strip_edges()
	while n.contains("  "):
		n = n.replace("  ", " ")
	return n


## "" if the name is fine, otherwise a message to show the player.
func validate_mc_name(raw: String) -> String:
	var n := clean_mc_name(raw)
	if n.length() < MC_NAME_MIN:
		return "Name needs at least %d characters." % MC_NAME_MIN
	if n.length() > MC_NAME_MAX:
		return "Name can be at most %d characters." % MC_NAME_MAX
	return ""


func random_mc_name(gender: String = "") -> String:
	if gender == "":
		gender = mc_gender
	var list: Array = MC_RANDOM_NAMES.get(gender, MC_RANDOM_NAMES["male"])
	return list.pick_random()


## Called by the character creation screen.
func create_main_character(new_name: String, gender: String, path: Enums.Path) -> void:
	mc_name = clean_mc_name(new_name)
	mc_gender = gender
	mc_path = path
	mc_created = true
	_register_mc_data()
	save_game()
	roster_changed.emit()
	realm_changed.emit()
	mc_changed.emit()


## Jade the next rename costs: 0 for the first one.
func get_rename_cost() -> int:
	return 0 if mc_rename_count == 0 else MC_RENAME_COST


## Checks the name, charges the cost, then renames.
## Returns "" on success, otherwise a message to show.
func try_rename_mc(new_name: String) -> String:
	var error := validate_mc_name(new_name)
	if error != "":
		return error

	var cost := get_rename_cost()
	if cost > 0 and not spend_immortal_jade(cost):
		return "Not enough Immortal Jade."

	mc_rename_count += 1
	rename_mc(new_name)
	return ""


## Renames the MC for free (gender and Dao stay locked).
## Players go through try_rename_mc() instead.
func rename_mc(new_name: String) -> void:
	mc_name = clean_mc_name(new_name)
	_register_mc_data()
	save_game()
	roster_changed.emit()
	mc_changed.emit()


## Team-wide HP and ATK bonus (in %) from the MC's tier.
const MC_TIER_BONUS := {
	"WHITE": 0, "BLUE": 3, "GREEN": 6, "PURPLE": 10,
	"RED": 15, "GOLD": 22, "PRISMATIC": 30,
}


func get_mc_team_bonus() -> int:
	var key := str(Enums.Rarity.keys()[mc_rarity])
	return int(MC_TIER_BONUS.get(key, 0))


## Keeps the MC's tier in step with its stars.
## Returns true if the tier changed.
func sync_mc_tier() -> bool:
	var mc := get_mc()
	if mc == null:
		return false

	var tier_name := Realms.tier_for_stars(mc.stars)
	if not Enums.Rarity.has(tier_name):
		push_warning("GameState: Enums.Rarity has no " + tier_name)
		return false

	var new_rarity: int = Enums.Rarity[tier_name]
	if new_rarity == mc_rarity:
		return false

	mc_rarity = new_rarity as Enums.Rarity
	_register_mc_data()
	return true


# ---------------------------------------------------------
# NEW ACCOUNT
# ---------------------------------------------------------

func _create_new_account():
	print("GameState: creating new account")

	roster.clear()
	formation = [-1, -1, -1, -1, -1, -1]

	# MC first
	_register_mc_data()
	roster.append(OwnedPartner.create_new(MC_ID, PartnerDatabase.get_partner(MC_ID)))
	formation[MC_SLOT] = 0
	sync_mc_tier()

	# No starter partners: new players summon their first ones
	# and add them on the Formation screen.

	save_game()


# ---------------------------------------------------------
# ROSTER
# ---------------------------------------------------------

## Adds a partner. If it's already owned, it becomes a duplicate
## copy (for Awaken) and the existing partner is returned.
## Counts something for the achievements (summons, crafts, forges).
func bump(key: String, amount := 1) -> void:
	# Start a new mission day/week first, so this counts for the new one
	Missions.refresh()
	stats[key] = int(stats.get(key, 0)) + amount
	# Most titles ride these same counters, so this is where they fall
	# due. Only a newly earned one costs anything.
	Titles.refresh()
	achievements_changed.emit()


func add_partner(partner_id: String) -> OwnedPartner:
	var data = PartnerDatabase.get_partner(partner_id)

	if data == null:
		return null
	Codex.discover_partner(partner_id)

	var owned := find_owned(partner_id)
	if owned != null:
		partner_copies[partner_id] = get_copies(partner_id) + 1
		roster_changed.emit()
		return owned

	var partner = OwnedPartner.create_new(partner_id, data)

	roster.append(partner)

	roster_changed.emit()

	return partner


func find_owned(partner_id: String) -> OwnedPartner:
	for partner in roster:
		if partner.partner_id == partner_id:
			return partner
	return null


func get_copies(partner_id: String) -> int:
	return int(partner_copies.get(partner_id, 0))


# ---------------------------------------------------------
# SALVAGE  -- tune these freely
# Spare copies and whole partners (not the MC, not in the team)
# turn into Star-up Pills.
# ---------------------------------------------------------

## Pills for one copy of a partner, by tier.
## Premium Soul Essence from salvaging one spare copy. Premium Reds
## can't be summoned, so spare Reds and better are the only route to
## their Soul Fragments. Tiers below Red give none.
const PREMIUM_ESSENCE_ID := "premium_essence"
const SALVAGE_ESSENCE := {
	Enums.Rarity.RED: 5,
	Enums.Rarity.GOLD: 15,
	Enums.Rarity.PRISMATIC: 50,
}
## Essence spent to forge one Soul Fragment.
##
## The whole chain, in spare Reds (a Red salvages to 5 Essence):
##   1 to 15 stars   29 fragments   58 Essence   ~12 Reds
##   Red to Gold     50 Essence                  ~10 Reds
##   15 to 18 stars  12 fragments   24 Essence    ~5 Reds
##   Gold to Prismatic  150 Essence              ~30 Reds
## so roughly 22 spare Reds to reach Gold and 57 to reach Prismatic.
const ESSENCE_PER_FRAGMENT := 2

## Essence to evolve into the next form, by the form you are leaving.
## Purple lines mostly cap at Red; Reds become Gold; the seven lines
## with a Prismatic form go one step further.
const EVOLVE_ESSENCE := {
	Enums.Rarity.PURPLE: 20,
	Enums.Rarity.RED: 50,
	Enums.Rarity.GOLD: 150,
}

const SALVAGE_PILLS := {
	Enums.Rarity.WHITE: 20,
	Enums.Rarity.BLUE: 60,
	Enums.Rarity.GREEN: 180,
	Enums.Rarity.PURPLE: 600,
	Enums.Rarity.RED: 2000,
	Enums.Rarity.GOLD: 8000,
	Enums.Rarity.PRISMATIC: 30000,
}

## Share of what was spent on a partner that salvaging gives back.
const SALVAGE_REFUND := 0.5


func get_copy_salvage_value(partner_id: String) -> int:
	var data = PartnerDatabase.get_partner(partner_id)
	if data == null:
		return 0
	return int(SALVAGE_PILLS.get(data.rarity, 0))


## "" if this partner can evolve right now, otherwise the reason,
## which the Evolve button shows.
func can_evolve(partner) -> String:
	if partner == null or partner.is_mc():
		return "The MC rises through realms, not forms."
	var forms: Array = SummonSystem.next_forms(partner.partner_id)
	if forms.is_empty():
		return "This cultivator has no higher form."
	var data = PartnerDatabase.get_partner(partner.partner_id)
	if data == null:
		return "This cultivator has no higher form."

	# No star requirement. Stars carry over but the new form restarts
	# the star bonus, so evolving early is its own punishment: a Gold
	# at 1 star (x5.60) is weaker than the Red at 15 (x9.11) it came
	# from, and needs 7 stars just to break even. That makes it a
	# choice — dip now for a higher ceiling, or max the Red first —
	# rather than a queue, and Essence is already the real cost.
	var cost := int(EVOLVE_ESSENCE.get(data.rarity, 0))
	if cost <= 0:
		return "This cultivator has no higher form."
	if get_item_count(PREMIUM_ESSENCE_ID) < cost:
		return "Need %d Premium Soul Essence." % cost
	return ""


## Essence this partner's next evolution costs (0 if it can't).
func evolve_cost(partner) -> int:
	if partner == null:
		return 0
	var data = PartnerDatabase.get_partner(partner.partner_id)
	return int(EVOLVE_ESSENCE.get(data.rarity, 0)) if data != null else 0


## Moves everything stored against a partner id onto the new one, so
## an evolved cultivator keeps their gear, treasures, artifacts, soul
## spirit, lifebound artifact and Battle Array place.
##
## Spare copies of the old form are deliberately left behind: they
## still salvage into Essence, and fragments of the old card can't
## awaken the new one.
func _rekey_partner(old_id: String, new_id: String) -> void:
	for item in gear:
		if str(item.get("owner", "")) == old_id:
			item["owner"] = new_id
	for t in treasures:
		if str(t.get("owner", "")) == old_id:
			t["owner"] = new_id
	for a in artifacts:
		if str(a.get("owner", "")) == old_id:
			a["owner"] = new_id
	for spirit in soul_spirits:
		if str(spirit.get("partner", "")) == old_id:
			spirit["partner"] = new_id
	if lifebound.has(old_id):
		lifebound[new_id] = lifebound[old_id]
		lifebound.erase(old_id)
	var slot := battle_array.find(old_id)
	if slot != -1:
		battle_array[slot] = new_id


## Evolves a partner into `target` (one of SummonSystem.next_forms).
## Stars, level, gear and everything else carry over: only who they
## are changes. Returns "" on success, otherwise the reason.
func evolve_partner(partner, target := "") -> String:
	var problem := can_evolve(partner)
	if problem != "":
		return problem

	var forms: Array = SummonSystem.next_forms(partner.partner_id)
	var new_id := str(target) if target != "" else str(forms[0])
	if not forms.has(new_id):
		return "That is not a form they can take."
	if find_owned(new_id) != null:
		return "You already have that form."

	var old_id: String = partner.partner_id
	var cost := evolve_cost(partner)
	if not spend_item(PREMIUM_ESSENCE_ID, cost):
		return "Need %d Premium Soul Essence." % cost

	_rekey_partner(old_id, new_id)
	partner.partner_id = new_id
	Codex.discover_partner(new_id)
	save_game()
	roster_changed.emit()
	return ""


## Spends essence to add one Soul Fragment to a Premium Red you own.
## Returns "" on success, otherwise the reason it didn't happen.
func forge_premium_fragment(partner_id: String) -> String:
	if find_owned(partner_id) == null:
		return "You don't have that cultivator yet."
	if get_item_count(PREMIUM_ESSENCE_ID) < ESSENCE_PER_FRAGMENT:
		return "Need %d Premium Soul Essence." % ESSENCE_PER_FRAGMENT
	if not spend_item(PREMIUM_ESSENCE_ID, ESSENCE_PER_FRAGMENT):
		return "Need %d Premium Soul Essence." % ESSENCE_PER_FRAGMENT
	partner_copies[partner_id] = get_copies(partner_id) + 1
	save_game()
	roster_changed.emit()
	return ""


## Premium Soul Essence from salvaging one spare copy of this partner.
func get_copy_essence_value(partner_id: String) -> int:
	var data = PartnerDatabase.get_partner(partner_id)
	if data == null:
		return 0
	return int(SALVAGE_ESSENCE.get(data.rarity, 0))


## Salvages up to `count` spare copies. Returns the pills gained.
## Red and better also give Premium Soul Essence, on top of the pills.
func salvage_copies(partner_id: String, count: int) -> int:
	var have := get_copies(partner_id)
	count = mini(count, have)
	if count <= 0:
		return 0

	partner_copies[partner_id] = have - count
	if partner_copies[partner_id] <= 0:
		partner_copies.erase(partner_id)

	var essence := count * get_copy_essence_value(partner_id)
	if essence > 0:
		add_items({PREMIUM_ESSENCE_ID: essence})

	var pills := count * get_copy_salvage_value(partner_id)
	add_starup_pills(pills)
	save_game()
	roster_changed.emit()
	return pills


func get_all_copies_salvage_value() -> int:
	var total := 0
	for id in partner_copies:
		total += get_copies(id) * get_copy_salvage_value(id)
	return total


## Essence the whole spare pile would give, for the preview text.
func get_all_copies_essence_value() -> int:
	var total := 0
	for id in partner_copies:
		total += get_copies(id) * get_copy_essence_value(str(id))
	return total


func salvage_all_copies() -> int:
	var pills := get_all_copies_salvage_value()
	var essence := get_all_copies_essence_value()
	if pills <= 0 and essence <= 0:
		return 0
	partner_copies.clear()
	if essence > 0:
		add_items({PREMIUM_ESSENCE_ID: essence})
	add_starup_pills(pills)
	save_game()
	roster_changed.emit()
	return pills


## "" if this roster entry can be salvaged, otherwise the reason.
func can_salvage_partner(roster_index: int) -> String:
	if roster_index <= 0 or roster_index >= roster.size():
		return "This can't be salvaged."
	if get_slot_of(roster_index) != -1:
		return "Remove them from your team first."
	if battle_array.has(roster[roster_index].partner_id):
		return "Remove them from the Battle Array first."
	return ""


## What salvaging this partner gives: {pills, qi, copies}.
func get_partner_salvage_value(roster_index: int) -> Dictionary:
	if roster_index <= 0 or roster_index >= roster.size():
		return {"pills": 0, "qi": 0, "copies": 0}

	var p: OwnedPartner = roster[roster_index]
	var base := get_copy_salvage_value(p.partner_id)
	var copies := get_copies(p.partner_id)

	var pills := base * (1 + copies)
	pills += int(p.get_pills_invested() * SALVAGE_REFUND)
	pills += int(p.get_copies_invested() * base * SALVAGE_REFUND)
	var qi_back := int(p.get_qi_invested() * SALVAGE_REFUND)

	return {"pills": pills, "qi": qi_back, "copies": copies}


## Removes the partner (and its spare copies) for pills and Qi.
## Returns what was gained, or {} if it couldn't be salvaged.
func salvage_partner(roster_index: int) -> Dictionary:
	if can_salvage_partner(roster_index) != "":
		return {}

	var value := get_partner_salvage_value(roster_index)
	var id: String = roster[roster_index].partner_id

	unequip_all(id)
	unequip_all_treasures(id)
	unequip_all_artifacts(id)
	lifebound.erase(id)
	# A salvaged partner's Soul Spirit is released (its rings stay in it)
	for spirit in soul_spirits:
		if str(spirit.get("partner", "")) == roster[roster_index].partner_id:
			spirit["partner"] = ""
	roster.remove_at(roster_index)
	partner_copies.erase(id)

	# Later roster entries moved down by one
	for slot in FORMATION_SIZE:
		if formation[slot] > roster_index:
			formation[slot] -= 1

	add_starup_pills(value["pills"])
	add_qi(value["qi"])
	save_game()
	roster_changed.emit()
	formation_changed.emit()
	return value


## Salvages many partners and fragments in one go.
## roster_indices: whole partners (their fragments come with them).
## fragment_ids: partner ids whose spare fragments to salvage.
## Returns {"pills", "qi", "partners", "fragments"}.
func salvage_batch(roster_indices: Array, fragment_ids: Array) -> Dictionary:
	var result := {"pills": 0, "qi": 0, "partners": 0, "fragments": 0}

	# Whole partners, highest index first so earlier indices stay valid
	var indices := roster_indices.duplicate()
	indices.sort()
	indices.reverse()
	var removed_ids := {}
	for index in indices:
		if can_salvage_partner(index) != "":
			continue
		var value := get_partner_salvage_value(index)
		var id: String = roster[index].partner_id
		result["pills"] += value["pills"]
		result["qi"] += value["qi"]
		result["fragments"] += value["copies"]
		result["partners"] += 1
		removed_ids[id] = true
		unequip_all(id)
		unequip_all_treasures(id)
		unequip_all_artifacts(id)
		lifebound.erase(id)
		roster.remove_at(index)
		partner_copies.erase(id)
		for slot in FORMATION_SIZE:
			if formation[slot] > index:
				formation[slot] -= 1

	# Loose fragments of partners you keep
	for id in fragment_ids:
		if removed_ids.has(id):
			continue
		var n := get_copies(id)
		if n <= 0:
			continue
		result["pills"] += n * get_copy_salvage_value(id)
		result["fragments"] += n
		partner_copies.erase(id)

	if result["pills"] > 0:
		add_starup_pills(result["pills"])
	if result["qi"] > 0:
		add_qi(result["qi"])
	save_game()
	roster_changed.emit()
	if result["partners"] > 0:
		formation_changed.emit()
	return result


# ---------------------------------------------------------
# ASCEND AND AWAKEN
# Both return "" on success, otherwise a message to show.
# ---------------------------------------------------------

# ---------------------------------------------------------
# BREAKTHROUGHS  -- tune these freely
# Level 10 -> next minor realm can fail. Levels inside a realm can't.
# ---------------------------------------------------------

## Mortal Realm: the first breakthrough is certain, then each one is
## harder (100%, 90%, 80% ... down to 20% at Tribulation Transcendence).
const BREAKTHROUGH_MORTAL_START := 100
const BREAKTHROUGH_MORTAL_STEP := 10
## Spirit Realm and above: always this low. Pills are what make it possible.
const BREAKTHROUGH_HIGH_REALM_CHANCE := 10
## Extra chance (%) from EACH of that realm's pills. Several can be used.
const BREAKTHROUGH_PILL_BONUS := 5
## Share of the Qi cost lost on a failed attempt.
const BREAKTHROUGH_FAIL_LOSS := 0.5


## True when the next Ascend is a risky breakthrough into a new realm.
func is_breakthrough(partner: OwnedPartner) -> bool:
	return partner != null and partner.tier >= Realms.LEVELS_PER_MINOR and not partner.is_max_realm()


func get_breakthrough_pill(partner: OwnedPartner) -> String:
	return ItemDB.realm_pill_id(partner.realm_index + 1)


## Chance (%) without a pill, when breaking out of minor realm `index`.
func get_base_breakthrough_chance(index: int) -> int:
	if Realms.get_major(index) == 0:
		return clampi(BREAKTHROUGH_MORTAL_START - BREAKTHROUGH_MORTAL_STEP * index,
			BREAKTHROUGH_HIGH_REALM_CHANCE, 100)
	return BREAKTHROUGH_HIGH_REALM_CHANCE


func get_breakthrough_chance(partner: OwnedPartner, pills: int) -> int:
	var chance := get_base_breakthrough_chance(partner.realm_index)
	chance += maxi(pills, 0) * BREAKTHROUGH_PILL_BONUS
	return clampi(chance, 0, 100)


## Pills needed to reach 100% (0 if it's already certain).
func pills_for_certain(partner: OwnedPartner) -> int:
	var missing := 100 - get_base_breakthrough_chance(partner.realm_index)
	return maxi(0, ceili(missing / float(BREAKTHROUGH_PILL_BONUS)))


## Rolls a breakthrough. Returns:
##   {"ok": false, "error": "..."}  -- couldn't attempt
##   {"ok": true, "success": bool, "chance": int, "qi_lost": int, "pills": int}
func attempt_breakthrough(partner: OwnedPartner, pills: int) -> Dictionary:
	if not is_breakthrough(partner):
		return {"ok": false, "error": "No breakthrough needed."}
	if partner.is_capped_by_mc():
		return {"ok": false, "error": "Can't pass your own realm."}

	var cost := partner.get_ascend_cost()
	if qi < cost:
		return {"ok": false, "error": "Not enough Qi."}

	var pill := get_breakthrough_pill(partner)
	pills = clampi(pills, 0, pills_for_certain(partner))
	if get_item_count(pill) < pills:
		return {"ok": false, "error": "You don't have enough pills."}

	var chance := get_breakthrough_chance(partner, pills)
	if pills > 0:
		spend_item(pill, pills)   # used up either way

	var success := randi() % 100 < chance
	var lost := 0
	if success:
		spend_qi(cost)
		partner.breakthrough()
		if partner.is_mc():
			realm_changed.emit()
	else:
		lost = int(cost * BREAKTHROUGH_FAIL_LOSS)
		spend_qi(lost)

	save_game()
	roster_changed.emit()
	return {"ok": true, "success": success, "chance": chance, "qi_lost": lost, "pills": pills}


func try_ascend(partner: OwnedPartner) -> String:
	if partner == null:
		return "No partner selected."
	if partner.is_max_realm():
		return "Already at the highest realm."
	if partner.is_capped_by_mc():
		return "Can't pass your own realm."
	if is_breakthrough(partner):
		return "This needs a breakthrough attempt."

	var cost := partner.get_ascend_cost()
	if not spend_qi(cost):
		return "Not enough Qi."

	partner.breakthrough()
	save_game()
	roster_changed.emit()
	return ""


func try_awaken(partner: OwnedPartner) -> String:
	if partner == null:
		return "No partner selected."
	if partner.stars >= partner.get_star_cap():
		return "Star limit reached for this realm."

	var need_copies := partner.get_awaken_copies()
	var have_copies := get_copies(partner.partner_id)
	if have_copies < need_copies:
		var missing := need_copies - have_copies
		return "Need %d more Soul Fragment%s." % [missing, "" if missing == 1 else "s"]

	var need_pills := partner.get_awaken_pills()
	if starup_pills < need_pills:
		return "Need %s more Star-up Pills." % NumberFormat.short(need_pills - starup_pills)

	# Pay both
	if need_copies > 0:
		partner_copies[partner.partner_id] = have_copies - need_copies
		if partner_copies[partner.partner_id] <= 0:
			partner_copies.erase(partner.partner_id)
	spend_starup_pills(need_pills)

	partner.add_star()
	if partner.is_mc():
		sync_mc_tier()
	save_game()
	roster_changed.emit()
	return ""


func get_partner_in_slot(slot: int) -> OwnedPartner:
	if slot < 0 or slot >= FORMATION_SIZE:
		return null

	var roster_index = formation[slot]

	if roster_index < 0 or roster_index >= roster.size():
		return null

	return roster[roster_index]


func get_formation_partners() -> Array:
	var result: Array = []

	for slot in range(FORMATION_SIZE):
		result.append(get_partner_in_slot(slot))

	return result


func set_formation_slot(slot: int, roster_index: int):
	if slot < 0 or slot >= FORMATION_SIZE:
		return

	# The MC's slot is locked, and the MC can't move.
	if slot == MC_SLOT or roster_index == 0:
		return

	for i in range(FORMATION_SIZE):
		if formation[i] == roster_index and i != slot:
			formation[i] = -1

	# Joining the team takes a partner out of the Battle Array
	if roster_index > 0 and roster_index < roster.size():
		var at := battle_array.find(roster[roster_index].partner_id)
		if at >= 0:
			battle_array[at] = ""
			array_changed.emit()

	formation[slot] = roster_index

	formation_changed.emit()

	save_game()


## Slot (1-5) holding this roster index, or -1 if not in the team.
func get_slot_of(roster_index: int) -> int:
	return formation.find(roster_index)


## Puts a partner in the first free slot. Returns false if the team is full.
func add_to_formation(roster_index: int) -> bool:
	if roster_index <= 0 or get_slot_of(roster_index) != -1:
		return false
	for slot in range(1, FORMATION_SIZE):
		if formation[slot] == -1:
			set_formation_slot(slot, roster_index)
			return true
	return false


func remove_from_formation(roster_index: int) -> void:
	var slot := get_slot_of(roster_index)
	if slot > 0:
		set_formation_slot(slot, -1)


func get_team_size() -> int:
	var count := 0
	for idx in formation:
		if idx >= 0:
			count += 1
	return count


func get_team_power() -> int:
	var total = 0

	for partner in get_formation_partners():
		if partner != null:
			total += partner.get_power()

	return total


# ---------------------------------------------------------
# CURRENCY
# ---------------------------------------------------------

func add_spirit_stones(amount: int):
	spirit_stones = maxi(0, spirit_stones + amount)
	currency_changed.emit()


func add_immortal_jade(amount: int):
	immortal_jade = maxi(0, immortal_jade + amount)
	currency_changed.emit()


func add_qi(amount: int):
	qi = maxi(0, qi + amount)
	currency_changed.emit()


func spend_qi(amount: int) -> bool:
	if qi < amount:
		return false

	qi -= amount
	currency_changed.emit()

	return true


func add_starup_pills(amount: int):
	starup_pills = maxi(0, starup_pills + amount)
	currency_changed.emit()


func spend_starup_pills(amount: int) -> bool:
	if starup_pills < amount:
		return false

	starup_pills -= amount
	currency_changed.emit()

	return true


func get_item_count(id: String) -> int:
	if id == "starup_pill":
		return starup_pills
	return int(items.get(id, 0))


func add_item(id: String, amount: int) -> void:
	if id == "starup_pill":
		add_starup_pills(amount)
		return
	items[id] = maxi(0, get_item_count(id) + amount)
	if items[id] == 0:
		items.erase(id)
	currency_changed.emit()


## Adds several items at once: {item id: count}.
func add_items(drops: Dictionary) -> void:
	for id in drops:
		if id == "starup_pill":
			starup_pills = maxi(0, starup_pills + int(drops[id]))
		else:
			var n := get_item_count(id) + int(drops[id])
			if n > 0:
				items[id] = n
			else:
				items.erase(id)
	currency_changed.emit()


func spend_item(id: String, amount: int) -> bool:
	if get_item_count(id) < amount:
		return false
	add_item(id, -amount)
	return true


func spend_spirit_stones(amount: int) -> bool:
	if spirit_stones < amount:
		return false

	spirit_stones -= amount
	currency_changed.emit()

	return true


func spend_immortal_jade(amount: int) -> bool:
	if immortal_jade < amount:
		return false

	immortal_jade -= amount
	currency_changed.emit()

	return true


# ---------------------------------------------------------
# STAGE PROGRESS
# ---------------------------------------------------------

func advance_stage():
	if current_stage >= MAX_STAGE:
		return

	pending_boss = 0
	current_stage += 1

	highest_stage = maxi(highest_stage, current_stage)
	bump("stages")

	stage_changed.emit()

	save_game()


## The account realm shown in the top bar = the MC's realm.
func get_realm_text() -> String:
	var mc = get_mc()
	if mc == null:
		return Realms.get_label(0, 1)
	return mc.get_realm_text()


# ---------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	var roster_data: Array = []

	for partner in roster:
		roster_data.append(partner.to_dict())

	return {
		"version": SAVE_VERSION,
		"realm_count": Realms.count(),
		"last_seen": now_unix(),
		"mc": {
			"name": mc_name,
			"gender": mc_gender,
			"path": mc_path,
			"rarity": mc_rarity,
			"created": mc_created,
			"renames": mc_rename_count,
		},
		"highest_stage": highest_stage,
		"current_stage": current_stage,
		"spirit_stones": spirit_stones,
		"immortal_jade": immortal_jade,
		"qi": qi,
		"starup_pills": starup_pills,
		"summon_pity": summon_pity,
		"known_recipes": known_recipes,
		"gear": gear,
		"next_gear_uid": next_gear_uid,
		"treasures": treasures,
		"next_treasure_uid": next_treasure_uid,
		"artifacts": artifacts,
		"next_artifact_uid": next_artifact_uid,
		"lifebound": lifebound,
		"lifebound_seeds": lifebound_seeds,
		"expeditions": expeditions,
		"expedition_offers": expedition_offers,
		"pending_boss": pending_boss,
		"stats": stats,
		"claimed_achievements": claimed_achievements,
		"titles_owned": titles_owned,
		"title_worn": title_worn,
		"login_streak": login_streak,
		"login_streak_day": login_streak_day,
		"pending_card_choices": pending_card_choices,
		"missions": missions,
		"array_level": array_level,
		"battle_array": battle_array,
		"trials": trials,
		"tribulation": tribulation,
		"gods": gods,
		"fate_points": fate_points,
		"fallen_god": fallen_god,
		"beast_rings": beast_rings,
		"soul_spirits": soul_spirits,
		"beast_codex": beast_codex,
		"codex_partners": codex_partners,
		"codex_treasures": codex_treasures,
		"sect_bonus": sect_bonus,
		"sect_shop": sect_shop,
		"unlocks_seen": unlocks_seen,
		"first_summon_done": first_summon_done,
		"tutorials_done": tutorials_done,
		"tutorials_pending": tutorials_pending,
		"tutorial_step": tutorial_step,
		"ads_state": ads_state,
		"beast_forest": beast_forest,
		"mail": mail,
		"next_mail_id": next_mail_id,
		"ranking_day": ranking_day,
		"dungeon_progress": dungeon_progress,
		"dungeon_entries": dungeon_entries,
		"dungeon_day": dungeon_day,
		"bought_packs": bought_packs,
		"shop_day": shop_day,
		"shop_bought": shop_bought,
		"items": items,
		"partner_copies": partner_copies,
		"roster": roster_data,
		"formation": formation
	}


# ---------------------------------------------------------
# EQUIPMENT
# ---------------------------------------------------------

func add_gear(item: Dictionary) -> Dictionary:
	item["uid"] = next_gear_uid
	next_gear_uid += 1
	gear.append(item)
	return item


func find_gear(uid: int) -> Dictionary:
	for item in gear:
		if int(item["uid"]) == uid:
			return item
	return {}


func remove_gear(uid: int) -> void:
	for i in gear.size():
		if int(gear[i]["uid"]) == uid:
			gear.remove_at(i)
			return


## Puts a piece on a partner (replacing whatever was in that slot,
## and taking it off whoever wore it before).
func equip_gear(uid: int, partner_id: String) -> void:
	var item := find_gear(uid)
	if item.is_empty():
		return
	for other in gear:
		if other.get("owner", "") == partner_id and int(other["slot"]) == int(item["slot"]):
			other["owner"] = ""
	item["owner"] = partner_id
	gear_changed()


func unequip_gear(uid: int) -> void:
	var item := find_gear(uid)
	if not item.is_empty():
		item["owner"] = ""
		gear_changed()


func unequip_all(partner_id: String) -> void:
	for item in gear:
		if item.get("owner", "") == partner_id:
			item["owner"] = ""


func gear_in_slot(partner_id: String, slot: int) -> Dictionary:
	for item in gear:
		if item.get("owner", "") == partner_id and int(item["slot"]) == slot:
			return item
	return {}


## Call after changing any gear: saves and refreshes stats everywhere.
func gear_changed() -> void:
	save_game()
	gear_updated.emit()
	roster_changed.emit()


## Salvages several pieces at once. Returns the ore gained.
func salvage_gear_batch(uids: Array) -> int:
	var ore := 0
	for uid in uids:
		var item := find_gear(int(uid))
		if item.is_empty() or item.get("locked", false) or item.get("owner", "") != "":
			continue
		ore += Gear.salvage_value(item)
		remove_gear(int(uid))
	if ore > 0:
		add_items({"refining_ore": ore})
		gear_changed()
	return ore


## Salvages one piece for Refining Ore. Returns the ore gained (0 if not allowed).
func salvage_gear(uid: int) -> int:
	var item := find_gear(uid)
	if item.is_empty() or item.get("locked", false):
		return 0
	var ore := Gear.salvage_value(item)
	remove_gear(uid)
	add_items({"refining_ore": ore})
	gear_changed()
	return ore


## A boss beat you: drop back one stage and remember the boss.
func boss_defeat(stage: int) -> void:
	pending_boss = stage
	current_stage = maxi(1, stage - 1)
	save_game()
	stage_changed.emit()


## Go back and fight the boss that beat you.
func retry_boss() -> void:
	if pending_boss <= 0:
		return
	current_stage = pending_boss
	save_game()
	stage_changed.emit()


# ---------------------------------------------------------
# ARTIFACTS, LIFEBOUND AND EXPEDITIONS
# ---------------------------------------------------------

func add_artifact(a: Dictionary) -> Dictionary:
	a["uid"] = next_artifact_uid
	next_artifact_uid += 1
	artifacts.append(a)
	return a


func find_artifact(uid: int) -> Dictionary:
	for a in artifacts:
		if int(a["uid"]) == uid:
			return a
	return {}


func remove_artifact(uid: int) -> void:
	for i in artifacts.size():
		if int(artifacts[i]["uid"]) == uid:
			artifacts.remove_at(i)
			return


func artifacts_of(partner_id: String) -> Array:
	var out: Array = []
	for a in artifacts:
		if a.get("owner", "") == partner_id:
			out.append(a)
	return out


func equip_artifact(uid: int, partner_id: String, slot: int) -> void:
	var a := find_artifact(uid)
	if a.is_empty():
		return
	var worn := artifacts_of(partner_id)
	if slot < worn.size() and int(worn[slot]["uid"]) != uid:
		worn[slot]["owner"] = ""
	a["owner"] = partner_id
	artifacts_changed()


func unequip_artifact(uid: int) -> void:
	var a := find_artifact(uid)
	if not a.is_empty():
		a["owner"] = ""
		artifacts_changed()


func unequip_all_artifacts(partner_id: String) -> void:
	for a in artifacts:
		if a.get("owner", "") == partner_id:
			a["owner"] = ""


func artifacts_changed() -> void:
	save_game()
	artifacts_updated.emit()
	roster_changed.emit()


## Salvages an artifact back into Artifact Cores.
func salvage_artifact(uid: int) -> int:
	var a := find_artifact(uid)
	if a.is_empty() or a.get("locked", false) or a.get("owner", "") != "":
		return 0
	var cores := Artifacts.salvage_value(a)
	remove_artifact(uid)
	add_items({Artifacts.CORE_ID: cores})
	artifacts_changed()
	return cores


func lifebound_changed() -> void:
	save_game()
	lifebound_updated.emit()
	roster_changed.emit()


func expeditions_changed() -> void:
	save_game()
	expeditions_updated.emit()


# ---------------------------------------------------------
# TREASURES
# ---------------------------------------------------------

func add_treasure(t: Dictionary) -> Dictionary:
	t["uid"] = next_treasure_uid
	next_treasure_uid += 1
	treasures.append(t)
	Codex.discover_treasure(str(t.get("id", "")), int(t.get("grade", 0)))
	return t


func find_treasure(uid: int) -> Dictionary:
	for t in treasures:
		if int(t["uid"]) == uid:
			return t
	return {}


func remove_treasure(uid: int) -> void:
	for i in treasures.size():
		if int(treasures[i]["uid"]) == uid:
			treasures.remove_at(i)
			return


func treasures_of(partner_id: String) -> Array:
	var out: Array = []
	for t in treasures:
		if t.get("owner", "") == partner_id:
			out.append(t)
	return out


## Equips into one of the 3 treasure slots (slot 0, 1 or 2).
func equip_treasure(uid: int, partner_id: String, slot: int) -> void:
	var t := find_treasure(uid)
	if t.is_empty():
		return
	var worn := treasures_of(partner_id)
	if slot < worn.size() and int(worn[slot]["uid"]) != uid:
		worn[slot]["owner"] = ""
	t["owner"] = partner_id
	treasures_changed()


func unequip_treasure(uid: int) -> void:
	var t := find_treasure(uid)
	if not t.is_empty():
		t["owner"] = ""
		treasures_changed()


func unequip_all_treasures(partner_id: String) -> void:
	for t in treasures:
		if t.get("owner", "") == partner_id:
			t["owner"] = ""


func treasures_changed() -> void:
	save_game()
	treasures_updated.emit()
	roster_changed.emit()


## Salvages a treasure into Treasure Dust. Returns the dust gained.
func salvage_treasure(uid: int) -> int:
	var t := find_treasure(uid)
	if t.is_empty() or t.get("locked", false) or t.get("owner", "") != "":
		return 0
	var dust := Treasures.salvage_value(t)
	remove_treasure(uid)
	add_items({Treasures.DUST_ID: dust})
	treasures_changed()
	return dust


## Salvages several treasures at once. Returns the dust gained.
func salvage_treasures_batch(uids: Array) -> int:
	var dust := 0
	for uid in uids:
		var t := find_treasure(int(uid))
		if t.is_empty() or t.get("locked", false) or t.get("owner", "") != "":
			continue
		dust += Treasures.salvage_value(t)
		remove_treasure(int(uid))
	if dust > 0:
		add_items({Treasures.DUST_ID: dust})
		treasures_changed()
	return dust


# ---------------------------------------------------------
# RECIPES AND SHOP STOCK
# ---------------------------------------------------------

func has_recipe(target: int) -> bool:
	return known_recipes.has(target)


func learn_recipe(target: int) -> void:
	if not known_recipes.has(target):
		known_recipes.append(target)
		known_recipes.sort()


## The clock everything dated runs on. The server's when we have it,
## so winding the device forward no longer buys a new day of resets,
## a login streak or a night of offline rewards. Falls back to the
## device only until the first response arrives.
func now_unix() -> int:
	if Backend.has_server_time:
		return Backend.server_unix()
	return int(Time.get_unix_time_from_system())


## Now, broken out, in UTC. Every daily and weekly boundary in the
## game reads this rather than the device's own calendar.
func now_dict() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(now_unix())


## Today's number, for the daily shop reset and every other daily.
## UTC, not local: it has to agree with the server, and the Arena and
## its settlement were already reckoning in UTC.
func today() -> int:
	var t := Time.get_datetime_dict_from_unix_time(now_unix())
	return int(t["year"]) * 10000 + int(t["month"]) * 100 + int(t["day"])


## Clears the daily purchase counts when a new day starts.
func refresh_shop_day() -> void:
	var d := today()
	if d != shop_day:
		shop_day = d
		shop_bought.clear()


func get_bought_today(offer_id: String) -> int:
	refresh_shop_day()
	return int(shop_bought.get(offer_id, 0))


func add_bought_today(offer_id: String, n: int) -> void:
	refresh_shop_day()
	shop_bought[offer_id] = get_bought_today(offer_id) + n


func get_dungeon_entries_used(id: String) -> int:
	var d := today()
	if d != dungeon_day:
		dungeon_day = d
		dungeon_entries.clear()
	return int(dungeon_entries.get(id, 0))


func use_dungeon_entry(id: String) -> void:
	dungeon_entries[id] = get_dungeon_entries_used(id) + 1
	bump("dungeon_runs")


# ---------------------------------------------------------
# OFFLINE REWARDS
# ---------------------------------------------------------

func has_offline_rewards() -> bool:
	return not pending_offline.is_empty()


func claim_offline() -> Dictionary:
	var got := pending_offline
	pending_offline = {}
	if got.is_empty():
		return got
	qi += int(got["qi"])
	spirit_stones += int(got["stones"])
	add_items(got["items"])   # also emits currency_changed
	bump("offline")
	save_game()
	return got


func _compute_offline(last_seen: int) -> void:
	pending_offline = {}
	if last_seen <= 0 or not mc_created:
		return
	# Server time, so winding the clock forward buys nothing. A clock
	# wound backwards gives a negative figure, which falls below the
	# minimum and pays nothing; roll_offline() caps the top end at
	# OFFLINE_MAX_HOURS by itself.
	var away := now_unix() - last_seen
	if away < Loot.OFFLINE_MIN_SECONDS:
		return
	var rewards := Loot.roll_offline(current_stage, away)
	if rewards["battles"] > 0:
		pending_offline = rewards


## Save when the app is closed or sent to the background (phones).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("GameState: could not write save file")
		return

	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	# Cloud save (batched by the Backend autoload, if it's set up)
	var backend := get_node_or_null("/root/Backend")
	if backend != null:
		backend.call("note_saved")


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return false

	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if parsed == null or not parsed is Dictionary:
		push_error("GameState: save file is corrupt")
		return false

	var dict: Dictionary = parsed

	# Saves from before the MC existed start over.
	if int(dict.get("version", 1)) < SAVE_VERSION or not dict.has("mc"):
		print("GameState: old save found, starting a new account")
		return false

	var mc_dict: Dictionary = dict["mc"]
	mc_name   = mc_dict.get("name", "Cultivator")
	mc_gender = mc_dict.get("gender", "male")
	mc_created = bool(mc_dict.get("created", false))
	mc_rename_count = int(mc_dict.get("renames", 0))

	var saved_path: int = int(mc_dict.get("path", Enums.Path.SWORD))
	var saved_rarity: int = int(mc_dict.get("rarity", Enums.Rarity.WHITE))
	mc_path = saved_path as Enums.Path
	mc_rarity = saved_rarity as Enums.Rarity

	_register_mc_data()

	highest_stage = dict.get("highest_stage", 1)
	current_stage = dict.get("current_stage", 1)
	spirit_stones = dict.get("spirit_stones", 1000)
	immortal_jade = dict.get("immortal_jade", 1000)
	qi = int(dict.get("qi", 0))
	starup_pills = int(dict.get("starup_pills", 0))
	summon_pity = int(dict.get("summon_pity", 0))

	artifacts.clear()
	for a in dict.get("artifacts", []):
		if not a is Dictionary:
			continue
		artifacts.append({
			"uid": int(a.get("uid", 0)), "trait": str(a.get("trait", "")),
			"grade": int(a.get("grade", 0)), "owner": str(a.get("owner", "")),
			"locked": bool(a.get("locked", false)),
		})
	next_artifact_uid = int(dict.get("next_artifact_uid", 1))

	lifebound.clear()
	var saved_life: Dictionary = dict.get("lifebound", {})
	for id in saved_life:
		var entry: Dictionary = saved_life[id]
		var lines: Array = []
		for line in entry.get("lines", []):
			lines.append({"stat": str(line["stat"]), "value": float(line["value"]),
				"sealed": bool(line.get("sealed", false))})
		lifebound[str(id)] = {"grade": int(entry.get("grade", 0)),
			"stars": int(entry.get("stars", 0)), "lines": lines}
	lifebound_seeds.clear()
	var saved_seeds: Dictionary = dict.get("lifebound_seeds", {})
	for star in saved_seeds:
		lifebound_seeds[int(star)] = int(saved_seeds[star])

	expeditions.clear()
	for trip in dict.get("expeditions", []):
		if trip is Dictionary:
			expeditions.append(trip.duplicate(true))
	expedition_offers.clear()
	for offer in dict.get("expedition_offers", []):
		if offer is Dictionary:
			expedition_offers.append(offer.duplicate(true))

	treasures.clear()
	for t in dict.get("treasures", []):
		if not t is Dictionary:
			continue
		treasures.append({
			"uid": int(t.get("uid", 0)), "id": str(t.get("id", "")),
			"grade": int(t.get("grade", 0)), "level": int(t.get("level", 0)),
			"owner": str(t.get("owner", "")), "locked": bool(t.get("locked", false)),
		})
	next_treasure_uid = int(dict.get("next_treasure_uid", 1))

	gear.clear()
	for g in dict.get("gear", []):
		if not g is Dictionary:
			continue
		var bonus: Array = []
		for line in g.get("bonus", []):
			bonus.append([str(line[0]), float(line[1])])
		gear.append({
			"uid": int(g.get("uid", 0)), "slot": int(g.get("slot", 0)),
			"tier": int(g.get("tier", 0)), "sub": int(g.get("sub", 0)),
			"set": str(g.get("set", "")), "refine": int(g.get("refine", 0)),
			"bonus": bonus, "owner": str(g.get("owner", "")),
			"locked": bool(g.get("locked", false)),
		})
	next_gear_uid = int(dict.get("next_gear_uid", 1))

	pending_boss = int(dict.get("pending_boss", 0))

	stats.clear()
	var saved_stats: Dictionary = dict.get("stats", {})
	for key in saved_stats:
		stats[str(key)] = int(saved_stats[key])
	claimed_achievements.clear()
	for id in dict.get("claimed_achievements", []):
		claimed_achievements.append(str(id))
	titles_owned = {}
	var saved_titles = dict.get("titles_owned", {})
	if saved_titles is Dictionary:
		for id in saved_titles:
			# Saves from before titles could lapse stored `true`.
			# Those become 0, meaning kept for good; refresh() puts a
			# clock on any that should have one.
			var until = saved_titles[id]
			titles_owned[str(id)] = 0 if until is bool else int(until)
	title_worn = str(dict.get("title_worn", ""))
	login_streak = int(dict.get("login_streak", 0))
	login_streak_day = int(dict.get("login_streak_day", 0))
	Titles.refresh_bonus()
	pending_card_choices.clear()
	for choice in dict.get("pending_card_choices", []):
		if choice is Dictionary:
			pending_card_choices.append(choice.duplicate(true))
	missions = {}
	var saved_missions = dict.get("missions", {})
	if saved_missions is Dictionary:
		missions = saved_missions.duplicate(true)
	array_level = maxi(1, int(dict.get("array_level", 1)))
	battle_array.clear()
	for id in dict.get("battle_array", []):
		battle_array.append(str(id))
	trials = {}
	var saved_trials = dict.get("trials", {})
	if saved_trials is Dictionary:
		trials = saved_trials.duplicate(true)
	tribulation = {}
	var saved_trib = dict.get("tribulation", {})
	if saved_trib is Dictionary:
		tribulation = saved_trib.duplicate(true)
	gods = {}
	var saved_gods = dict.get("gods", {})
	if saved_gods is Dictionary:
		gods = saved_gods.duplicate(true)
	fate_points = int(dict.get("fate_points", 0))
	fallen_god = {}
	var saved_fg = dict.get("fallen_god", {})
	if saved_fg is Dictionary:
		fallen_god = saved_fg.duplicate(true)
	beast_rings = []
	for r in dict.get("beast_rings", []):
		if r is Dictionary:
			var ring: Dictionary = r.duplicate(true)
			ring["uid"] = int(ring.get("uid", 0))
			ring["grade"] = int(ring.get("grade", 0))
			ring["slot"] = int(ring.get("slot", -1))
			ring["spirit"] = int(ring.get("spirit", 0))
			ring.erase("owner")
			beast_rings.append(ring)
	soul_spirits = []
	for sp in dict.get("soul_spirits", []):
		if sp is Dictionary:
			var spirit: Dictionary = sp.duplicate(true)
			spirit["uid"] = int(spirit.get("uid", 0))
			soul_spirits.append(spirit)
	beast_codex = {}
	var saved_codex = dict.get("beast_codex", {})
	if saved_codex is Dictionary:
		beast_codex = saved_codex.duplicate(true)
	beast_forest = {}
	var saved_bf = dict.get("beast_forest", {})
	if saved_bf is Dictionary:
		beast_forest = saved_bf.duplicate(true)

	mail.clear()
	for m in dict.get("mail", []):
		if not m is Dictionary:
			continue
		var mail_items := {}
		for id in m.get("items", {}):
			mail_items[str(id)] = int(m["items"][id])
		mail.append({
			"id": int(m.get("id", 0)), "title": str(m.get("title", "")),
			"body": str(m.get("body", "")), "jade": int(m.get("jade", 0)),
			"items": mail_items, "claimed": bool(m.get("claimed", false)),
			"read": bool(m.get("read", false)), "day": int(m.get("day", 0)),
		})
	next_mail_id = int(dict.get("next_mail_id", 1))
	ranking_day = int(dict.get("ranking_day", 0))

	dungeon_progress.clear()
	var saved_dp: Dictionary = dict.get("dungeon_progress", {})
	for k in saved_dp:
		dungeon_progress[str(k)] = int(saved_dp[k])
	dungeon_entries.clear()
	var saved_de: Dictionary = dict.get("dungeon_entries", {})
	for k in saved_de:
		dungeon_entries[str(k)] = int(saved_de[k])
	dungeon_day = int(dict.get("dungeon_day", 0))

	bought_packs.clear()
	for sku in dict.get("bought_packs", []):
		bought_packs.append(str(sku))
	known_recipes.clear()
	for t in dict.get("known_recipes", []):
		known_recipes.append(int(t))
	shop_day = int(dict.get("shop_day", 0))
	shop_bought.clear()
	var saved_bought: Dictionary = dict.get("shop_bought", {})
	for k in saved_bought:
		shop_bought[str(k)] = int(saved_bought[k])

	items.clear()
	var saved_items: Dictionary = dict.get("items", {})
	for id in saved_items:
		items[str(id)] = int(saved_items[id])

	partner_copies.clear()
	var saved_copies: Dictionary = dict.get("partner_copies", {})
	for id in saved_copies:
		partner_copies[str(id)] = int(saved_copies[id])

	roster.clear()

	for entry in dict.get("roster", []):
		roster.append(OwnedPartner.from_dict(entry))

	formation = [-1, -1, -1, -1, -1, -1]

	var saved_formation = dict.get("formation", [])

	for i in range(mini(FORMATION_SIZE, saved_formation.size())):
		formation[i] = int(saved_formation[i])

	# Safety: the MC is always roster[0] in slot 0.
	if roster.is_empty() or roster[0].partner_id != MC_ID:
		push_error("GameState: save has no MC, starting a new account")
		return false
	formation[MC_SLOT] = 0

	# Codex: what's been found (older saves fill it from what they own)
	codex_partners = {}
	var saved_cp = dict.get("codex_partners", {})
	if saved_cp is Dictionary:
		codex_partners = saved_cp.duplicate(true)
	codex_treasures = {}
	var saved_ct = dict.get("codex_treasures", {})
	if saved_ct is Dictionary:
		for tid in saved_ct:
			codex_treasures[str(tid)] = int(saved_ct[tid])
	Codex.backfill()
	sect_bonus = {}
	var saved_sb = dict.get("sect_bonus", {})
	if saved_sb is Dictionary:
		for stat in saved_sb:
			sect_bonus[str(stat)] = float(saved_sb[stat])
	sect_shop = {}
	var saved_ss = dict.get("sect_shop", {})
	if saved_ss is Dictionary:
		sect_shop = saved_ss.duplicate(true)
	unlocks_seen = {}
	var saved_us = dict.get("unlocks_seen", {})
	if saved_us is Dictionary:
		unlocks_seen = saved_us.duplicate(true)
	# Older saves that already summoned don't get the first-summon bonus again
	first_summon_done = bool(dict.get("first_summon_done", roster.size() > 1))
	tutorials_done = {}
	var saved_td = dict.get("tutorials_done", {})
	if saved_td is Dictionary:
		tutorials_done = saved_td.duplicate(true)
	tutorials_pending = []
	for tid in dict.get("tutorials_pending", []):
		tutorials_pending.append(str(tid))
	ads_state = {}
	var saved_ads = dict.get("ads_state", {})
	if saved_ads is Dictionary:
		ads_state = saved_ads.duplicate(true)
	tutorial_step = {}
	var saved_ts = dict.get("tutorial_step", {})
	if saved_ts is Dictionary:
		for tid in saved_ts:
			tutorial_step[str(tid)] = int(saved_ts[tid])

	# Saves from the old 28-realm ladder: move everyone to the new indices
	_migrate_realms(int(dict.get("realm_count", 28)))

	# Make sure the MC's tier matches its stars.
	sync_mc_tier()

	print("GameState: loaded save with %d partners" % roster.size())

	_compute_offline(int(dict.get("last_seen", 0)))

	return true


## Old 28-realm index -> new 30-realm index (Dao Saint and Dao Ancestor
## were added at 20 and 23). Kept here so loading never depends on
## another file being updated first.
const OLD_28_TO_30 := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
	17, 18, 19, 21, 22, 24, 25, 26, 27, 28, 29]


## Converts a save made with the 28-realm ladder to the 30-realm one:
## realms, known recipes, realm pills and realm achievements.
func _migrate_realms(old_count: int) -> void:
	if old_count != 28 or Realms.count() != 30:
		return
	var map: Array = OLD_28_TO_30
	for p in roster:
		p.realm_index = int(map[clampi(p.realm_index, 0, map.size() - 1)])

	var recipes: Array[int] = []
	for t in known_recipes:
		recipes.append(int(map[clampi(t, 0, map.size() - 1)]))
	recipes.sort()
	known_recipes = recipes

	var moved := {}
	for id in items.keys():
		var key := str(id)
		if key.begins_with("realm_pill_"):
			var old := key.trim_prefix("realm_pill_").to_int()
			var new_id := ItemDB.realm_pill_id(int(map[clampi(old, 0, map.size() - 1)]))
			moved[new_id] = int(moved.get(new_id, 0)) + int(items[id])
			items.erase(id)
	for id in moved:
		items[id] = int(items.get(id, 0)) + int(moved[id])

	for i in claimed_achievements.size():
		var claimed := str(claimed_achievements[i])
		if claimed.begins_with("realm_"):
			var goal := claimed.trim_prefix("realm_").to_int()
			claimed_achievements[i] = "realm_%d" % int(map[clampi(goal, 0, map.size() - 1)])
	print("GameState: converted save to the 30-realm ladder")
	save_game()


## Wipes the save. Handy while testing.
func reset_account():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	current_stage = 1
	highest_stage = 1
	spirit_stones = 1000
	immortal_jade = 1000
	qi = 0
	starup_pills = 0
	summon_pity = 0
	known_recipes.clear()
	gear.clear()
	next_gear_uid = 1
	treasures.clear()
	next_treasure_uid = 1
	artifacts.clear()
	next_artifact_uid = 1
	lifebound.clear()
	lifebound_seeds.clear()
	expeditions.clear()
	expedition_offers.clear()
	pending_boss = 0
	stats.clear()
	claimed_achievements.clear()
	titles_owned.clear()
	title_worn = ""
	login_streak = 0
	login_streak_day = 0
	title_bonus = {}
	pending_card_choices.clear()
	missions = {}
	array_level = 1
	battle_array.clear()
	trials = {}
	tribulation = {}
	gods = {}
	fate_points = 0
	fallen_god = {}
	beast_rings = []
	soul_spirits = []
	beast_codex = {}
	codex_partners = {}
	codex_treasures = {}
	sect_bonus = {}
	sect_shop = {}
	unlocks_seen = {}
	first_summon_done = false
	tutorials_done = {}
	tutorials_pending = []
	tutorial_step = {}
	ads_state = {}
	beast_forest = {}
	mail.clear()
	next_mail_id = 1
	ranking_day = 0
	dungeon_progress.clear()
	dungeon_entries.clear()
	dungeon_day = 0
	shop_day = 0
	shop_bought.clear()
	pending_offline = {}
	items.clear()
	partner_copies.clear()
	mc_name = "Gay Min"
	mc_gender = "male"
	mc_path = Enums.Path.SWORD
	mc_rarity = Enums.Rarity.WHITE
	mc_created = false
	mc_rename_count = 0

	_create_new_account()

	roster_changed.emit()
	formation_changed.emit()
	currency_changed.emit()
	realm_changed.emit()
