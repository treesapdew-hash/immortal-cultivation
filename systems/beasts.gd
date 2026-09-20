class_name Beasts

# =========================================================
# Spirit Beasts, Soul Spirits and spirit rings. Save as
#   res://systems/beasts.gd
#
# BEASTS live in hunting GROUNDS. In the Beast Forest (Events >
# Daily) the player hunts one: a boss fight on the home battlefield.
# A win can TAME the beast as a Soul Spirit (always the first time
# for a species, TAME_CHANCE after) and drops a spirit ring
# (Soul Land style: named and coloured by beast age) plus Beast Cores.
#
# SOUL SPIRITS: each partner bonds one; each spirit bonds only one
# partner (tame a species twice to use it on two partners). A spirit
# has 6 ring slots, opened by its partner's realm (RING_SLOT_REALMS).
# Rings in a spirit give the partner their stats and:
#   - unlock the beast's own BEAST SKILL (1+ rings), stronger with
#     more and older rings; it fires on every BEAST_EVERY-th action
#   - from 10,000-Year: a special battle effect
#   - from 100,000-Year: a boost to the partner's signature skill
# Rings move freely between spirits; merge 3 into the next age;
# salvage spares into Beast Cores.
#
# Saved in GameState: soul_spirits, beast_rings, beast_codex,
# beast_forest.
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

const HUNTS_PER_DAY := 3
const REFRESH_MAX := 2
const REFRESH_JADE := 100
## Chance a ring drop is one age above the ground's.
const UPGRADE_CHANCE := 15.0
## Chance to tame a beast after the first time.
const TAME_CHANCE := 10.0
const CORE_ID := "beast_core"
const ART_DIR := "res://assets/beasts/"

## Partner realm index needed for each of a spirit's 6 ring slots.
const RING_SLOT_REALMS := [0, 2, 6, 9, 13, 17]

## A spirit's Beast Skill fires on every Nth action of its partner.
const BEAST_EVERY := 4
## Beast Skill strength: power x (BASE + PER_RING x rings + PER_AGE x average age 0-6).
const BEAST_POWER_BASE := 0.55
const BEAST_POWER_PER_RING := 0.1
const BEAST_POWER_PER_AGE := 0.07
## + status chance per average age, +1 status turn with a 100,000-Year ring or older.
const BEAST_CHANCE_PER_AGE := 3.0

## Hunting grounds. grade = tier of the ring age dropped (see AGE_NAMES);
## realm = MC realm to enter; power = beast strength vs a major boss at
## your highest stage; cores = Beast Cores per win.
const GROUNDS := [
	{"id": "misty_woods", "name": "Misty Woods", "age": "10 to 100-year beasts", "grade": Enums.Rarity.WHITE,
		"realm": 0, "power": 0.7, "cores": 10, "color": Color("a8e8c8"),
		"species": ["azure_frost_wolf", "iron_hide_boar", "mist_fox", "moss_back_tortoise", "jade_scale_python", "wind_whisper_sparrow", "bamboo_panda", "silver_moon_rabbit", "shadow_lynx"]},
	{"id": "thunder_valley", "name": "Thunder Valley", "age": "1,000-year beasts", "grade": Enums.Rarity.GREEN,
		"realm": 2, "power": 0.9, "cores": 20, "color": Color("c8b8ff"),
		"species": ["thunder_roc", "stonebreaker_ape", "blade_wing_falcon", "thunder_rhino", "lightning_eel", "bronze_mantis", "cloud_leopard", "spirit_owl", "violet_thunder_serpent"]},
	{"id": "frost_peaks", "name": "Frost Peaks", "age": "10,000-year beasts", "grade": Enums.Rarity.PURPLE,
		"realm": 9, "power": 1.1, "cores": 35, "color": Color("a8e0ff"),
		"species": ["snow_jade_crane", "frost_tiger", "ice_silk_spider", "glacier_bear", "crystal_scorpion", "snow_lion", "ice_wyrm", "ice_phoenix", "white_ape_king"]},
	{"id": "abyssal_marsh", "name": "Abyssal Marsh", "age": "100,000-year beasts", "grade": Enums.Rarity.RED,
		"realm": 17, "power": 1.3, "cores": 55, "color": Color("ff8a6b"),
		"species": ["swamp_hydra", "flame_salamander", "black_tortoise", "blood_crocodile", "ghost_moth", "venom_toad_king", "abyss_kraken", "bone_vulture", "shadow_panther"]},
	{"id": "primordial_wilds", "name": "Primordial Wilds", "age": "Million-year beasts", "grade": Enums.Rarity.GOLD,
		"realm": 24, "power": 1.6, "cores": 80, "color": Color("ffd36b"),
		"species": ["golden_crow", "azure_dragon", "nine_tailed_fox", "white_tiger", "vermilion_bird", "qilin", "kunpeng", "taotie", "void_titan_ape"]},
]

## Beasts: [name, Dao, ground index, skill name, skill description,
## skill template (PartnerSkills.TEMPLATES), colour]
const SPECIES := {
	"azure_frost_wolf": ["Azure Frost Wolf", Enums.Path.SPIRIT, 0, "Frost Fang", "Freezing fangs on 3 foes that may freeze them.", "triple_stun", "9fe8ff"],
	"iron_hide_boar": ["Iron-Hide Boar", Enums.Path.MARTIAL, 0, "Iron Charge", "A crushing charge at the strongest foe.", "burst", "c8a070"],
	"mist_fox": ["Mist Fox", Enums.Path.MYSTIC, 0, "Veil of Mist", "Mist weakens every foe.", "sweep_weaken", "e0f0ff"],
	"moss_back_tortoise": ["Moss-Back Tortoise", Enums.Path.MARTIAL, 0, "Moss Shell", "A mossy shell shields the team.", "shield", "8fd49a"],
	"jade_scale_python": ["Jade-Scale Python", Enums.Path.SPIRIT, 0, "Jade Venom", "Venom seeps into every foe.", "sweep_bleed", "6bff9a"],
	"wind_whisper_sparrow": ["Wind-Whisper Sparrow", Enums.Path.MYSTIC, 0, "Tailwind Song", "A song of wind fills the team's energy.", "rally_team", "b8f0ff"],
	"bamboo_panda": ["Bamboo Panda", Enums.Path.MARTIAL, 0, "Bamboo Slam", "A heavy slam that may stun.", "burst_stun", "e8e8e8"],
	"silver_moon_rabbit": ["Silver Moon Rabbit", Enums.Path.DIVINE, 0, "Moonlit Mend", "Moonlight mends the weakest ally.", "heal", "e0e8ff"],
	"shadow_lynx": ["Shadow Lynx", Enums.Path.SPIRIT, 0, "Shadow Pounce", "Finishes the weakest foe from the shadows.", "execute", "8a7ab8"],
	"thunder_roc": ["Thunder Roc", Enums.Path.DIVINE, 1, "Storm Dive", "A lightning dive on 3 foes that may stun.", "triple_stun", "d9c8ff"],
	"stonebreaker_ape": ["Stonebreaker Ape", Enums.Path.MARTIAL, 1, "Mountain Fist", "A stone fist that breaks the strongest foe's armour.", "burst_ab", "c0a080"],
	"blade_wing_falcon": ["Blade-Wing Falcon", Enums.Path.SWORD, 1, "Blade Feathers", "Steel feathers slice 3 foes.", "triple", "c8e0ff"],
	"thunder_rhino": ["Thunder Rhino", Enums.Path.MARTIAL, 1, "Thunder Horn", "A thundering charge that breaks the guard of 3 foes.", "triple_ab", "b8a8ff"],
	"lightning_eel": ["Lightning Eel", Enums.Path.MYSTIC, 1, "Chain Lightning", "Lightning arcs through every foe and may stun.", "sweep_stun", "a8c8ff"],
	"bronze_mantis": ["Bronze Mantis", Enums.Path.SWORD, 1, "Scythe Dance", "Bronze scythes finish the weakest foe.", "execute", "d0a060"],
	"cloud_leopard": ["Cloud Leopard", Enums.Path.MARTIAL, 1, "Cloud Step", "Swift strikes on 2 foes that may stun.", "duo_stun", "d8e8ff"],
	"spirit_owl": ["Spirit Owl", Enums.Path.MYSTIC, 1, "Hush", "An eerie hoot silences 2 foes.", "duo_silence", "c9a0ff"],
	"violet_thunder_serpent": ["Violet Thunder Serpent", Enums.Path.SPIRIT, 1, "Thunder Coil", "A coil of violet lightning crushes one foe and silences it.", "burst_silence", "b476ff"],
	"snow_jade_crane": ["Snow Jade Crane", Enums.Path.DIVINE, 2, "Jade Blessing", "Healing light for the weakest ally.", "heal", "a8ffd8"],
	"frost_tiger": ["Frost Tiger", Enums.Path.MARTIAL, 2, "Glacial Pounce", "A frozen pounce that may freeze its target.", "burst_stun", "a8e0ff"],
	"ice_silk_spider": ["Ice Silk Spider", Enums.Path.SPIRIT, 2, "Frost Web", "Frost silk binds every foe, weakening them.", "sweep_weaken", "c8f0ff"],
	"glacier_bear": ["Glacier Bear", Enums.Path.MARTIAL, 2, "Glacier Hide", "An icy hide shields the team.", "shield", "a8d8ff"],
	"crystal_scorpion": ["Crystal Scorpion", Enums.Path.SPIRIT, 2, "Crystal Sting", "A venomous sting that eats the strongest foe's life.", "boss_killer", "a0f0ff"],
	"snow_lion": ["Snow Lion", Enums.Path.DIVINE, 2, "Holy Roar", "A holy roar strikes 3 foes and may silence them.", "triple_silence", "fff0c0"],
	"ice_wyrm": ["Ice Wyrm", Enums.Path.MYSTIC, 2, "Frost Breath", "Freezing breath sweeps every foe and may freeze them.", "sweep_stun", "9fe4ff"],
	"ice_phoenix": ["Ice Phoenix", Enums.Path.DIVINE, 2, "Frozen Rebirth", "Icy flames mend the weakest and shield the team.", "heal_team", "b8f0ff"],
	"white_ape_king": ["White Ape King", Enums.Path.MARTIAL, 2, "King's Rally", "A kingly roar strikes one foe and fills the team's energy.", "rally", "f0f0f0"],
	"swamp_hydra": ["Nine-Headed Swamp Hydra", Enums.Path.SPIRIT, 3, "Nine Venoms", "Nine heads poison every foe.", "sweep_bleed", "8fd46b"],
	"flame_salamander": ["Abyss Flame Salamander", Enums.Path.MYSTIC, 3, "Abyssal Flame", "Black-red flames burn every foe.", "sweep_bleed", "ff5a3a"],
	"black_tortoise": ["Black Tortoise", Enums.Path.MARTIAL, 3, "Northern Bastion", "An ancient shell shields the team.", "shield", "4a5a7a"],
	"blood_crocodile": ["Blood Crocodile", Enums.Path.MARTIAL, 3, "Death Roll", "A crushing bite that breaks the strongest foe's armour.", "burst_ab", "c03a3a"],
	"ghost_moth": ["Ghost Moth", Enums.Path.SPIRIT, 3, "Soul Dust", "Ghostly dust silences 3 foes.", "triple_silence", "c8b8ff"],
	"venom_toad_king": ["Venom Toad King", Enums.Path.SPIRIT, 3, "Toxic Croak", "A toxic croak weakens every foe.", "sweep_weaken", "9aff5a"],
	"abyss_kraken": ["Abyss Kraken", Enums.Path.MYSTIC, 3, "Abyssal Tide", "Tentacles from the deep crash on every foe.", "sweep", "4a8aaa"],
	"bone_vulture": ["Bone Vulture", Enums.Path.SPIRIT, 3, "Carrion Strike", "Finishes the weakest foe.", "execute", "d8d0c0"],
	"shadow_panther": ["Shadow Panther", Enums.Path.SWORD, 3, "Night Claws", "Claws like blades cut 3 foes and break their guard.", "triple_ab", "6a5a9a"],
	"golden_crow": ["Golden Crow", Enums.Path.DIVINE, 4, "Sun-Scorching Flight", "Sunfire scorches the strongest foe's life every turn.", "boss_killer", "ffd36b"],
	"azure_dragon": ["Azure Dragon", Enums.Path.MYSTIC, 4, "Azure Storm", "A dragon storm strikes every foe and may stun.", "sweep_stun", "6bb8ff"],
	"nine_tailed_fox": ["Nine-Tailed Fox", Enums.Path.SPIRIT, 4, "Nine-Tail Charm", "Spirit fire charms 3 foes, silencing them.", "triple_silence", "e0a0ff"],
	"white_tiger": ["White Tiger of the West", Enums.Path.MARTIAL, 4, "Killing Star", "The white tiger's claws break the guard of 3 foes.", "triple_ab", "f0f0ff"],
	"vermilion_bird": ["Vermilion Bird", Enums.Path.DIVINE, 4, "Southern Flame", "Divine flames mend the weakest and shield the team.", "heal_team", "ff6a3a"],
	"qilin": ["Qilin", Enums.Path.DIVINE, 4, "Auspicious Light", "Holy light shields the team and mends the weakest.", "shield_heal", "ffe6a8"],
	"kunpeng": ["Kunpeng", Enums.Path.MYSTIC, 4, "Ninety Thousand Li", "A colossal beating of wings strikes every foe.", "sweep", "8fd4ff"],
	"taotie": ["Taotie", Enums.Path.SPIRIT, 4, "Devour", "Devours one foe, crushing and silencing it.", "burst_silence", "c05a3a"],
	"void_titan_ape": ["Void Titan Ape", Enums.Path.MARTIAL, 4, "World-Shaking Fist", "A titanic fist on the strongest foe.", "burst", "8a6ab8"],
}

## Ring ages 0-6 (a ground's "grade" is the matching tier).
const GRADES := [Enums.Rarity.WHITE, Enums.Rarity.BLUE, Enums.Rarity.GREEN, Enums.Rarity.PURPLE,
	Enums.Rarity.RED, Enums.Rarity.GOLD, Enums.Rarity.PRISMATIC]
const AGE_NAMES := ["10-Year", "100-Year", "1,000-Year", "10,000-Year", "100,000-Year", "Million-Year", "Divine"]
## Ring icon files: assets/items/spirit_ring_<suffix>.png
const AGE_FILES := ["10y", "100y", "1000y", "10ky", "100ky", "million", "divine"]
## The ring's own colour (black for 10,000-Year) ...
const AGE_COLORS := [Color("f4f4f8"), Color("ffd84a"), Color("b476ff"), Color("1a1a24"),
	Color("ff3a3a"), Color("ffae2a"), Color("aef2ff")]
## ... and a readable text colour for each on dark UI
const AGE_TEXT_COLORS := [Color("f4f4f8"), Color("ffd84a"), Color("c9a0ff"), Color("9a8ab8"),
	Color("ff6a5a"), Color("ffc04a"), Color("aef2ff")]

## Main stats: key -> [label, value per age 0-6]
const MAIN_STATS := {
	"hp_pct": ["HP", [3.0, 5.0, 8.0, 12.0, 17.0, 23.0, 30.0]],
	"atk_pct": ["ATK", [3.0, 5.0, 8.0, 12.0, 17.0, 23.0, 30.0]],
	"def_pct": ["DEF", [4.0, 7.0, 11.0, 16.0, 22.0, 30.0, 40.0]],
	"spd": ["SPD", [3.0, 5.0, 8.0, 12.0, 16.0, 21.0, 27.0]],
	"crit": ["Crit", [1.0, 1.5, 2.5, 4.0, 5.5, 7.0, 9.0]],
}

## Special effects (10,000-Year and older): key -> [text, value for 10k, 100k, Million, Divine]
const SPECIALS := {
	"lifesteal": ["Heals %s%% of damage dealt", [4.0, 6.0, 9.0, 12.0]],
	"boss_damage": ["+%s%% damage to bosses", [8.0, 12.0, 17.0, 24.0]],
	"crit_damage": ["+%s%% crit damage", [15.0, 22.0, 32.0, 45.0]],
	"start_shield": ["Starts battle with a %s%% HP shield", [6.0, 9.0, 13.0, 18.0]],
	"start_energy": ["Starts battle with +%s energy", [15.0, 22.0, 30.0, 40.0]],
}

## Signature skill boosts (100,000-Year and older): key -> [text, value for 100k, Million, Divine]
const SKILL_EFFECTS := {
	"skill_power": ["Signature skill +%s%% power", [15.0, 22.0, 30.0]],
	"skill_chance": ["Signature skill +%s%% status chance", [10.0, 15.0, 20.0]],
	"skill_turns": ["Signature skill statuses last +%s turn", [1.0, 1.0, 2.0]],
}

## Merge: 3 spare rings of an age -> 1 of the next (costs cores).
const MERGE_COUNT := 3
const MERGE_CORES := [10, 20, 40, 80, 160, 320]
const SALVAGE_CORES := [3, 6, 12, 25, 50, 100, 200]


# ---------------------------------------------------------
# BEASTS AND AGES
# ---------------------------------------------------------

static func grade_index(rarity: int) -> int:
	return maxi(0, GRADES.find(rarity))


## "10,000-Year"
static func grade_name(g: int) -> String:
	return str(AGE_NAMES[clampi(g, 0, 6)])


static func grade_color(g: int) -> Color:
	var c: Color = AGE_COLORS[clampi(g, 0, 6)]
	return c


static func grade_text_color(g: int) -> Color:
	var c: Color = AGE_TEXT_COLORS[clampi(g, 0, 6)]
	return c


static func ring_icon_id(g: int) -> String:
	return "spirit_ring_" + str(AGE_FILES[clampi(g, 0, 6)])


static func species_name(id: String) -> String:
	return str(SPECIES.get(id, ["Spirit Beast"])[0])


static func species_dao(id: String) -> int:
	return int(SPECIES.get(id, ["", Enums.Path.MARTIAL])[1])


static func species_art(id: String) -> Texture2D:
	var path := ART_DIR + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func ground(id: String) -> Dictionary:
	for g in GROUNDS:
		if g["id"] == id:
			return g
	return {}


static func ground_open(g: Dictionary) -> bool:
	var mc := GameState.get_mc()
	return mc != null and mc.realm_index >= int(g["realm"])


## Codex: {species: {"slain": n, "tamed": n}}
static func codex_entry(species: String) -> Dictionary:
	var e: Dictionary = GameState.beast_codex.get(species, {})
	return e


# ---------------------------------------------------------
# SOUL SPIRITS
# ---------------------------------------------------------

static func _next_uid(list: Array) -> int:
	var best := 0
	for x in list:
		best = maxi(best, int(x.get("uid", 0)))
	return best + 1


static func tame(species: String) -> Dictionary:
	var spirit := {"uid": _next_uid(GameState.soul_spirits), "species": species, "partner": ""}
	GameState.soul_spirits.append(spirit)
	return spirit


static func find_spirit(uid: int) -> Dictionary:
	for s in GameState.soul_spirits:
		if int(s["uid"]) == uid:
			return s
	return {}


## The spirit bonded to a partner, or {}.
static func spirit_of(partner_id: String) -> Dictionary:
	for s in GameState.soul_spirits:
		if str(s.get("partner", "")) == partner_id:
			return s
	return {}


## Spirits not bonded to anyone.
static func free_spirits() -> Array:
	var out: Array = []
	for s in GameState.soul_spirits:
		if str(s.get("partner", "")) == "":
			out.append(s)
	return out


## Bonds a spirit to a partner (the partner's old spirit is released).
static func bond(spirit_uid: int, partner_id: String) -> String:
	var spirit := find_spirit(spirit_uid)
	if spirit.is_empty():
		return "Soul Spirit not found."
	if str(spirit.get("partner", "")) != "" and str(spirit["partner"]) != partner_id:
		return "That Soul Spirit is bonded to another partner."
	for s in GameState.soul_spirits:
		if str(s.get("partner", "")) == partner_id:
			s["partner"] = ""
	spirit["partner"] = partner_id
	_trim_rings(spirit)
	_changed()
	return ""


static func release(spirit_uid: int) -> void:
	var spirit := find_spirit(spirit_uid)
	if spirit.is_empty():
		return
	spirit["partner"] = ""
	_changed()


## How many ring slots a spirit has open (by its partner's realm).
static func open_slots(spirit: Dictionary) -> int:
	var partner := GameState.find_owned(str(spirit.get("partner", "")))
	if partner == null:
		return 0
	var n := 0
	for need in RING_SLOT_REALMS:
		if partner.realm_index >= int(need):
			n += 1
	return n


## Rings inside a spirit, ordered by slot.
static func rings_in(spirit: Dictionary) -> Array:
	var out: Array = []
	if spirit.is_empty():
		return out
	for r in GameState.beast_rings:
		if int(r.get("spirit", 0)) == int(spirit["uid"]):
			out.append(r)
	out.sort_custom(func(a, b): return int(a["slot"]) < int(b["slot"]))
	return out


## Rings in slots a spirit no longer has come out.
static func _trim_rings(spirit: Dictionary) -> void:
	var open := open_slots(spirit)
	for r in rings_in(spirit):
		if int(r["slot"]) >= open:
			r["spirit"] = 0
			r["slot"] = -1


# ---------------------------------------------------------
# RINGS
# ---------------------------------------------------------

static func make_ring(species: String, g: int) -> Dictionary:
	var keys: Array = MAIN_STATS.keys()
	var main_key := str(keys.pick_random())
	var ring := {
		"uid": _next_uid(GameState.beast_rings),
		"species": species,
		"grade": g,
		"main": main_key,
		"main_value": float(MAIN_STATS[main_key][1][g]),
		"special": "",
		"skill": "",
		"spirit": 0,
		"slot": -1,
	}
	if g >= 3:
		ring["special"] = str(SPECIALS.keys().pick_random())
	if g >= 4:
		ring["skill"] = str(SKILL_EFFECTS.keys().pick_random())
	return ring


static func find_ring(uid: int) -> Dictionary:
	for r in GameState.beast_rings:
		if int(r["uid"]) == uid:
			return r
	return {}


static func special_value(ring: Dictionary) -> float:
	var key := str(ring.get("special", ""))
	if key == "" or not SPECIALS.has(key):
		return 0.0
	return float(SPECIALS[key][1][clampi(int(ring["grade"]) - 3, 0, 3)])


static func skill_value(ring: Dictionary) -> float:
	var key := str(ring.get("skill", ""))
	if key == "" or not SKILL_EFFECTS.has(key):
		return 0.0
	return float(SKILL_EFFECTS[key][1][clampi(int(ring["grade"]) - 4, 0, 2)])


## "10,000-Year Frost Tiger Ring"
static func ring_name(ring: Dictionary) -> String:
	return "%s %s Ring" % [grade_name(int(ring["grade"])), species_name(str(ring["species"]))]


static func ring_lines(ring: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var main_key := str(ring["main"])
	var label := str(MAIN_STATS[main_key][0])
	var v := float(ring["main_value"])
	if main_key.ends_with("_pct") or main_key == "crit":
		out.append("+%s%% %s" % [_num(v), label])
	else:
		out.append("+%s %s" % [_num(v), label])
	if str(ring.get("special", "")) != "":
		out.append(str(SPECIALS[ring["special"]][0]) % _num(special_value(ring)))
	if str(ring.get("skill", "")) != "":
		out.append(str(SKILL_EFFECTS[ring["skill"]][0]) % _num(skill_value(ring)))
	return out


## Puts a ring into a spirit's slot (whatever was there comes out).
static func insert_ring(ring_uid: int, spirit_uid: int, slot: int) -> String:
	var ring := find_ring(ring_uid)
	var spirit := find_spirit(spirit_uid)
	if ring.is_empty() or spirit.is_empty():
		return "Not found."
	if slot < 0 or slot >= open_slots(spirit):
		return "That ring slot isn't open yet."
	for r in rings_in(spirit):
		if int(r["slot"]) == slot:
			r["spirit"] = 0
			r["slot"] = -1
	ring["spirit"] = spirit_uid
	ring["slot"] = slot
	_changed()
	return ""


static func remove_ring(ring_uid: int) -> void:
	var ring := find_ring(ring_uid)
	if ring.is_empty():
		return
	ring["spirit"] = 0
	ring["slot"] = -1
	_changed()


## Rings not in any spirit, best first.
static func spare_rings() -> Array:
	var out: Array = []
	for r in GameState.beast_rings:
		if int(r.get("spirit", 0)) == 0:
			out.append(r)
	out.sort_custom(func(a, b): return int(a["grade"]) > int(b["grade"]))
	return out


static func spare_of_age(g: int) -> Array:
	var out: Array = []
	for r in spare_rings():
		if int(r["grade"]) == g:
			out.append(r)
	return out


## Merges MERGE_COUNT spare rings of an age into one of the next age.
static func merge(g: int) -> Dictionary:
	if g >= 6:
		return {}
	var spares := spare_of_age(g)
	if spares.size() < MERGE_COUNT:
		return {}
	if not GameState.spend_item(CORE_ID, int(MERGE_CORES[g])):
		return {}
	var species := str(spares[0]["species"])
	for i in MERGE_COUNT:
		GameState.beast_rings.erase(spares[i])
	var ring := make_ring(species, g + 1)
	GameState.beast_rings.append(ring)
	_changed()
	return ring


static func salvage(ring_uid: int) -> int:
	var ring := find_ring(ring_uid)
	if ring.is_empty() or int(ring.get("spirit", 0)) != 0:
		return 0
	var cores := int(SALVAGE_CORES[clampi(int(ring["grade"]), 0, 6)])
	GameState.beast_rings.erase(ring)
	GameState.add_items({CORE_ID: cores})
	_changed()
	return cores


# ---------------------------------------------------------
# WHAT A PARTNER GETS
# ---------------------------------------------------------

## Stat totals from the rings in a partner's spirit (OwnedPartner gear keys).
static func totals_for(partner_id: String) -> Dictionary:
	var out := {}
	for r in rings_in(spirit_of(partner_id)):
		var key := str(r["main"])
		out[key] = float(out.get(key, 0.0)) + float(r["main_value"])
	return out


## Ring specials and signature-skill boosts: {key: total}.
static func effects_for(partner_id: String) -> Dictionary:
	var out := {}
	for r in rings_in(spirit_of(partner_id)):
		if str(r.get("special", "")) != "":
			var k := str(r["special"])
			out[k] = float(out.get(k, 0.0)) + special_value(r)
		if str(r.get("skill", "")) != "":
			var s := str(r["skill"])
			out[s] = float(out.get(s, 0.0)) + skill_value(r)
	return out


## The partner's Beast Skill, or {} (no spirit, or no rings in it).
static func beast_skill_for(partner_id: String) -> Dictionary:
	var spirit := spirit_of(partner_id)
	var rings := rings_in(spirit)
	if rings.is_empty():
		return {}
	var entry: Array = SPECIES.get(str(spirit["species"]), [])
	if entry.is_empty():
		return {}
	var base: Dictionary = PartnerSkills.TEMPLATES.get(str(entry[5]), PartnerSkills.TEMPLATES["burst"])
	var s := base.duplicate()
	var age_sum := 0.0
	var oldest := 0
	for r in rings:
		age_sum += float(r["grade"])
		oldest = maxi(oldest, int(r["grade"]))
	var avg_age := age_sum / float(rings.size())
	var mult := BEAST_POWER_BASE + BEAST_POWER_PER_RING * float(rings.size()) + BEAST_POWER_PER_AGE * avg_age
	s["power"] = float(s.get("power", 0.0)) * mult
	for key in ["heal_ally", "shield_team"]:
		if s.has(key):
			s[key] = float(s[key]) * mult
	if s.has("energy_team"):
		s["energy_team"] = int(round(float(s["energy_team"]) * mult))
	if s.has("status"):
		s["status_chance"] = minf(100.0, float(s.get("status_chance", 0.0)) + BEAST_CHANCE_PER_AGE * avg_age)
		if oldest >= 4:
			s["status_turns"] = int(s.get("status_turns", 1)) + 1
	s["name"] = str(entry[3])
	s["desc"] = str(entry[4])
	s["color"] = Color(str(entry[6]))
	s["beast"] = str(spirit["species"])
	return s


# ---------------------------------------------------------
# BEAST FOREST
# ---------------------------------------------------------

static func _forest() -> Dictionary:
	var f := GameState.beast_forest
	if int(f.get("day", 0)) != GameState.today():
		f["day"] = GameState.today()
		f["used"] = 0
		f["refreshes"] = 0
	return f


static func is_unlocked() -> bool:
	return GameState.get_mc() != null


static func hunts_left() -> int:
	return maxi(0, HUNTS_PER_DAY - int(_forest()["used"]))


static func refreshes_left() -> int:
	return maxi(0, REFRESH_MAX - int(_forest()["refreshes"]))


## A rewarded ad's extra hunt (Ads placement "extra_hunt").
static func grant_extra_hunt() -> void:
	var f := _forest()
	f["used"] = maxi(0, int(f["used"]) - 1)
	GameState.save_game()


static func buy_hunt() -> String:
	if refreshes_left() <= 0:
		return "No more extra hunts today."
	if not GameState.spend_immortal_jade(REFRESH_JADE):
		return "Not enough Immortal Jade."
	var f := _forest()
	f["refreshes"] = int(f["refreshes"]) + 1
	f["used"] = maxi(0, int(f["used"]) - 1)
	GameState.save_game()
	return ""


static func beast_enemies(g: Dictionary, species: String) -> Array:
	var stage := maxi(GameState.highest_stage, 1)
	var power := float(g["power"])
	var m := EnemyGenerator.atk_multiplier(stage)
	var team: Array = []
	team.resize(EnemyGenerator.TEAM_SIZE)
	var tex := species_art(species)
	if tex == null:
		tex = MonsterDB.pick_boss(stage, false)["sprite"]
	team[EnemyGenerator.BOSS_SLOT] = {
		"name": species_name(species),
		"monster_id": species,
		"immune": false,
		"hp": int(float(EnemyGenerator.BASE_HP) * EnemyGenerator.hp_multiplier(stage) * 8.0 * power),
		"atk": int(float(EnemyGenerator.BASE_ATK) * m * 2.5 * power),
		"def": int(float(EnemyGenerator.BASE_DEF) * m * 2.0 * power),
		"mdef": int(float(EnemyGenerator.BASE_DEF) * m * 2.0 * power),
		"spd": int(float(EnemyGenerator.BASE_SPD) * 1.1),
		"is_boss": true,
		"sprite": tex,
		"path": species_dao(species),
		"color": g["color"],
	}
	return team


static func can_hunt(g: Dictionary) -> String:
	if not ground_open(g):
		return "Opens at %s." % str(Realms.get_label(int(g["realm"]), 1))
	if hunts_left() <= 0:
		return "No hunts left today."
	return ""


static func challenge(from: Node, ground_id: String) -> String:
	var g := ground(ground_id)
	if g.is_empty():
		return "Unknown hunting ground."
	var error := can_hunt(g)
	if error != "":
		return error
	var battle := Dungeons.find_battle(from)
	if battle == null:
		return "Battle area not found."
	if battle.call("is_in_dungeon"):
		return "A fight is already waiting."
	var pool: Array = g["species"]
	var species := str(pool.pick_random())
	var request := {
		"kind": "beast_hunt",
		"ground": ground_id,
		"species": species,
		"enemies": beast_enemies(g, species),
		"title": species_name(species).to_upper(),
		"subtitle": "%s  ·  %s" % [g["name"], species_name(species)],
		"rewards": {},
	}
	if not battle.call("start_dungeon", request):
		return "A fight is already waiting."
	var router := from
	while router != null and not router.has_method("open_tab"):
		router = router.get_parent()
	if router != null:
		router.call("open_tab", "Home")
	return ""


## A won hunt: uses the hunt, maybe tames the beast, gives a ring and
## cores. Returns {"ring": ring, "tamed": bool}.
static func finish_hunt(request: Dictionary) -> Dictionary:
	var g := ground(str(request["ground"]))
	var species := str(request["species"])
	var f := _forest()
	f["used"] = int(f["used"]) + 1

	var entry: Dictionary = GameState.beast_codex.get(species, {"slain": 0, "tamed": 0})
	entry["slain"] = int(entry.get("slain", 0)) + 1
	var tamed := int(entry.get("tamed", 0)) == 0 or randf() * 100.0 < TAME_CHANCE
	if tamed:
		tame(species)
		entry["tamed"] = int(entry.get("tamed", 0)) + 1
	GameState.beast_codex[species] = entry

	var grade := grade_index(int(g["grade"]))
	if grade < 6 and randf() * 100.0 < UPGRADE_CHANCE:
		grade += 1
	var ring := make_ring(species, grade)
	GameState.beast_rings.append(ring)
	GameState.add_items({CORE_ID: int(g["cores"])})
	GameState.bump("beast_hunts")
	GameState.save_game()
	GameState.roster_changed.emit()
	return {"ring": ring, "tamed": tamed}


static func _changed() -> void:
	GameState.save_game()
	GameState.roster_changed.emit()


static func _num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")
