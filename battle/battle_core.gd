class_name BattleCore
extends RefCounted

# Battle logic. Knows nothing about nodes or animations --
# the scene reads the results and draws them.
#
# Spec section 36: turn order is SLOT ORDER, not speed.
#   P1, E1, P2, E2, P3, E3 ... P6, E6, then next round.
#
# Spec section 37: lane targeting.
#   Lane 0 = slots 1 and 4   (indices 0, 3)
#   Lane 1 = slots 2 and 5   (indices 1, 4)
#   Lane 2 = slots 3 and 6   (indices 2, 5)

const TEAM_SIZE := 6

# Hit chance is clamped so nothing is ever a guaranteed
# hit or a guaranteed miss.
const MIN_HIT_CHANCE := 20.0
const MAX_HIT_CHANCE := 95.0

# Safety net -- a battle where nobody can kill anybody
# would otherwise loop forever.
const MAX_ROUNDS := 200

var player_units: Array = []
var enemy_units: Array = []

var round_number: int = 1

## God Path blessing for this fight: [id, value] (see Gods).
var _blessing: Array = ["", 0.0]


func setup(partners: Array, enemies: Array):
	player_units.clear()
	enemy_units.clear()

	for i in range(TEAM_SIZE):
		if i < partners.size() and partners[i] != null:
			player_units.append(CombatUnit.from_partner(partners[i], i))

	# The MC's tier boosts the whole team.
	var bonus := (1.0 + GameState.get_mc_team_bonus() / 100.0) * GameState.debug_power_mult
	if bonus > 1.0:
		for unit in player_units:
			unit.apply_team_bonus(bonus)

	# Battle Array: bench partners lend part of their stats to every unit
	var lent := BattleArray.bonus()
	for unit in player_units:
		unit.add_flat_bonus(int(lent["hp"]), int(lent["atk"]), int(lent["def"]))

	# God Path: the active Avatar's team stats and blessing
	_apply_god_path()

	for unit in player_units:
		unit.apply_start_effects()

	# Blessings that act once the fight is set up
	var blessing_id := str(_blessing[0])
	var blessing_val := float(_blessing[1])
	for unit in player_units:
		if blessing_id == "tide_shield":
			unit.shield += floori(float(unit.max_hp) * blessing_val / 100.0)
		elif blessing_id == "dawn_energy":
			unit.energy = mini(unit.max_energy, unit.energy + floori(blessing_val))

	for i in range(TEAM_SIZE):
		if i < enemies.size() and enemies[i] != null:
			enemy_units.append(CombatUnit.from_enemy(enemies[i], i))

	round_number = 1


# ---------------------------------------------------------
# TURN ORDER
# ---------------------------------------------------------

# ---------------------------------------------------------
# SKILLS (see Skills)
# ---------------------------------------------------------

## The active Avatar's stats (and the crit blessing) on every unit.
func _apply_god_path() -> void:
	_blessing = Gods.blessing()
	var b := Gods.team_bonus()
	var crit_dmg := float(b["crit_dmg"])
	if str(_blessing[0]) == "crit_dmg":
		crit_dmg += float(_blessing[1])
	for unit in player_units:
		unit.max_hp = floori(float(unit.max_hp) * (1.0 + float(b["hp_pct"]) / 100.0))
		unit.current_hp = unit.max_hp
		unit.atk = floori(float(unit.atk) * (1.0 + float(b["atk_pct"]) / 100.0))
		unit.defense = floori(float(unit.defense) * (1.0 + float(b["def_pct"]) / 100.0))
		unit.spd = floori(float(unit.spd) * (1.0 + float(b["spd_pct"]) / 100.0))
		unit.crit = minf(unit.crit + float(b["crit"]), 100.0)
		unit.crit_damage += crit_dmg


## Which units a skill hits.
func skill_targets(attacker: CombatUnit, skill: Dictionary) -> Array:
	var count := int(skill.get("targets", 0))
	if count <= 0:
		return []
	var foes: Array = []
	var pool: Array = enemy_units if attacker.side == CombatUnit.Side.PLAYER else player_units
	for unit in pool:
		if unit != null and unit.is_alive():
			foes.append(unit)
	if foes.is_empty():
		return []

	var rule := str(skill.get("target_rule", ""))
	if rule == "strongest":
		foes.sort_custom(func(a, b): return a.current_hp > b.current_hp)
	elif rule == "weakest":
		foes.sort_custom(func(a, b): return a.current_hp < b.current_hp)
	return foes.slice(0, mini(count, foes.size()))


## Allies of a unit, alive only.
func allies_of(unit: CombatUnit) -> Array:
	var out: Array = []
	var pool: Array = player_units if unit.side == CombatUnit.Side.PLAYER else enemy_units
	for other in pool:
		if other != null and other.is_alive():
			out.append(other)
	return out


## Runs a skill. Returns:
##   {"skill", "hits": [{target, result}], "support": [{unit, heal, shield, energy}]}
func resolve_skill(attacker: CombatUnit) -> Dictionary:
	return resolve_skill_with(attacker, Skills.for_unit(attacker))


## The god descends: the active Avatar's divine skill, struck with the
## team's average ATK (see Gods). Same result shape as resolve_skill.
func resolve_divine() -> Dictionary:
	var god := Gods.make_god_unit(get_living(player_units))
	return resolve_skill_with(god, Gods.battle_skill())


## keep_energy: Beast Skills don't use up the energy bar.
func resolve_skill_with(attacker: CombatUnit, skill: Dictionary, keep_energy := false) -> Dictionary:
	var out := {"skill": skill, "hits": [], "support": []}

	for target in skill_targets(attacker, skill):
		var result := resolve_attack(attacker, target, float(skill["power"]))
		# Skills can leave a debuff behind. Curse Weaver improves the odds,
		# and Immunity can block it entirely.
		var chance := float(skill.get("status_chance", 0.0))
		chance += chance * float(attacker.traits.get("curse_weaver", 0.0)) / 100.0
		if skill.has("status") and not result["dodged"] and target.is_alive() \
				and randf() * 100.0 < chance:
			var status_id := str(skill["status"])
			# Ordinary Bleed scales with the attacker's ATK;
			# Heavenly Bleed is a share of the target's max HP.
			var power := float(skill.get("status_power", 0.0))
			if status_id == Statuses.BLEED:
				power *= attacker.atk / 100.0
			if target.add_status(status_id, int(skill["status_turns"]), power):
				result["status"] = status_id
			else:
				result["immune"] = true
		out["hits"].append({"target": target, "result": result})

	# Team support (shields, energy, healing)
	var allies := allies_of(attacker)
	if skill.has("shield_team") or skill.has("energy_team"):
		for ally in allies:
			var gained := {"unit": ally, "heal": 0, "shield": 0, "energy": 0}
			if skill.has("shield_team"):
				gained["shield"] = int(ally.max_hp * float(skill["shield_team"]) / 100.0)
				ally.shield += gained["shield"]
			if skill.has("energy_team"):
				gained["energy"] = int(skill["energy_team"])
				ally.energy = mini(ally.max_energy, ally.energy + gained["energy"])
			out["support"].append(gained)

	# Healing the weakest ally
	if skill.has("heal_ally") and not allies.is_empty():
		var weakest: CombatUnit = allies[0]
		for ally in allies:
			if float(ally.current_hp) / maxf(ally.max_hp, 1) < float(weakest.current_hp) / maxf(weakest.max_hp, 1):
				weakest = ally
		var healed := int(weakest.max_hp * float(skill["heal_ally"]) / 100.0)
		weakest.current_hp = mini(weakest.max_hp, weakest.current_hp + healed)
		out["support"].append({"unit": weakest, "heal": healed, "shield": 0, "energy": 0})

	if not keep_energy:
		attacker.energy = 0
	return out


func build_turn_order() -> Array:
	var order: Array = []

	for slot in range(TEAM_SIZE):

		var player = get_unit_at(player_units, slot)

		if player != null and player.is_alive():
			order.append(player)

		var enemy = get_unit_at(enemy_units, slot)

		if enemy != null and enemy.is_alive():
			order.append(enemy)

	return order


func get_unit_at(units: Array, slot: int) -> CombatUnit:
	for unit in units:
		if unit.slot_index == slot:
			return unit

	return null


# ---------------------------------------------------------
# TARGETING
#
# 1. Front-row enemy in my lane.
# 2. If dead, back-row enemy in my lane.
# 3. If the lane is empty, any living front-row enemy.
# 4. Failing that, anyone still standing.
# ---------------------------------------------------------

func pick_target(attacker: CombatUnit) -> CombatUnit:
	var enemies = opposing_team(attacker)

	var lane = attacker.get_lane()

	var front = get_unit_at(enemies, lane)

	if front != null and front.is_alive():
		return front

	var back = get_unit_at(enemies, lane + 3)

	if back != null and back.is_alive():
		return back

	var front_candidates: Array = []

	for unit in enemies:
		if unit.is_alive() and unit.is_front_row():
			front_candidates.append(unit)

	if not front_candidates.is_empty():
		return front_candidates.pick_random()

	var any_alive = get_living(enemies)

	if not any_alive.is_empty():
		return any_alive.pick_random()

	return null


func opposing_team(unit: CombatUnit) -> Array:
	if unit.side == CombatUnit.Side.PLAYER:
		return enemy_units

	return player_units


func get_living(units: Array) -> Array:
	var result: Array = []

	for unit in units:
		if unit.is_alive():
			result.append(unit)

	return result


func team_alive(units: Array) -> bool:
	for unit in units:
		if unit.is_alive():
			return true

	return false


# ---------------------------------------------------------
# DAMAGE
#
# Returns a dictionary describing what happened, so the
# scene can animate it without recalculating anything.
# ---------------------------------------------------------

## power multiplies the attack (skills pass more than 1.0).
func resolve_attack(attacker: CombatUnit, target: CombatUnit, power := 1.0) -> Dictionary:

	var result := {
		"dodged": false,
		"crit": false,
		"damage": 0,
		"killed": false,
		"lightning": false,
		"frozen": false,
		"events": [],
	}

	var hit_chance = clampf(
		attacker.accuracy - target.eva + 15.0,
		MIN_HIT_CHANCE,
		MAX_HIT_CHANCE
	)

	if randf() * 100.0 > hit_chance:
		result["dodged"] = true
		return result

	# damage = ATK^2 / (ATK + DEF): when ATK equals DEF a hit does
	# half damage. It scales with the numbers, so HP, ATK and DEF
	# all keep mattering from stage 1 to 10,000, and damage never
	# drops to zero. (Tribulation Lightning uses the same rule.)
	# Armor Piercer ignores part of the target's defence
	var pierce := 1.0 - float(attacker.traits.get("armor_piercer", 0.0)) / 100.0
	var attack := maxf(float(attacker.atk), 1.0)
	var effective_def := maxf(float(target.defense), 0.0) * maxf(pierce, 0.1)
	var defense_multiplier := attack / (attack + effective_def)

	var variance = randf_range(0.92, 1.08)

	var damage = attack * defense_multiplier * variance

	if randf() * 100.0 < attacker.crit:
		result["crit"] = true
		damage *= attacker.crit_damage / 100.0

	# Skill power, then Weaken (attacker) and Armor Break (target)
	damage *= power
	damage *= attacker.attack_mult()
	damage *= target.damage_taken_mult()

	# Asura blessing: your units hit harder below half HP
	if attacker.side == CombatUnit.Side.PLAYER and str(_blessing[0]) == "desperate" \
			and attacker.slot_index >= 0 and attacker.current_hp < attacker.max_hp * 0.5:
		damage *= 1.0 + float(_blessing[1]) / 100.0

	# Demon Suppression: bosses take more
	if attacker.effects.has("boss_dmg") and target.is_boss:
		damage *= 1.0 + attacker.effects["boss_dmg"] / 100.0

	# Soul Quelling: the target shrugs part of it off
	if target.effects.has("dmg_reduce"):
		damage *= maxf(0.1, 1.0 - target.effects["dmg_reduce"] / 100.0)

	# Nether Shadow: finish off weakened targets
	if attacker.effects.has("execute") and target.current_hp < target.max_hp * 0.5:
		damage *= 1.0 + attacker.effects["execute"] / 100.0

	# Thunder Tribulation: chance of a lightning strike
	if attacker.effects.has("lightning") and randf() * 100.0 < attacker.effects["lightning"]:
		damage *= 1.6
		result["lightning"] = true

	var final_damage = maxi(1, int(damage))
	# Beast Ring lifesteal: heal a share of the damage dealt
	if attacker.effects.has("lifesteal") and attacker.is_alive():
		var heal := int(float(final_damage) * float(attacker.effects["lifesteal"]) / 100.0)
		attacker.current_hp = mini(attacker.max_hp, attacker.current_hp + heal)

	target.take_damage(final_damage)

	# Frost Soul (freeze) and Netherworld (seal) both cost a turn
	for key in ["freeze", "seal"]:
		if attacker.effects.has(key) and target.is_alive() and not target.frozen \
				and randf() * 100.0 < attacker.effects[key]:
			target.frozen = true
			result["frozen"] = true
			result["sealed"] = key == "seal"

	result["damage"] = final_damage
	result["killed"] = not target.is_alive()
	result["events"] = target.last_events.duplicate()

	return result


# 1 = player won, -1 = player lost, 0 = still going
func check_battle_over() -> int:
	if not team_alive(enemy_units):
		return 1

	if not team_alive(player_units):
		return -1

	return 0
