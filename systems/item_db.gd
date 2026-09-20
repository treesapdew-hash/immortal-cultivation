class_name ItemDB

# =========================================================
# Every stackable item in the game.
#
#   Fixed items are listed in ITEMS.
#   Regional materials come from MATERIALS (one group per major realm).
#   Breakthrough pills are generated: one per minor realm, named
#   after the realm you break into ("Golden Core Pill").
#
# Counts live in GameState.items (Star-up Pills are special:
# they use GameState.starup_pills).
# =========================================================

enum Category { PILL, MATERIAL, EQUIPMENT, TREASURE }

const CATEGORY_NAMES := ["Pills", "Materials", "Equipment", "Treasures"]

## Grade names from the concept (treasure ladder), shared by all items.
const GRADE_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Heaven-Defying"]
const GRADE_COLORS := [
	Color("c9cfd8"), Color("5aa8ff"), Color("4ddc7a"), Color("b476ff"),
	Color("ff5a4d"), Color("ffcf4a"), Color("9ff6ff"),
]

const ITEMS := {
	"starup_pill": {
		"name": "Star-up Pill", "category": Category.PILL, "grade": 3, "icon": "pill",
		"desc": "Refined essence used to awaken partners and the MC to higher stars.",
		"action": "awaken",
	},
	"refining_ore": {
		"name": "Refining Ore", "category": Category.MATERIAL, "grade": 2, "icon": "core",
		"tint": Color("c9a27a"),
		"desc": "Used to refine equipment. From the Armory Ruins and salvaged gear.",
	},
	"forge_formula_1": {
		"name": "Refined Forging Formula", "category": Category.MATERIAL, "grade": 1, "icon": "core",
		"tint": Color("9fd8ff"),
		"desc": "Used at the Spirit Forge. The artifact is at least Uncommon.",
	},
	"forge_formula_2": {
		"name": "Profound Forging Formula", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("b476ff"),
		"desc": "Used at the Spirit Forge. The artifact is at least Rare.",
	},
	"forge_formula_3": {
		"name": "Heavenly Forging Formula", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ffcf4a"),
		"desc": "Used at the Spirit Forge. The artifact is at least Epic.",
	},
	"artifact_core": {
		"name": "Artifact Core", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("9fd8ff"),
		"desc": "Forged into artifacts at the Spirit Forge. From Secret Realm expeditions.",
	},
	"lifebound_essence": {
		"name": "Lifebound Essence", "category": Category.MATERIAL, "grade": 4, "icon": "core",
		"tint": Color("ff9ad8"),
		"desc": "Feeds a partner's Lifebound Artifact. From Secret Realm expeditions.",
	},
	"treasure_dust": {
		"name": "Treasure Dust", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("d8a8ff"),
		"desc": "Ground from old treasures. Used to enhance and grade up treasures.",
	},
	"array_flag": {
		"name": "Array Flag", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("ff8a5a"),
		"desc": "Formation flags that upgrade the Battle Array in the Abode.",
		"source": "Daily and weekly mission chests, and the Treasure Pavilion (More tab).",
	},
	"sect_contribution": {
		"name": "Sect Contribution", "category": Category.MATERIAL, "grade": 4, "icon": "core",
		"tint": Color("8fe0a8"),
		"desc": "Your standing in your sect, spent in the Sect Shop. Earned by signing in and donating each day.",
		"source": "Sect Hall: daily sign-in and donations.",
	},
	"beast_core": {
		"name": "Beast Core", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("ffb36b"),
		"desc": "The core of a spirit beast. Merges Beast Rings into higher grades.",
		"source": "Beast Forest hunts (Events > Daily) and salvaging Beast Rings.",
	},
	"spirit_ring_10y": {
		"name": "10-Year Spirit Ring", "category": Category.MATERIAL, "grade": 0, "icon": "core",
		"tint": Color("f4f4f8"),
		"desc": "A 10-Year spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"spirit_ring_100y": {
		"name": "100-Year Spirit Ring", "category": Category.MATERIAL, "grade": 1, "icon": "core",
		"tint": Color("ffd84a"),
		"desc": "A 100-Year spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"spirit_ring_1000y": {
		"name": "1,000-Year Spirit Ring", "category": Category.MATERIAL, "grade": 2, "icon": "core",
		"tint": Color("b476ff"),
		"desc": "A 1,000-Year spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"spirit_ring_10ky": {
		"name": "10,000-Year Spirit Ring", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("6a5a8a"),
		"desc": "A 10,000-Year spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"spirit_ring_100ky": {
		"name": "100,000-Year Spirit Ring", "category": Category.MATERIAL, "grade": 4, "icon": "core",
		"tint": Color("ff3a3a"),
		"desc": "A 100,000-Year spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"spirit_ring_million": {
		"name": "Million-Year Spirit Ring", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ffae2a"),
		"desc": "A Million-Year spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"spirit_ring_divine": {
		"name": "Divine Spirit Ring", "category": Category.MATERIAL, "grade": 6, "icon": "core",
		"tint": Color("aef2ff"),
		"desc": "A Divine spirit ring from a spirit beast. Rings are kept in the partner panel's ring slots, not here.",
	},
	"summon_scroll": {
		"name": "Summon Scroll", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("9fe4ff"),
		"desc": "One free summon at the Summoning Altar. Used before Jade.",
		"source": "Events, mission chests and the Treasure Pavilion.",
	},
	"summon_scroll_10": {
		"name": "Summon Scroll Bundle", "category": Category.MATERIAL, "grade": 4, "icon": "core",
		"tint": Color("ffd36b"),
		"desc": "A full ×10 summon at the Summoning Altar, with its guaranteed Purple. Used before Jade.",
		"source": "Events, mission chests and the Treasure Pavilion.",
	},
	"premium_scroll": {
		"name": "Premium Selection Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ff4a3a"),
		"desc": "Choose one Premium Red from several. Premium Reds can evolve into Gold and Prismatic forms, and can't be summoned normally.",
		"source": "Special events, top rankings and packs.",
	},
	"premium_scroll_heavenly_flames": {
		"name": "Heavenly Flames Premium Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ff8a3a"),
		"desc": "Choose a Premium Red of the Heavenly Flames set: Xiao Yan, Medusa, Xiao Xun'er, Zi Yan or Yao Lao.",
		"source": "Special events, top rankings and packs.",
	},
	"premium_scroll_douluo_continent": {
		"name": "Douluo Continent Premium Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("b8a0ff"),
		"desc": "Choose a Premium Red of the Douluo Continent set: Tang San, Bibi Dong or Qian Renxue.",
		"source": "Special events, top rankings and packs.",
	},
	"premium_scroll_heaven_defiers": {
		"name": "Heaven-Defiers Premium Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ff5a4a"),
		"desc": "Choose a Premium Red of the Heaven-Defiers set: Wang Lin or Shi Hao.",
		"source": "Special events, top rankings and packs.",
	},
	"premium_scroll_peak_seekers": {
		"name": "Peak Seekers Premium Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ffd36b"),
		"desc": "Choose a Premium Red of the Peak Seekers set: Yang Kai, Qin Yu or Meng Chuan.",
		"source": "Special events, top rankings and packs.",
	},
	"premium_scroll_guardians_of_light": {
		"name": "Guardians of Light Premium Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("fff0c0"),
		"desc": "Choose a Premium Red of the Guardians of Light set: Lin Qiye or Long Haochen.",
		"source": "Special events, top rankings and packs.",
	},
	"select_scroll_purple": {
		"name": "Purple Selection Scroll", "category": Category.MATERIAL, "grade": 3, "icon": "core",
		"tint": Color("b476ff"),
		"desc": "Choose one Purple partner from several. Open it at the Summoning Altar.",
	},
	"select_scroll_red": {
		"name": "Red Selection Scroll", "category": Category.MATERIAL, "grade": 4, "icon": "core",
		"tint": Color("ff5a5a"),
		"desc": "Choose one Red partner from several. Open it at the Summoning Altar.",
	},
	"select_scroll_gold": {
		"name": "Gold Selection Scroll", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ffcf4a"),
		"desc": "Choose one Gold partner from several. Gold partners can't be summoned any other way.",
	},
	"select_scroll_prismatic": {
		"name": "Prismatic Selection Scroll", "category": Category.MATERIAL, "grade": 6, "icon": "core",
		"tint": Color("aef2ff"),
		"desc": "Choose one Prismatic partner from several, the rarest cards of all.",
	},
	"divinity_essence": {
		"name": "Divine Essence", "category": Category.MATERIAL, "grade": 5, "icon": "core",
		"tint": Color("ffe6a8"),
		"desc": "Pure divine essence. Trains your god's Blessing and Divine Skill in the God Path.",
		"source": "The Fallen God (Events) and divine events.",
	},
	"heavenly_ore": {
		"name": "Heavenly Refining Ore", "category": Category.MATERIAL, "grade": 4, "icon": "core",
		"tint": Color("ffd36b"),
		"desc": "Needed to refine equipment past +50. From deep Armory Ruins floors.",
	},
	"enhance_pill_1": {
		"name": "Tempering Pill", "category": Category.PILL, "grade": 0, "icon": "pill",
		"desc": "Enhances a card a little.",
	},
	"enhance_pill_2": {
		"name": "Refining Pill", "category": Category.PILL, "grade": 2, "icon": "pill",
		"desc": "Enhances a card considerably.",
	},
	"enhance_pill_3": {
		"name": "Nirvana Pill", "category": Category.PILL, "grade": 4, "icon": "pill",
		"desc": "Enhances a card greatly. Needed to push Red cards toward evolution.",
	},
}

## Material roles within a region.
const ROLES := ["herb_common", "herb_rare", "core_common", "core_rare"]

## One group per major realm (Mortal, Spirit, Sovereign, Immortal), in ROLES order:
## [id, name, grade, description]
const MATERIALS := [
	[
		["spirit_grass", "Spirit Grass", 0, "A common herb found across the Mortal lands."],
		["cloud_ginseng", "Cloud Ginseng", 1, "A ginseng that grows above the clouds. Mortal lands, from Stage 100."],
		["beast_core_1", "Lesser Beast Core", 1, "Condensed Qi from a Mortal-land beast."],
		["flame_serpent_core", "Flame Serpent Core", 2, "Still warm to the touch. Mortal lands, from Stage 200."],
	],
	[
		["jade_lotus", "Jade Lotus", 2, "A lotus of the Spirit lands, from Stage 800."],
		["moonlit_orchid", "Moonlit Orchid", 3, "Only opens under the full moon. Spirit lands, from Stage 900."],
		["beast_core_2", "Spirit Beast Core", 3, "The core of a Spirit-land beast, from Stage 800."],
		["thunder_roc_core", "Thunder Roc Core", 4, "Crackles with lightning. Spirit lands, from Stage 1,000."],
	],
	[
		["dragon_blood_vine", "Dragon Blood Vine", 3, "Grows where dragons bled. Sovereign lands, from Stage 2,500."],
		["dao_lotus", "Nine-Leaf Dao Lotus", 4, "Each leaf holds a fragment of the Dao. Sovereign lands, from Stage 2,600."],
		["sovereign_core", "Sovereign Beast Core", 4, "The core of a Sovereign-land beast, from Stage 2,500."],
		["azure_dragon_core", "Azure Dragon Core", 5, "The heart of an azure dragon. Sovereign lands, from Stage 2,700."],
	],
	[
		["phoenix_blossom", "Phoenix Blossom", 4, "Blooms in phoenix fire. Immortal lands, from Stage 6,000."],
		["immortal_peach", "Immortal Peach", 5, "One bite adds a thousand years. Immortal lands, from Stage 6,100."],
		["beast_core_3", "Demon King Core", 5, "Pulses with terrifying power. Immortal lands, from Stage 6,000."],
		["chaos_core", "Primordial Chaos Core", 6, "Older than the heavens. Immortal lands, from Stage 6,200."],
	],
]

## Grade of the breakthrough pill for each minor realm index (0 is unused).
const REALM_PILL_GRADES := [
	0, 1, 1, 1, 2, 2, 2, 2, 2,        # Mortal
	3, 3, 3, 3, 3, 4, 4, 4,           # Spirit
	4, 4, 5, 5, 5, 5, 5,              # Sovereign (7)
	5, 5, 6, 6, 6, 6,                 # Immortal
]

static var _all: Dictionary = {}


## Every item, fixed and generated.
static func all() -> Dictionary:
	if not _all.is_empty():
		return _all

	_all = ITEMS.duplicate(true)

	for major in MATERIALS.size():
		var group: Array = MATERIALS[major]
		for r in ROLES.size():
			var m: Array = group[r]
			var role: String = ROLES[r]
			_all[m[0]] = {
				"name": m[1], "category": Category.MATERIAL, "grade": m[2],
				"icon": "herb" if role.begins_with("herb") else "core",
				"desc": m[3], "major": major, "role": role,
			}

	for i in range(1, Realms.count()):
		var realm := Realms.get_minor_name(i)
		_all[realm_pill_id(i)] = {
			"name": "%s Pill" % realm,
			"category": Category.PILL,
			"grade": REALM_PILL_GRADES[clampi(i, 0, REALM_PILL_GRADES.size() - 1)],
			"icon": "pill",
			"desc": "Raises the chance of breaking through into %s. Crafted in the Abode." % realm,
			"realm_index": i,
			"major": Realms.get_major(i),
			"tint": realm_pill_color(i),
			"pattern": i % 3,
		}

	return _all


## A distinct colour per realm pill. Hues are spread with the golden
## ratio, so neighbouring realms never look alike.
static func realm_pill_color(index: int) -> Color:
	var hue := fmod(0.08 + index * 0.618034, 1.0)
	var major := Realms.get_major(index)
	# Higher realms: richer and brighter
	var sat := 0.55 + major * 0.08
	var val := 0.85 + major * 0.04
	return Color.from_hsv(hue, clampf(sat, 0.0, 1.0), clampf(val, 0.0, 1.0))


## Pill for breaking INTO minor realm `index`.
static func realm_pill_id(index: int) -> String:
	return "realm_pill_%d" % index


## Material id for a major realm and role ("herb_common", ...).
static func material_id(major: int, role: String) -> String:
	var group: Array = MATERIALS[clampi(major, 0, MATERIALS.size() - 1)]
	return group[ROLES.find(role)][0]


static func all_ids() -> Array:
	return all().keys()


static func has(id: String) -> bool:
	return all().has(id)


static func get_item(id: String) -> Dictionary:
	return all().get(id, {})


static func grade_color(grade: int) -> Color:
	return GRADE_COLORS[clampi(grade, 0, GRADE_COLORS.size() - 1)]


static func grade_name(grade: int) -> String:
	return GRADE_NAMES[clampi(grade, 0, GRADE_NAMES.size() - 1)]


## Card tier -> item grade (White = Common ... Prismatic = Heaven-Defying).
static func grade_for_rarity(rarity: int) -> int:
	return clampi(Realms.tier_index(rarity), 0, GRADE_COLORS.size() - 1)


## All item ids in a category, highest grade first.
static func ids_in(category: int) -> Array:
	var items := all()
	var ids: Array = []
	for id in items:
		if items[id]["category"] == category:
			ids.append(id)
	ids.sort_custom(func(a, b): return items[a]["grade"] > items[b]["grade"])
	return ids
