class_name OwnedPartner
extends Resource

# =========================================================
# The PLAYER'S copy of a partner (or the MC).
#
# PartnerData says "Han Li exists and has these base stats".
# OwnedPartner says "MY Han Li is 6 stars, Golden Core 3,
# awakened twice, holding this sword".
# =========================================================


## Which partner this is. Looked up in PartnerDatabase.
@export var partner_id: String = ""

## Cultivation position: which minor realm (index into Realms.MINOR)
## and the level inside it (1-10). "tier" is the level.
@export var realm_index: int = 0
@export var tier: int = 1

## 0-20. Capped by card tier and by major realm.
@export var stars: int = 1

@export var awakening: int = 0

@export var weapon_id: String = ""
@export var armor_id: String = ""
@export var ring_id: String = ""
@export var boots_id: String = ""


# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

## Compounding stat growth per cultivation step.
const GROWTH_PER_STEP := 1.035

## Extra stats per star above the first.
const GAIN_PER_STAR := 0.12

## Extra stats per awakening level.
const GAIN_PER_AWAKENING := 0.08

## Awaken costs for the next star, by star band:
##   stars 2-5, 6-10, 11-15, 16-20
## Partners pay copies + pills. The MC has no duplicates,
## so it pays pills only, but more of them.
const COPIES_PER_STAR := [1, 2, 3, 4]

## Pills for the next star = base x growth ^ (stars - 1), rounded.
## MC: 18->19 costs ~100k, 19->20 ~160k, ~440k total to 20 stars.
## Partner: 19->20 ~48k, ~130k total to 20 stars.
const PILL_BASE := 15.0
const MC_PILL_BASE := 50.0
const PILL_GROWTH := 1.565


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


## "Qi Condensation 1"
func get_realm_text() -> String:
	return Realms.get_label(realm_index, tier)


## "Mortal Realm"
func get_major_realm_text() -> String:
	return Realms.get_major_name(realm_index)


## "Mortal Realm · Qi Condensation 1"
func get_full_realm_text() -> String:
	return "%s · %s" % [get_major_realm_text(), get_realm_text()]


func get_world() -> Enums.World:
	return Enums.get_world_for_realm(realm_index)


## The lower of the card tier cap and the major realm cap.
## The MC has no card-tier limit: only its realm caps its stars.
func get_star_cap() -> int:
	var realm_cap = Realms.get_star_cap_for_major(realm_index)

	if partner_id == GameState.MC_ID:
		return realm_cap

	var data = get_data()
	if data == null:
		return realm_cap
	return mini(realm_cap, Realms.get_star_cap_for_rarity(data.rarity))


# ---------------------------------------------------------
# STAT CALCULATION
#
#   base
#   x rarity multiplier
#   x growth ^ cultivation step
#   x star bonus
#   x awakening bonus
# ---------------------------------------------------------

func _get_stat_multiplier() -> float:
	var data = get_data()

	if data == null:
		return 1.0

	var step = Realms.get_step(realm_index, tier)

	var growth = pow(GROWTH_PER_STEP, step)

	var star_bonus = 1.0 + (stars - 1) * GAIN_PER_STAR

	var awakening_bonus = 1.0 + awakening * GAIN_PER_AWAKENING

	return (
		data.get_rarity_multiplier()
		* growth
		* star_bonus
		* awakening_bonus
	)


## Equipment and set bonuses for this partner (see Gear).
func _gear() -> Dictionary:
	var totals := Gear.totals_for(partner_id)
	for source in [Treasures.totals_for(partner_id), Lifebound.totals_for(partner_id), Beasts.totals_for(partner_id),
			Codex.totals(), GameState.sect_bonus]:
		for stat in source:
			totals[stat] = float(totals.get(stat, 0.0)) + source[stat]
	return totals


## (base x growth + flat gear) x (1 + gear %)
func _with_gear(base: float, flat_key: String, pct_key: String, g: Dictionary) -> int:
	var flat := float(g.get(flat_key, 0.0))
	var pct := float(g.get(pct_key, 0.0))
	return int((base * _get_stat_multiplier() + flat) * (1.0 + pct / 100.0))


func get_max_hp() -> int:
	var data = get_data()

	if data == null:
		return 1

	return _with_gear(data.base_hp, "hp", "hp_pct", _gear())


func get_atk() -> int:
	var data = get_data()

	if data == null:
		return 1

	return _with_gear(data.base_atk, "atk", "atk_pct", _gear())


func get_def() -> int:
	var data = get_data()

	if data == null:
		return 0

	return _with_gear(data.base_def, "def", "def_pct", _gear())


func get_mdef() -> int:
	var data = get_data()

	if data == null:
		return 0

	return _with_gear(data.base_mdef, "mdef", "mdef_pct", _gear())


func get_spd() -> int:
	var data = get_data()

	if data == null:
		return 0

	# Beast Rings can add flat SPD
	return int(data.base_spd * (1.0 + stars * 0.02) + float(_gear().get("spd", 0.0)))


func get_crit() -> float:
	var data = get_data()

	if data == null:
		return 0.0

	return minf(data.base_crit + awakening * 1.5 + float(_gear().get("crit", 0.0)), 100.0)


func get_crit_damage() -> float:
	var data = get_data()

	if data == null:
		return 150.0

	return data.base_crit_damage + awakening * 5.0 + float(_gear().get("crit_dmg", 0.0))


func get_eva() -> float:
	var data = get_data()

	if data == null:
		return 0.0

	return minf(data.base_eva + stars * 0.2 + float(_gear().get("eva", 0.0)), 75.0)


func get_accuracy() -> float:
	var data = get_data()

	if data == null:
		return 90.0

	return data.base_accuracy + float(_gear().get("acc", 0.0))


func get_energy_regen() -> int:
	var data = get_data()

	if data == null:
		return 20

	return data.base_energy_regen + awakening * 2 + int(_gear().get("energy", 0.0))


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

func is_mc() -> bool:
	return partner_id == GameState.MC_ID


## Qi needed for the next breakthrough (0 at the very top).
func get_ascend_cost() -> int:
	if is_max_realm():
		return 0
	return Realms.get_breakthrough_cost(realm_index, tier)


func _star_band() -> int:
	return clampi(floori(stars / 5.0), 0, COPIES_PER_STAR.size() - 1)


## Duplicate copies needed for the next star (0 for the MC).
func get_awaken_copies() -> int:
	if is_mc():
		return 0
	return COPIES_PER_STAR[_star_band()]


## Star-up Pills needed for the next star.
func get_awaken_pills() -> int:
	var base := MC_PILL_BASE if is_mc() else PILL_BASE
	return _round_nice(base * pow(PILL_GROWTH, maxi(stars - 1, 0)))


## 63 -> 65, 347 -> 350, 7384 -> 7400
static func _round_nice(value: float) -> int:
	if value < 100.0:
		return int(round(value / 5.0) * 5.0)
	if value < 1000.0:
		return int(round(value / 10.0) * 10.0)
	return int(round(value / 50.0) * 50.0)


# ---------------------------------------------------------
# WHAT'S BEEN SPENT (for salvage refunds)
# ---------------------------------------------------------

## Star-up Pills paid to reach the current stars.
func get_pills_invested() -> int:
	var base := MC_PILL_BASE if is_mc() else PILL_BASE
	var total := 0
	for s in range(1, stars):
		total += _round_nice(base * pow(PILL_GROWTH, s - 1))
	return total


## Duplicate copies used to reach the current stars.
func get_copies_invested() -> int:
	if is_mc():
		return 0
	var total := 0
	for s in range(1, stars):
		total += COPIES_PER_STAR[clampi(floori(s / 5.0), 0, COPIES_PER_STAR.size() - 1)]
	return total


## Qi paid for breakthroughs since the partner's starting realm.
func get_qi_invested() -> int:
	var data := get_data()
	var idx := Realms.clamp_index(data.starting_realm_index) if data != null else 0
	var lvl := 1
	var target := Realms.get_step(realm_index, tier)
	var total := 0
	while Realms.get_step(idx, lvl) < target:
		total += Realms.get_breakthrough_cost(idx, lvl)
		if lvl < Realms.LEVELS_PER_MINOR:
			lvl += 1
		elif idx < Realms.count() - 1:
			idx += 1
			lvl = 1
		else:
			break
	return total


## Partners can't pass the MC's realm and level.
func is_capped_by_mc() -> bool:
	if is_mc():
		return false
	var mc: OwnedPartner = GameState.get_mc()
	if mc == null:
		return false
	return Realms.get_step(realm_index, tier) >= Realms.get_step(mc.realm_index, mc.tier)

## True when the next breakthrough is a major one
## (e.g. Tribulation Transcendence 10 -> Spirit Realm).
func needs_major_breakthrough() -> bool:
	return tier >= Realms.LEVELS_PER_MINOR and Realms.is_last_in_major(realm_index)


func is_max_realm() -> bool:
	return realm_index >= Realms.count() - 1 and tier >= Realms.LEVELS_PER_MINOR


## Level 1-9: +1 level. Level 10: next minor realm.
## Last minor realm at level 10: major breakthrough.
## Returns false if already at the very top.
## (No costs or requirements yet -- test version.)
func breakthrough() -> bool:
	if tier < Realms.LEVELS_PER_MINOR:
		tier += 1
		return true

	if realm_index < Realms.count() - 1:
		realm_index += 1
		tier = 1
		return true

	return false


func add_star() -> bool:
	if stars >= get_star_cap():
		return false

	stars += 1
	return true


# ---------------------------------------------------------
# SAVE / LOAD
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
	partner.realm_index = Realms.clamp_index(int(dict.get("realm_index", 0)))
	partner.tier        = clampi(int(dict.get("tier", 1)), 1, Realms.LEVELS_PER_MINOR)
	partner.stars       = int(dict.get("stars", 1))
	partner.awakening   = int(dict.get("awakening", 0))
	partner.weapon_id   = dict.get("weapon_id", "")
	partner.armor_id    = dict.get("armor_id", "")
	partner.ring_id     = dict.get("ring_id", "")
	partner.boots_id    = dict.get("boots_id", "")

	return partner


static func create_new(id: String, data: PartnerData) -> OwnedPartner:
	var partner = OwnedPartner.new()

	partner.partner_id = id
	partner.realm_index = Realms.clamp_index(data.starting_realm_index)
	partner.tier = 1
	partner.stars = 1
	partner.awakening = 0

	return partner
