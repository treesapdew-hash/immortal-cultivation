class_name Tribulation

# =========================================================
# Tribulation Lightning, a daily survival trial. Save as
#   res://systems/tribulation.gd
#
# Once a day the whole formation faces up to MAX_WAVES waves of
# heavenly lightning. Bolts strike random team members; every
# GREAT_EVERY waves a Great Tribulation strikes everyone.
# Survivors recover a little between waves. The scene is
# TribulationScene.
#
# Bolts hit for a fixed amount that climbs every wave, so how far
# you get is a true measure of your team's strength: weak partners
# fall early, strong ones keep standing. DEF blocks small bolts
# well and big ones less: damage = power^2 / (power + DEF).
#
# Tested curve (median): 6 beginners ~wave 19, a 2.9M HP MC with
# beginner partners ~54, a whole team that strong ~62, an
# endgame team (100M HP) ~83. Wave 100 is beyond endgame.
#
# Saved in GameState.tribulation: {day, done, best}
# =========================================================

# ---------------------------------------------------------
# TUNING
# ---------------------------------------------------------

const UNLOCK_STAGE := 50
const MAX_WAVES := 100

## Bolt power = POWER_START x POWER_GROWTH ^ (wave - 1).
## ~2.3K at wave 20, ~2M at wave 60, ~650M at wave 100.
const POWER_START := 50.0
const POWER_GROWTH := 1.18

## Bolts per wave: 1 + wave / BOLTS_EVERY, at most MAX_BOLTS.
const BOLTS_EVERY := 10
const MAX_BOLTS := 6

## Every GREAT_EVERY waves, one bolt of GREAT_MULT power hits everyone.
const GREAT_EVERY := 10
const GREAT_MULT := 1.5

## HP recovered (share of max HP) by survivors between waves.
const HEAL_SHARE := 0.15

## Qi and Stones: this many minutes of closed-door cultivation per wave.
const MINUTES_PER_WAVE := 5

## Extra rewards for reaching a wave (all reached milestones pay out).
const MILESTONES := {
	10: {"jade": 15},
	20: {"jade": 20, "starup_pill": 5},
	30: {"jade": 25, "lifebound_essence": 100},
	40: {"jade": 30, "starup_pill": 10},
	50: {"jade": 40, "treasure_dust": 150},
	60: {"jade": 45, "starup_pill": 20},
	70: {"jade": 50, "artifact_core": 150},
	80: {"jade": 55, "starup_pill": 30},
	90: {"jade": 60, "treasure_dust": 300},
	100: {"jade": 70, "starup_pill": 50},
}


# ---------------------------------------------------------
# STATE
# ---------------------------------------------------------

static func _state() -> Dictionary:
	var t := GameState.tribulation
	var today := GameState.today()
	if int(t.get("day", 0)) != today:
		t["day"] = today
		t["done"] = false
	return t


static func is_unlocked() -> bool:
	return GameState.highest_stage >= UNLOCK_STAGE


static func done_today() -> bool:
	return bool(_state().get("done", false))


static func best() -> int:
	return int(GameState.tribulation.get("best", 0))


## "" if the tribulation can be faced now, otherwise why not.
static func can_start() -> String:
	if not is_unlocked():
		return "Reach Stage %d to face the tribulation." % UNLOCK_STAGE
	if done_today():
		return "The heavens are calm. Come back tomorrow."
	if GameState.get_team_size() <= 0:
		return "You need a team."
	return ""


## Uses today's attempt. Call when the scene starts.
static func begin() -> void:
	_state()["done"] = true
	GameState.save_game()


# ---------------------------------------------------------
# THE STORM
# ---------------------------------------------------------

## The team as it would enter battle (tier, array and gear bonuses included).
static func make_team() -> Array:
	var core := BattleCore.new()
	core.setup(GameState.get_formation_partners(), [])
	return core.player_units


## Strength of one bolt in this wave.
static func bolt_power(wave: int) -> float:
	return POWER_START * pow(POWER_GROWTH, float(wave - 1))


static func bolts_in(wave: int) -> int:
	return mini(1 + floori(float(wave) / float(BOLTS_EVERY)), MAX_BOLTS)


static func is_great(wave: int) -> bool:
	return wave % GREAT_EVERY == 0


## Damage a bolt does to a unit, before shields and traits.
## DEF blocks small bolts well and big ones less.
static func damage_to(unit: CombatUnit, power: float) -> int:
	var def := maxf(float(unit.defense), 0.0)
	var raw := power * power / maxf(power + def, 1.0)
	return maxi(1, floori(raw * randf_range(0.9, 1.1)))


# ---------------------------------------------------------
# REWARDS
# ---------------------------------------------------------

## What surviving this many waves gives: {"qi", "stones", "jade", "items"}.
static func rewards_for(waves: int) -> Dictionary:
	var out := {"qi": 0, "stones": 0, "jade": 0, "items": {}}
	if waves <= 0:
		return out
	var cult := Loot.roll_offline(GameState.current_stage, float(waves * MINUTES_PER_WAVE * 60))
	out["qi"] = int(cult["qi"])
	out["stones"] = int(cult["stones"])
	var items: Dictionary = out["items"]
	for need in MILESTONES:
		if waves < int(need):
			continue
		var bonus: Dictionary = MILESTONES[need]
		for key in bonus:
			if key == "jade":
				out["jade"] = int(out["jade"]) + int(bonus[key])
			else:
				items[key] = int(items.get(key, 0)) + int(bonus[key])
	return out


## Pays out and records the best. Returns what was given.
static func finish(waves: int) -> Dictionary:
	var got := rewards_for(waves)
	GameState.add_qi(int(got["qi"]))
	GameState.add_spirit_stones(int(got["stones"]))
	if int(got["jade"]) > 0:
		GameState.add_immortal_jade(int(got["jade"]))
	var items: Dictionary = got["items"]
	if not items.is_empty():
		GameState.add_items(items)
	var new_best := waves > best()
	if new_best:
		GameState.tribulation["best"] = waves
	got["new_best"] = new_best
	GameState.bump("tribulation")
	GameState.save_game()
	return got
