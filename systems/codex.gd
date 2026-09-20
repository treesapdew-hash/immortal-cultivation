class_name Codex

# =========================================================
# The Codex: every partner, spirit beast and treasure you've ever
# found, plus collection SETS whose completion gives a permanent
# bonus to your whole team (added to every partner's stats).
# Save as res://systems/codex.gd
#
# Discovered:
#   partners   GameState.codex_partners  {partner_id: true}
#   treasures  GameState.codex_treasures {treasure_id: best grade}
#   beasts     GameState.beast_codex     {species: {slain, tamed}}
#              (discovered = tamed at least once)
# Entries stay discovered even if you salvage them later.
#
# Sets (tuning below):
#   Partners  - a Legend set per character with several forms
#             - tier milestones (own N partners of a tier)
#   Beasts    - tame every beast of a hunting ground
#             - hunter milestones (beasts slain)
#   Treasures - find all 3 treasures of a treasure set
# Backgrounds for every entry are in codex_lore.gd.
# =========================================================

## A Legend set's bonus depends on the character's Dao.
const LEGEND_BONUS := {
	Enums.Path.SWORD: ["atk_pct", 1.5],
	Enums.Path.MARTIAL: ["hp_pct", 2.0],
	Enums.Path.MYSTIC: ["atk_pct", 1.5],
	Enums.Path.SPIRIT: ["def_pct", 2.0],
	Enums.Path.DIVINE: ["hp_pct", 2.0],
}

## [tier, partners needed, stat, value]
const TIER_MILESTONES := [
	[Enums.Rarity.BLUE, 10, "hp_pct", 1.0],
	[Enums.Rarity.GREEN, 10, "atk_pct", 1.0],
	[Enums.Rarity.PURPLE, 10, "hp_pct", 1.5],
	[Enums.Rarity.PURPLE, 25, "atk_pct", 1.5],
	[Enums.Rarity.RED, 5, "atk_pct", 2.0],
	[Enums.Rarity.RED, 15, "hp_pct", 2.0],
	[Enums.Rarity.RED, 30, "crit", 1.0],
]

## Hunting ground: [stat, value] for taming all its beasts.
const GROUND_BONUS := {
	"misty_woods": ["hp_pct", 1.5],
	"thunder_valley": ["atk_pct", 1.5],
	"frost_peaks": ["def_pct", 2.0],
	"abyssal_marsh": ["hp_pct", 2.5],
	"primordial_wilds": ["atk_pct", 3.0],
}

## [beasts slain, stat, value]
const HUNTER_MILESTONES := [
	[50, "hp_pct", 1.0],
	[200, "atk_pct", 1.0],
	[1000, "crit", 1.0],
]

## Treasure set: [stat, value] for finding all 3 of its treasures.
const TREASURE_BONUS := {
	"demon_suppression": ["atk_pct", 1.5],
	"soul_quelling": ["def_pct", 1.5],
	"alchemy_dao": ["hp_pct", 1.5],
	"heavenly_star": ["crit", 0.5],
	"lotus_sanctuary": ["hp_pct", 1.5],
	"azure_dragon": ["def_pct", 1.5],
	"wind_flame": ["atk_pct", 1.5],
	"netherworld": ["crit", 0.5],
}

const STAT_LABELS := {"hp_pct": "HP", "atk_pct": "ATK", "def_pct": "DEF", "crit": "Crit"}


# ---------------------------------------------------------
# DISCOVERY
# ---------------------------------------------------------

static func discover_partner(partner_id: String) -> void:
	if partner_id == GameState.MC_ID or partner_id == "":
		return
	GameState.codex_partners[partner_id] = true


static func discover_treasure(id: String, grade: int) -> void:
	GameState.codex_treasures[id] = maxi(int(GameState.codex_treasures.get(id, -1)), grade)


static func has_partner(partner_id: String) -> bool:
	return GameState.codex_partners.has(partner_id)


static func has_treasure(id: String) -> bool:
	return GameState.codex_treasures.has(id)


static func beast_tamed(species: String) -> bool:
	return int(Beasts.codex_entry(species).get("tamed", 0)) > 0


static func beast_slain(species: String) -> int:
	return int(Beasts.codex_entry(species).get("slain", 0))


## Fills the Codex from what the player already owns (old saves).
static func backfill() -> void:
	for p in GameState.roster:
		discover_partner(p.partner_id)
	for t in GameState.treasures:
		discover_treasure(str(t.get("id", "")), int(t.get("grade", 0)))


# ---------------------------------------------------------
# SETS
# ---------------------------------------------------------
# A set is {id, name, desc, have, need, stat, value, done}.

static func _make_set(id: String, set_name: String, desc: String, have: int, need: int, bonus: Array) -> Dictionary:
	return {"id": id, "name": set_name, "desc": desc, "have": mini(have, need), "need": need,
		"stat": str(bonus[0]), "value": float(bonus[1]), "done": have >= need}


static func partner_sets() -> Array:
	var out: Array = []
	# Legend sets: every form of one character
	for fam in PartnerSkills.FAMILIES:
		var entry: Array = PartnerSkills.FAMILIES[fam]
		var members: Array = []
		for id in entry[5]:
			if PartnerDatabase.has_partner(str(id)):
				members.append(str(id))
		if members.size() < 2:
			continue
		var have := 0
		for id in members:
			if has_partner(id):
				have += 1
		var first = PartnerDatabase.get_partner(members[0])
		var who := str(first.display_name) if first != null else str(fam).capitalize()
		var bonus: Array = LEGEND_BONUS.get(int(entry[4]), ["hp_pct", 1.5])
		out.append(_make_set("legend_" + str(fam), "Path of %s" % who,
			"Collect all %d forms of %s." % [members.size(), who], have, members.size(), bonus))
	# Tier milestones
	var by_tier := {}
	for id in GameState.codex_partners:
		var data = PartnerDatabase.get_partner(str(id))
		if data != null:
			by_tier[int(data.rarity)] = int(by_tier.get(int(data.rarity), 0)) + 1
	for m in TIER_MILESTONES:
		var tier_name := str(Enums.Rarity.keys()[int(m[0])]).capitalize()
		out.append(_make_set("tier_%d_%d" % [int(m[0]), int(m[1])], "%s Collector %d" % [tier_name, int(m[1])],
			"Discover %d %s partners." % [int(m[1]), tier_name], int(by_tier.get(int(m[0]), 0)), int(m[1]),
			[m[2], m[3]]))
	return out


static func beast_sets() -> Array:
	var out: Array = []
	for g in Beasts.GROUNDS:
		var species: Array = g["species"]
		var have := 0
		for sp in species:
			if beast_tamed(str(sp)):
				have += 1
		out.append(_make_set("ground_" + str(g["id"]), "Beasts of %s" % g["name"],
			"Tame every spirit beast of %s." % g["name"], have, species.size(),
			GROUND_BONUS.get(str(g["id"]), ["hp_pct", 1.0])))
	var slain := 0
	for sp in Beasts.SPECIES:
		slain += beast_slain(str(sp))
	for m in HUNTER_MILESTONES:
		out.append(_make_set("hunter_%d" % int(m[0]), "Beast Hunter %d" % int(m[0]),
			"Slay %d spirit beasts." % int(m[0]), slain, int(m[0]), [m[1], m[2]]))
	return out


static func treasure_sets() -> Array:
	var out: Array = []
	for set_id in Treasures.SETS:
		var members: Array = []
		for id in Treasures.LIST:
			if str(Treasures.LIST[id]["set"]) == str(set_id):
				members.append(str(id))
		var have := 0
		for id in members:
			if has_treasure(id):
				have += 1
		var set_name := str(Treasures.SETS[set_id]["name"])
		out.append(_make_set("treasure_" + str(set_id), "%s Relics" % set_name,
			"Find all %d treasures of the %s set." % [members.size(), set_name], have, members.size(),
			TREASURE_BONUS.get(str(set_id), ["hp_pct", 1.0])))
	return out


# ---------------------------------------------------------
# BONUSES
# ---------------------------------------------------------

static var _cache := {}
static var _cache_key := ""


## Total bonus from every completed set, in gear stat keys.
## Added to every partner's stats (OwnedPartner._gear).
static func totals() -> Dictionary:
	var key := _state_key()
	if key == _cache_key:
		return _cache
	var out := {}
	for group in [partner_sets(), beast_sets(), treasure_sets()]:
		for s in group:
			if bool(s["done"]):
				out[s["stat"]] = float(out.get(s["stat"], 0.0)) + float(s["value"])
	_cache = out
	_cache_key = key
	return out


## Changes whenever anything that affects the sets changes.
static func _state_key() -> String:
	var tamed := 0
	var slain := 0
	for sp in GameState.beast_codex:
		tamed += int(GameState.beast_codex[sp].get("tamed", 0))
		slain += int(GameState.beast_codex[sp].get("slain", 0))
	return "%d|%d|%d|%d" % [GameState.codex_partners.size(), GameState.codex_treasures.size(), tamed, slain]


## "+4% HP, +3% ATK, +1% Crit"
static func bonus_text(bonus: Dictionary) -> String:
	if bonus.is_empty():
		return "None yet"
	var parts := PackedStringArray()
	for stat in ["hp_pct", "atk_pct", "def_pct", "crit"]:
		if bonus.has(stat):
			parts.append("+%s%% %s" % [str(snappedf(float(bonus[stat]), 0.1)).trim_suffix(".0"), STAT_LABELS[stat]])
	return ", ".join(parts)


static func set_bonus_text(s: Dictionary) -> String:
	return "+%s%% %s" % [str(snappedf(float(s["value"]), 0.1)).trim_suffix(".0"),
		STAT_LABELS.get(str(s["stat"]), str(s["stat"]))]
