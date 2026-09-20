class_name Treasures

# =========================================================
# Treasures. Each partner holds 3 (the Treasure slots on the
# partner panel).
#
#   Every treasure gives stats on its own.
#   Fill all 3 slots from the SAME SET for that set's effect.
#
# Dungeons are the main source, and duplicates merge up:
#   Common -> Uncommon -> Rare -> Epic -> Legendary
#   -> Mythical -> Heaven-Defying
#
# A treasure is a Dictionary in GameState.treasures:
#   {uid, id, grade, owner, locked}
# =========================================================

const GRADES := 7
const SLOTS := 3
## Copies of the same treasure and grade needed to make the next grade.
const MERGE_COST := 3

## Treasure Dust pays for everything treasures need.
const DUST_ID := "treasure_dust"
## Enhancement: +1 ... +10, each level adds this much of the base stat.
const MAX_LEVEL := 10
const ENHANCE_STEP := 0.08

## Stats and set effects multiply by this per grade
## (Common x1 ... Heaven-Defying x about 7.5).
const GRADE_STEP := 1.4

## Optional art: res://assets/treasures/<id>.png
const ART_FOLDER := "res://assets/treasures/"

## Sets: 3 treasures each. The effect needs all 3 slots filled
## with treasures of this set; its strength uses the WEAKEST of them.
const SETS := {
	"demon_suppression": {
		"name": "Demon Suppression", "color": Color("ffc95b"),
		"effect": "boss_dmg", "power": 15.0,
		"text": "+%s%% damage to bosses",
	},
	"soul_quelling": {
		"name": "Soul Quelling", "color": Color("b9a0ff"),
		"effect": "dmg_reduce", "power": 6.0,
		"text": "-%s%% damage taken",
	},
	"alchemy_dao": {
		"name": "Alchemy Dao", "color": Color("ff9a5a"),
		"effect": "craft_bonus", "power": 12.0,
		"text": "+%s%% pills per craft",
	},
	"heavenly_star": {
		"name": "Heavenly Star", "color": Color("9fb8ff"),
		"effect": "qi_bonus", "power": 14.0,
		"text": "+%s%% Qi from kills",
	},
	"lotus_sanctuary": {
		"name": "Lotus Sanctuary", "color": Color("ffb3d9"),
		"effect": "regen", "power": 2.5,
		"text": "Heals %s%% HP each turn",
	},
	"azure_dragon": {
		"name": "Azure Dragon", "color": Color("5ad4ff"),
		"effect": "shield", "power": 10.0,
		"text": "Battle-start shield worth %s%% HP",
	},
	"wind_flame": {
		"name": "Wind and Flame", "color": Color("7dffa8"),
		"effect": "energy", "power": 25.0,
		"text": "Start each battle with %s energy",
	},
	"netherworld": {
		"name": "Netherworld", "color": Color("c86bff"),
		"effect": "seal", "power": 8.0,
		"text": "%s%% chance to seal a foe (it loses its turn)",
	},
}

## Highest each set effect can reach.
const CAPS := {
	"boss_dmg": 90.0, "dmg_reduce": 30.0, "craft_bonus": 60.0, "qi_bonus": 80.0,
	"regen": 8.0, "shield": 45.0, "energy": 100.0, "seal": 35.0,
}

## Effects that work outside battle (only the MC's count).
const ECONOMY := ["qi_bonus", "craft_bonus", "drop_bonus"]

## [id] = {name, set, shape, stat, value, desc}
## Stats use the same keys as gear: atk_pct, hp_pct, def_pct, mdef_pct,
## crit, crit_dmg, eva, acc, energy.
const LIST := {
	# --- Demon Suppression ---
	"nine_story_pagoda": {
		"name": "Nine-Story Pagoda", "set": "demon_suppression", "shape": "pagoda",
		"stat": "atk_pct", "value": 5.0,
		"desc": "A pagoda that presses down on demons with nine floors of weight.",
	},
	"demon_mirror": {
		"name": "Demon-Revealing Mirror", "set": "demon_suppression", "shape": "mirror",
		"stat": "acc", "value": 4.0,
		"desc": "Nothing false survives its light.",
	},
	"purple_gourd": {
		"name": "Purple Gold Gourd", "set": "demon_suppression", "shape": "gourd",
		"stat": "mdef_pct", "value": 6.0,
		"desc": "Answer when it calls your name and you are already inside.",
	},

	# --- Soul Quelling ---
	"soul_bell": {
		"name": "Soul-Quelling Bell", "set": "soul_quelling", "shape": "bell",
		"stat": "def_pct", "value": 6.0,
		"desc": "Its toll steadies the spirit against any blow.",
	},
	"soul_lantern": {
		"name": "Soul-Guiding Lantern", "set": "soul_quelling", "shape": "lantern",
		"stat": "crit", "value": 2.0,
		"desc": "It lights the road for the dying.",
	},
	"yin_yang_wheel": {
		"name": "Yin-Yang Wheel", "set": "soul_quelling", "shape": "wheel",
		"stat": "mdef_pct", "value": 6.0,
		"desc": "Turning without end, giving back what it is given.",
	},

	# --- Alchemy Dao ---
	"dragon_cauldron": {
		"name": "Nine Dragon Cauldron", "set": "alchemy_dao", "shape": "cauldron",
		"stat": "hp_pct", "value": 6.0,
		"desc": "Nine dragons coil its rim, breathing the fire of refinement.",
	},
	"pill_furnace": {
		"name": "Jade Pill Furnace", "set": "alchemy_dao", "shape": "furnace",
		"stat": "def_pct", "value": 5.0,
		"desc": "A furnace of warm jade that never cracks.",
	},
	"medicine_gourd": {
		"name": "Medicine Gourd", "set": "alchemy_dao", "shape": "gourd",
		"stat": "hp_pct", "value": 5.0,
		"desc": "Always a pill left inside, however many you pour out.",
	},

	# --- Heavenly Star ---
	"star_chart": {
		"name": "Heaven Star Chart", "set": "heavenly_star", "shape": "chart",
		"stat": "crit_dmg", "value": 8.0,
		"desc": "Maps every current of heaven's Qi.",
	},
	"star_compass": {
		"name": "Star-Plucking Compass", "set": "heavenly_star", "shape": "compass",
		"stat": "acc", "value": 4.0,
		"desc": "Points at the star you mean to take.",
	},
	"astral_dial": {
		"name": "Astral Dial", "set": "heavenly_star", "shape": "dial",
		"stat": "eva", "value": 2.5,
		"desc": "Turns a breath ahead of the moment.",
	},

	# --- Lotus Sanctuary ---
	"lotus_platform": {
		"name": "Twelve-Grade Lotus Platform", "set": "lotus_sanctuary", "shape": "lotus",
		"stat": "hp_pct", "value": 7.0,
		"desc": "A seat of merit, twelve petals of accumulated virtue.",
	},
	"jade_ruyi": {
		"name": "Jade Ruyi", "set": "lotus_sanctuary", "shape": "ruyi",
		"stat": "atk_pct", "value": 5.0,
		"desc": "A sceptre of fortune, shaped like a wish granted.",
	},
	"merit_bead": {
		"name": "Merit Bead", "set": "lotus_sanctuary", "shape": "bead",
		"stat": "mdef_pct", "value": 5.0,
		"desc": "One bead for every life quietly saved.",
	},

	# --- Azure Dragon ---
	"dragon_scale": {
		"name": "Azure Dragon Scale", "set": "azure_dragon", "shape": "scale",
		"stat": "def_pct", "value": 6.0,
		"desc": "One scale, harder than a mountain's root.",
	},
	"dragon_pearl": {
		"name": "Dragon Pearl", "set": "azure_dragon", "shape": "pearl",
		"stat": "hp_pct", "value": 6.0,
		"desc": "The pearl a dragon guards beneath its chin.",
	},
	"dragon_flute": {
		"name": "Dragon Horn Flute", "set": "azure_dragon", "shape": "flute",
		"stat": "crit_dmg", "value": 7.0,
		"desc": "Its note calls thunderheads over still water.",
	},

	# --- Wind and Flame ---
	"banana_fan": {
		"name": "Banana Leaf Fan", "set": "wind_flame", "shape": "fan",
		"stat": "eva", "value": 2.5,
		"desc": "One wave raises the wind, a second puts out the sun.",
	},
	"flame_gourd": {
		"name": "Flame Gourd", "set": "wind_flame", "shape": "gourd",
		"stat": "atk_pct", "value": 5.0,
		"desc": "Uncork it downwind, never up.",
	},
	"cloud_sash": {
		"name": "Cloud Stride Sash", "set": "wind_flame", "shape": "sash",
		"stat": "energy", "value": 2.0,
		"desc": "Silk that finds footing on empty air.",
	},

	# --- Netherworld ---
	"ghost_banner": {
		"name": "Ghost Banner", "set": "netherworld", "shape": "banner",
		"stat": "atk_pct", "value": 6.0,
		"desc": "Ten thousand souls stitched into one dark cloth.",
	},
	"bone_whistle": {
		"name": "Bone Whistle", "set": "netherworld", "shape": "whistle",
		"stat": "crit", "value": 2.5,
		"desc": "Only the dead hear it clearly.",
	},
	"soul_chain": {
		"name": "Soul Chain", "set": "netherworld", "shape": "chain",
		"stat": "def_pct", "value": 5.0,
		"desc": "It binds what cannot be held.",
	},
}


static func get_def(id: String) -> Dictionary:
	return LIST.get(id, {})


static func set_def(set_id: String) -> Dictionary:
	return SETS.get(set_id, {})


static func item_name(t: Dictionary) -> String:
	return str(get_def(t["id"]).get("name", t["id"]))


static func set_of(t: Dictionary) -> String:
	return str(get_def(t["id"]).get("set", ""))


static func color_of(t: Dictionary) -> Color:
	return set_def(set_of(t)).get("color", Color.WHITE)


static func grade_color(grade: int) -> Color:
	return ItemDB.grade_color(grade)


static func grade_name(grade: int) -> String:
	return ItemDB.grade_name(grade)


static func grade_mult(grade: int) -> float:
	return pow(GRADE_STEP, grade)


## The stats one treasure gives, e.g. {"atk_pct": 9.8}
static func stats_of(t: Dictionary) -> Dictionary:
	var def := get_def(t["id"])
	if def.is_empty():
		return {}
	return {str(def["stat"]): float(def["value"]) * grade_mult(int(t["grade"])) * level_mult(t)}


static func stat_text(t: Dictionary) -> String:
	for stat in stats_of(t):
		return Gear.format_stat(stat, stats_of(t)[stat])
	return ""


## The set effect's strength at a grade (capped).
static func set_power(set_id: String, grade: int) -> float:
	var def := set_def(set_id)
	if def.is_empty():
		return 0.0
	return minf(float(def["power"]) * grade_mult(grade), float(CAPS.get(def["effect"], 999.0)))


static func set_effect_text(set_id: String, grade: int) -> String:
	var def := set_def(set_id)
	if def.is_empty():
		return ""
	return str(def["text"]) % String.num(snappedf(set_power(set_id, grade), 0.1))


# ---------------------------------------------------------
# OWNED TREASURES
# ---------------------------------------------------------

static func make(id: String, grade := 0) -> Dictionary:
	return {"uid": 0, "id": id, "grade": clampi(grade, 0, GRADES - 1),
		"level": 0, "owner": "", "locked": false}


## Enhancement multiplier for a treasure's stat.
static func level_mult(t: Dictionary) -> float:
	return 1.0 + int(t.get("level", 0)) * ENHANCE_STEP


## Dust for the next enhancement level.
static func enhance_cost(t: Dictionary) -> int:
	var level := int(t.get("level", 0))
	return int((20 + level * 25) * grade_mult(int(t["grade"])))


## Dust charged on top of the 3 copies when grading up.
static func merge_dust_cost(t: Dictionary) -> int:
	return int(120 * grade_mult(int(t["grade"])))


## Enhances once. Returns "" on success, otherwise the reason.
static func enhance(t: Dictionary) -> String:
	if int(t.get("level", 0)) >= MAX_LEVEL:
		return "Already at +%d." % MAX_LEVEL
	var cost := enhance_cost(t)
	if GameState.get_item_count(DUST_ID) < cost:
		return "Needs %s Treasure Dust." % NumberFormat.short(cost)
	GameState.spend_item(DUST_ID, cost)
	t["level"] = int(t.get("level", 0)) + 1
	GameState.treasures_changed()
	return ""


## A Treasure Vault drop: deeper floors give better grades.
static func random_drop(floor_n: int) -> Dictionary:
	var grade := int(sqrt(float(floor_n)) * 0.55)
	if randf() < 0.25:
		grade += 1
	return make(LIST.keys().pick_random(), clampi(grade, 0, GRADES - 1))


static func worn_by(partner_id: String) -> Array:
	return GameState.treasures_of(partner_id)


## Stats from a partner's treasures.
static func totals_for(partner_id: String) -> Dictionary:
	var totals := {}
	for t in worn_by(partner_id):
		var stats := stats_of(t)
		for stat in stats:
			totals[stat] = float(totals.get(stat, 0.0)) + stats[stat]
	return totals


## The set a partner has completed, or "" if the 3 slots aren't
## all the same set. Also returns the weakest grade among them.
static func active_set(partner_id: String) -> Dictionary:
	var worn := worn_by(partner_id)
	if worn.size() < SLOTS:
		return {}
	var set_id := set_of(worn[0])
	var lowest := int(worn[0]["grade"])
	for t in worn:
		if set_of(t) != set_id:
			return {}
		lowest = mini(lowest, int(t["grade"]))
	return {"set": set_id, "grade": lowest}


## Battle effects from a completed set: {effect: strength}
static func effects_for(partner_id: String) -> Dictionary:
	var active := active_set(partner_id)
	if active.is_empty():
		return {}
	var def := set_def(active["set"])
	var effect: String = def.get("effect", "")
	if effect == "" or effect in ECONOMY:
		return {}
	return {effect: set_power(active["set"], int(active["grade"]))}


## Qi, crafting and drop bonuses, from the MC's completed set.
static func economy_bonus(effect: String) -> float:
	var active := active_set(GameState.MC_ID)
	if active.is_empty():
		return 0.0
	if set_def(active["set"]).get("effect", "") != effect:
		return 0.0
	return set_power(active["set"], int(active["grade"]))


# ---------------------------------------------------------
# MERGING AND SALVAGE
# ---------------------------------------------------------

## Other copies of the same treasure and grade that could be merged.
static func merge_partners(t: Dictionary) -> Array:
	var out: Array = []
	for other in GameState.treasures:
		if other["uid"] == t["uid"] or other["id"] != t["id"]:
			continue
		if int(other["grade"]) != int(t["grade"]) or other.get("locked", false):
			continue
		if other.get("owner", "") != "":
			continue
		out.append(other)
	return out


## 3 of the same treasure and grade make 1 of the next grade.
static func merge(t: Dictionary) -> String:
	if int(t["grade"]) >= GRADES - 1:
		return "Already Heaven-Defying."
	var others := merge_partners(t)
	if others.size() < MERGE_COST - 1:
		return "Needs %d more of the same grade." % (MERGE_COST - 1 - others.size())
	var dust := merge_dust_cost(t)
	if GameState.get_item_count(DUST_ID) < dust:
		return "Needs %s Treasure Dust." % NumberFormat.short(dust)
	GameState.spend_item(DUST_ID, dust)
	for i in MERGE_COST - 1:
		GameState.remove_treasure(int(others[i]["uid"]))
	t["grade"] = int(t["grade"]) + 1
	GameState.treasures_changed()
	return ""


## Rough power score, for "something better is waiting".
static func score(t: Dictionary) -> float:
	var total := 0.0
	for stat in stats_of(t):
		total += stats_of(t)[stat] * float(Gear.SCORE_WEIGHTS.get(stat, 1.0))
	return total


## True when an unheld treasure would beat what's in that slot
## (or the slot is empty and you own one).
static func better_available(partner_id: String, slot: int) -> bool:
	var worn := GameState.treasures_of(partner_id)
	var current: Dictionary = worn[slot] if slot < worn.size() else {}
	var best := score(current) if not current.is_empty() else 0.0
	for t in GameState.treasures:
		if t.get("owner", "") != "":
			continue
		if score(t) > best:
			return true
	return false


## Salvaging grinds a treasure back into Treasure Dust.
static func salvage_value(t: Dictionary) -> int:
	return int(40 * grade_mult(int(t["grade"])) * level_mult(t))
