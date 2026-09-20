class_name EnemyGenerator
extends RefCounted

# Builds an enemy team for a given stage.
# Returns plain dictionaries -- CombatUnit.from_enemy() turns
# them into fighters.

const TEAM_SIZE := 6

# Base stats for a stage-1 normal enemy. Kept low so the MC
# can clear the first stages alone.
const BASE_HP := 300
const BASE_ATK := 45
const BASE_DEF := 20
const BASE_SPD := 95

# ---------------------------------------------------------
# DIFFICULTY BANDS  -- tune these freely
#
# [stage, enemy strength at that stage]. Between two entries
# strength grows smoothly (same % each stage). Early bands are
# gentle, later bands stretch out so progress stays steady.
# After the last entry, strength keeps growing by
# LATE_GROWTH_PER_500 every 500 stages.
# ---------------------------------------------------------

const STRENGTH_BANDS := [
	[1, 1.0],
	[30, 1.6],
	[100, 6.4],
	[300, 38.0],
	[500, 115.0],
	[800, 400.0],
	[1000, 800.0],
	[1500, 2800.0],
]
const LATE_GROWTH_PER_500 := 1.4

## Ceiling on enemy strength.
##
## Strength keeps compounding 1.4x per 500 stages forever, and enemy
## HP is BASE_HP x strength x the boss multiplier. Past roughly stage
## 46,000 that passes int64's limit (9.22e18): the HP wraps to
## nonsense, enemies die instantly and the same stage "clears" over
## and over. Only the dev stage cheats reach that far, but a wrapped
## integer is a silly way to find out.
##
## 1e14 leaves BASE_HP x strength x BOSS_HP_MULT four orders of
## magnitude clear of the limit.
const MAX_STRENGTH := 1.0e14

# HP scales a bit harder than ATK, so fights get longer
# rather than suddenly lethal.
const HP_EXPONENT := 1.0
const ATK_EXPONENT := 0.92

# How many enemies show up: [from stage, count]
const ENEMY_COUNT := [
	[1, 2],
	[6, 3],
	[16, 4],
	[31, 5],
	[61, 6],
]

# Fill order for enemy slots: front centre first, then front
# sides, then the back row.
const SLOT_ORDER := [1, 0, 2, 4, 3, 5]

# Boss multipliers (spec section 39). Early bosses are softer.
const BOSS_HP_MULT := 4.0
const BOSS_ATK_MULT := 1.8
const BOSS_DEF_MULT := 1.5
const EARLY_BOSS_UNTIL := 30
const EARLY_BOSS_HP_MULT := 2.5
const EARLY_BOSS_ATK_MULT := 1.4

const ENEMY_NAMES := [
	"Ironfang Wolf",
	"Bloodclaw Ape",
	"Shadow Serpent",
	"Spirit Boar",
	"Mountain Fiend",
	"Darkscale Beast"
]

const BOSS_NAMES := [
	"Ancient Realm Guardian",
	"Heavenly Realm Sovereign"
]


static func is_boss_stage(stage: int) -> bool:
	return stage % 10 == 0


## Overall enemy strength at a stage (1.0 at stage 1).
static func strength(stage: int) -> float:
	stage = maxi(stage, 1)

	for i in range(STRENGTH_BANDS.size() - 1):
		var from: Array = STRENGTH_BANDS[i]
		var to: Array = STRENGTH_BANDS[i + 1]
		if stage <= to[0]:
			var t := float(stage - from[0]) / float(to[0] - from[0])
			# Geometric blend: the same % growth every stage in the band
			return from[1] * pow(to[1] / from[1], t)

	var last: Array = STRENGTH_BANDS.back()
	var extra := float(stage - last[0]) / 500.0
	return minf(last[1] * pow(LATE_GROWTH_PER_500, extra), MAX_STRENGTH)


static func hp_multiplier(stage: int) -> float:
	return pow(strength(stage), HP_EXPONENT)


static func atk_multiplier(stage: int) -> float:
	return pow(strength(stage), ATK_EXPONENT)


static func enemy_count(stage: int) -> int:
	var count := TEAM_SIZE
	for entry in ENEMY_COUNT:
		if stage >= entry[0]:
			count = entry[1]
	return count


# TEMPORARY: borrows a partner sprite until real enemy art
# exists. Delete this and the "sprite" lines below once you
# have proper enemy textures.
static func _placeholder_sprite() -> Texture2D:
	var all = PartnerDatabase.get_all()

	if all.is_empty():
		return null

	var data = all.pick_random()

	return data.sprite_texture


## Slots the boss stands in: it fills the front-centre slot and
## takes up the one beside it, so a boss stage has one enemy fewer.
## Bosses can't be debuffed from this stage on.
const BOSS_IMMUNITY_STAGE := 2000
## Ordinary monsters only get immunity much later.
const MOB_IMMUNITY_STAGE := 5000

const BOSS_SLOT := 1
const BOSS_BLOCKED_SLOT := 2


static func generate(stage: int) -> Array:
	var team: Array = []
	team.resize(TEAM_SIZE)   # empty slots stay null

	var boss := is_boss_stage(stage)
	var count := enemy_count(stage)
	if boss:
		count = maxi(2, count - 1)   # the boss is worth two slots

	var filled := 0
	for n in SLOT_ORDER.size():
		if filled >= count:
			break
		var slot: int = SLOT_ORDER[n]
		if boss and slot == BOSS_BLOCKED_SLOT:
			continue          # kept clear for the boss's bulk
		if boss and slot == BOSS_SLOT:
			team[slot] = _make_boss(stage)
		else:
			team[slot] = _make_normal(stage, slot)
		filled += 1

	return team


static func _make_normal(stage: int, index: int) -> Dictionary:

	# At most 2 kinds of mob per stage (see MonsterDB)
	var monster := MonsterDB.monster_for(stage, index)
	var archetype: String = monster["archetype"]
	var sprite: Texture2D = monster["sprite"]
	if sprite == null:
		sprite = _placeholder_sprite()

	var hp := float(BASE_HP)
	var atk := float(BASE_ATK)
	var defense := float(BASE_DEF)
	var spd := float(BASE_SPD)

	if archetype == "Tank":
		hp *= 1.40
		defense *= 1.30
		spd *= 0.85

	elif archetype == "Assassin":
		hp *= 0.80
		atk *= 1.30
		spd *= 1.25

	return {
		"name": monster["name"],
		"monster_id": monster["id"],
		"immune": stage >= MOB_IMMUNITY_STAGE,
		"hp": int(hp * hp_multiplier(stage)),
		"atk": int(atk * atk_multiplier(stage)),
		"def": int(defense * atk_multiplier(stage)),
		"mdef": int(defense * atk_multiplier(stage)),
		"spd": int(spd),
		"crit": 10.0,
		"crit_damage": 150.0,
		"eva": 6.0,
		"accuracy": 85.0,
		"energy_regen": 15,
		"is_boss": false,
		"sprite": sprite,
		"color": Color(1.0, 0.65, 0.65)
	}


static func _make_boss(stage: int) -> Dictionary:

	var is_major = stage % 100 == 0

	var hp_mult = BOSS_HP_MULT
	var atk_mult = BOSS_ATK_MULT
	var def_mult = BOSS_DEF_MULT

	if stage <= EARLY_BOSS_UNTIL:
		hp_mult = EARLY_BOSS_HP_MULT
		atk_mult = EARLY_BOSS_ATK_MULT
		def_mult = 1.2
	elif is_major:
		hp_mult = 8.0
		atk_mult = 2.5
		def_mult = 2.0

	var boss := MonsterDB.pick_boss(stage, is_major)
	var boss_sprite: Texture2D = boss["sprite"]
	if boss_sprite == null:
		boss_sprite = _placeholder_sprite()

	return {
		"name": boss["name"],
		"monster_id": boss["id"],
		"immune": stage >= BOSS_IMMUNITY_STAGE,
		"hp": int(BASE_HP * hp_multiplier(stage) * hp_mult),
		"atk": int(BASE_ATK * atk_multiplier(stage) * atk_mult),
		"def": int(BASE_DEF * atk_multiplier(stage) * def_mult),
		"mdef": int(BASE_DEF * atk_multiplier(stage) * def_mult),
		"spd": int(BASE_SPD * 1.1),
		"crit": 18.0,
		"crit_damage": 170.0,
		"eva": 8.0,
		"accuracy": 92.0,
		"energy_regen": 20,
		"is_boss": true,
		"sprite": boss_sprite,
		"color": Color(1.0, 0.85, 0.3)
	}
