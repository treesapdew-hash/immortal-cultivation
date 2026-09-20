class_name Alchemy

# =========================================================
# Pill recipes, crafted in the Abode.
#
# The pill for breaking INTO realm `i` uses the materials of the
# major realm you're breaking FROM (realm i - 1), so you can always
# gather them before you need them. Later realms within a major
# realm need more, and rarer, ingredients.
# =========================================================

## Spirit Stones per craft = STONE_COST_BASE x target realm index squared.
const STONE_COST_BASE := 150

## Pills made by one craft.
const PILLS_PER_CRAFT := 5

## Recipes are bought in the shop, one realm ahead of the MC.
## Mortal Realm pills cost Spirit Stones; from the Spirit Realm on, Jade.
const RECIPE_STONES_BASE := 400      # x target squared
const RECIPE_JADE_BASE := 200        # first Spirit Realm recipe
const RECIPE_JADE_STEP := 60         # more per realm after that


## Recipe for the pill that breaks into minor realm `target`:
## {"target", "pill", "stones", "materials": {item id: count}}
static func recipe_for(target: int) -> Dictionary:
	target = clampi(target, 1, Realms.count() - 1)
	var source := target - 1
	var major := Realms.get_major(source)

	# Position of the source realm within its major realm (0 = first)
	var same: Array = []
	for i in Realms.count():
		if Realms.get_major(i) == major:
			same.append(i)
	var pos := same.find(source)
	var n := same.size()

	var mats := {}
	mats[ItemDB.material_id(major, "herb_common")] = 5 + pos * 5
	mats[ItemDB.material_id(major, "core_common")] = 3 + pos * 3
	if pos >= int(n / 3.0):
		mats[ItemDB.material_id(major, "herb_rare")] = 1 + pos
	if pos >= int(n * 2 / 3.0):
		mats[ItemDB.material_id(major, "core_rare")] = 1 + int(pos / 2.0)

	return {
		"target": target,
		"pill": ItemDB.realm_pill_id(target),
		"stones": STONE_COST_BASE * target * target,
		"materials": mats,
	}


## Highest recipe the shop will sell right now: the MC's next realm.
static func buyable_up_to() -> int:
	var mc := GameState.get_mc()
	var realm := mc.realm_index if mc != null else 0
	return clampi(realm + 1, 1, Realms.count() - 1)


## Price of learning a recipe: {"currency": "stones"/"jade", "amount": n}
static func recipe_price(target: int) -> Dictionary:
	if Realms.get_major(target) == 0:
		return {"currency": "stones", "amount": RECIPE_STONES_BASE * target * target}
	var first_spirit := 0
	for i in Realms.count():
		if Realms.get_major(i) > 0:
			first_spirit = i
			break
	return {"currency": "jade", "amount": RECIPE_JADE_BASE + (target - first_spirit) * RECIPE_JADE_STEP}


## How many times this recipe can be crafted right now.
static func max_craftable(recipe: Dictionary) -> int:
	var best := 999999
	var stones: int = recipe["stones"]
	if stones > 0:
		best = mini(best, int(GameState.spirit_stones / float(stones)))
	var mats: Dictionary = recipe["materials"]
	for id in mats:
		best = mini(best, int(GameState.get_item_count(id) / float(mats[id])))
	return maxi(best, 0)


## Crafts `times` batches (PILLS_PER_CRAFT pills each). Returns pills made.
static func craft(target: int, times: int) -> int:
	var recipe := recipe_for(target)
	times = mini(times, max_craftable(recipe))
	if times <= 0:
		return 0

	if not GameState.spend_spirit_stones(recipe["stones"] * times):
		return 0
	var mats: Dictionary = recipe["materials"]
	var spend := {}
	for id in mats:
		spend[id] = -int(mats[id]) * times
	# Alchemy Dao treasures raise the yield
	var yield_mult := 1.0 + Treasures.economy_bonus("craft_bonus") / 100.0
	spend[recipe["pill"]] = int(times * PILLS_PER_CRAFT * yield_mult)
	GameState.add_items(spend)
	GameState.bump("craft", int(spend[recipe["pill"]]))
	GameState.save_game()
	return int(spend[recipe["pill"]])
