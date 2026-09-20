class_name Expeditions

# =========================================================
# Secret Realm Expeditions.
#
# Send partners away for a few hours and they come back with
# Artifact Cores, Lifebound Essence and materials. Partners
# keep fighting in your team, so there's no cost to sending
# them. Offers you don't like can be rerolled.
#
# Running trips live in GameState.expeditions:
#   {id, name, grade, hours, partners, ends_at, rewards}
# Offers live in GameState.expedition_offers (same shape,
# without ends_at).
# =========================================================

## How many can run at once, and how many offers you can pick from.
const MAX_RUNNING := 3
const OFFER_COUNT := 5

## Free rerolls a day, then this much Jade each, up to a hard cap.
const FREE_REROLLS := 3
const REROLL_JADE := 20
const MAX_REROLLS_PER_DAY := 10

## Expeditions you can send in a day, however much Jade you spend.
const MAX_SENDS_PER_DAY := 6

## Lengths you can send them for.
const DURATIONS := [1, 4, 8]

## Grades, best last. The name is shown in the grade's colour.
const GRADE_NAMES := ["Misty Vale", "Jade Hollow", "Azure Ruins", "Cloud Abyss",
	"Dragon Tomb", "Immortal Sanctum", "Heaven's Remnant"]

## Rewards per hour at Common, multiplied by the grade.
const CORES_PER_HOUR := 8
const ESSENCE_PER_HOUR := 6
const JADE_PER_HOUR := 4
const GRADE_STEP := 1.45

## Higher-realm partners bring back more.
const REALM_BONUS := 0.04      # per realm index, per partner
const PARTNER_SLOTS := 3


static func grade_color(grade: int) -> Color:
	return ItemDB.grade_color(grade)


static func grade_mult(grade: int) -> float:
	return pow(GRADE_STEP, grade)


## Rolls one offer. Higher grades are rarer.
static func make_offer() -> Dictionary:
	var roll := randf()
	var grade := 0
	if roll > 0.97:
		grade = 5
	elif roll > 0.90:
		grade = 4
	elif roll > 0.76:
		grade = 3
	elif roll > 0.55:
		grade = 2
	elif roll > 0.30:
		grade = 1
	return {
		"id": randi(),
		"name": GRADE_NAMES[clampi(grade, 0, GRADE_NAMES.size() - 1)],
		"grade": grade,
		"hours": DURATIONS.pick_random(),
		"partners": [],
	}


static func offers() -> Array:
	if GameState.expedition_offers.is_empty():
		reroll(true)
	return GameState.expedition_offers


## Rerolls the offer list. free = no cost (first fill of the day).
static func reroll(free := false) -> String:
	if not free:
		var used := GameState.get_bought_today("expedition_reroll")
		if used >= MAX_REROLLS_PER_DAY:
			return "No rerolls left today."
		if used >= FREE_REROLLS:
			if not GameState.spend_immortal_jade(REROLL_JADE):
				return "Needs %d Jade." % REROLL_JADE
		GameState.add_bought_today("expedition_reroll", 1)

	var list: Array = []
	for i in OFFER_COUNT:
		list.append(make_offer())
	GameState.expedition_offers = list
	GameState.expeditions_changed()
	return ""


## Free rerolls left today.
static func rerolls_left() -> int:
	return maxi(0, FREE_REROLLS - GameState.get_bought_today("expedition_reroll"))


## Rerolls left today in total, free and paid.
static func rerolls_left_total() -> int:
	return maxi(0, MAX_REROLLS_PER_DAY - GameState.get_bought_today("expedition_reroll"))


## Expeditions you can still send today.
static func sends_left() -> int:
	return maxi(0, MAX_SENDS_PER_DAY - GameState.get_bought_today("expedition_send"))


## What an expedition will bring back.
static func rewards_for(offer: Dictionary, partner_ids: Array) -> Dictionary:
	var hours := int(offer["hours"])
	var mult := grade_mult(int(offer["grade"]))

	# Stronger partners bring back more
	var bonus := 1.0
	for id in partner_ids:
		var owned := GameState.find_owned(str(id))
		if owned != null:
			bonus += owned.realm_index * REALM_BONUS
	mult *= bonus

	return {
		Artifacts.CORE_ID: int(CORES_PER_HOUR * hours * mult),
		Lifebound.ESSENCE_ID: int(ESSENCE_PER_HOUR * hours * mult),
		"jade": int(JADE_PER_HOUR * hours * mult),
	}


static func running() -> Array:
	return GameState.expeditions


static func is_busy(partner_id: String) -> bool:
	for trip in GameState.expeditions:
		if partner_id in trip["partners"]:
			return true
	return false


## Sends partners off. Returns "" when the trip started.
static func send(offer: Dictionary, partner_ids: Array) -> String:
	if GameState.expeditions.size() >= MAX_RUNNING:
		return "All %d expedition slots are busy." % MAX_RUNNING
	if sends_left() <= 0:
		return "You've sent all %d expeditions today." % MAX_SENDS_PER_DAY
	if partner_ids.is_empty():
		return "Choose at least one partner."
	GameState.add_bought_today("expedition_send", 1)
	GameState.bump("expeditions")

	var trip := offer.duplicate(true)
	trip["partners"] = partner_ids.duplicate()
	trip["rewards"] = rewards_for(offer, partner_ids)
	# Server time, or a wound-forward clock finishes every trip at once.
	trip["ends_at"] = GameState.now_unix() + int(offer["hours"]) * 3600

	GameState.expeditions.append(trip)
	GameState.expedition_offers = GameState.expedition_offers.filter(
		func(o): return int(o["id"]) != int(offer["id"]))
	GameState.expeditions_changed()
	return ""


static func seconds_left(trip: Dictionary) -> int:
	return maxi(0, int(trip["ends_at"]) - GameState.now_unix())


static func is_done(trip: Dictionary) -> bool:
	return seconds_left(trip) <= 0


## Jade to finish a trip now: 1 Jade per 5 minutes left.
static func rush_cost(trip: Dictionary) -> int:
	return maxi(1, int(ceil(seconds_left(trip) / 300.0)))


static func rush(trip: Dictionary) -> String:
	if is_done(trip):
		return ""
	var cost := rush_cost(trip)
	if not GameState.spend_immortal_jade(cost):
		return "Needs %s Jade." % NumberFormat.short(cost)
	trip["ends_at"] = GameState.now_unix()
	GameState.expeditions_changed()
	return ""


## Collects a finished trip. Returns what it brought back.
static func collect(trip: Dictionary) -> Dictionary:
	if not is_done(trip):
		return {}
	var rewards: Dictionary = trip["rewards"]
	var items := rewards.duplicate()
	var jade := int(items.get("jade", 0))
	items.erase("jade")
	if jade > 0:
		GameState.add_immortal_jade(jade)
	GameState.add_items(items)
	GameState.expeditions = GameState.expeditions.filter(
		func(t): return int(t["id"]) != int(trip["id"]))
	GameState.expeditions_changed()
	return rewards


## Collects everything that's finished. Returns the totals.
static func collect_all() -> Dictionary:
	var total := {}
	for trip in GameState.expeditions.duplicate():
		if not is_done(trip):
			continue
		var got := collect(trip)
		for key in got:
			total[key] = int(total.get(key, 0)) + int(got[key])
	return total
