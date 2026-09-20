class_name Paths

# =========================================================
# Path Resonance: the bonus for stacking one Path in your
# formation. Save as res://systems/paths.gd
#
#   2 of a Path   a small bonus to that Path's stats
#   3             bigger
#   4             bigger still, plus a second effect
#   5             same as 4 (the next step is a full team)
#   6             the full resonance
#
# The bonus goes to the WHOLE team, not just the matching
# partners, so a part-stacked formation still gains something.
#
# Only the strongest Path counts: a 4-2 split gives the 4's
# bonus, not both.
#
# Feeds GameState.path_bonus, which OwnedPartner._gear() adds
# alongside gear, treasures, beasts, codex and sect bonuses.
# The keys here are that pipeline's keys:
#   hp_pct atk_pct def_pct mdef_pct   percentages
#   crit spd eva acc crit_dmg energy  flat points
# =========================================================

## Partners of one Path needed for each step. 5 has no entry of
## its own: it keeps the 4 bonus until the team is all six.
const STEPS := [2, 3, 4, 6]

## [path] -> [count] -> {stat: amount}
const BONUS := {
	Enums.Path.MARTIAL: {
		2: {"atk_pct": 5.0, "hp_pct": 5.0},
		3: {"atk_pct": 10.0, "hp_pct": 10.0},
		4: {"atk_pct": 15.0, "hp_pct": 15.0, "def_pct": 10.0},
		6: {"atk_pct": 25.0, "hp_pct": 25.0, "def_pct": 10.0, "crit_dmg": 30.0},
	},
	Enums.Path.SWORD: {
		2: {"crit": 3.0, "spd": 5.0},
		3: {"crit": 6.0, "spd": 10.0},
		4: {"crit": 9.0, "spd": 15.0, "crit_dmg": 20.0},
		6: {"crit": 15.0, "spd": 25.0, "crit_dmg": 20.0, "atk_pct": 10.0},
	},
	Enums.Path.DIVINE: {
		2: {"def_pct": 6.0, "mdef_pct": 6.0},
		3: {"def_pct": 12.0, "mdef_pct": 12.0},
		4: {"def_pct": 18.0, "mdef_pct": 18.0, "hp_pct": 10.0},
		6: {"def_pct": 30.0, "mdef_pct": 30.0, "hp_pct": 25.0},
	},
	Enums.Path.MYSTIC: {
		2: {"acc": 3.0, "crit_dmg": 10.0},
		3: {"acc": 6.0, "crit_dmg": 20.0},
		4: {"acc": 9.0, "crit_dmg": 30.0, "energy": 10.0},
		6: {"acc": 15.0, "crit_dmg": 50.0, "energy": 10.0, "atk_pct": 10.0},
	},
	Enums.Path.SPIRIT: {
		2: {"energy": 3.0, "eva": 2.0},
		3: {"energy": 6.0, "eva": 4.0},
		4: {"energy": 9.0, "eva": 6.0, "hp_pct": 8.0},
		6: {"energy": 15.0, "eva": 10.0, "hp_pct": 8.0, "crit_dmg": 20.0},
	},
}

## Short name for each step, for the Formation screen.
const STEP_NAMES := {
	2: "Stirring",
	3: "Flowing",
	4: "Surging",
	6: "Resonance",
}


## How many formation partners walk each Path: {path: count}.
static func counts() -> Dictionary:
	var out := {}
	for index in GameState.formation:
		var i := int(index)
		if i < 0 or i >= GameState.roster.size():
			continue
		var p = GameState.roster[i]
		if p == null:
			continue
		var data = p.get_data()
		if data == null:
			continue
		var path := int(data.path)
		out[path] = int(out.get(path, 0)) + 1
	return out


## [path, count] for the most-represented Path, or [-1, 0].
static func strongest() -> Array:
	var tally := counts()
	var best_path := -1
	var best := 0
	for path in tally:
		var n := int(tally[path])
		if n > best:
			best = n
			best_path = int(path)
	return [best_path, best]


## The step a count reaches: 2, 3, 4, 6, or 0 for none.
## Five keeps the 4 bonus; only a full team reaches 6.
static func step_for(count: int) -> int:
	var step := 0
	for s in STEPS:
		if count >= int(s):
			step = int(s)
	return step


## The bonus a Path and count earn: {stat: amount}, or {}.
static func bonus_for(path: int, count: int) -> Dictionary:
	var step := step_for(count)
	if step <= 0 or not BONUS.has(path):
		return {}
	var table: Dictionary = BONUS[path]
	return table[step].duplicate() if table.has(step) else {}


## The bonus the current formation earns. Only the strongest Path
## counts, so a 4-2 split gives the 4's bonus and nothing for the 2.
static func active() -> Dictionary:
	var best := strongest()
	return bonus_for(int(best[0]), int(best[1]))


## "Sword Path Surging" — what the Formation screen shows, or "".
static func active_text() -> String:
	var best := strongest()
	var step := step_for(int(best[1]))
	if step <= 0 or int(best[0]) < 0:
		return ""
	return "%s %s" % [str(Enums.PATH_NAMES.get(int(best[0]), "Path")),
		str(STEP_NAMES.get(step, ""))]


## "+15% ATK, +15% HP, +10% DEF" for a bonus dictionary.
static func describe(bonus: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat in bonus:
		parts.append(_stat_text(str(stat), float(bonus[stat])))
	return ", ".join(parts)


static func _stat_text(stat: String, amount: float) -> String:
	var whole := "%d" % int(round(amount))
	match stat:
		"hp_pct":
			return "+%s%% HP" % whole
		"atk_pct":
			return "+%s%% ATK" % whole
		"def_pct":
			return "+%s%% DEF" % whole
		"mdef_pct":
			return "+%s%% MDEF" % whole
		"crit":
			return "+%s%% Crit" % whole
		"crit_dmg":
			return "+%s%% Crit DMG" % whole
		"spd":
			return "+%s SPD" % whole
		"eva":
			return "+%s%% Evasion" % whole
		"acc":
			return "+%s%% Accuracy" % whole
		"energy":
			return "+%s Energy" % whole
		_:
			return "+%s %s" % [whole, stat]
