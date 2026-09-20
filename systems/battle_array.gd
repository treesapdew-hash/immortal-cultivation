class_name BattleArray

# =========================================================
# Battle Array, in the Abode. Save as
#   res://systems/battle_array.gd
#
# Partners who aren't in the formation can rest in the array.
# Each one lends a share of its HP, ATK and DEF to every unit
# in the team, so bench partners are still worth ascending,
# starring up and gearing. Upgrading the array opens more
# slots and raises the share.
#
# Saved in GameState.array_level and GameState.battle_array
# (partner id per slot, "" = empty).
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

## Upgrade material.
const FLAG_ID := "array_flag"

## One entry per level (level 1 first):
##   slots   open slots
##   share   % of each array partner's HP / ATK / DEF lent to every unit
##   stones, flags   cost to reach this level
##   realm   MC's minor realm index needed to reach this level
const LEVELS := [
	{"slots": 2, "share": 3.0, "stones": 0, "flags": 0, "realm": 0},
	{"slots": 2, "share": 3.5, "stones": 30000, "flags": 10, "realm": 2},
	{"slots": 4, "share": 4.0, "stones": 80000, "flags": 20, "realm": 4},
	{"slots": 4, "share": 4.5, "stones": 200000, "flags": 35, "realm": 6},
	{"slots": 6, "share": 5.0, "stones": 500000, "flags": 60, "realm": 9},
	{"slots": 6, "share": 5.5, "stones": 1200000, "flags": 90, "realm": 11},
	{"slots": 7, "share": 6.0, "stones": 3000000, "flags": 130, "realm": 13},
	{"slots": 8, "share": 6.5, "stones": 7000000, "flags": 180, "realm": 16},
	{"slots": 9, "share": 7.0, "stones": 15000000, "flags": 250, "realm": 19},
	{"slots": 10, "share": 8.0, "stones": 30000000, "flags": 350, "realm": 24},
]

## Once the array is maxed, flag rewards turn into this much
## Treasure Dust per flag, so they never pile up unused.
const FLAG_TO_DUST := 10

## Dao harmony: when this many array partners share a Dao, every
## array partner lends this many extra % points.
const DAO_BONUS := {3: 1.0, 5: 2.0}


# ---------------------------------------------------------
# LEVELS AND SLOTS
# ---------------------------------------------------------

static func level() -> int:
	return clampi(GameState.array_level, 1, LEVELS.size())


static func level_def(lv: int) -> Dictionary:
	return LEVELS[clampi(lv, 1, LEVELS.size()) - 1]


static func is_max_level() -> bool:
	return level() >= LEVELS.size()


## Swaps Array Flags for Treasure Dust in a reward list once the
## array can't use them any more. Changes `items` in place.
static func convert_spare_flags(items: Dictionary) -> void:
	if not is_max_level() or not items.has(FLAG_ID):
		return
	var dust := int(items[FLAG_ID]) * FLAG_TO_DUST
	items.erase(FLAG_ID)
	items["treasure_dust"] = int(items.get("treasure_dust", 0)) + dust


static func slot_count() -> int:
	return int(level_def(level())["slots"])


static func max_slots() -> int:
	return int(LEVELS[LEVELS.size() - 1]["slots"])


## Level at which a slot opens (slot 0 = first).
static func level_for_slot(slot: int) -> int:
	for i in LEVELS.size():
		if int(LEVELS[i]["slots"]) > slot:
			return i + 1
	return LEVELS.size()


## Partner id in each open slot ("" = empty).
static func slots() -> Array:
	_pad()
	return GameState.battle_array.slice(0, slot_count())


## Makes sure every open slot exists in the save.
static func _pad() -> void:
	while GameState.battle_array.size() < slot_count():
		GameState.battle_array.append("")


static func is_member(partner_id: String) -> bool:
	return slots().has(partner_id)


## Partners in the array who can lend stats right now.
static func members() -> Array:
	var out: Array = []
	for id in slots():
		if str(id) == "":
			continue
		var p := GameState.find_owned(str(id))
		if p != null and not _in_team(p):
			out.append(p)
	return out


## Partners that could be placed: not the MC, not in the team,
## not already in the array. Strongest first.
static func candidates() -> Array:
	var out: Array = []
	for p in GameState.roster:
		if p == null or p.is_mc() or _in_team(p) or is_member(p.partner_id):
			continue
		out.append(p)
	out.sort_custom(func(a, b): return strength(a) > strength(b))
	return out


## Rough strength, only used for sorting.
static func strength(p: OwnedPartner) -> int:
	return floori(float(p.get_max_hp()) / 10.0) + p.get_atk() + p.get_def()


static func _in_team(p: OwnedPartner) -> bool:
	return GameState.get_slot_of(GameState.roster.find(p)) != -1


# ---------------------------------------------------------
# BONUS
# ---------------------------------------------------------

static func dao_of(p: OwnedPartner) -> int:
	var path = p.get("path")
	var data = p.get_data()
	if path == null and data != null:
		path = data.get("path")
	return int(path) if path != null else -1


## Most array partners sharing one Dao: [dao, count].
static func dao_harmony() -> Array:
	var counts := {}
	for p in members():
		var d := dao_of(p)
		if d >= 0:
			counts[d] = int(counts.get(d, 0)) + 1
	var best_dao := -1
	var best := 0
	for d in counts:
		if int(counts[d]) > best:
			best = int(counts[d])
			best_dao = int(d)
	return [best_dao, best]


## Extra % points from Dao harmony.
static func dao_extra() -> float:
	var count := int(dao_harmony()[1])
	var extra := 0.0
	for need in DAO_BONUS:
		if count >= int(need):
			extra = maxf(extra, float(DAO_BONUS[need]))
	return extra


## % of stats each array partner lends right now.
static func share() -> float:
	return float(level_def(level())["share"]) + dao_extra()


## What one partner lends at a given share: {hp, atk, def}.
static func contribution(p: OwnedPartner, share_pct: float) -> Dictionary:
	var f := share_pct / 100.0
	return {
		"hp": floori(float(p.get_max_hp()) * f),
		"atk": floori(float(p.get_atk()) * f),
		"def": floori(float(p.get_def()) * f),
	}


## Total added to every unit in the team: {hp, atk, def}.
static func bonus() -> Dictionary:
	var total := {"hp": 0, "atk": 0, "def": 0}
	var pct := share()
	for p in members():
		var c := contribution(p, pct)
		for key in total:
			total[key] = int(total[key]) + int(c[key])
	return total


# ---------------------------------------------------------
# PLACING
# ---------------------------------------------------------

## Puts a partner in a slot (swapping out whoever was there).
## Returns "" on success, or why it can't.
static func place(slot: int, partner_id: String) -> String:
	if slot < 0 or slot >= slot_count():
		return "That slot isn't open yet."
	var p := GameState.find_owned(partner_id)
	if p == null:
		return "Partner not found."
	if p.is_mc():
		return "The MC always fights in the team."
	if _in_team(p):
		return "Remove them from your team first."
	var arr := slots()
	var old := arr.find(partner_id)
	if old >= 0:
		GameState.battle_array[old] = ""
	GameState.battle_array[slot] = partner_id
	_changed()
	return ""


static func remove(slot: int) -> void:
	if slot < 0 or slot >= GameState.battle_array.size():
		return
	GameState.battle_array[slot] = ""
	_changed()


## Fills every empty slot with the strongest free partners.
## Returns how many were placed.
static func auto_fill() -> int:
	var free := candidates()
	var arr := slots()
	var placed := 0
	for i in arr.size():
		if str(arr[i]) != "" or free.is_empty():
			continue
		var p: OwnedPartner = free.pop_front()
		GameState.battle_array[i] = p.partner_id
		placed += 1
	if placed > 0:
		_changed()
	return placed


static func _changed() -> void:
	GameState.save_game()
	GameState.array_changed.emit()


# ---------------------------------------------------------
# UPGRADING
# ---------------------------------------------------------

## "" if the next level can be bought, otherwise why not.
static func can_upgrade() -> String:
	if is_max_level():
		return "The array is at its highest level."
	var next := level_def(level() + 1)
	var mc := GameState.get_mc()
	var need_realm := int(next["realm"])
	if mc == null or mc.realm_index < need_realm:
		var realm: String = Realms.get_label(need_realm, 1)
		return "Your MC must reach %s first." % realm
	if GameState.spirit_stones < int(next["stones"]):
		return "Not enough Spirit Stones."
	if GameState.get_item_count(FLAG_ID) < int(next["flags"]):
		return "Not enough Array Flags."
	return ""


static func upgrade() -> String:
	var error := can_upgrade()
	if error != "":
		return error
	var next := level_def(level() + 1)
	if not GameState.spend_spirit_stones(int(next["stones"])):
		return "Not enough Spirit Stones."
	if not GameState.spend_item(FLAG_ID, int(next["flags"])):
		GameState.add_spirit_stones(int(next["stones"]))
		return "Not enough Array Flags."
	GameState.array_level = level() + 1
	_pad()
	_changed()
	return ""
