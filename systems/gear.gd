class_name Gear

# =========================================================
# Equipment. A piece of gear is a Dictionary saved in
# GameState.gear:
#   uid     unique number
#   slot    0 Weapon, 1 Armor, 2 Ring, 3 Boots
#   tier    0 White ... 6 Prismatic   (artifact class)
#   sub     0 Low, 1 Mid, 2 High, 3 Peak
#   set     set id (see SETS)
#   refine  0 ... 100
#   bonus   [[stat, roll], ...]  extra lines, roll 0.8 - 1.2
#   owner   partner id wearing it, or ""
#   locked  true = protected from merge and salvage
#
# Grade index g = tier * 4 + sub (0 ... 27). Each step is ~20% stronger.
# =========================================================

const SLOT_NAMES := ["Weapon", "Armor", "Ring", "Boots"]
const TIER_NAMES := ["Mortal Tool", "Magic Tool", "Spirit Artifact", "Magic Treasure",
	"Ancient Treasure", "Immortal Artifact", "Divine Artifact"]
const SUB_NAMES := ["Low-grade", "Mid-grade", "High-grade", "Peak-grade"]
const GRADES := 28
const MAX_REFINE := 100

## Bonus lines per tier (White ... Prismatic)
const BONUS_LINES := [0, 1, 2, 2, 3, 3, 4]

## Readable stat names
const STAT_NAMES := {
	"atk": "ATK", "atk_pct": "ATK", "hp": "HP", "hp_pct": "HP",
	"def": "DEF", "def_pct": "DEF", "mdef": "MDEF", "mdef_pct": "MDEF",
	"crit": "Crit", "crit_dmg": "Crit DMG", "eva": "Evasion",
	"acc": "Accuracy", "energy": "Energy Regen",
}
const PERCENT_STATS := ["atk_pct", "hp_pct", "def_pct", "mdef_pct", "crit", "crit_dmg", "eva", "acc"]
const BONUS_POOL := ["atk_pct", "hp_pct", "def_pct", "mdef_pct", "crit", "crit_dmg", "eva", "acc", "energy"]

## Sets: 2-piece stats, 4-piece effect, linked Dao (+50% when it matches).
## Effects: stat-type 4-pieces add to stats; the rest are handled in battle.
const SETS := {
	"azure_cloud": {
		"name": "Azure Cloud", "dao": Enums.Path.SWORD, "color": Color("7fd4ff"),
		"shapes": ["sword", "robe", "gem_ring", "boot"],
		"pieces": ["Cloudpiercer Sword", "Azure Cloud Robe", "Azure Cloud Ring", "Cloudstep Boots"],
		"two": {"atk_pct": 8.0}, "four_stats": {"crit_dmg": 30.0},
		"four_text": "Crits deal +{crit_dmg}% damage",
	},
	"iron_mountain": {
		"name": "Iron Mountain", "dao": Enums.Path.MARTIAL, "color": Color("c9a27a"),
		"shapes": ["axe", "plate", "seal_ring", "boot"],
		"pieces": ["Mountain-Splitter Axe", "Iron Mountain Plate", "Iron Mountain Band", "Stonewalker Boots"],
		"two": {"def_pct": 10.0}, "effect": "shield", "power": 15.0,
		"four_text": "Start each battle with a shield worth {v}% HP",
	},
	"crimson_phoenix": {
		"name": "Crimson Phoenix", "dao": Enums.Path.DIVINE, "color": Color("ff6b4a"),
		"shapes": ["spear", "cloak", "gem_ring", "slipper"],
		"pieces": ["Phoenix Plume Spear", "Crimson Phoenix Mantle", "Phoenix Flame Ring", "Emberwing Boots"],
		"two": {"hp_pct": 10.0}, "effect": "revive", "power": 30.0,
		"four_text": "Nirvana: revive once per battle at {v}% HP",
	},
	"thunder_tribulation": {
		"name": "Thunder Tribulation", "dao": Enums.Path.MYSTIC, "color": Color("b8a4ff"),
		"shapes": ["halberd", "robe", "seal_ring", "boot"],
		"pieces": ["Tribulation Halberd", "Thunderclap Robe", "Lightning Seal Ring", "Stormstride Boots"],
		"two": {"crit_dmg": 10.0}, "effect": "lightning", "power": 20.0,
		"four_text": "{v}% chance per attack to call lightning for +60% damage",
	},
	"jade_lotus": {
		"name": "Jade Lotus", "dao": Enums.Path.SPIRIT, "color": Color("7dffa8"),
		"shapes": ["fan", "robe", "gem_ring", "slipper"],
		"pieces": ["Jade Lotus Fan", "Lotus Silk Robe", "Jade Lotus Ring", "Lotus Petal Slippers"],
		"two": {"energy": 3.0}, "effect": "energy", "power": 50.0,
		"four_text": "Start each battle with {v} Energy",
	},
	"nether_shadow": {
		"name": "Nether Shadow", "dao": Enums.Path.SWORD, "color": Color("9a6bff"),
		"shapes": ["dagger", "cloak", "seal_ring", "slipper"],
		"pieces": ["Nether Fang Dagger", "Shadowveil Cloak", "Nether Shadow Ring", "Silent Step Boots"],
		"two": {"crit": 6.0}, "effect": "execute", "power": 25.0,
		"four_text": "+{v}% damage to targets below 50% HP",
	},
	"frost_soul": {
		"name": "Frost Soul", "dao": Enums.Path.MYSTIC, "color": Color("a8e8ff"),
		"shapes": ["staff", "robe", "gem_ring", "boot"],
		"pieces": ["Frost Soul Staff", "Glacier Robe", "Frost Soul Ring", "Snowdrift Boots"],
		"two": {"mdef_pct": 10.0}, "effect": "freeze", "power": 15.0,
		"four_text": "{v}% chance to freeze the target (skips its next turn)",
	},
	"five_elements": {
		"name": "Five Elements", "dao": Enums.Path.DIVINE, "color": Color("f2c85b"),
		"shapes": ["seal", "plate", "seal_ring", "boot"],
		"pieces": ["Five Elements Seal", "Five Elements Robe", "Five Elements Ring", "Five Elements Boots"],
		"two": {"atk_pct": 4.0, "hp_pct": 4.0, "def_pct": 4.0},
		"four_stats": {"atk_pct": 10.0, "hp_pct": 10.0, "def_pct": 10.0},
		"four_text": "+{atk_pct}% ATK, HP and DEF",
	},
}

## A matching Dao makes set bonuses this much stronger.
const DAO_MATCH_MULT := 1.5

## Set bonuses grow with grade: x(1 + g x SET_GRADE_STEP).
## Low Mortal Tool = x1.0 ... Peak Divine Artifact = about x3.0.
const SET_GRADE_STEP := 0.075

## Highest value each 4-piece effect can reach.
const EFFECT_CAPS := {
	"shield": 45.0, "revive": 90.0, "lightning": 60.0,
	"energy": 100.0, "execute": 100.0, "freeze": 45.0,
}


# ---------------------------------------------------------
# NAMES AND LOOKS
# ---------------------------------------------------------

static func grade_index(item: Dictionary) -> int:
	return int(item["tier"]) * 4 + int(item["sub"])


static func grade_text(item: Dictionary) -> String:
	return "%s %s" % [SUB_NAMES[int(item["sub"])], TIER_NAMES[int(item["tier"])]]


static func item_name(item: Dictionary) -> String:
	var s: Dictionary = SETS.get(item["set"], {})
	var pieces: Array = s.get("pieces", SLOT_NAMES)
	return pieces[int(item["slot"])]


## Tier colour, matching card tiers.
static func tier_color(item: Dictionary) -> Color:
	return ItemDB.grade_color(int(item["tier"]))


# ---------------------------------------------------------
# STATS
# ---------------------------------------------------------

static func _flat(g: int) -> float:
	return pow(1.25, g)


static func _pct(g: int) -> float:
	return pow(1.1, g)


## Main stats of a piece, before refining: {stat: value}
static func main_stats(slot: int, g: int) -> Dictionary:
	match slot:
		0:
			return {"atk": 15.0 * _flat(g), "atk_pct": 4.0 * _pct(g)}
		1:
			return {"hp": 120.0 * _flat(g), "def": 6.0 * _flat(g), "hp_pct": 3.0 * _pct(g)}
		2:
			return {"crit": 1.0 + 0.35 * g, "crit_dmg": 2.0 + 0.8 * g, "mdef": 6.0 * _flat(g)}
		_:
			return {"hp": 60.0 * _flat(g), "eva": 0.5 + 0.2 * g, "def_pct": 2.0 * _pct(g)}


static func bonus_value(stat: String, g: int, roll: float) -> float:
	var v := 0.0
	match stat:
		"atk_pct", "hp_pct", "def_pct", "mdef_pct":
			v = 1.5 * _pct(g)
		"crit", "acc":
			v = 0.5 + 0.15 * g
		"crit_dmg":
			v = 1.0 + 0.5 * g
		"eva":
			v = 0.3 + 0.1 * g
		"energy":
			v = 1.0 + g / 4.0
	return v * roll


## Refining boosts flat and % stats by 3% per level, and
## crit/evasion/accuracy/energy by 1% per level.
static func refine_mult(stat: String, refine_level: int) -> float:
	if stat in ["crit", "crit_dmg", "eva", "acc", "energy"]:
		return 1.0 + refine_level * 0.01
	return 1.0 + refine_level * 0.03


## Every stat a piece gives, refining included.
static func item_stats(item: Dictionary) -> Dictionary:
	var g := grade_index(item)
	var r := int(item.get("refine", 0))
	var out := {}
	var main := main_stats(int(item["slot"]), g)
	for stat in main:
		out[stat] = float(out.get(stat, 0.0)) + main[stat] * refine_mult(stat, r)
	for line in item.get("bonus", []):
		var stat: String = line[0]
		out[stat] = float(out.get(stat, 0.0)) + bonus_value(stat, g, float(line[1])) * refine_mult(stat, r)
	return out


static func format_stat(stat: String, value: float) -> String:
	var label: String = STAT_NAMES.get(stat, stat)
	if stat in PERCENT_STATS:
		return "%s +%s%%" % [label, String.num(snappedf(value, 0.1))]
	return "%s +%s" % [label, NumberFormat.short(int(value))]


# ---------------------------------------------------------
# SETS ON A PARTNER
# ---------------------------------------------------------

static func worn_by(partner_id: String) -> Array:
	var out: Array = []
	for item in GameState.gear:
		if item.get("owner", "") == partner_id:
			out.append(item)
	return out


static func dao_of(partner_id: String) -> int:
	if partner_id == GameState.MC_ID:
		return GameState.mc_path
	var data = PartnerDatabase.get_partner(partner_id)
	return int(data.path) if data != null else -1


static func set_grade_mult(g: int) -> float:
	return 1.0 + g * SET_GRADE_STEP


## {set id: pieces worn}
static func set_counts(partner_id: String) -> Dictionary:
	var counts := {}
	for item in worn_by(partner_id):
		counts[item["set"]] = int(counts.get(item["set"], 0)) + 1
	return counts


## {set id: grade indices of the worn pieces, best first}
static func set_grades(partner_id: String) -> Dictionary:
	var grades := {}
	for item in worn_by(partner_id):
		if not grades.has(item["set"]):
			grades[item["set"]] = []
		grades[item["set"]].append(grade_index(item))
	for set_id in grades:
		grades[set_id].sort()
		grades[set_id].reverse()
	return grades


## 2-piece stats at a grade: {stat: value}
static func two_piece(set_id: String, g: int, dao_match := false) -> Dictionary:
	var def: Dictionary = SETS.get(set_id, {})
	var out := {}
	var mult := set_grade_mult(g) * (DAO_MATCH_MULT if dao_match else 1.0)
	for stat in def.get("two", {}):
		out[stat] = def["two"][stat] * mult
	return out


## 4-piece stats (stat-type sets) at a grade.
static func four_piece_stats(set_id: String, g: int, dao_match := false) -> Dictionary:
	var def: Dictionary = SETS.get(set_id, {})
	var out := {}
	var mult := set_grade_mult(g) * (DAO_MATCH_MULT if dao_match else 1.0)
	for stat in def.get("four_stats", {}):
		out[stat] = def["four_stats"][stat] * mult
	return out


## 4-piece effect strength at a grade (capped).
static func four_piece_power(set_id: String, g: int, dao_match := false) -> float:
	var def: Dictionary = SETS.get(set_id, {})
	if not def.has("effect"):
		return 0.0
	var mult := set_grade_mult(g) * (DAO_MATCH_MULT if dao_match else 1.0)
	return minf(float(def["power"]) * mult, float(EFFECT_CAPS.get(def["effect"], 999.0)))


## "Start each battle with a shield worth 22% HP" at a grade.
static func four_piece_text(set_id: String, g: int, dao_match := false) -> String:
	var def: Dictionary = SETS.get(set_id, {})
	var text: String = def.get("four_text", "")
	if def.has("effect"):
		text = text.replace("{v}", String.num(snappedf(four_piece_power(set_id, g, dao_match), 0.1)))
	var stats := four_piece_stats(set_id, g, dao_match)
	for stat in stats:
		text = text.replace("{%s}" % stat, String.num(snappedf(stats[stat], 0.1)))
	return text


## Total stats from gear and set bonuses.
## A set bonus uses the weakest piece that counts toward it.
static func totals_for(partner_id: String) -> Dictionary:
	var t := {}
	for item in worn_by(partner_id):
		var s := item_stats(item)
		for stat in s:
			t[stat] = float(t.get(stat, 0.0)) + s[stat]

	var dao := dao_of(partner_id)
	var grades := set_grades(partner_id)
	for set_id in grades:
		var def: Dictionary = SETS.get(set_id, {})
		if def.is_empty():
			continue
		var list: Array = grades[set_id]
		var match_dao := int(def["dao"]) == dao
		if list.size() >= 2:
			var two := two_piece(set_id, list[1], match_dao)
			for stat in two:
				t[stat] = float(t.get(stat, 0.0)) + two[stat]
		if list.size() >= 4:
			var four := four_piece_stats(set_id, list[3], match_dao)
			for stat in four:
				t[stat] = float(t.get(stat, 0.0)) + four[stat]
	return t


## Battle effects from 4-piece sets: {effect: strength}
static func effects_for(partner_id: String) -> Dictionary:
	var fx := {}
	var dao := dao_of(partner_id)
	var grades := set_grades(partner_id)
	for set_id in grades:
		var def: Dictionary = SETS.get(set_id, {})
		var list: Array = grades[set_id]
		if list.size() >= 4 and def.has("effect"):
			fx[def["effect"]] = four_piece_power(set_id, list[3], int(def["dao"]) == dao)
	return fx


# ---------------------------------------------------------
# MAKING GEAR
# ---------------------------------------------------------

static func make(slot: int, g: int, set_id := "") -> Dictionary:
	g = clampi(g, 0, GRADES - 1)
	if set_id == "":
		set_id = SETS.keys().pick_random()
	var tier := int(g / 4.0)
	var bonus: Array = []
	var pool := BONUS_POOL.duplicate()
	pool.shuffle()
	for i in BONUS_LINES[tier]:
		bonus.append([pool[i], snappedf(randf_range(0.8, 1.2), 0.01)])
	return {
		"uid": 0, "slot": slot, "tier": tier, "sub": g % 4, "set": set_id,
		"refine": 0, "bonus": bonus, "owner": "", "locked": false,
	}


## Grade dropped on an Armory floor (with a little randomness).
static func grade_for_floor(floor_n: int) -> int:
	var g := int(sqrt(float(floor_n)) * 1.9) + randi_range(-1, 1)
	return clampi(g, 0, GRADES - 1)


static func random_drop(floor_n: int) -> Dictionary:
	return make(randi_range(0, 3), grade_for_floor(floor_n))


# ---------------------------------------------------------
# REFINE, MERGE, SALVAGE
# ---------------------------------------------------------

## Refining past this level needs Heavenly Refining Ore.
const HEAVENLY_FROM := 50
const ORE_ID := "refining_ore"
const HEAVENLY_ORE_ID := "heavenly_ore"


## Cost of the next refine: {"stones": n, "ore": n, "ore_id": id}
static func refine_cost(item: Dictionary) -> Dictionary:
	var r := int(item.get("refine", 0))
	var g := grade_index(item)
	var heavenly := r >= HEAVENLY_FROM
	var ore_id := HEAVENLY_ORE_ID if heavenly else ORE_ID
	# Steeper the higher you go, and every 10 levels costs a step more
	var step := 1.0 + int(r / 10.0) * 0.35
	var ore := 1 + int(r / 4.0) + int(g / 3.0)
	if heavenly:
		ore = 1 + int((r - HEAVENLY_FROM) / 6.0) + int(g / 6.0)
	return {
		"stones": int(200.0 * pow(1.075, r) * step * (1.0 + g * 0.2)),
		"ore": ore,
		"ore_id": ore_id,
	}


## Refines once. Returns "" on success, otherwise the reason.
static func refine(item: Dictionary) -> String:
	if int(item.get("refine", 0)) >= MAX_REFINE:
		return "Already at +%d." % MAX_REFINE
	var cost := refine_cost(item)
	var ore_name: String = ItemDB.get_item(cost["ore_id"]).get("name", "Ore")
	if GameState.spirit_stones < cost["stones"]:
		return "Not enough Spirit Stones."
	if GameState.get_item_count(cost["ore_id"]) < cost["ore"]:
		return "Not enough %s." % ore_name
	GameState.spend_spirit_stones(cost["stones"])
	GameState.spend_item(cost["ore_id"], cost["ore"])
	item["refine"] = int(item.get("refine", 0)) + 1
	GameState.gear_changed()
	return ""


## Other pieces that can be merged with this one: same slot and
## grade, not worn, not locked.
static func merge_partners(item: Dictionary) -> Array:
	var out: Array = []
	for other in GameState.gear:
		if other["uid"] == item["uid"]:
			continue
		if other["slot"] == item["slot"] and grade_index(other) == grade_index(item) \
				and other.get("owner", "") == "" and not other.get("locked", false):
			out.append(other)
	out.sort_custom(func(a, b): return int(a["refine"]) < int(b["refine"]))
	return out


## 3 of the same slot and grade -> 1 of the next grade. Keeps this
## piece's set and bonus lines (adds one if the new tier allows),
## and the highest refine level of the three.
static func merge(item: Dictionary) -> String:
	if grade_index(item) >= GRADES - 1:
		return "Already the highest grade."
	var others := merge_partners(item)
	if others.size() < 2:
		return "Needs 2 more of the same slot and grade."
	var used: Array = [others[0], others[1]]
	var best := int(item["refine"])
	for o in used:
		best = maxi(best, int(o["refine"]))
		GameState.remove_gear(o["uid"])

	var g := grade_index(item) + 1
	item["tier"] = int(g / 4.0)
	item["sub"] = g % 4
	item["refine"] = best
	var lines: Array = item["bonus"]
	while lines.size() < BONUS_LINES[item["tier"]]:
		var taken: Array = lines.map(func(l): return l[0])
		var pool := BONUS_POOL.filter(func(s): return not s in taken)
		lines.append([pool.pick_random(), snappedf(randf_range(0.8, 1.2), 0.01)])
	GameState.gear_changed()
	return ""


## Rough power score, used to compare two pieces.
const SCORE_WEIGHTS := {
	"atk": 2.0, "hp": 0.1, "def": 1.0, "mdef": 1.0,
	"atk_pct": 30.0, "hp_pct": 25.0, "def_pct": 20.0, "mdef_pct": 20.0,
	"crit": 40.0, "crit_dmg": 12.0, "eva": 30.0, "acc": 12.0, "energy": 25.0,
}


static func score(item: Dictionary) -> float:
	var total := 0.0
	var stats := item_stats(item)
	for stat in stats:
		total += stats[stat] * float(SCORE_WEIGHTS.get(stat, 1.0))
	return total


## Is there an unworn piece for this slot that beats what's equipped?
static func better_available(partner_id: String, slot: int) -> bool:
	var equipped := GameState.gear_in_slot(partner_id, slot)
	var best := score(equipped) if not equipped.is_empty() else 0.0
	for item in GameState.gear:
		if int(item["slot"]) != slot or item.get("owner", "") != "":
			continue
		if score(item) > best:
			return true
	return false


## Pieces whose refine level can be moved onto this one.
static func transfer_sources(item: Dictionary) -> Array:
	var out: Array = []
	for other in GameState.gear:
		if other["uid"] == item["uid"] or int(other["slot"]) != int(item["slot"]):
			continue
		if other.get("locked", false) or int(other.get("refine", 0)) <= 0:
			continue
		out.append(other)
	out.sort_custom(func(a, b): return int(a["refine"]) > int(b["refine"]))
	return out


## Stones charged for moving refinement across.
static func transfer_cost(source: Dictionary) -> int:
	return int(500 * int(source.get("refine", 0)) * (1 + grade_index(source) * 0.2))


## Moves the source's refine level onto the target. The source is used up.
static func transfer_refine(target: Dictionary, source: Dictionary) -> String:
	if int(source.get("refine", 0)) <= int(target.get("refine", 0)):
		return "That piece isn't refined higher."
	var cost := transfer_cost(source)
	if GameState.spirit_stones < cost:
		return "Not enough Spirit Stones (%s)." % NumberFormat.short(cost)
	GameState.spend_spirit_stones(cost)
	target["refine"] = int(source["refine"])
	GameState.remove_gear(int(source["uid"]))
	GameState.gear_changed()
	return ""


## True when the wearer has all 4 pieces of this piece's set.
static func is_full_set(item: Dictionary) -> bool:
	var wearer: String = item.get("owner", "")
	if wearer == "":
		return false
	return int(set_counts(wearer).get(item["set"], 0)) >= 4


## "Azure Cloud 4/4 · Frost Soul 2/4" for a partner (best first).
static func set_summary(partner_id: String) -> Array:
	var out: Array = []
	var counts := set_counts(partner_id)
	for set_id in counts:
		var def: Dictionary = SETS.get(set_id, {})
		out.append({"name": def.get("name", set_id), "count": counts[set_id],
			"color": def.get("color", Color.WHITE), "full": int(counts[set_id]) >= 4})
	out.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	return out


## What a set is actually giving a partner right now, e.g.
## "+11% Crit DMG  ·  22% chance to call lightning".
static func active_bonus_text(partner_id: String, set_id: String) -> String:
	var grades: Array = set_grades(partner_id).get(set_id, [])
	var def: Dictionary = SETS.get(set_id, {})
	if grades.is_empty() or def.is_empty():
		return ""
	var match_dao := int(def["dao"]) == dao_of(partner_id)
	var parts := PackedStringArray()

	if grades.size() >= 2:
		var two := two_piece(set_id, grades[1], match_dao)
		for stat in two:
			parts.append(format_stat(stat, two[stat]))
	if grades.size() >= 4:
		parts.append(four_piece_text(set_id, grades[3], match_dao))
	return "  ·  ".join(parts)


## Short labels for the 4-piece effects, for tight spaces.
const EFFECT_SHORT := {
	"shield": "Shield %s%% HP", "revive": "Revive %s%% HP", "lightning": "Lightning %s%%",
	"energy": "Start Energy %s", "execute": "Execute +%s%%", "freeze": "Freeze %s%%",
}


## Compact version of active_bonus_text, e.g.
## "Crit DMG +14.8%  ·  Lightning 29.6%".
static func active_bonus_short(partner_id: String, set_id: String) -> String:
	var grades: Array = set_grades(partner_id).get(set_id, [])
	var def: Dictionary = SETS.get(set_id, {})
	if grades.is_empty() or def.is_empty():
		return ""
	var match_dao := int(def["dao"]) == dao_of(partner_id)
	var parts := PackedStringArray()

	if grades.size() >= 2:
		var two := two_piece(set_id, grades[1], match_dao)
		for stat in two:
			parts.append(format_stat(stat, two[stat]))
	if grades.size() >= 4:
		if def.has("effect"):
			var power := four_piece_power(set_id, grades[3], match_dao)
			parts.append(str(EFFECT_SHORT.get(def["effect"], "%s")) % String.num(snappedf(power, 0.1)))
		for stat in four_piece_stats(set_id, grades[3], match_dao):
			parts.append(format_stat(stat, four_piece_stats(set_id, grades[3], match_dao)[stat]))
	return "  ·  ".join(parts)


## Refining Ore from salvaging a piece.
static func salvage_value(item: Dictionary) -> int:
	return 2 + grade_index(item) * 2 + int(int(item.get("refine", 0)) / 2.0)
