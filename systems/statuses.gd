class_name Statuses

# =========================================================
# Debuffs and buffs carried by a unit in battle.
#
# A unit's statuses live in CombatUnit.statuses:
#   {"bleed": {"turns": 2, "power": 18.0}, ...}
#
# "power" means different things per status (see below).
# =========================================================

const STUN := "stun"
const SILENCE := "silence"
const BLEED := "bleed"
const WEAKEN := "weaken"
const ARMOR_BREAK := "armor_break"
const HEAVENLY_BLEED := "heavenly_bleed"
const IMMUNE := "immune"

## Everything a unit can be protected from by Immunity.
const DEBUFFS := [STUN, SILENCE, BLEED, WEAKEN, ARMOR_BREAK, HEAVENLY_BLEED]

## name, colour, short tag for the unit's status row, and what power means.
const DEFS := {
	STUN: {
		"name": "Stun", "color": Color("ffd36b"), "tag": "STN",
		"desc": "Loses its turn.",
	},
	SILENCE: {
		"name": "Silence", "color": Color("c86bff"), "tag": "SIL",
		"desc": "Can't use skills.",
	},
	BLEED: {
		"name": "Bleed", "color": Color("ff6b6b"), "tag": "BLD",
		"desc": "Takes damage at the start of each turn.",
	},
	WEAKEN: {
		"name": "Weaken", "color": Color("9aa7bd"), "tag": "WKN",
		"desc": "Deals less damage.",
	},
	ARMOR_BREAK: {
		"name": "Armor Break", "color": Color("ff9a5a"), "tag": "ARM",
		"desc": "Takes more damage.",
	},
	HEAVENLY_BLEED: {
		"name": "Heavenly Bleed", "color": Color("ff4d7a"), "tag": "HBL",
		"desc": "Loses a share of its maximum HP each turn, however large it is.",
	},
	IMMUNE: {
		"name": "Immunity", "color": Color("ffe6a8"), "tag": "IMM",
		"desc": "Cannot be debuffed.",
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func color_of(id: String) -> Color:
	return get_def(id).get("color", Color.WHITE)


static func name_of(id: String) -> String:
	return str(get_def(id).get("name", id))


static func tag_of(id: String) -> String:
	return str(get_def(id).get("tag", "?"))


static func is_debuff(id: String) -> bool:
	return id in DEBUFFS
