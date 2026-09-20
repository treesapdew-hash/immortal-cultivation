class_name Lifebound

# =========================================================
# The Lifebound Artifact: one per partner, bonded for life.
#
# It has 4 stat lines. Upgrading REROLLS every unsealed line
# within its grade's range, so values can rise or fall. Seal
# the lines you like; each sealed line makes the upgrade cost
# more, so sealing everything is expensive.
#
# Where it comes from:
#   1. Craft a Lifebound Seed at the Spirit Forge (1 star).
#   2. Merge seeds: 3 of the same star make the next star
#      (2 from 6 stars up), to a cap of 10.
#   3. Bond a seed to a partner. Its stars multiply every line.
#
# Grade (Common ... Heaven-Defying) is separate and raises the
# ceiling each line rolls against.
#
# Stored in GameState.lifebound:
#   {partner_id: {grade, stars, lines: [{stat, value, sealed}]}}
# Seeds live in GameState.lifebound_seeds: {star: count}
# =========================================================

const GRADES := 7
const LINES := 4

## Materials
const ESSENCE_ID := "lifebound_essence"

## Crafting a seed (1 star) at the Spirit Forge
const SEED_ESSENCE_COST := 300
const SEED_CORE_COST := 40

## Stars
const MAX_STARS := 10
## Seeds needed to make the next star, by current star (1 ... 9).
## 3 while it's cheap, 2 once the numbers get big.
const MERGE_COUNTS := [3, 3, 3, 3, 2, 2, 2, 2, 2]
## Each star adds this much to every line.
const STAR_BONUS := 0.15

## Base cost to upgrade, plus this much for each sealed line.
## A bonded artifact is meant to take months, not days.
const UPGRADE_COST := 400
const SEAL_SURCHARGE := 800

## Essence to raise the grade, x grade multiplier.
const GRADE_COST := 3000
const GRADE_STEP := 2.2

## Stats a line can roll, with its value at Common.
## Percentage stats use the same keys as gear.
const STAT_POOL := {
	"atk_pct": 6.0,
	"hp_pct": 7.0,
	"def_pct": 6.0,
	"mdef_pct": 6.0,
	"crit": 2.5,
	"crit_dmg": 9.0,
	"eva": 2.0,
	"acc": 3.0,
	"energy": 3.0,
}

## A rolled line lands between these shares of the grade's ceiling,
## so landing near the top takes a lot of tries.
const ROLL_MIN := 0.35
const ROLL_MAX := 1.0


static func grade_mult(grade: int) -> float:
	return pow(GRADE_STEP, grade)


## Highest a stat can roll at a grade.
static func stat_ceiling(stat: String, grade: int) -> float:
	return float(STAT_POOL.get(stat, 5.0)) * grade_mult(grade)


static func roll_value(stat: String, grade: int) -> float:
	return snappedf(stat_ceiling(stat, grade) * randf_range(ROLL_MIN, ROLL_MAX), 0.1)


# ---------------------------------------------------------
# SEEDS: CRAFTING, MERGING AND BONDING
# ---------------------------------------------------------

static func seed_count(star: int) -> int:
	return int(GameState.lifebound_seeds.get(star, 0))


static func add_seeds(star: int, amount: int) -> void:
	GameState.lifebound_seeds[star] = maxi(0, seed_count(star) + amount)
	if GameState.lifebound_seeds[star] == 0:
		GameState.lifebound_seeds.erase(star)


## Crafts one 1-star seed. Returns "" on success.
static func craft_seed() -> String:
	if GameState.get_item_count(ESSENCE_ID) < SEED_ESSENCE_COST:
		return "Needs %s Lifebound Essence." % NumberFormat.short(SEED_ESSENCE_COST)
	if GameState.get_item_count(Artifacts.CORE_ID) < SEED_CORE_COST:
		return "Needs %d Artifact Cores." % SEED_CORE_COST
	GameState.spend_item(ESSENCE_ID, SEED_ESSENCE_COST)
	GameState.spend_item(Artifacts.CORE_ID, SEED_CORE_COST)
	add_seeds(1, 1)
	GameState.lifebound_changed()
	return ""


## How many seeds of `star` make one of the next star.
static func merge_count(star: int) -> int:
	return MERGE_COUNTS[clampi(star - 1, 0, MERGE_COUNTS.size() - 1)]


## Merges seeds up one star. Returns "" on success.
static func merge_seeds(star: int) -> String:
	if star >= MAX_STARS:
		return "Already %d stars." % MAX_STARS
	var needed := merge_count(star)
	if seed_count(star) < needed:
		return "Needs %d seeds of %d star%s." % [needed, star, "" if star == 1 else "s"]
	add_seeds(star, -needed)
	add_seeds(star + 1, 1)
	GameState.lifebound_changed()
	return ""


## Bonds a seed to a partner, setting their artifact's stars.
## Returns "" on success.
static func bond(partner_id: String, star: int) -> String:
	if seed_count(star) <= 0:
		return "You have no %d-star seeds." % star
	var artifact := get_for(partner_id)
	if star <= int(artifact.get("stars", 0)):
		return "%s already has a %d-star artifact." % [partner_id, int(artifact["stars"])]
	add_seeds(star, -1)
	artifact["stars"] = star
	GameState.lifebound_changed()
	return ""


## Stars multiply every line.
static func star_mult(artifact: Dictionary) -> float:
	return 1.0 + maxi(int(artifact.get("stars", 0)) - 1, 0) * STAR_BONUS


# ---------------------------------------------------------
# THE ARTIFACT ITSELF
# ---------------------------------------------------------

## Creates the artifact a partner is born with (unbonded, 0 stars).
static func create_for(partner_id: String) -> Dictionary:
	var pool := STAT_POOL.keys()
	pool.shuffle()
	var lines: Array = []
	for i in LINES:
		var stat: String = pool[i % pool.size()]
		lines.append({"stat": stat, "value": roll_value(stat, 0), "sealed": false})
	var artifact := {"grade": 0, "stars": 0, "lines": lines}
	GameState.lifebound[partner_id] = artifact
	return artifact


static func get_for(partner_id: String) -> Dictionary:
	if not GameState.lifebound.has(partner_id):
		return create_for(partner_id)
	return GameState.lifebound[partner_id]


## Stats it grants, in the same shape as Gear.totals_for.
static func totals_for(partner_id: String) -> Dictionary:
	if not GameState.lifebound.has(partner_id):
		return {}
	var artifact: Dictionary = GameState.lifebound[partner_id]
	if int(artifact.get("stars", 0)) <= 0:
		return {}                      # nothing until a seed is bonded
	var mult := star_mult(artifact)
	var out := {}
	for line in artifact["lines"]:
		out[line["stat"]] = float(out.get(line["stat"], 0.0)) + float(line["value"]) * mult
	return out


## How full a line is, 0 to 1, against its grade's ceiling.
static func line_fill(artifact: Dictionary, index: int) -> float:
	var line: Dictionary = artifact["lines"][index]
	var ceiling := stat_ceiling(str(line["stat"]), int(artifact["grade"]))
	return clampf(float(line["value"]) / maxf(ceiling, 0.01), 0.0, 1.0)


static func sealed_count(artifact: Dictionary) -> int:
	var n := 0
	for line in artifact["lines"]:
		if line["sealed"]:
			n += 1
	return n


static func upgrade_cost(artifact: Dictionary) -> int:
	return int((UPGRADE_COST + sealed_count(artifact) * SEAL_SURCHARGE) * grade_mult(int(artifact["grade"])))


## Rerolls every unsealed line. Returns the old values, so the
## UI can show what went up and what went down.
static func upgrade(partner_id: String) -> Dictionary:
	var artifact := get_for(partner_id)
	if sealed_count(artifact) >= LINES:
		return {"error": "Every line is sealed."}
	var cost := upgrade_cost(artifact)
	if GameState.get_item_count(ESSENCE_ID) < cost:
		return {"error": "Needs %s Lifebound Essence." % NumberFormat.short(cost)}
	GameState.spend_item(ESSENCE_ID, cost)

	var before: Array = []
	for line in artifact["lines"]:
		before.append(float(line["value"]))
		if not line["sealed"]:
			line["value"] = roll_value(str(line["stat"]), int(artifact["grade"]))
	GameState.lifebound_changed()
	return {"before": before}


## Sealing keeps a line through upgrades (and raises their cost).
static func toggle_seal(partner_id: String, index: int) -> void:
	var artifact := get_for(partner_id)
	var line: Dictionary = artifact["lines"][index]
	line["sealed"] = not line["sealed"]
	GameState.lifebound_changed()


static func grade_up_cost(artifact: Dictionary) -> int:
	return int(GRADE_COST * grade_mult(int(artifact["grade"])))


## Raises the grade, which raises every line's ceiling.
## Sealed lines keep their value; unsealed ones reroll higher.
static func grade_up(partner_id: String) -> String:
	var artifact := get_for(partner_id)
	if int(artifact["grade"]) >= GRADES - 1:
		return "Already Heaven-Defying."
	var cost := grade_up_cost(artifact)
	if GameState.get_item_count(ESSENCE_ID) < cost:
		return "Needs %s Lifebound Essence." % NumberFormat.short(cost)
	GameState.spend_item(ESSENCE_ID, cost)
	artifact["grade"] = int(artifact["grade"]) + 1
	for line in artifact["lines"]:
		if not line["sealed"]:
			line["value"] = roll_value(str(line["stat"]), int(artifact["grade"]))
	GameState.lifebound_changed()
	return ""
