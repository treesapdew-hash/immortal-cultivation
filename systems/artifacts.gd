class_name Artifacts

# =========================================================
# Artifacts. 3 per partner, in the Artifact slots.
#
# Where gear gives stats and treasures give set effects,
# an artifact gives ONE TRAIT: a rule that changes how the
# partner fights. Artifacts are forged in the Spirit Forge
# from Artifact Cores, not looted.
#
# The trait is decided at the forge and can never be changed,
# so forging is a gamble. Tempering raises an artifact's grade,
# and unwanted artifacts are salvaged back into cores.
#
# An artifact is a Dictionary in GameState.artifacts:
#   {uid, trait, grade, owner, locked}
# =========================================================

const GRADES := 7
const SLOTS := 3

## Materials
const CORE_ID := "artifact_core"

## Trait power multiplies by this per grade
## (Common x1 ... Heaven-Defying x about 5.3).
const GRADE_STEP := 1.32

## Forging
const FORGE_CORE_COST := 30
## Tempering (one grade up) gets steeply harder: x TEMPER_STEP each grade.
## Common->Uncommon 80, Legendary->Mythical about 26K.
const TEMPER_CORE_COST := 80
const TEMPER_STEP := 3.4
## Salvage pays back far less than tempering costs.
const SALVAGE_CORES := 10
const SALVAGE_STEP := 2.0

## The best grade forging can produce. Anything above it has to be tempered.
const MAX_FORGED_GRADE := 3

## Formulas bought in the shop: each sets a floor on the grade.
const FORMULAS := {
	"forge_formula_1": 1,     # at least Uncommon
	"forge_formula_2": 2,     # at least Rare
	"forge_formula_3": 3,     # at least Epic
}

## [trait id] = {name, desc, power, cap, color}
## "power" is the value at Common; it scales with grade.
const TRAITS := {
	"first_blood": {
		"name": "First Blood", "color": Color("ff8a6b"), "power": 100.0, "cap": 100.0,
		"desc": "The first attack each battle always crits.",
		"unit": "",
	},
	"bloodfeast": {
		"name": "Bloodfeast", "color": Color("ff6b6b"), "power": 6.0, "cap": 30.0,
		"desc": "Heals %s%% of max HP on every kill.", "unit": "%",
	},
	"second_wind": {
		"name": "Second Wind", "color": Color("8fffc4"), "power": 15.0, "cap": 60.0,
		"desc": "Heals %s%% of max HP the first time it drops below 30%%.", "unit": "%",
	},
	"unyielding": {
		"name": "Unyielding", "color": Color("c9a27a"), "power": 10.0, "cap": 40.0,
		"desc": "Takes %s%% less damage while below 30%% HP.", "unit": "%",
	},
	"twin_strike": {
		"name": "Twin Strike", "color": Color("9fe4ff"), "power": 8.0, "cap": 35.0,
		"desc": "%s%% chance to attack a second time.", "unit": "%",
	},
	"armor_piercer": {
		"name": "Armor Piercer", "color": Color("ffb36b"), "power": 10.0, "cap": 50.0,
		"desc": "Ignores %s%% of the target's defence.", "unit": "%",
	},
	"executioner": {
		"name": "Executioner", "color": Color("b476ff"), "power": 15.0, "cap": 70.0,
		"desc": "+%s%% damage to foes below 30%% HP.", "unit": "%",
	},
	"qi_thief": {
		"name": "Qi Thief", "color": Color("8ff0ff"), "power": 5.0, "cap": 25.0,
		"desc": "Steals %s energy from the target on hit.", "unit": "",
	},
	"curse_weaver": {
		"name": "Curse Weaver", "color": Color("c86bff"), "power": 15.0, "cap": 60.0,
		"desc": "+%s%% chance to land debuffs.", "unit": "%",
	},
	"crimson_edge": {
		"name": "Crimson Edge", "color": Color("ff4d7a"), "power": 1.0, "cap": 4.0,
		"desc": "Crits inflict Heavenly Bleed for %s%% max HP a turn.", "unit": "%",
	},
	"thornmail": {
		"name": "Thornmail", "color": Color("d8d8e8"), "power": 8.0, "cap": 35.0,
		"desc": "Returns %s%% of the damage it takes.", "unit": "%",
	},
	"swift_start": {
		"name": "Swift Start", "color": Color("7dffa8"), "power": 20.0, "cap": 100.0,
		"desc": "Starts each battle with %s energy.", "unit": "",
	},
}


static func trait_def(id: String) -> Dictionary:
	return TRAITS.get(id, {})


static func trait_name(a: Dictionary) -> String:
	return str(trait_def(a.get("trait", "")).get("name", "Artifact"))


static func color_of(a: Dictionary) -> Color:
	return trait_def(a.get("trait", "")).get("color", Color.WHITE)


static func grade_color(grade: int) -> Color:
	return ItemDB.grade_color(grade)


static func grade_name(grade: int) -> String:
	return ItemDB.grade_name(grade)


static func grade_mult(grade: int) -> float:
	return pow(GRADE_STEP, grade)


## The trait's strength at this artifact's grade (capped).
static func power_of(a: Dictionary) -> float:
	var def := trait_def(a.get("trait", ""))
	if def.is_empty():
		return 0.0
	return minf(float(def["power"]) * grade_mult(int(a["grade"])), float(def["cap"]))


static func trait_text(a: Dictionary) -> String:
	var def := trait_def(a.get("trait", ""))
	if def.is_empty():
		return ""
	var text: String = def["desc"]
	if text.find("%s") < 0:
		return text
	return text % String.num(snappedf(power_of(a), 0.1))


# ---------------------------------------------------------
# OWNED ARTIFACTS
# ---------------------------------------------------------

static func make(trait_id := "", grade := 0) -> Dictionary:
	if trait_id == "":
		trait_id = TRAITS.keys().pick_random()
	return {"uid": 0, "trait": trait_id, "grade": clampi(grade, 0, GRADES - 1),
		"owner": "", "locked": false}


## Grade rolled when forging: mostly low, and never above
## MAX_FORGED_GRADE. Higher grades come only from tempering.
static func roll_grade(luck := 0.0) -> int:
	var roll := randf() + luck
	if roll > 0.97:
		return 3
	if roll > 0.85:
		return 2
	if roll > 0.55:
		return 1
	return 0


static func worn_by(partner_id: String) -> Array:
	return GameState.artifacts_of(partner_id)


## Traits a partner has: {trait id: strength}
static func traits_for(partner_id: String) -> Dictionary:
	var out := {}
	for a in worn_by(partner_id):
		var id: String = a["trait"]
		out[id] = maxf(float(out.get(id, 0.0)), power_of(a))
	return out


# ---------------------------------------------------------
# THE SPIRIT FORGE
# ---------------------------------------------------------

## Forges a new artifact. A formula sets the lowest grade it can be.
## Returns the artifact, or {} if you can't pay.
static func forge(formula_id := "") -> Dictionary:
	if GameState.get_item_count(CORE_ID) < FORGE_CORE_COST:
		return {}
	var floor_grade := 0
	if formula_id != "":
		if not FORMULAS.has(formula_id) or GameState.get_item_count(formula_id) <= 0:
			return {}
		floor_grade = int(FORMULAS[formula_id])
	GameState.spend_item(CORE_ID, FORGE_CORE_COST)
	if formula_id != "":
		GameState.spend_item(formula_id, 1)

	var grade := maxi(roll_grade(), floor_grade)
	var made := GameState.add_artifact(make("", grade))
	GameState.bump("forge")
	GameState.artifacts_changed()
	return made


static func temper_cost(a: Dictionary) -> int:
	return int(TEMPER_CORE_COST * pow(TEMPER_STEP, int(a["grade"])))


## Raises the grade by one. Returns "" on success.
static func temper(a: Dictionary) -> String:
	if int(a["grade"]) >= GRADES - 1:
		return "Already Heaven-Defying."
	var cost := temper_cost(a)
	if GameState.get_item_count(CORE_ID) < cost:
		return "Needs %s Artifact Cores." % NumberFormat.short(cost)
	GameState.spend_item(CORE_ID, cost)
	a["grade"] = int(a["grade"]) + 1
	GameState.artifacts_changed()
	return ""


## Is there an unheld artifact better than what's in that slot?
static func better_available(partner_id: String, slot: int) -> bool:
	var worn := worn_by(partner_id)
	var current: Dictionary = worn[slot] if slot < worn.size() else {}
	var best := float(current["grade"]) if not current.is_empty() else -1.0
	for a in GameState.artifacts:
		if a.get("owner", "") != "":
			continue
		if float(a["grade"]) > best:
			return true
	return false


static func salvage_value(a: Dictionary) -> int:
	return int(SALVAGE_CORES * pow(SALVAGE_STEP, int(a["grade"])))
