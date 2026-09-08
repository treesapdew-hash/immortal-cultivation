class_name Enums
extends RefCounted

# =========================================================
# Shared enums and constants.
#
# This file has a class_name, so you can use these anywhere
# without loading anything: Enums.Rarity.GOLD, Enums.Path.SWORD
# =========================================================


# ---------------------------------------------------------
# RARITY  (spec section 18)
# ---------------------------------------------------------

enum Rarity {
	WHITE,
	BLUE,
	GREEN,
	PURPLE,
	RED,
	GOLD,
	PRISMATIC
}


# Display colours for frames, name labels, etc.
const RARITY_COLORS := {
	Rarity.WHITE:     Color(0.85, 0.85, 0.85),
	Rarity.BLUE:      Color(0.30, 0.60, 1.00),
	Rarity.GREEN:     Color(0.25, 0.80, 0.35),
	Rarity.PURPLE:    Color(0.65, 0.35, 0.95),
	Rarity.RED:       Color(0.95, 0.30, 0.30),
	Rarity.GOLD:      Color(1.00, 0.80, 0.20),
	Rarity.PRISMATIC: Color(0.80, 0.95, 1.00)
}


# Base stat multiplier per rarity.
# A Gold partner starts far stronger than a White one.
const RARITY_STAT_MULTIPLIER := {
	Rarity.WHITE:     1.00,
	Rarity.BLUE:      1.25,
	Rarity.GREEN:     1.60,
	Rarity.PURPLE:    2.10,
	Rarity.RED:       2.80,
	Rarity.GOLD:      3.80,
	Rarity.PRISMATIC: 5.20
}


# ---------------------------------------------------------
# PATH  (spec sections 23 and 24)
# ---------------------------------------------------------

enum Path {
	DIVINE,   # All Damage, Defence
	SPIRIT,   # Energy, Effect Resistance
	MYSTIC,   # Skill Damage, Accuracy
	SWORD,    # Critical, Speed
	MARTIAL   # ATK, HP
}


const PATH_NAMES := {
	Path.DIVINE:  "Divine Path",
	Path.SPIRIT:  "Spirit Path",
	Path.MYSTIC:  "Mystic Path",
	Path.SWORD:   "Sword Path",
	Path.MARTIAL: "Martial Path"
}


# ---------------------------------------------------------
# MAJOR WORLDS  (spec section 3)
# ---------------------------------------------------------

enum World {
	LOWER,
	MIDDLE,
	UPPER,
	IMMORTAL
}


# Highest star level allowed in each world (spec section 22).
const WORLD_STAR_CAP := {
	World.LOWER:    10,
	World.MIDDLE:   20,
	World.UPPER:    30,
	World.IMMORTAL: 40
}


# ---------------------------------------------------------
# CULTIVATION REALMS  (spec section 4)
#
# 30 realms total. Index 0 = Mortal, index 29 = Transcendence.
# Each realm has 10 tiers, so there are 300 cultivation steps.
# ---------------------------------------------------------

const TIERS_PER_REALM := 10

const REALMS := [
	# --- LOWER REALM (index 0-9) ---
	"Mortal",
	"Qi Refining",
	"Foundation Establishment",
	"Golden Core",
	"Nascent Soul",
	"Soul Formation",
	"Void Refinement",
	"Body Integration",
	"Mahayana",
	"Tribulation Transcendence",

	# --- MIDDLE REALM (index 10-17) ---
	"Ascendant",
	"Spirit Saint",
	"Saint",
	"Saint King",
	"Great Saint",
	"Holy Sovereign",
	"Supreme",
	"Supreme Sovereign",

	# --- UPPER REALM (index 18-23) ---
	"Heavenly Venerable",
	"Dao Venerable",
	"Dao Lord",
	"Dao King",
	"Dao Sovereign",
	"Dao Emperor",

	# --- IMMORTAL REALM (index 24-29) ---
	"True Immortal",
	"Immortal King",
	"Quasi Immortal Emperor",
	"Immortal Emperor",
	"Sacrifice of Dao",
	"Transcendence"
]


const TIER_NUMERALS := [
	"I", "II", "III", "IV", "V",
	"VI", "VII", "VIII", "IX", "X"
]


# Which major world a realm index belongs to.
static func get_world_for_realm(realm_index: int) -> World:
	if realm_index < 10:
		return World.LOWER
	elif realm_index < 18:
		return World.MIDDLE
	elif realm_index < 24:
		return World.UPPER
	return World.IMMORTAL


# "Golden Core Tier IV"
static func format_realm(realm_index: int, tier: int) -> String:
	if realm_index < 0 or realm_index >= REALMS.size():
		return "Unknown"

	var tier_index = clampi(tier - 1, 0, TIERS_PER_REALM - 1)

	return "%s Tier %s" % [
		REALMS[realm_index],
		TIER_NUMERALS[tier_index]
	]


# Flattens realm + tier into a single 0-299 number.
# Used for stat scaling so one formula covers the whole game.
static func get_cultivation_step(realm_index: int, tier: int) -> int:
	return realm_index * TIERS_PER_REALM + (tier - 1)
