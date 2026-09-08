extends Control

# Runs the battle and draws it.
# Logic lives in BattleCore -- this only handles pacing,
# animation and the slot views.

const UNIT_VIEW = preload("res://battle/battle_unit_view.tscn")

const TURN_DELAY := 0.15
const ROUND_DELAY := 0.2
const RESULT_DELAY := 0.8

@onready var stage_title: Label = $Layout/StageTitle
@onready var combat_log: Label = $Layout/CombatLog

@onready var enemy_back_row: HBoxContainer = $Layout/FormationLayout/EnemyBackRow
@onready var enemy_front_row: HBoxContainer = $Layout/FormationLayout/EnemyFrontRow
@onready var player_front_row: HBoxContainer = $Layout/FormationLayout/PlayerFrontRow
@onready var player_back_row: HBoxContainer = $Layout/FormationLayout/PlayerBackRow

var core: BattleCore

# slot index -> view node
var player_views: Dictionary = {}
var enemy_views: Dictionary = {}

var log_lines: Array = []


func _ready():
	_build_slots()

	start_battle()


# ---------------------------------------------------------
# SLOT CREATION
#
# Front row holds slots 1-3 (indices 0,1,2).
# Back row holds slots 4-6 (indices 3,4,5).
# Columns line up, so lane = index % 3 matches what you see.
# ---------------------------------------------------------

func _build_slots():
	for i in range(3):
		player_views[i] = _make_view(player_front_row)
		player_views[i + 3] = _make_view(player_back_row)

		enemy_views[i] = _make_view(enemy_front_row)
		enemy_views[i + 3] = _make_view(enemy_back_row)


func _make_view(parent: Node) -> Control:
	var view = UNIT_VIEW.instantiate()

	parent.add_child(view)

	return view


func _get_view(unit: CombatUnit) -> Control:
	if unit.side == CombatUnit.Side.PLAYER:
		return player_views.get(unit.slot_index)

	return enemy_views.get(unit.slot_index)


# ---------------------------------------------------------
# BATTLE
# ---------------------------------------------------------

func start_battle():
	var stage = GameState.current_stage

	stage_title.text = "Stage %d" % stage

	if EnemyGenerator.is_boss_stage(stage):
		stage_title.text += "  -  BOSS"

	core = BattleCore.new()

	core.setup(
		GameState.get_formation_partners(),
		EnemyGenerator.generate(stage)
	)

	# Hide every slot, then show the ones that have a fighter.
	for view in player_views.values():
		view.bind(null)

	for view in enemy_views.values():
		view.bind(null)

	for unit in core.player_units:
		player_views[unit.slot_index].bind(unit)

	for unit in core.enemy_units:
		enemy_views[unit.slot_index].bind(unit)

	log_lines.clear()

	_log("Stage %d begins." % stage)

	await get_tree().create_timer(0.6).timeout

	await run_battle()


func run_battle():

	while core.round_number <= BattleCore.MAX_ROUNDS:

		_log("--- Round %d ---" % core.round_number)

		for unit in core.build_turn_order():

			# It may have died earlier in this same round.
			if not unit.is_alive():
				continue

			await take_turn(unit)

			var outcome = core.check_battle_over()

			if outcome != 0:
				await finish_battle(outcome == 1)
				return

		core.round_number += 1

		await get_tree().create_timer(ROUND_DELAY).timeout

	# Ran out of rounds -- treat as a loss.
	await finish_battle(false)


func take_turn(attacker: CombatUnit):
	var target = core.pick_target(attacker)

	if target == null:
		return

	var attacker_view = _get_view(attacker)
	var target_view = _get_view(target)

	if attacker_view != null:
		await attacker_view.play_attack()

	var result = core.resolve_attack(attacker, target)

	attacker.gain_energy()

	if result["dodged"]:
		if target_view != null:
			target_view.show_popup("DODGE", Color(0.7, 0.9, 1.0))

		_log("%s attacks %s - dodged" % [
			attacker.display_name,
			target.display_name
		])

	else:
		if target_view != null:
			target_view.play_hit()

			if result["crit"]:
				target_view.show_popup(
					"CRIT %d" % result["damage"],
					Color(1.0, 0.85, 0.2),
					true
				)
			else:
				target_view.show_popup(
					"-%d" % result["damage"],
					Color.WHITE
				)

		_log("%s hits %s for %d%s" % [
			attacker.display_name,
			target.display_name,
			result["damage"],
			"  CRIT" if result["crit"] else ""
		])

		if result["killed"]:
			_log("%s is defeated." % target.display_name)

			if target_view != null:
				await target_view.play_death()

	await get_tree().create_timer(TURN_DELAY).timeout


func finish_battle(player_won: bool):

	if player_won:
		var stones = 50 + GameState.current_stage * 10

		GameState.add_spirit_stones(stones)

		stage_title.text = "VICTORY   +%d Spirit Stones" % stones

		_log("Victory. Gained %d spirit stones." % stones)

		await get_tree().create_timer(RESULT_DELAY).timeout

		GameState.advance_stage()

	else:
		stage_title.text = "DEFEAT"

		_log("Defeat. Retrying stage %d." % GameState.current_stage)

		await get_tree().create_timer(RESULT_DELAY).timeout

	await start_battle()


# ---------------------------------------------------------
# LOG
# ---------------------------------------------------------

func _log(text: String):
	print(text)

	log_lines.append(text)

	while log_lines.size() > 6:
		log_lines.pop_front()

	combat_log.text = "\n".join(log_lines)
