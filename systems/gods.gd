class_name Gods

# =========================================================
# God Path: God's Avatar and Divinity. Save as
#   res://systems/gods.gd
#
# Unlocks when the MC reaches UNLOCK_REALM. The player then CHOOSES
# a god. Later gods unlock at higher Divinity Levels, but they're
# sidegrades (different styles), not stronger.
#
#   Divinity Level (permanent, Divinity EXP): raises the chosen
#     god's team stats and the strength of its divine strike.
#   Training (Divine Essence), per god, levels 1-TRAIN_MAX:
#     Blessing     the passive gets stronger
#     Divine Skill more skill damage, better status chance
#   Switching gods resets both trainings to level 1; the Divine
#   Essence spent on them is lost.
#
# The chosen god gives team stats, its blessing (battle_core.gd)
# and, from DESCEND_LEVEL, its divine skill every few rounds
# (home_battle.gd).
#
# Saved in GameState.gods: {level, exp, active, blessing_lv, skill_lv}
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

## Ascendant, the first Spirit Realm.
const UNLOCK_REALM := 9
const MAX_LEVEL := 100

## EXP for the next level = EXP_BASE x EXP_GROWTH ^ (level - 1).
## ~2.5M EXP in total to reach level 100.
const EXP_BASE := 100.0
const EXP_GROWTH := 1.08

## Divine skill: unlocks at DESCEND_LEVEL. The god takes its own turn
## after every DESCEND_AFTER_ROUNDS full rounds:
##   round 1, round 2, GOD, round 3, round 4, GOD, ...
const DESCEND_LEVEL := 5
const DESCEND_AFTER_ROUNDS := 2
## The god strikes with the team's average ATK x this (grows per level).
const GOD_ATK_BASE := 0.6
const GOD_ATK_PER_LEVEL := 0.02

## Training: Divine Essence per level = TRAIN_COST_BASE x TRAIN_COST_GROWTH ^ (level - 1).
## ~7.5K Essence to take one track from 1 to 30.
const ESSENCE_ID := "divinity_essence"
const TRAIN_MAX := 30
const TRAIN_COST_BASE := 20.0
const TRAIN_COST_GROWTH := 1.15
## Each Divine Skill level: +4% skill power and +1% status chance.
const SKILL_POWER_PER_LEVEL := 0.04
const SKILL_CHANCE_PER_LEVEL := 1.0

## Art in assets/ui/god_path/: avatar_<id>.png, emblem_<id>.png
const ART_DIR := "res://assets/ui/god_path/"

## Each Avatar. "stats" are per Divinity Level (similar budgets, so no
## god is simply stronger):
##   hp_pct, atk_pct, def_pct, spd_pct: team % bonus
##   crit: flat crit chance, crit_dmg: flat crit damage
## Blessing strength = blessing_base + blessing_per_level x Blessing level.
const AVATARS := [
	{
		"id": "thunder", "name": "Thunder Sovereign", "inspired": "Lord of storms and heavenly thunder",
		"unlock": 1, "color": Color("c8a8ff"),
		"stats": {"atk_pct": 0.35, "crit": 0.08},
		"blessing": "crit_dmg", "blessing_per_level": 1.2, "blessing_base": 10.0,
		"blessing_text": "Critical hits deal +%s%% more damage.",
		"blessing_label": "Crit damage", "blessing_format": "+%s%%",
		"skill": {
			"name": "Heaven-Splitting Thunder", "color": Color("d9c8ff"),
			"desc": "Thunder crashes on 3 foes, with a chance to stun.",
			"targets": 3, "power": 1.6,
			"status": Statuses.STUN, "status_chance": 35.0, "status_turns": 1, "status_power": 0.0,
			"fx": "beam",
		},
	},
	{
		"id": "asura", "name": "Asura War God", "inspired": "The three-faced god of endless war",
		"unlock": 10, "color": Color("ff6b5a"),
		"stats": {"atk_pct": 0.3, "hp_pct": 0.2},
		"blessing": "desperate", "blessing_per_level": 1.0, "blessing_base": 10.0,
		"blessing_text": "Units below half HP deal +%s%% damage.",
		"blessing_label": "Damage below half HP", "blessing_format": "+%s%%",
		"skill": {
			"name": "Six Paths of Carnage", "color": Color("ff8a6b"),
			"desc": "Blades rain on every foe and leave them bleeding.",
			"targets": 6, "power": 0.9,
			"status": Statuses.BLEED, "status_chance": 60.0, "status_turns": 2, "status_power": 20.0,
			"fx": "slash",
		},
	},
	{
		"id": "sea", "name": "Abyssal Sea Emperor", "inspired": "Sovereign of the boundless seas",
		"unlock": 25, "color": Color("6bd8ff"),
		"stats": {"hp_pct": 0.35, "def_pct": 0.3},
		"blessing": "tide_shield", "blessing_per_level": 0.5, "blessing_base": 5.0,
		"blessing_text": "The team starts every battle with a shield of %s%% max HP.",
		"blessing_label": "Starting shield", "blessing_format": "%s%% of max HP",
		"skill": {
			"name": "Abyssal Tide", "color": Color("8fe4ff"),
			"desc": "A great wave weakens every foe and shields your team.",
			"targets": 6, "power": 0.5,
			"status": Statuses.WEAKEN, "status_chance": 60.0, "status_turns": 2, "status_power": 20.0,
			"shield_team": 12.0,
			"fx": "aura",
		},
	},
	{
		"id": "sky", "name": "Heavenly Father of Skies", "inspired": "Ruler of the heavens and the dawn",
		"unlock": 40, "color": Color("ffd36b"),
		"stats": {"spd_pct": 0.2, "atk_pct": 0.2, "crit": 0.05},
		"blessing": "dawn_energy", "blessing_per_level": 1.0, "blessing_base": 20.0,
		"blessing_text": "Units start every battle with +%s energy.",
		"blessing_label": "Starting energy", "blessing_format": "+%s",
		"skill": {
			"name": "Decree of the Sky Father", "color": Color("ffe6a8"),
			"desc": "Judgment falls on the strongest foe, breaking its armour; allies gain energy.",
			"targets": 1, "power": 3.5, "target_rule": "strongest",
			"status": Statuses.ARMOR_BREAK, "status_chance": 80.0, "status_turns": 2, "status_power": 25.0,
			"energy_team": 25,
			"fx": "beam",
		},
	},
]


# ---------------------------------------------------------
# STATE
# ---------------------------------------------------------

static func _state() -> Dictionary:
	var g := GameState.gods
	if not g.has("level"):
		g["level"] = 1
		g["exp"] = 0
		g["active"] = ""
	if not g.has("blessing_lv"):
		g["blessing_lv"] = 1
		g["skill_lv"] = 1
	return g


static func is_unlocked() -> bool:
	var mc := GameState.get_mc()
	return mc != null and mc.realm_index >= UNLOCK_REALM


static func level() -> int:
	return clampi(int(_state()["level"]), 1, MAX_LEVEL)


static func exp_now() -> int:
	return int(_state()["exp"])


static func exp_to_next(lv: int) -> int:
	return int(round(EXP_BASE * pow(EXP_GROWTH, float(lv - 1))))


static func is_max() -> bool:
	return level() >= MAX_LEVEL


## Adds Divinity EXP, levelling up as it fills. Returns levels gained.
static func add_exp(amount: int) -> int:
	var g := _state()
	var lv := level()
	var xp := exp_now() + maxi(amount, 0)
	var gained := 0
	while lv < MAX_LEVEL and xp >= exp_to_next(lv):
		xp -= exp_to_next(lv)
		lv += 1
		gained += 1
	if lv >= MAX_LEVEL:
		xp = 0
	g["level"] = lv
	g["exp"] = xp
	GameState.save_game()
	GameState.roster_changed.emit()
	return gained


# ---------------------------------------------------------
# AVATARS
# ---------------------------------------------------------

static func get_avatar(id: String) -> Dictionary:
	for a in AVATARS:
		if a["id"] == id:
			return a
	return {}


static func is_avatar_unlocked(avatar: Dictionary) -> bool:
	return level() >= int(avatar.get("unlock", 1))


static func has_chosen() -> bool:
	return str(_state()["active"]) != ""


## The chosen god, or {} if God Path is locked or none is chosen yet.
static func active() -> Dictionary:
	if not is_unlocked():
		return {}
	return get_avatar(str(_state()["active"]))


## Chooses (or switches to) a god. Switching resets training.
static func set_active(id: String) -> String:
	var a := get_avatar(id)
	if a.is_empty():
		return "Unknown god."
	if not is_avatar_unlocked(a):
		return "Reaches you at Divinity Level %d." % int(a["unlock"])
	var g := _state()
	if str(g["active"]) == id:
		return ""
	g["active"] = id
	g["blessing_lv"] = 1
	g["skill_lv"] = 1
	GameState.save_game()
	GameState.roster_changed.emit()
	return ""


## Leaves the current god: training resets and the player goes back
## to choosing (Divinity Level is kept).
static func abandon() -> void:
	var g := _state()
	g["active"] = ""
	g["blessing_lv"] = 1
	g["skill_lv"] = 1
	GameState.save_game()
	GameState.roster_changed.emit()


# ---------------------------------------------------------
# TRAINING (resets when switching gods)
# ---------------------------------------------------------

## track: "blessing" or "skill"
static func train_level(track: String) -> int:
	return clampi(int(_state()["blessing_lv" if track == "blessing" else "skill_lv"]), 1, TRAIN_MAX)


static func train_cost(lv: int) -> int:
	return int(round(TRAIN_COST_BASE * pow(TRAIN_COST_GROWTH, float(lv - 1))))


## "" if it can be trained now, otherwise why not.
static func can_train(track: String) -> String:
	if active().is_empty():
		return "Choose a god first."
	var lv := train_level(track)
	if lv >= TRAIN_MAX:
		return "Fully trained."
	if GameState.get_item_count(ESSENCE_ID) < train_cost(lv):
		return "Not enough Divine Essence."
	return ""


static func train(track: String) -> String:
	var error := can_train(track)
	if error != "":
		return error
	var lv := train_level(track)
	if not GameState.spend_item(ESSENCE_ID, train_cost(lv)):
		return "Not enough Divine Essence."
	_state()["blessing_lv" if track == "blessing" else "skill_lv"] = lv + 1
	GameState.save_game()
	GameState.roster_changed.emit()
	return ""


## Divine Essence spent on the current god's training (lost on a switch).
static func essence_invested() -> int:
	var total := 0
	for track in ["blessing", "skill"]:
		for lv in range(1, train_level(track)):
			total += train_cost(lv)
	return total


## Team bonus from the active Avatar: {hp_pct, atk_pct, def_pct, spd_pct, crit, crit_dmg}.
static func team_bonus() -> Dictionary:
	var out := {"hp_pct": 0.0, "atk_pct": 0.0, "def_pct": 0.0, "spd_pct": 0.0, "crit": 0.0, "crit_dmg": 0.0}
	var a := active()
	if a.is_empty():
		return out
	var stats: Dictionary = a["stats"]
	for key in stats:
		out[key] = float(out.get(key, 0.0)) + float(stats[key]) * float(level())
	return out


## A god's blessing strength: at its trained level if it's the chosen
## god, otherwise at level 1 (what you'd start with after switching).
static func blessing_value(avatar: Dictionary) -> float:
	var lv := 1
	if str(avatar.get("id", "")) == str(_state()["active"]):
		lv = train_level("blessing")
	return float(avatar.get("blessing_base", 0.0)) + float(avatar.get("blessing_per_level", 0.0)) * float(lv)


static func blessing_text(avatar: Dictionary) -> String:
	return str(avatar["blessing_text"]) % _num(blessing_value(avatar))


## Training line for the blessing, e.g. "Damage below half HP: +11% → +12%".
static func blessing_training_text(avatar: Dictionary) -> String:
	var fmt := str(avatar.get("blessing_format", "%s"))
	var now := blessing_value(avatar)
	var label := str(avatar.get("blessing_label", "Blessing"))
	if train_level("blessing") >= TRAIN_MAX:
		return "%s: %s" % [label, fmt % _num(now)]
	var next := now + float(avatar.get("blessing_per_level", 0.0))
	return "%s: %s  →  %s" % [label, fmt % _num(now), fmt % _num(next)]


## Training line for the divine skill.
static func skill_training_text(avatar: Dictionary) -> String:
	var lv := train_level("skill")
	var power_now := _num(SKILL_POWER_PER_LEVEL * float(lv - 1) * 100.0)
	var chance_now := _num(SKILL_CHANCE_PER_LEVEL * float(lv - 1))
	var skill: Dictionary = avatar.get("skill", {})
	var has_status := skill.has("status")
	if lv >= TRAIN_MAX:
		var done := "Skill power: +%s%%" % power_now
		if has_status:
			done += "  ·  %s chance: +%s%%" % [Statuses.name_of(str(skill["status"])), chance_now]
		return done
	var power_next := _num(SKILL_POWER_PER_LEVEL * float(lv) * 100.0)
	var chance_next := _num(SKILL_CHANCE_PER_LEVEL * float(lv))
	var line := "Skill power: +%s%%  →  +%s%%" % [power_now, power_next]
	if has_status:
		line += "\n%s chance: +%s%%  →  +%s%%" % [Statuses.name_of(str(skill["status"])), chance_now, chance_next]
	return line


## Active blessing id and value for battle, or ["", 0.0].
static func blessing() -> Array:
	var a := active()
	if a.is_empty():
		return ["", 0.0]
	return [str(a["blessing"]), blessing_value(a)]


# ---------------------------------------------------------
# DIVINE SKILL
# ---------------------------------------------------------

static func skill_unlocked() -> bool:
	return not active().is_empty() and level() >= DESCEND_LEVEL


## The chosen god's divine skill, strengthened by its training.
static func battle_skill() -> Dictionary:
	var a := active()
	if a.is_empty():
		return {}
	var base: Dictionary = a["skill"]
	var skill := base.duplicate()
	var lv := train_level("skill")
	skill["power"] = float(skill.get("power", 0.0)) * (1.0 + SKILL_POWER_PER_LEVEL * float(lv - 1))
	if skill.has("status_chance"):
		skill["status_chance"] = minf(100.0, float(skill["status_chance"]) + SKILL_CHANCE_PER_LEVEL * float(lv - 1))
	return skill


## True if the god takes its turn once this round has finished.
static func acts_after(round_number: int) -> bool:
	return skill_unlocked() and round_number > 0 and round_number % DESCEND_AFTER_ROUNDS == 0


static func god_atk_mult() -> float:
	return GOD_ATK_BASE + GOD_ATK_PER_LEVEL * float(level())


## A stand-in fighter for the god, striking with the team's average ATK.
static func make_god_unit(team: Array) -> CombatUnit:
	var total := 0.0
	var n := 0
	for unit in team:
		if unit != null:
			total += float(unit.atk)
			n += 1
	var god := CombatUnit.new()
	god.side = CombatUnit.Side.PLAYER
	god.slot_index = -1
	god.display_name = str(active().get("name", "God"))
	god.atk = maxi(1, floori(total / float(maxi(n, 1)) * god_atk_mult()))
	god.crit = 0.0
	god.accuracy = 100.0
	god.max_hp = 1
	god.current_hp = 1
	return god


# ---------------------------------------------------------
# ART
# ---------------------------------------------------------

static var _trimmed := {}


## Avatar or emblem art. Portraits have dark bars trimmed off their
## sides and top/bottom (generated images often come letterboxed).
static func art(kind: String, avatar: Dictionary) -> Texture2D:
	var path := ART_DIR + "%s_%s.png" % [kind, str(avatar.get("id", ""))]
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if kind != "avatar" or tex == null:
		return tex
	if not _trimmed.has(path):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = _content_region(tex)
		_trimmed[path] = atlas
	return _trimmed[path]


## The part of an image inside any solid dark bars at its edges.
static func _content_region(tex: Texture2D) -> Rect2:
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img == null:
		return full
	if img.is_compressed() and img.decompress() != OK:
		return full
	var w := img.get_width()
	var h := img.get_height()
	var left := 0
	while left < floori(w / 3.0) and _is_bar_col(img, left):
		left += 1
	var right := w - 1
	while right > floori(w * 2.0 / 3.0) and _is_bar_col(img, right):
		right -= 1
	var top := 0
	while top < floori(h / 3.0) and _is_bar_row(img, top, left, right):
		top += 1
	var bottom := h - 1
	while bottom > floori(h * 2.0 / 3.0) and _is_bar_row(img, bottom, left, right):
		bottom -= 1
	return Rect2(left, top, right - left + 1, bottom - top + 1)


## True if a column is (almost) all near-black or transparent.
static func _is_bar_col(img: Image, x: int) -> bool:
	for y in range(0, img.get_height(), 7):
		if _visible_pixel(img.get_pixel(x, y)):
			return false
	return true


static func _is_bar_row(img: Image, y: int, x_from: int, x_to: int) -> bool:
	for x in range(x_from, x_to + 1, 7):
		if _visible_pixel(img.get_pixel(x, y)):
			return false
	return true


static func _visible_pixel(c: Color) -> bool:
	return c.a > 0.2 and (c.r + c.g + c.b) > 0.12


static func _num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")
