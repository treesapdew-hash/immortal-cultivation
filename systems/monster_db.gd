class_name MonsterDB

# =========================================================
# Monsters in battle.
#
#   Mobs:   res://assets/monsters/mob/<id>.png
#   Bosses: res://assets/monsters/boss/<id>.png
#
# A normal stage uses at most 2 kinds of mob. A boss stage uses
# 2 kinds of mob plus the boss. Which ones a stage uses is fixed
# by the stage number, so the same stage always looks the same.
# =========================================================

const MOB_FOLDER := "res://assets/monsters/mob/"
const BOSS_FOLDER := "res://assets/monsters/boss/"

## Kinds of mob on one stage (the boss is extra).
const TYPES_PER_STAGE := 2

## [id, name, archetype] -- Balanced, Tank (tougher, slower) or Assassin (hits hard, frail)
const MOBS := [
	["bat_demon", "Bat Demon", "Assassin"],
	["grey_spirit_wolf", "Grey Spirit Wolf", "Balanced"],
	["jiangshi", "Jiangshi", "Tank"],
	["moss_monkey", "Moss Monkey", "Assassin"],
	["rock_boar", "Rock Boar", "Tank"],
	["swamp_toad", "Swamp Toad", "Balanced"],
]

## [id, name] -- bosses are drawn bigger, with a crimson aura
const BOSSES := [
	["calamity_roc", "Calamity Roc"],
	["heavenly_qilin", "Heavenly Qilin"],
	["jadehorn_moonfang", "Jadehorn Moonfang"],
	["mistpeak_king", "Mistpeak King"],
	["nine_tailed_empress", "Nine-Tailed Empress"],
	["voidmoon_mantis", "Voidmoon Mantis"],
]

## Titles added to bosses every 100 stages.
const MILESTONE_TITLES := ["Ancient", "Heaven-Defying", "Primordial"]

static var _sprites := {}


## The kinds of mob this stage uses (always the same for a stage).
static func types_for_stage(stage: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("stage_%d" % stage)
	var pool := MOBS.duplicate()
	var picked: Array = []
	for i in mini(TYPES_PER_STAGE, pool.size()):
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## One enemy for a slot: {id, name, archetype, sprite}
static func monster_for(stage: int, index: int) -> Dictionary:
	var types := types_for_stage(stage)
	var m: Array = types[index % types.size()]
	return {"id": m[0], "name": m[1], "archetype": m[2], "sprite": mob_sprite(m[0])}


static func mob_sprite(id: String) -> Texture2D:
	return _load(MOB_FOLDER + id + ".png")


static func boss_sprite(id: String) -> Texture2D:
	return _load(BOSS_FOLDER + id + ".png")


static func _load(path: String) -> Texture2D:
	if not _sprites.has(path):
		_sprites[path] = load(path) if ResourceLoader.exists(path) else null
	return _sprites[path]


## The boss of a stage. Every 100th stage gets a grander title.
static func pick_boss(stage: int, milestone: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("boss_%d" % stage)
	var b: Array = BOSSES[rng.randi_range(0, BOSSES.size() - 1)]
	var display: String = b[1]
	if milestone:
		display = "%s %s" % [MILESTONE_TITLES[rng.randi_range(0, MILESTONE_TITLES.size() - 1)], display]
	return {"id": b[0], "name": display, "sprite": boss_sprite(b[0])}
