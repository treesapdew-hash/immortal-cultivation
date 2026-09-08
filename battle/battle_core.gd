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


func setup(partners: Array, enemies: Array):
	player_units.clear()
	enemy_units.clear()

	for i in range(TEAM_SIZE):
		if i < partners.size() and partners[i] != null:
			player_units.append(CombatUnit.from_partner(partners[i], i))

	for i in range(TEAM_SIZE):
		if i < enemies.size() and enemies[i] != null:
			enemy_units.append(CombatUnit.from_enemy(enemies[i], i))

	round_number = 1


# ---------------------------------------------------------
# TURN ORDER
# ---------------------------------------------------------

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

func resolve_attack(attacker: CombatUnit, target: CombatUnit) -> Dictionary:

	var result := {
		"dodged": false,
		"crit": false,
		"damage": 0,
		"killed": false
	}

	var hit_chance = clampf(
		attacker.accuracy - target.eva + 15.0,
		MIN_HIT_CHANCE,
		MAX_HIT_CHANCE
	)

	if randf() * 100.0 > hit_chance:
		result["dodged"] = true
		return result

	# Defence gives diminishing returns rather than flat
	# subtraction, so damage never drops to zero.
	var defense_multiplier = 100.0 / (100.0 + float(target.defense))

	var variance = randf_range(0.92, 1.08)

	var damage = float(attacker.atk) * defense_multiplier * variance

	if randf() * 100.0 < attacker.crit:
		result["crit"] = true
		damage *= attacker.crit_damage / 100.0

	var final_damage = maxi(1, int(damage))

	target.take_damage(final_damage)

	result["damage"] = final_damage
	result["killed"] = not target.is_alive()

	return result


# 1 = player won, -1 = player lost, 0 = still going
func check_battle_over() -> int:
	if not team_alive(enemy_units):
		return 1

	if not team_alive(player_units):
		return -1

	return 0
