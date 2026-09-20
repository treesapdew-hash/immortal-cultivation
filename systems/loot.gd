class_name Loot

# =========================================================
# What stages drop. Main stages give Qi, Spirit Stones and
# basic crafting materials. Equipment and treasures will come
# from dungeons later, not from here.
# =========================================================

## Stage regions: [first stage, major realm whose materials drop there]
const REGIONS := [
	[1, 0],       # Mortal lands
	[800, 1],     # Spirit lands
	[2500, 2],    # Sovereign lands
	[6000, 3],    # Immortal lands
]

## Per material role:
## [chance on normal stages, chance on boss stages, min, max,
##  stages into the region before it starts dropping]
const ROLE_DROPS := {
	"herb_common": [0.60, 1.00, 1, 3, 0],
	"core_common": [0.35, 0.80, 1, 2, 0],
	"herb_rare":   [0.10, 0.45, 1, 1, 100],
	"core_rare":   [0.05, 0.30, 1, 1, 200],
}

## After moving to a new region, the previous region's common
## materials still drop at this share of their usual chance.
const PREVIOUS_REGION_SHARE := 0.3

## Max amount grows by 1 every this many stages into a region.
const AMOUNT_GROWTH_EVERY := 100

## Every 100th stage also guarantees 2 of the region's rare core
## and 3 of its rare herb (if they've unlocked).
const MILESTONE_RARE_CORES := 2
const MILESTONE_RARE_HERBS := 3


## Region index for a stage.
static func region_for(stage: int) -> int:
	var region := 0
	for i in REGIONS.size():
		if stage >= REGIONS[i][0]:
			region = i
	return region


static func region_start(region: int) -> int:
	return REGIONS[clampi(region, 0, REGIONS.size() - 1)][0]


## Rolls the drops for one cleared stage: item id -> count.
static func roll_stage(stage: int, boss: bool) -> Dictionary:
	var drops := {}
	var region := region_for(stage)
	var major: int = REGIONS[region][1]
	var into := stage - region_start(region)
	var extra := int(into / float(AMOUNT_GROWTH_EVERY))

	for role in ROLE_DROPS:
		var row: Array = ROLE_DROPS[role]
		if into < row[4]:
			continue
		var chance: float = row[1] if boss else row[0]
		if randf() < chance:
			_add(drops, ItemDB.material_id(major, role), randi_range(row[2], row[3] + extra))

	# Previous region's common materials, at a lower rate
	if region > 0:
		var prev_major: int = REGIONS[region - 1][1]
		for role in ["herb_common", "core_common"]:
			var row: Array = ROLE_DROPS[role]
			var chance: float = (row[1] if boss else row[0]) * PREVIOUS_REGION_SHARE
			if randf() < chance:
				_add(drops, ItemDB.material_id(prev_major, role), randi_range(row[2], row[3] + 1))

	# Milestones
	if stage % 100 == 0:
		if into >= ROLE_DROPS["core_rare"][4]:
			_add(drops, ItemDB.material_id(major, "core_rare"), MILESTONE_RARE_CORES)
		if into >= ROLE_DROPS["herb_rare"][4]:
			_add(drops, ItemDB.material_id(major, "herb_rare"), MILESTONE_RARE_HERBS)

	return drops


static func _add(drops: Dictionary, id: String, n: int) -> void:
	if n > 0:
		drops[id] = int(drops.get(id, 0)) + n


static func merge(into: Dictionary, add: Dictionary) -> void:
	for id in add:
		into[id] = int(into.get(id, 0)) + int(add[id])


# ---------------------------------------------------------
# OFFLINE ("closed-door cultivation")
# ---------------------------------------------------------

## Most time that counts while away.
const OFFLINE_MAX_HOURS := 12.0
## Shorter absences don't show the popup.
const OFFLINE_MIN_SECONDS := 120
## Battles per hour on the current stage, and how much of that you get.
const OFFLINE_BATTLES_PER_HOUR := 40.0
const OFFLINE_EFFICIENCY := 0.6


## Everything earned while away. Stays on the current stage.
static func roll_offline(stage: int, seconds: float) -> Dictionary:
	var capped := minf(seconds, OFFLINE_MAX_HOURS * 3600.0)
	var battles := int(capped / 3600.0 * OFFLINE_BATTLES_PER_HOUR * OFFLINE_EFFICIENCY)

	var kills := EnemyGenerator.enemy_count(stage)
	var qi_per_battle := kills * GameState.get_qi_per_kill(stage, false) + GameState.get_qi_stage_bonus(stage)
	var stones_per_battle := 50 + stage * 10

	var items := {}
	for i in battles:
		# Roughly one in ten fights is a boss
		merge(items, roll_stage(stage, i % 10 == 9))

	return {
		"seconds": int(seconds),
		"counted_seconds": int(capped),
		"capped": seconds > capped,
		"battles": battles,
		"qi": battles * qi_per_battle,
		"stones": battles * stones_per_battle,
		"items": items,
	}


## "3h 20m", "45m", "12h"
static func format_duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h := seconds / 3600
	@warning_ignore("integer_division")
	var m := (seconds % 3600) / 60
	if h > 0 and m > 0:
		return "%dh %dm" % [h, m]
	if h > 0:
		return "%dh" % h
	return "%dm" % maxi(m, 1)
