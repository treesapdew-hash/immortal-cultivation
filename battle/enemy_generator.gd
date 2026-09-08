class_name EnemyGenerator
extends RefCounted

# Builds an enemy team for a given stage.
# Returns plain dictionaries -- CombatUnit.from_enemy() turns
# them into fighters.

const TEAM_SIZE := 6

# Base stats for a stage-1 normal enemy.
const BASE_HP := 900
const BASE_ATK := 85
const BASE_DEF := 45
const BASE_SPD := 95

# Growth per stage. HP climbs faster than ATK so fights get
# longer rather than suddenly lethal.
const HP_GROWTH := 1.045
const ATK_GROWTH := 1.035

# Boss multipliers (spec section 39).
const BOSS_HP_MULT := 4.0
const BOSS_ATK_MULT := 1.8
const BOSS_DEF_MULT := 1.5

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


static func hp_multiplier(stage: int) -> float:
	return pow(HP_GROWTH, stage - 1)


static func atk_multiplier(stage: int) -> float:
	return pow(ATK_GROWTH, stage - 1)


# TEMPORARY: borrows a partner sprite until real enemy art
# exists. Delete this and the "sprite" lines below once you
# have proper enemy textures.
static func _placeholder_sprite() -> Texture2D:
	var all = PartnerDatabase.get_all()

	if all.is_empty():
		return null

	var data = all.pick_random()

	return data.sprite_texture


static func generate(stage: int) -> Array:
	var team: Array = []

	for i in range(TEAM_SIZE):

		# The boss takes the front-centre slot (index 1).
		if is_boss_stage(stage) and i == 1:
			team.append(_make_boss(stage))
		else:
			team.append(_make_normal(stage, i))

	return team


static func _make_normal(stage: int, index: int) -> Dictionary:

	var archetype = ["Balanced", "Tank", "Assassin"].pick_random()

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
		"name": ENEMY_NAMES[index % ENEMY_NAMES.size()],
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
		"sprite": _placeholder_sprite(),
		"color": Color(1.0, 0.65, 0.65)
	}


static func _make_boss(stage: int) -> Dictionary:

	var is_major = stage % 100 == 0

	var hp_mult = BOSS_HP_MULT
	var atk_mult = BOSS_ATK_MULT
	var def_mult = BOSS_DEF_MULT

	if is_major:
		hp_mult = 8.0
		atk_mult = 2.5
		def_mult = 2.0

	return {
		"name": BOSS_NAMES[1] if is_major else BOSS_NAMES[0],
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
		"sprite": _placeholder_sprite(),
		"color": Color(1.0, 0.85, 0.3)
	}
