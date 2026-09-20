class_name Realms

# =========================================================
# The cultivation ladder.
#
# 4 major realms, each split into minor realms, each with
# levels 1-10. A unit's position is saved as realm_index
# (which minor realm) + level.
#
# Star caps rise every few minor realms, with bigger jumps
# at each major breakthrough. Card tiers cap stars too
# (the MC ignores the card tier cap).
# =========================================================


enum Major { MORTAL, SPIRIT, SOVEREIGN, IMMORTAL }

const LEVELS_PER_MINOR := 10

const MAJOR_NAMES := ["Mortal Realm", "Spirit Realm", "Sovereign Realm", "Immortal Realm"]


# ---------------------------------------------------------
# MINOR REALMS  [name, major realm]  -- index shown on the right
# ---------------------------------------------------------

const MINOR := [
	# Mortal Realm
	["Qi Condensation", Major.MORTAL],             # 0
	["Foundation Establishment", Major.MORTAL],    # 1
	["Golden Core", Major.MORTAL],                 # 2
	["Nascent Soul", Major.MORTAL],                # 3
	["Soul Formation", Major.MORTAL],              # 4
	["Void Refinement", Major.MORTAL],             # 5
	["Body Integration", Major.MORTAL],            # 6
	["Mahayana", Major.MORTAL],                    # 7
	["Tribulation Transcendence", Major.MORTAL],   # 8
	# Spirit Realm
	["Ascendant", Major.SPIRIT],                   # 9
	["Spirit Saint", Major.SPIRIT],                # 10
	["Saint", Major.SPIRIT],                       # 11
	["Saint King", Major.SPIRIT],                  # 12
	["Great Saint", Major.SPIRIT],                 # 13
	["Holy Sovereign Supreme", Major.SPIRIT],      # 14
	["Supreme Sovereign", Major.SPIRIT],           # 15
	["Heavenly Venerable", Major.SPIRIT],          # 16
	# Sovereign Realm
	["Dao Venerable", Major.SOVEREIGN],            # 17
	["Dao Lord", Major.SOVEREIGN],                 # 18
	["Dao King", Major.SOVEREIGN],                 # 19
	["Dao Saint", Major.SOVEREIGN],                # 20  (added: 30 realms)
	["Dao Sovereign", Major.SOVEREIGN],            # 21
	["Dao Emperor", Major.SOVEREIGN],              # 22
	["Dao Ancestor", Major.SOVEREIGN],             # 23  (added: 30 realms)
	# Immortal Realm
	["True Immortal", Major.IMMORTAL],             # 24
	["Immortal King", Major.IMMORTAL],             # 25
	["Quasi-Immortal Emperor", Major.IMMORTAL],    # 26
	["Immortal Emperor", Major.IMMORTAL],          # 27
	["Sacrifice of Dao", Major.IMMORTAL],          # 28
	["Transcendence", Major.IMMORTAL],             # 29
]

## Saves made with the old 28-realm ladder are converted on load:
## old index -> new index (see GameState._migrate_realms).
const OLD_28_TO_30 := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
	17, 18, 19, 21, 22, 24, 25, 26, 27, 28, 29]


# ---------------------------------------------------------
# STAR CAPS
# ---------------------------------------------------------

## [first minor realm index, star cap from that realm on]
const STAR_CAP_STEPS := [
	[0, 5], [2, 6], [4, 7], [7, 8],          # Mortal:    QC 5, GC 6, SF 7, Mahayana 8
	[9, 10], [11, 11], [13, 12], [15, 13],   # Spirit:    Asc 10, Saint 11, GS 12, SS 13
	[17, 15], [19, 16], [22, 17],            # Sovereign: DV 15, DK 16, DE 17
	[24, 18], [26, 19], [28, 20],            # Immortal:  TI 18, QIE 19, SoD 20
]

## Max stars for each card tier
const STAR_CAP_BY_RARITY := {
	"WHITE": 5, "BLUE": 8, "GREEN": 10, "PURPLE": 12,
	"RED": 15, "GOLD": 18, "PRISMATIC": 20,
}

## Card tiers in order, lowest first
const TIER_ORDER := ["WHITE", "BLUE", "GREEN", "PURPLE", "RED", "GOLD", "PRISMATIC"]


# ---------------------------------------------------------
# BREAKTHROUGH COST (Qi)  -- tune these freely
#
#   cost = QI_BASE x QI_GROWTH ^ step
#   x QI_MINOR_MULT when level 10 moves into the next minor realm
#   x QI_MAJOR_MULT when it moves into the next major realm
# ---------------------------------------------------------

## Retuned after alpha. The old 50 / 1.0745 made the Mortal Realm
## cost 757K Qi — about eight hours of idling — while the whole
## ladder came to 2.72T. That curve was steeply back-loaded: Spirit
## cost 314 times Mortal, so the early realms went by in an afternoon
## and testers were in the Spirit Realm the first day.
##
## Raising the base alone would not do: multiplying everything by the
## 22 the early game needed would have pushed the far end past eighty
## years. A bigger base with a gentler growth flattens it instead —
## the early realms cost far more, the late ones slightly less.
##
##   Mortal   757.5K -> 28.93M   (8 h -> 289 h of idling)
##   Spirit   238.1M -> 2.12B
##   Whole    2.72T  -> 2.24T    (the end barely moves)
##
## Spirit over Mortal falls from 314x to 73x, which is the point.
## Those hours are idle only; missions, achievements and chests make
## the real figure lower, so expect nearer a week than twelve days.
const QI_BASE := 8000.0
const QI_GROWTH := 1.055
const QI_MINOR_MULT := 3.0
const QI_MAJOR_MULT := 10.0


## Qi needed to go from (index, level) to the next step.
static func get_breakthrough_cost(index: int, level: int) -> int:
	var cost := QI_BASE * pow(QI_GROWTH, get_step(index, level))
	if level >= LEVELS_PER_MINOR:
		cost *= QI_MAJOR_MULT if is_last_in_major(index) else QI_MINOR_MULT
	return int(round(cost))


# ---------------------------------------------------------
# REALM LOOKUPS
# ---------------------------------------------------------

static func count() -> int:
	return MINOR.size()


static func clamp_index(index: int) -> int:
	return clampi(index, 0, MINOR.size() - 1)


static func get_major(index: int) -> int:
	return MINOR[clamp_index(index)][1]


## "Mortal Realm"
static func get_major_name(index: int) -> String:
	return MAJOR_NAMES[get_major(index)]


## "Qi Condensation"
static func get_minor_name(index: int) -> String:
	return MINOR[clamp_index(index)][0]


## "Qi Condensation 1"
static func get_label(index: int, level: int) -> String:
	return "%s %d" % [get_minor_name(index), level]


## Overall progress number (0, 1, 2 ...), used for stat growth.
static func get_step(index: int, level: int) -> int:
	return clamp_index(index) * LEVELS_PER_MINOR + clampi(level, 1, LEVELS_PER_MINOR) - 1


## True if the next breakthrough moves into a new major realm.
static func is_last_in_major(index: int) -> bool:
	index = clamp_index(index)
	if index >= MINOR.size() - 1:
		return true
	return get_major(index + 1) != get_major(index)


# ---------------------------------------------------------
# STAR CAP LOOKUPS
# ---------------------------------------------------------

## Star cap for a minor realm.
static func get_star_cap_for_realm(index: int) -> int:
	index = clamp_index(index)
	var cap := 5
	for step in STAR_CAP_STEPS:
		if index >= step[0]:
			cap = step[1]
	return cap


## Old name kept so other scripts still work.
static func get_star_cap_for_major(index: int) -> int:
	return get_star_cap_for_realm(index)


## Star cap for a card tier (Enums.Rarity value).
static func get_star_cap_for_rarity(rarity: int) -> int:
	var names = Enums.Rarity.keys()
	if rarity < 0 or rarity >= names.size():
		return 20
	return STAR_CAP_BY_RARITY.get(str(names[rarity]), 20)


# ---------------------------------------------------------
# TIER LOOKUPS
# ---------------------------------------------------------

## 0 = White ... 6 = Prismatic, whatever order Enums.Rarity uses.
static func tier_index(rarity: int) -> int:
	var names = Enums.Rarity.keys()
	if rarity < 0 or rarity >= names.size():
		return 0
	return maxi(0, TIER_ORDER.find(str(names[rarity])))


## The MC's tier for a star count: the first tier whose cap covers it.
static func tier_for_stars(star_count: int) -> String:
	for t in TIER_ORDER:
		if star_count <= STAR_CAP_BY_RARITY[t]:
			return t
	return TIER_ORDER[TIER_ORDER.size() - 1]
