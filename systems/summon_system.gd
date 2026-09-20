class_name SummonSystem

# =========================================================
# Summon rules. All numbers are tunable here.
#
#   var results := SummonSystem.pull(10)
#   # -> [{partner_id, tier, is_new}, ...] or [] if not enough Jade
#
# If a tier has no cards yet (e.g. only White art exists), the
# pull falls back to the nearest tier that does have cards.
#
# Paying: scrolls are used before Jade.
#   x1   1 Summon Scroll, else COST_SINGLE Jade
#   x10  1 Scroll Bundle, else 10 Summon Scrolls, else COST_TEN Jade
#
# Selection Scrolls (Purple and up): pick 1 of CHOICE_SIZE
# partners of that tier. The scroll is used only once you choose.
# =========================================================

# Fate Points: every summon earns FATE_PER_PULL. FATE_COST of them buy
# one of the featured Red partners, which rotate every ROTATION_DAYS
# through FATE_ROTATION. Reds that can evolve (Gold / Prismatic forms)
# are kept out of the rotation.
const FATE_PER_PULL := 1
const FATE_COST := 300
const ROTATION_DAYS := 14

## Groups of 4 featured Reds, each a mix of damage, control and support.
const FATE_ROTATION := [
	["han_li_nascent", "zi_yu", "huo_yuhao_ice_jade_emperor", "bai_xiaochun_young_ancestor"],
	["luo_feng_peak", "mo_fan_demon_element", "zhang_xiaofan_ghost_li", "ye_fan_sacred_body"],
	["sheng_caier_reincarnation", "jing_jiu_peak", "nie_li_shadow_devil", "baili_dongjun_mature"],
	["chen_ping_an_swordbearer", "zhuo_fan_demon_emperor", "chu_feng", "ni_tian_er_xing"],
	["qin_mu_devil_cult", "mu_chen_nine_nether_flame_form", "wu_geng_late_king", "luo_zheng_late_form"],
	["fang_han_mature", "jiang_taixu_divine_king", "xiao_se_late", "yun_yun_hua_sect"],
	["ye_dingzhi", "lin_dong_yuan_gate", "wuxin_late", "abao_demonized_form"],
	["xu_yang", "luo_feng_peak", "chu_feng", "bai_xiaochun_young_ancestor"],
]

# Premium Reds: Reds that evolve into Gold (and Prismatic) forms.
# They never appear in normal summons, Fate Exchange, regular Red
# Selection Scrolls or reward chests: only Premium Selection Scrolls
# (event, ranking and pack rewards) give them.
# Grouped into legend sets, each with its own scroll.
const PREMIUM_SCROLL := "premium_scroll"
## group id: [name, colour, [premium red ids]]
const PREMIUM_GROUPS := {
	"heavenly_flames": ["Heavenly Flames", Color("ff8a3a"),
		["xiao_yan_douzun", "medusa_dou_sheng", "gu_xuner_gu_clan", "zi_yan_mature_dragon", "yao_lao_restored_body"]],
	"douluo_continent": ["Douluo Continent", Color("b8a0ff"),
		["tang_san_sea_god", "bibi_dong_limit_douluo", "qian_renxue_limit_douluo"]],
	"heaven_defiers": ["Heaven-Defiers", Color("ff5a4a"),
		["wang_lin_ascendant", "shi_hao_imperial_pass"]],
	"peak_seekers": ["Peak Seekers", Color("ffd36b"),
		["yang_kai_late_dragon", "qin_yu_god_realm", "meng_chuan_lightning_form"]],
	"guardians_of_light": ["Guardians of Light", Color("fff0c0"),
		["lin_qiye_night_watcher", "long_haochen_divine_knight"]],
}

const SCROLL_ID := "summon_scroll"
const BUNDLE_ID := "summon_scroll_10"

## Selection Scroll item per tier.
const SELECT_SCROLLS := {
	Enums.Rarity.PURPLE: "select_scroll_purple",
	Enums.Rarity.RED: "select_scroll_red",
	Enums.Rarity.GOLD: "select_scroll_gold",
	Enums.Rarity.PRISMATIC: "select_scroll_prismatic",
}

## Raised from 100/900 after alpha: achievements hand out far more
## Jade than the old prices assumed, so a x10 was close to free.
## The x10 keeps its discount, just a smaller one.
const COST_SINGLE := 350
const COST_TEN := 3000

## Normal rates, in % (adds up to 100).
## Gold and Prismatic can never be summoned.
const RATES := {
	Enums.Rarity.WHITE:  51.0,
	Enums.Rarity.BLUE:   30.4,
	Enums.Rarity.GREEN:  13.0,
	Enums.Rarity.PURPLE: 5.0,
	Enums.Rarity.RED:    0.6,
}

## Highest tier a summon can ever give.
const MAX_TIER := Enums.Rarity.RED

## Guaranteed pull (10-pull slot and pity): Purple, small chance of Red.
const GUARANTEE_RATES := {
	Enums.Rarity.PURPLE: 95.0,
	Enums.Rarity.RED:    5.0,
}

## A guaranteed Purple (or Red) on this pull if none came earlier.
const PITY_LIMIT := 20


static func get_cost(count: int) -> int:
	return COST_TEN if count >= 10 else COST_SINGLE * count


## How this summon would be paid: "bundle", "scrolls", "jade" or "" (can't).
static func pay_method(count: int) -> String:
	if count >= 10:
		if GameState.get_item_count(BUNDLE_ID) >= 1:
			return "bundle"
		if GameState.get_item_count(SCROLL_ID) >= 10:
			return "scrolls"
	elif GameState.get_item_count(SCROLL_ID) >= count:
		return "scrolls"
	return "jade" if GameState.immortal_jade >= get_cost(count) else ""


static func can_afford(count: int) -> bool:
	return pay_method(count) != ""


## "1 Scroll Bundle", "10 Summon Scrolls", "900 Jade"...
static func cost_text(count: int) -> String:
	match pay_method(count):
		"bundle":
			return "1 Scroll Bundle"
		"scrolls":
			return "%d Summon Scroll%s" % [count, "" if count == 1 else "s"]
	return "%s Jade" % NumberFormat.short(get_cost(count))


static func _pay(count: int) -> bool:
	match pay_method(count):
		"bundle":
			return GameState.spend_item(BUNDLE_ID, 1)
		"scrolls":
			return GameState.spend_item(SCROLL_ID, count)
		"jade":
			return GameState.spend_immortal_jade(get_cost(count))
	return false


## Pulls left until Purple is guaranteed.
static func pulls_until_pity() -> int:
	return maxi(PITY_LIMIT - GameState.summon_pity, 0)


## Pays (scrolls first, then Jade) and returns what was pulled
## (empty if it couldn't be paid).
static func pull(count: int) -> Array:
	if not _pay(count):
		return []
	GameState.fate_points += count * FATE_PER_PULL

	GameState.bump("summons", count)

	var tiers: Array = []
	for i in count:
		GameState.summon_pity += 1
		var tier: int
		if GameState.summon_pity >= PITY_LIMIT:
			tier = _roll(GUARANTEE_RATES)
		else:
			tier = _roll(RATES)
		if tier >= Enums.Rarity.PURPLE:
			GameState.summon_pity = 0
		tiers.append(tier)

	# 10-pull guarantee: if nothing reached Purple, upgrade one slot.
	# (Pity can't have triggered in that case, so recount it from there.)
	if count >= 10 and tiers.max() < Enums.Rarity.PURPLE:
		var slot := randi_range(0, count - 1)
		tiers[slot] = _roll(GUARANTEE_RATES)
		GameState.summon_pity = count - 1 - slot

	# The very first summon always brings a Purple (or better)
	if not GameState.first_summon_done:
		GameState.first_summon_done = true
		if tiers.max() < Enums.Rarity.PURPLE:
			tiers[0] = Enums.Rarity.PURPLE
			GameState.summon_pity = count - 1

	var pools := _build_pools()
	var results: Array = []
	for tier in tiers:
		var id := _pick_partner(pools, tier)
		if id == "":
			continue
		var is_new := GameState.find_owned(id) == null
		GameState.add_partner(id)
		results.append({"partner_id": id, "tier": tier, "is_new": is_new})

	GameState.save_game()
	return results


## Picks a tier using weighted chances.
static func _roll(table: Dictionary) -> int:
	var total := 0.0
	for key in table:
		total += table[key]

	var r := randf() * total
	for key in table:
		r -= table[key]
		if r <= 0.0:
			return key
	return table.keys().back()


## Rarity -> list of partner ids. The MC, Gold and Prismatic are never pullable.
static func _build_pools() -> Dictionary:
	var pools := {}
	for id in PartnerDatabase.get_all_ids():
		if id == GameState.MC_ID or is_premium(str(id)):
			continue
		var data = PartnerDatabase.get_partner(id)
		if data == null or data.rarity > MAX_TIER:
			continue
		if not pools.has(data.rarity):
			pools[data.rarity] = []
		pools[data.rarity].append(id)
	return pools


## A random partner of this tier, or of the nearest tier that has cards.
static func _pick_partner(pools: Dictionary, tier: int) -> String:
	var order := Enums.Rarity.values()
	var start := order.find(mini(tier, MAX_TIER))

	# Try this tier, then lower tiers, then higher ones.
	for i in range(start, -1, -1):
		if pools.has(order[i]) and not pools[order[i]].is_empty():
			return pools[order[i]].pick_random()
	for i in range(start + 1, order.size()):
		if pools.has(order[i]) and not pools[order[i]].is_empty():
			return pools[order[i]].pick_random()
	return ""


# ---------------------------------------------------------
# SELECTION SCROLLS
# ---------------------------------------------------------

## Selection Scrolls the player owns: [{tier, item_id, count}], best first.
static func owned_selection_scrolls() -> Array:
	var out: Array = []
	var tiers: Array = SELECT_SCROLLS.keys()
	tiers.sort()
	tiers.reverse()
	for tier in tiers:
		var id := str(SELECT_SCROLLS[tier])
		var n := GameState.get_item_count(id)
		if n > 0:
			out.append({"tier": int(tier), "item_id": id, "count": n})
	# Premium Selection Scrolls (Premium Reds)
	var premium := [PREMIUM_SCROLL]
	for g in PREMIUM_GROUPS:
		premium.append(premium_scroll_id(str(g)))
	for id in premium:
		var n := GameState.get_item_count(str(id))
		if n > 0:
			out.push_front({"tier": Enums.Rarity.RED, "item_id": str(id), "count": n, "premium": true})
	return out


## The partners a Selection Scroll offers (the scroll isn't used yet).
static func selection_options(tier: int) -> Array:
	return Achievements.card_options(tier)


## Uses one Selection Scroll and gives the chosen partner.
static func choose_from_scroll(item_id: String, partner_id: String) -> bool:
	if not GameState.spend_item(item_id, 1):
		return false
	GameState.add_partner(partner_id)
	GameState.save_game()
	GameState.roster_changed.emit()
	return true


# ---------------------------------------------------------
# FATE EXCHANGE
# ---------------------------------------------------------

## Local day number (days since 1 Jan 1970, local date).
static func _day_number() -> int:
	var t := Time.get_datetime_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": t["year"], "month": t["month"], "day": t["day"], "hour": 0, "minute": 0, "second": 0})
	return floori(float(unix) / 86400.0)


static func _period() -> int:
	return floori(float(_day_number()) / float(ROTATION_DAYS))


## This period's featured Reds (only ones that exist in the game).
static func featured_ids() -> Array:
	var group: Array = FATE_ROTATION[posmod(_period(), FATE_ROTATION.size())]
	var out: Array = []
	for id in group:
		if PartnerDatabase.has_partner(str(id)):
			out.append(str(id))
	return out


## Days until the featured list changes.
static func days_to_rotation() -> int:
	return (_period() + 1) * ROTATION_DAYS - _day_number()


static func can_exchange() -> bool:
	return GameState.fate_points >= FATE_COST and not featured_ids().is_empty()


## Spends Fate Points on a featured Red. Returns true if it worked.
static func exchange(partner_id: String) -> bool:
	if not featured_ids().has(partner_id) or GameState.fate_points < FATE_COST:
		return false
	GameState.fate_points -= FATE_COST
	GameState.add_partner(partner_id)
	GameState.save_game()
	GameState.roster_changed.emit()
	GameState.currency_changed.emit()
	return true


# ---------------------------------------------------------
# PREMIUM REDS
# ---------------------------------------------------------

static var _premium_cache := {}


## A Red with a Gold evolution in its family (or listed in a group).
static func is_premium(partner_id: String) -> bool:
	if _premium_cache.is_empty():
		for g in PREMIUM_GROUPS:
			for id in PREMIUM_GROUPS[g][2]:
				_premium_cache[str(id)] = true
		for fam in PartnerSkills.FAMILIES:
			var members: Array = PartnerSkills.FAMILIES[fam][5]
			var has_gold := false
			for id in members:
				var d = PartnerDatabase.get_partner(str(id))
				if d != null and int(d.rarity) >= Enums.Rarity.GOLD:
					has_gold = true
			if not has_gold:
				continue
			for id in members:
				var d = PartnerDatabase.get_partner(str(id))
				if d != null and int(d.rarity) == Enums.Rarity.RED:
					_premium_cache[str(id)] = true
		_premium_cache["_built"] = true
	return _premium_cache.has(partner_id)


## Every Premium Red that exists in the game.
static func premium_ids() -> Array:
	is_premium("")
	var out: Array = []
	for id in _premium_cache:
		if str(id) != "_built" and PartnerDatabase.has_partner(str(id)):
			out.append(str(id))
	return out


## Item id of a group's scroll ("premium_scroll_<group>").
static func premium_scroll_id(group: String) -> String:
	return "%s_%s" % [PREMIUM_SCROLL, group]


## Evolution starts here. Below Purple a family's forms (a White Han
## Li, a Green Han Li) are separate partners you summon, not stages
## of one card.
const EVOLVE_FROM := Enums.Rarity.PURPLE


## Every form a partner can evolve into right now: the members of
## their family at the next rarity up. Usually one, but Lin Qiye's
## Red becomes either Nyx or Merlin, so the player picks.
##
## How far a line runs is decided purely by which forms exist. A
## family topping out at Gold stops there; only the seven with a
## Prismatic form reach Prismatic; a Purple whose family's best is
## Red is capped at Red.
static func next_forms(partner_id: String) -> Array:
	var data = PartnerDatabase.get_partner(partner_id)
	if data == null or int(data.rarity) < EVOLVE_FROM:
		return []
	for fam in PartnerSkills.FAMILIES:
		var members: Array = PartnerSkills.FAMILIES[fam][5]
		if members.find(partner_id) < 0:
			continue
		# The lowest rarity above this one, and every form at it.
		var step := -1
		for id in members:
			var d = PartnerDatabase.get_partner(str(id))
			if d == null or int(d.rarity) <= int(data.rarity):
				continue
			if step < 0 or int(d.rarity) < step:
				step = int(d.rarity)
		if step < 0:
			return []
		var out: Array = []
		for id in members:
			var d2 = PartnerDatabase.get_partner(str(id))
			if d2 != null and int(d2.rarity) == step:
				out.append(str(id))
		return out
	return []


## The single form a partner evolves into, or "" when there is none
## or the player has to choose between several.
static func next_form(partner_id: String) -> String:
	var forms := next_forms(partner_id)
	return str(forms[0]) if forms.size() == 1 else ""


## Premium Reds the player actually owns. Soul Fragments are useless
## for a partner you don't have, so only these can be forged for.
static func owned_premium_ids() -> Array:
	var out: Array = []
	for id in premium_ids():
		if GameState.find_owned(str(id)) != null:
			out.append(str(id))
	return out


## The tier a Selection Scroll belongs to, or -1 if the item isn't
## one. Premium scrolls count as Red, since that is the tier their
## partners are before evolving.
static func scroll_tier(item_id: String) -> int:
	if item_id == PREMIUM_SCROLL:
		return Enums.Rarity.RED
	for g in PREMIUM_GROUPS:
		if item_id == premium_scroll_id(str(g)):
			return Enums.Rarity.RED
	for tier in SELECT_SCROLLS:
		if str(SELECT_SCROLLS[tier]) == item_id:
			return int(tier)
	return -1


## The partners a scroll offers (any Selection Scroll item).
##
## Premium scrolls offer EVERY partner they cover, not a random
## handful: they are rare enough that the pick should be the
## player's, and the group scrolls already worked this way. Tier
## scrolls still offer a random CHOICE_SIZE, which is what makes
## them the common reward.
static func options_for_scroll(item_id: String) -> Array:
	if item_id == PREMIUM_SCROLL:
		# Kept in group order (the cache is built from PREMIUM_GROUPS),
		# so the list reads as themed sets rather than a jumble.
		return premium_ids()
	for g in PREMIUM_GROUPS:
		if item_id == premium_scroll_id(str(g)):
			var ids: Array = []
			for id in PREMIUM_GROUPS[g][2]:
				if PartnerDatabase.has_partner(str(id)):
					ids.append(str(id))
			return ids
	for tier in SELECT_SCROLLS:
		if str(SELECT_SCROLLS[tier]) == item_id:
			return selection_options(int(tier))
	return []
