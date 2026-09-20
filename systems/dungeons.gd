class_name Dungeons

# =========================================================
# Dungeon Hall. Each dungeon is a tower of floors:
#   - Challenge: fight the next floor in the battle area.
#     Only a WIN uses up a daily entry.
#   - Sweep: collect your highest cleared floor's rewards
#     again without fighting (uses an entry).
# All numbers are tunable here.
# =========================================================

const ENTRIES_PER_DAY := 3
const MAX_FLOOR := 1000
const BOSS_EVERY := 5

## base / step: floor N fights like stage (base + (N - 1) x step).
## Requirements: "unlock_stage" and/or "unlock_realm" (MC's minor realm index,
## 9 = Ascendant, the first Spirit Realm).
const LIST := [
	{
		"id": "star_trial", "name": "Star Trial", "open": true,
		"desc": "Climb the trial of stars. Rewards Star-up Pills.",
		"unlock_stage": 20, "base": 15, "step": 6,
		"color": Color("ffd36b"), "emblem": "star",
	},
	{
		"id": "beast_den", "name": "Beast Den", "open": true,
		"desc": "Hunt spirit beasts for rare herbs and beast cores.",
		"unlock_stage": 500, "base": 480, "step": 8,
		"color": Color("ff7a5a"), "emblem": "claw",
	},
	{
		"id": "armory", "name": "Armory Ruins", "open": true,
		"desc": "Ancient weapons and armour lie buried in the ruins. Rewards equipment and Refining Ore.",
		"unlock_stage": 100, "base": 90, "step": 6,
		"color": Color("9fb8d8"), "emblem": "sword",
	},
	{
		"id": "vault", "name": "Treasure Vault", "open": true,
		"desc": "Guarded riches. Rewards treasures, Immortal Jade and Star-up Pills.",
		"unlock_realm": 9, "base": 800, "step": 10,
		"color": Color("b476ff"), "emblem": "chest",
	},
]

# Star Trial rewards
const STAR_BASE := 20
const STAR_PER_FLOOR := 6

# Beast Den rewards
const BEAST_HERBS_BASE := 10
const BEAST_HERBS_PER_FLOOR := 2
const BEAST_CORES_BASE := 5
const BEAST_CORES_PER_FLOOR := 1

# Armory Ruins rewards
const ARMORY_ORE_BASE := 3
const ARMORY_ORE_PER_FLOOR := 0.5
## Pieces per floor (boss floors give one more)
const ARMORY_GEAR := 1
## Heavenly Refining Ore starts dropping on this floor.
const ARMORY_HEAVENLY_FROM := 60

## Key used in reward dictionaries for "this many equipment pieces".
const GEAR_KEY := "__gear__"
## Key for Immortal Jade in reward dictionaries.
const JADE_KEY := "__jade__"
## Key for "this many treasures".
const TREASURE_KEY := "__treasure__"

## Every dungeon floor also gives Immortal Jade (keeps F2P summoning).
const DUNGEON_JADE_BASE := 5
const DUNGEON_JADE_PER_FLOOR := 1

# Treasure Vault rewards (placeholder until treasures exist)
const VAULT_JADE_BASE := 20
const VAULT_JADE_PER_FLOOR := 2
const VAULT_DUST_BASE := 30
const VAULT_DUST_PER_FLOOR := 12

## Every 10th floor gives double.
const MILESTONE_EVERY := 10


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if d["id"] == id:
			return d
	return {}


static func meets_requirements(def: Dictionary) -> bool:
	if GameState.current_stage < int(def.get("unlock_stage", 0)):
		return false
	var mc := GameState.get_mc()
	var realm := mc.realm_index if mc != null else 0
	return realm >= int(def.get("unlock_realm", 0))


static func is_unlocked(def: Dictionary) -> bool:
	return def.get("open", false) and meets_requirements(def)


## "Reach Stage 500" / "Reach the Spirit Realm" / both.
static func requirement_text(def: Dictionary) -> String:
	var parts := PackedStringArray()
	if def.has("unlock_stage") and int(def["unlock_stage"]) > 1:
		parts.append("Stage %s" % NumberFormat.short(def["unlock_stage"]))
	if def.has("unlock_realm"):
		var r := int(def["unlock_realm"])
		if r > 0:
			# First realm of a major realm reads better as the major realm's name
			var first_of_major := Realms.get_major(r) != Realms.get_major(r - 1)
			parts.append("the " + Realms.get_major_name(r) if first_of_major else Realms.get_minor_name(r))
	if parts.is_empty():
		return ""
	return "Reach " + " and ".join(parts)


static func highest(def: Dictionary) -> int:
	return int(GameState.dungeon_progress.get(def["id"], 0))


static func next_floor(def: Dictionary) -> int:
	return mini(highest(def) + 1, MAX_FLOOR)


static func entries_left(def: Dictionary) -> int:
	return maxi(0, ENTRIES_PER_DAY - GameState.get_dungeon_entries_used(def["id"]))


## The main stage a floor fights like.
static func stage_equiv(def: Dictionary, floor_n: int) -> int:
	return int(def["base"]) + (floor_n - 1) * int(def["step"])


static func is_boss_floor(floor_n: int) -> bool:
	return floor_n % BOSS_EVERY == 0


static func enemies_for(def: Dictionary, floor_n: int) -> Array:
	var stage := stage_equiv(def, floor_n)
	# Boss floors use a boss-stage lineup; others a normal one.
	if is_boss_floor(floor_n):
		stage = int(ceil(stage / 10.0)) * 10
	elif stage % 10 == 0:
		stage += 1
	return EnemyGenerator.generate(stage)


## What a floor gives: {item id: count}.
static func rewards_for(def: Dictionary, floor_n: int) -> Dictionary:
	var mult := 2 if floor_n % MILESTONE_EVERY == 0 else 1
	var items := {}

	# Jade from every floor of every dungeon
	items[JADE_KEY] = (DUNGEON_JADE_BASE + floor_n * DUNGEON_JADE_PER_FLOOR) * mult
	match def["id"]:
		"star_trial":
			items["starup_pill"] = (STAR_BASE + floor_n * STAR_PER_FLOOR) * mult
		"beast_den":
			var region := Loot.region_for(stage_equiv(def, floor_n))
			var major: int = Loot.REGIONS[region][1]
			items[ItemDB.material_id(major, "herb_common")] = (BEAST_HERBS_BASE + floor_n * BEAST_HERBS_PER_FLOOR) * mult
			items[ItemDB.material_id(major, "core_common")] = (BEAST_CORES_BASE + floor_n * BEAST_CORES_PER_FLOOR) * mult
			items[ItemDB.material_id(major, "herb_rare")] = (1 + int(floor_n / 3.0)) * mult
			if floor_n >= 5:
				items[ItemDB.material_id(major, "core_rare")] = int(floor_n / 5.0) * mult
		"vault":
			# Treasures, plus far more Jade than the other dungeons
			items[TREASURE_KEY] = (1 + (1 if is_boss_floor(floor_n) else 0)) * mult
			items[JADE_KEY] = (VAULT_JADE_BASE + floor_n * VAULT_JADE_PER_FLOOR) * mult
			items["treasure_dust"] = (VAULT_DUST_BASE + floor_n * VAULT_DUST_PER_FLOOR) * mult
		"armory":
			items["refining_ore"] = int(ARMORY_ORE_BASE + floor_n * ARMORY_ORE_PER_FLOOR) * mult
			if floor_n >= ARMORY_HEAVENLY_FROM:
				items["heavenly_ore"] = (1 + int((floor_n - ARMORY_HEAVENLY_FROM) / 15.0)) * mult
			items[GEAR_KEY] = (ARMORY_GEAR + (1 if is_boss_floor(floor_n) else 0)) * mult
	return items


## Grants a floor's rewards. Equipment is rolled here.
## Returns the gear pieces made (may be empty).
static func _grant(_def: Dictionary, floor_n: int, rewards: Dictionary) -> Array:
	var items := rewards.duplicate()
	var pieces: Array = []
	var count := int(items.get(GEAR_KEY, 0))
	items.erase(GEAR_KEY)
	var jade := int(items.get(JADE_KEY, 0))
	items.erase(JADE_KEY)
	if jade > 0:
		GameState.add_immortal_jade(jade)

	var treasure_count := int(items.get(TREASURE_KEY, 0))
	items.erase(TREASURE_KEY)
	for i in treasure_count:
		pieces.append(GameState.add_treasure(Treasures.random_drop(floor_n)))
	if treasure_count > 0:
		GameState.treasures_updated.emit()
	for i in count:
		pieces.append(GameState.add_gear(Gear.random_drop(floor_n)))
	GameState.add_items(items)
	if not pieces.is_empty():
		GameState.gear_updated.emit()
	return pieces


# ---------------------------------------------------------
# PLAYING
# ---------------------------------------------------------

## Finds the battle area that can run dungeon fights.
static func find_battle(from: Node) -> Node:
	var scene := from.get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "", true, false):
		if node.has_method("start_dungeon"):
			return node
	return null


## Starts the next floor. Returns "" if the fight started.
static func challenge(from: Node, def: Dictionary) -> String:
	if not is_unlocked(def):
		return "Not unlocked yet."
	if entries_left(def) <= 0:
		return "No entries left today."
	if highest(def) >= MAX_FLOOR:
		return "All floors cleared!"
	var battle := find_battle(from)
	if battle == null:
		return "Battle area not found."
	if battle.call("is_in_dungeon"):
		return "A dungeon fight is already running."

	var floor_n := next_floor(def)
	var request := {
		"dungeon": def["id"],
		"floor": floor_n,
		"enemies": enemies_for(def, floor_n),
		"title": "%s  F%d" % [str(def["name"]).to_upper(), floor_n],
		"subtitle": "%s  ·  Floor %d" % [def["name"], floor_n],
		"rewards": rewards_for(def, floor_n),
	}
	if not battle.call("start_dungeon", request):
		return "A dungeon fight is already running."

	# Show the battle straight away
	var router := from
	while router != null and not router.has_method("open_tab"):
		router = router.get_parent()
	if router != null:
		router.call("open_tab", "Home")
	return ""


## Called when a dungeon fight ends. Grants rewards on a win.
static func finish(request: Dictionary, won: bool) -> void:
	if not won:
		return
	var id: String = request["dungeon"]
	GameState.dungeon_progress[id] = maxi(int(GameState.dungeon_progress.get(id, 0)), request["floor"])
	GameState.use_dungeon_entry(id)
	request["gear_drops"] = _grant(get_def(id), request["floor"], request["rewards"])
	GameState.save_game()


## Collects the highest cleared floor again. Returns the rewards ({} if not possible).
static func sweep(def: Dictionary) -> Dictionary:
	var top := highest(def)
	if top <= 0 or entries_left(def) <= 0 or not is_unlocked(def):
		return {}
	var rewards := rewards_for(def, top)
	GameState.use_dungeon_entry(def["id"])
	var pieces := _grant(def, top, rewards)
	GameState.save_game()
	var out := rewards.duplicate()
	out.erase(GEAR_KEY)
	if not pieces.is_empty():
		out["__pieces__"] = pieces
	return out
