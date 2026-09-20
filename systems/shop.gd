class_name Shop

# =========================================================
# Treasure Pavilion offers. All prices and limits live here.
#
# An offer is a Dictionary:
#   id        unique key (used for daily limits)
#   kind      "item" / "qi" / "recipe"
#   item_id   what you get (items), target realm (recipes)
#   amount    how many per purchase
#   price     cost per purchase
#   currency  "stones" or "jade"
#   limit     purchases per day (0 = unlimited)
#   title     display name
# =========================================================

## Material price per unit in Spirit Stones, by role, before the
## region multiplier (x1 Mortal, x5 Spirit, x25 Sovereign, x125 Immortal).
const MATERIAL_PRICES := {
	"herb_common": 60,
	"core_common": 120,
	"herb_rare": 600,
	"core_rare": 1500,
}
const REGION_PRICE_MULT := 5
const MATERIAL_BUNDLE := {"herb_common": 10, "core_common": 5, "herb_rare": 1, "core_rare": 1}
const MATERIAL_LIMIT := {"herb_common": 5, "core_common": 5, "herb_rare": 3, "core_rare": 2}

## Array Flags (Battle Array upgrades): per-flag Stone price (x region
## multiplier), flags per bundle, bundles per day.
const ARRAY_FLAG_PRICE := 3000
const ARRAY_FLAG_BUNDLE := 5
const ARRAY_FLAG_LIMIT := 2

const STARUP_STONE_BUNDLE := 10
const STARUP_STONE_PRICE := 2500
const STARUP_STONE_LIMIT := 5
const STARUP_JADE_BUNDLE := 100
const STARUP_JADE_PRICE := 120
const STARUP_JADE_LIMIT := 3

## A Qi Bundle gives this many battles' worth of Qi on your current stage.
const QI_BUNDLE_BATTLES := 20
const QI_BUNDLE_PRICE_BASE := 1500
const QI_BUNDLE_PRICE_PER_STAGE := 30
const QI_BUNDLE_LIMIT := 5


# ---------------------------------------------------------
# TOP UP (real money, see payments.gd)
# ---------------------------------------------------------

## [sku, jade, bonus jade, price label]. Price labels are placeholders;
## the store shows the real local price once billing is connected.
const JADE_PACKS := [
	["jade_60", 60, 0, "$0.99"],
	["jade_300", 300, 30, "$4.99"],
	["jade_980", 980, 110, "$14.99"],
	["jade_1980", 1980, 260, "$29.99"],
	["jade_3280", 3280, 600, "$49.99"],
	["jade_6480", 6480, 1600, "$99.99"],
]

## Jade -> Spirit Stones: [jade price, battles' worth of stones, daily limit]
const STONE_EXCHANGE := [
	[20, 30, 5],
	[100, 180, 3],
]


static func jade_pack_offers() -> Array:
	var offers: Array = []
	for pack in JADE_PACKS:
		var sku: String = pack[0]
		var first := not GameState.bought_packs.has(sku)
		offers.append({
			"id": sku, "kind": "jade_pack", "item_id": "", "sku": sku,
			"amount": pack[1], "bonus": pack[1] if first else pack[2],
			"first_bonus": first, "price_label": pack[3],
			"price": 0, "currency": "cash", "limit": 0,
			"title": "%s Immortal Jade" % NumberFormat.short(pack[1]),
		})
	return offers


static func stone_exchange_offers() -> Array:
	var stage := GameState.current_stage
	var per_battle := 50 + stage * 10
	var offers: Array = []
	for i in STONE_EXCHANGE.size():
		var row: Array = STONE_EXCHANGE[i]
		offers.append({
			"id": "stones_%d" % i, "kind": "stones", "item_id": "",
			"amount": per_battle * int(row[1]), "price": row[0], "currency": "jade",
			"limit": row[2], "title": "Spirit Stone Pouch" if i == 0 else "Spirit Stone Chest",
		})
	return offers


## Real-money purchase. `on_done` gets (success: bool, jade_gained: int).
static func buy_jade_pack(host: Node, offer: Dictionary, on_done: Callable) -> void:
	# The Jade comes back already granted, from the server's own
	# store_products. Adding offer["amount"] here as well would be
	# letting the device decide what a purchase was worth, which is
	# the one thing a paid product must never allow.
	Payments.purchase(host, offer["sku"], func(_sku: String, success: bool, jade: int):
		if not success:
			on_done.call(false, 0)
			return
		if not GameState.bought_packs.has(offer["sku"]):
			GameState.bought_packs.append(offer["sku"])
			GameState.save_game()
		on_done.call(true, jade)
	)


# ---------------------------------------------------------
# OFFERS
# ---------------------------------------------------------

## Materials from the current region (rare ones once they drop there).
static func material_offers() -> Array:
	var stage := GameState.current_stage
	var region := Loot.region_for(stage)
	var major: int = Loot.REGIONS[region][1]
	var into := stage - Loot.region_start(region)
	var mult := int(pow(REGION_PRICE_MULT, region))
	var offers: Array = []

	for role in ItemDB.ROLES:
		if into < Loot.ROLE_DROPS[role][4]:
			continue
		var id := ItemDB.material_id(major, role)
		var bundle: int = MATERIAL_BUNDLE[role]
		offers.append({
			"id": "mat_" + id, "kind": "item", "item_id": id, "amount": bundle,
			"price": MATERIAL_PRICES[role] * bundle * mult, "currency": "stones",
			"limit": MATERIAL_LIMIT[role],
			"title": ItemDB.get_item(id).get("name", id),
		})

	# Also the previous region's common materials, for older recipes
	if region > 0:
		var prev: int = Loot.REGIONS[region - 1][1]
		var prev_mult := int(pow(REGION_PRICE_MULT, region - 1))
		for role in ["herb_common", "core_common"]:
			var id := ItemDB.material_id(prev, role)
			var bundle: int = MATERIAL_BUNDLE[role]
			offers.append({
				"id": "mat_" + id, "kind": "item", "item_id": id, "amount": bundle,
				"price": MATERIAL_PRICES[role] * bundle * prev_mult, "currency": "stones",
				"limit": MATERIAL_LIMIT[role],
				"title": ItemDB.get_item(id).get("name", id),
			})

	# Array Flags for the Battle Array (not once it's maxed)
	if BattleArray.is_max_level():
		return offers
	offers.append({
		"id": "mat_array_flag", "kind": "item", "item_id": BattleArray.FLAG_ID,
		"amount": ARRAY_FLAG_BUNDLE, "price": ARRAY_FLAG_PRICE * ARRAY_FLAG_BUNDLE * mult,
		"currency": "stones", "limit": ARRAY_FLAG_LIMIT,
		"title": ItemDB.get_item(BattleArray.FLAG_ID).get("name", "Array Flag"),
	})
	return offers


static func pill_offers() -> Array:
	var stage := GameState.current_stage
	var qi_amount := QI_BUNDLE_BATTLES * (
		EnemyGenerator.enemy_count(stage) * GameState.get_qi_per_kill(stage, false)
		+ GameState.get_qi_stage_bonus(stage))
	return [
		{
			"id": "starup_stones", "kind": "item", "item_id": "starup_pill",
			"amount": STARUP_STONE_BUNDLE, "price": STARUP_STONE_PRICE, "currency": "stones",
			"limit": STARUP_STONE_LIMIT, "title": "Star-up Pills",
		},
		{
			"id": "starup_jade", "kind": "item", "item_id": "starup_pill",
			"amount": STARUP_JADE_BUNDLE, "price": STARUP_JADE_PRICE, "currency": "jade",
			"limit": STARUP_JADE_LIMIT, "title": "Star-up Pill Chest",
		},
		{
			"id": "qi_bundle", "kind": "qi", "item_id": "",
			"amount": qi_amount,
			"price": QI_BUNDLE_PRICE_BASE + stage * QI_BUNDLE_PRICE_PER_STAGE, "currency": "stones",
			"limit": QI_BUNDLE_LIMIT, "title": "Qi Condensing Elixir",
		},
	]


## Forging formulas: [item id, price, currency, daily limit]
const FORMULA_OFFERS := [
	["forge_formula_1", 6000, "stones", 5],
	["forge_formula_2", 60, "jade", 3],
	["forge_formula_3", 260, "jade", 1],
]


static func formula_offers() -> Array:
	var offers: Array = []
	for row in FORMULA_OFFERS:
		var id: String = row[0]
		offers.append({
			"id": "formula_" + id, "kind": "item", "item_id": id, "amount": 1,
			"price": int(row[1]), "currency": str(row[2]), "limit": int(row[3]),
			"title": ItemDB.get_item(id).get("name", id),
		})
	return offers


## Recipes up to one realm past the MC that aren't owned yet, plus
## the next locked one as a preview ("locked": true).
static func recipe_offers() -> Array:
	var offers: Array = []
	var up_to := Alchemy.buyable_up_to()
	for target in range(1, up_to + 1):
		if GameState.has_recipe(target):
			continue
		offers.append(_recipe_offer(target, false))
	if up_to < Realms.count() - 1:
		offers.append(_recipe_offer(up_to + 1, true))
	return offers


static func _recipe_offer(target: int, locked: bool) -> Dictionary:
	var price := Alchemy.recipe_price(target)
	var pill := ItemDB.realm_pill_id(target)
	return {
		"id": "recipe_%d" % target, "kind": "recipe", "item_id": pill, "target": target,
		"amount": 1, "price": price["amount"], "currency": price["currency"],
		"limit": 1, "locked": locked,
		"title": "%s Recipe" % ItemDB.get_item(pill).get("name", "Pill"),
	}


# ---------------------------------------------------------
# BUYING
# ---------------------------------------------------------

static func bought_today(offer: Dictionary) -> int:
	if offer["kind"] == "recipe":
		return 1 if GameState.has_recipe(offer["target"]) else 0
	return GameState.get_bought_today(offer["id"])


static func left_today(offer: Dictionary) -> int:
	var limit: int = offer["limit"]
	if limit <= 0:
		return 999999
	return maxi(0, limit - bought_today(offer))


static func can_afford(offer: Dictionary) -> bool:
	var price: int = offer["price"]
	if offer["currency"] == "jade":
		return GameState.immortal_jade >= price
	return GameState.spirit_stones >= price


## Buys one of an offer. Returns "" on success, otherwise the reason.
static func buy(offer: Dictionary) -> String:
	if offer.get("locked", false):
		return "Reach the previous realm first."
	if left_today(offer) <= 0:
		return "Sold out for today."
	if not can_afford(offer):
		return "Not enough %s." % ("Immortal Jade" if offer["currency"] == "jade" else "Spirit Stones")

	var price: int = offer["price"]
	var paid := GameState.spend_immortal_jade(price) if offer["currency"] == "jade" \
		else GameState.spend_spirit_stones(price)
	if not paid:
		return "Couldn't pay."

	match offer["kind"]:
		"item":
			GameState.add_items({offer["item_id"]: offer["amount"]})
		"qi":
			GameState.add_qi(offer["amount"])
		"stones":
			GameState.add_spirit_stones(offer["amount"])
		"recipe":
			GameState.learn_recipe(offer["target"])
			GameState.currency_changed.emit()

	if offer["kind"] != "recipe":
		GameState.add_bought_today(offer["id"], 1)
	GameState.bump("shop_buys")
	GameState.save_game()
	return ""


## "Resets in 5h 12m"
static func time_until_reset() -> String:
	var now := Time.get_datetime_dict_from_system()
	var left := (23 - int(now["hour"])) * 3600 + (59 - int(now["minute"])) * 60 + (60 - int(now["second"]))
	return Loot.format_duration(left)
