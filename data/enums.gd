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
## White through Purple keep their original curve (about x1.3 a tier),
## so early progression is unchanged. Red and above step up harder:
## they are the rare tiers, Gold and Prismatic are only reachable by
## evolving a Premium Red, and the old table made Red a mere 33%
## better than Purple.
##
## The MC uses this too (its tier rises with sync_mc_tier), so it
## gains the same steeper curve as it climbs from White.
const RARITY_STAT_MULTIPLIER := {
	Rarity.WHITE:     1.00,
	Rarity.BLUE:      1.25,
	Rarity.GREEN:     1.60,
	Rarity.PURPLE:    2.10,
	Rarity.RED:       3.40,   # x1.62 Purple
	Rarity.GOLD:      5.60,   # x1.65 Red
	Rarity.PRISMATIC: 9.00    # x1.61 Gold
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


# Short descriptions for the Dao picker and tooltips.
const PATH_DESCRIPTIONS := {
	Path.DIVINE:  "All Damage, Defence",
	Path.SPIRIT:  "Energy, Effect Resistance",
	Path.MYSTIC:  "Skill Damage, Accuracy",
	Path.SWORD:   "Critical, Speed",
	Path.MARTIAL: "ATK, HP"
}


# Theme colour for each Dao (UI accents, glows).
const PATH_COLORS := {
	Path.DIVINE:  Color("f2c85b"),   # gold
	Path.SPIRIT:  Color("5ee6c8"),   # jade
	Path.MYSTIC:  Color("b57bff"),   # violet
	Path.SWORD:   Color("7fd4ff"),   # ice blue
	Path.MARTIAL: Color("ff6b5b"),   # crimson
}


# ---------------------------------------------------------
# MAJOR WORLDS
#
# One world per major realm, in the same order as
# Realms.Major (Mortal, Spirit, Sovereign, Immortal).
#
# The realm ladder itself, star caps and realm names all
# live in realms.gd. Don't add realm lists here.
# ---------------------------------------------------------

enum World {
	LOWER,      # Mortal Realm
	MIDDLE,     # Spirit Realm
	UPPER,      # Sovereign Realm
	IMMORTAL    # Immortal Realm
}


# Which world a minor realm index (see Realms.MINOR) belongs to.
static func get_world_for_realm(realm_index: int) -> World:
	return Realms.get_major(realm_index) as World
