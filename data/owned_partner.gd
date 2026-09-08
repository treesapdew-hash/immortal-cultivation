class_name OwnedPartner
extends Resource

# =========================================================
# The PLAYER'S copy of a partner.
#
# PartnerData says "Han Li exists and has these base stats".
# OwnedPartner says "MY Han Li is 6 stars, Golden Core Tier III,
# awakened twice, holding this sword".
#
# This is what gets saved. If the player owns three copies of
# the same partner, there are three OwnedPartner objects all
# pointing at one shared PartnerData.
# =========================================================


## Which partner this is. Looked up in PartnerDatabase.
@export var partner_id: String = ""

## Cultivation position (spec sections 5 and 26).
@export var realm_index: int = 0
@export var tier: int = 1

## Spec section 22. Capped by major world: Lower 10, Middle 20,
## Upper 30, Immortal 40.
@export var stars: int = 1

## Spec section 27. Separate from realm and stars.
@export var awakening: int = 0

## Equipment slot ids, empty string means nothing equipped.
## Spec section 31.
@export var weapon_id: String = ""
@export var armor_id: String = ""
@export var ring_id: String = ""
@export var boots_id: String = ""


# ---------------------------------------------------------
# TUNING
#
# These four numbers control the entire power curve.
# Change them here, nowhere else.
# ---------------------------------------------------------

## Compounding stat growth per cultivation step (0-299).
const GROWTH_PER_STEP := 1.035

## Extra stats per star above the first.
const GAIN_PER_STAR := 0.12

## Extra stats per awakening level.
const GAIN_PER_AWAKENING := 0.08


# ---------------------------------------------------------
# LOOKUP
# ---------------------------------------------------------

func get_data() -> PartnerData:
	return PartnerDatabase.get_partner(partner_id)


func get_display_name() -> String:
	var data = get_data()

	if data == null:
		return "Unknown Partner"

	return data.display_name


func get_realm_text() -> String:
	return Enums.format_realm(realm_index, tier)


func get_world() -> Enums.World:
	return Enums.get_world_for_realm(realm_index)


func get_star_cap() -> int:
	return Enums.WORLD_STAR_CAP[get_world()]


# ---------------------------------------------------------
# STAT CALCULATION
#
# One formula, applied to every stat:
#
#   base
#   x rarity multiplier
#   x growth ^ cultivation step
#   x star bonus
#   x awakening bonus
#
# Percentage stats (crit, evasion) do NOT use this -- they
# add flat amounts instead, or they would run past 100%.
# ---------------------------------------------------------

func _get_stat_multiplier() -> float:
	var data = get_data()

	if data == null:
		return 1.0

	var step = Enums.get_cultivation_step(realm_index, tier)

	var growth = pow(GROWTH_PER_STEP, step)

	var star_bonus = 1.0 + (stars - 1) * GAIN_PER_STAR

	var awakening_bonus = 1.0 + awakening * GAIN_PER_AWAKENING

	return (
		data.get_rarity_multiplier()
		* growth
		* star_bonus
		* awakening_bonus
	)


func get_max_hp() -> int:
	var data = get_data()

	if data == null:
		return 1

	return int(data.base_hp * _get_stat_multiplier())


func get_atk() -> int:
	var data = get_data()

	if data == null:
		return 1

	return int(data.base_atk * _get_stat_multiplier())


func get_def() -> int:
	var data = get_data()

	if data == null:
		return 0

	return int(data.base_def * _get_stat_multiplier())


func get_mdef() -> int:
	var data = get_data()

	if data == null:
		return 0

	return int(data.base_mdef * _get_stat_multiplier())


func get_spd() -> int:
	var data = get_data()

	if data == null:
		return 0

	# Speed grows much more slowly than the damage stats,
	# otherwise late-game turn order becomes meaningless.
	return int(data.base_spd * (1.0 + stars * 0.02))


func get_crit() -> float:
	var data = get_data()

	if data == null:
		return 0.0

	return minf(data.base_crit + awakening * 1.5, 100.0)


func get_crit_damage() -> float:
	var data = get_data()

	if data == null:
		return 150.0

	return data.base_crit_damage + awakening * 5.0


func get_eva() -> float:
	var data = get_data()

	if data == null:
		return 0.0

	return minf(data.base_eva + stars * 0.2, 75.0)


func get_accuracy() -> float:
	var data = get_data()

	if data == null:
		return 90.0

	return data.base_accuracy


func get_energy_regen() -> int:
	var data = get_data()

	if data == null:
		return 20

	return data.base_energy_regen + awakening * 2


## Single number shown in the UI so players can compare partners.
func get_power() -> int:
	return int(
		get_max_hp() * 0.10
		+ get_atk() * 2.00
		+ get_def() * 1.00
		+ get_mdef() * 1.00
		+ get_spd() * 0.50
	)


# ---------------------------------------------------------
# PROGRESSION
# ---------------------------------------------------------

## Advance one cultivation tier. Returns false if already capped.
func breakthrough() -> bool:
	if tier < Enums.TIERS_PER_REALM:
		tier += 1
		return true

	# Tier X reached -- move up a realm.
	if realm_index < Enums.REALMS.size() - 1:
		realm_index += 1
		tier = 1
		return true

	return false


## Add a star, respecting the major world cap.
func add_star() -> bool:
	if stars >= get_star_cap():
		return false

	stars += 1
	return true


# ---------------------------------------------------------
# SAVE / LOAD
#
# Dictionaries convert cleanly to JSON, and JSON is what a
# server will eventually expect (spec section 69).
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"partner_id": partner_id,
		"realm_index": realm_index,
		"tier": tier,
		"stars": stars,
		"awakening": awakening,
		"weapon_id": weapon_id,
		"armor_id": armor_id,
		"ring_id": ring_id,
		"boots_id": boots_id
	}


static func from_dict(dict: Dictionary) -> OwnedPartner:
	var partner = OwnedPartner.new()

	partner.partner_id  = dict.get("partner_id", "")
	partner.realm_index = dict.get("realm_index", 0)
	partner.tier        = dict.get("tier", 1)
	partner.stars       = dict.get("stars", 1)
	partner.awakening   = dict.get("awakening", 0)
	partner.weapon_id   = dict.get("weapon_id", "")
	partner.armor_id    = dict.get("armor_id", "")
	partner.ring_id     = dict.get("ring_id", "")
	partner.boots_id    = dict.get("boots_id", "")

	return partner


## Convenience for creating a freshly summoned partner.
static func create_new(id: String, data: PartnerData) -> OwnedPartner:
	var partner = OwnedPartner.new()

	partner.partner_id = id
	partner.realm_index = data.starting_realm_index
	partner.tier = 1
	partner.stars = 1
	partner.awakening = 0

	return partner
