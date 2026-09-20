extends Control

# Runs the idle battle inside the Home screen's BattleArea.
#
# All the rules live in BattleCore. This script only:
#   - finds the 12 unit views already placed in FormationLayout
#   - paces the fight (delays between turns and rounds)
#   - tells each view what to animate
#   - shows victory / defeat, then starts the next battle
#
# Attach to: home_screen > BattleArea

const TURN_DELAY := 0.15
const ROUND_DELAY := 0.2
const START_DELAY := 0.6
const RESULT_DELAY := 1.2
const RING_LEAD := 0.12   # ring shows briefly before the attacker moves

# Drag these in from the Inspector. Both are optional.
@export var stage_label: Label    # stage banner main text
@export var boss_label: Label     # stage banner small line, shown on boss stages
@export var result_label: Label   # old VICTORY text; hidden, can be deleted

## Pushes the whole battlefield down, so tall bosses don't cover
## the stage banner. Raise it if bosses still overlap.
@export var battlefield_offset_y := 70.0

## Skill pacing
const SKILL_BANNER_HOLD := 0.45
const SKILL_HIT_GAP := 0.08

## The stage banner draws above everything on the battlefield.
const BANNER_Z := 40

@export_group("Result Banner Icons")
@export var spirit_stone_icon: Texture2D   # optional
@export var qi_icon: Texture2D             # optional
@export_group("")

@onready var formation: Control = $FormationLayout

var core: BattleCore
var _result_banner: ResultBanner

## Emitted when a dungeon fight ends (won or not).
signal dungeon_finished(request: Dictionary, won: bool)
## Emitted when one was dropped before it could finish. Not a loss:
## whoever asked for the fight should forget it, not report it.
signal dungeon_aborted(request: Dictionary)

var _dungeon_request: Dictionary = {}
var _in_dungeon := false
var _loop_running := false
var _request_time := 0.0

# Set when the MC changes mid-fight (e.g. after character creation),
# so the current battle is dropped and restarted with the new MC.
var _restart_requested := false

# What _run_one_battle() returns
enum Outcome { LOSS, WIN, RESTART }

# slot index (0-5) -> view.  Index 0 = P1 / E1.
var player_views: Dictionary = {}
var enemy_views: Dictionary = {}


func _ready() -> void:
	_find_views()

	if result_label != null:
		result_label.visible = false

	# Added last so it draws above the units
	_result_banner = ResultBanner.new()
	add_child(_result_banner)

	GameState.mc_changed.connect(_on_mc_changed)

	# Rewards from closed-door cultivation (time away)
	OfflineRewardsPopup.open(self)

	# Yesterday's dungeon ranking rewards, delivered by mail
	Ranking.check_daily()
	_add_mail_button()
	_add_chat_button()
	_add_boss_button()
	GameState.stage_changed.connect(_refresh_boss_button)
	# New or removed team members join the fight straight away.
	GameState.formation_changed.connect(_on_mc_changed)

	_shift_battlefield()
	_raise_banner()
	_battle_loop()


func _on_mc_changed() -> void:
	# Never mid-dungeon. A stage fight is endless and restarting it
	# costs nothing, but a duel or a hunt is one decisive fight: the
	# restart was being reported as its result, so opening Formation
	# during an Arena duel handed the other cultivator a free win and
	# spent the attempt.
	if _in_dungeon or not _dungeon_request.is_empty():
		return
	_restart_requested = true


# ---------------------------------------------------------
# FIND THE PLACED UNITS
# P1-P3 / E1-E3 = front row (index 0-2)
# P4-P6 / E4-E6 = back row  (index 3-5)
# ---------------------------------------------------------

## Keeps the stage banner drawn above the units, so a tall boss
## can never cover the stage number.
func _raise_banner() -> void:
	_set_banner("STAGE %d" % GameState.current_stage)
	if stage_label == null:
		return
	# Lift the banner itself, and its frame if it sits in one
	var node: Node = stage_label
	for i in 3:
		if node is CanvasItem:
			(node as CanvasItem).z_index = BANNER_Z
		var parent := node.get_parent()
		if parent == null or parent == self:
			break
		node = parent


## Slides the unit layout down by battlefield_offset_y (once).
func _shift_battlefield() -> void:
	if battlefield_offset_y == 0.0 or formation == null or not formation is Control:
		return
	var layout := formation as Control
	if layout.get_meta("battlefield_shifted", false):
		return
	layout.set_meta("battlefield_shifted", true)
	layout.offset_top += battlefield_offset_y
	layout.offset_bottom += battlefield_offset_y


func _find_views() -> void:
	for i in range(BattleCore.TEAM_SIZE):
		player_views[i] = formation.find_child("P%d" % (i + 1), true, false)
		enemy_views[i] = formation.find_child("E%d" % (i + 1), true, false)

		if player_views[i] == null:
			push_error("HomeBattle: can't find P%d in FormationLayout" % (i + 1))
		if enemy_views[i] == null:
			push_error("HomeBattle: can't find E%d in FormationLayout" % (i + 1))


func _get_view(unit: CombatUnit) -> Control:
	if unit.side == CombatUnit.Side.PLAYER:
		return player_views.get(unit.slot_index)
	return enemy_views.get(unit.slot_index)


# ---------------------------------------------------------
# MAIN LOOP
# A plain loop, so battles never pile up on each other.
# ---------------------------------------------------------

## Asks the battle area to run a dungeon fight next (see Dungeons).
## The current stage fight is dropped and resumes afterwards.
func start_dungeon(request: Dictionary) -> bool:
	if _in_dungeon or not _dungeon_request.is_empty():
		return false
	_dungeon_request = request
	_restart_requested = true
	_request_time = Time.get_ticks_msec() / 1000.0
	print("Dungeon queued: %s" % request.get("title", ""))

	# If the battle loop somehow stopped, start it again
	if not _loop_running:
		push_warning("Battle loop wasn't running; restarting it")
		_battle_loop()
	return true


func is_in_dungeon() -> bool:
	return _in_dungeon or not _dungeon_request.is_empty()


## Safety net: if a dungeon has been waiting too long, the loop is
## stuck or gone, so start it again.
func _process(_delta: float) -> void:
	if _dungeon_request.is_empty() or _in_dungeon:
		return
	if Time.get_ticks_msec() / 1000.0 - _request_time < 3.0:
		return
	_request_time = Time.get_ticks_msec() / 1000.0
	if not _loop_running:
		push_warning("Battle loop stopped; restarting for the queued dungeon")
		_battle_loop()


func _battle_loop() -> void:
	if _loop_running:
		return
	_loop_running = true
	while is_inside_tree():
		_restart_requested = false

		if not _dungeon_request.is_empty():
			print("Dungeon starting: %s" % _dungeon_request.get("title", ""))
			await _run_dungeon()
			continue

		var outcome: Outcome = await _run_one_battle()

		# Restarted: skip the result and start fresh on the same stage.
		if outcome == Outcome.RESTART:
			continue

		await _show_result(outcome == Outcome.WIN)

	_loop_running = false


func _run_dungeon() -> void:
	var request := _dungeon_request
	_dungeon_request = {}
	_in_dungeon = true

	# Dip to black with the floor's name, then fade back in on the fight
	var fade: CanvasLayer = await _dungeon_intro(str(request.get("subtitle", "Dungeon")))
	# Fades away once the first frame of the dungeon fight is set up
	_dungeon_outro.call_deferred(fade)
	var outcome: Outcome = await _run_one_battle(request["enemies"], request["title"], request.get("mods", {}))
	var won := outcome == Outcome.WIN
	_in_dungeon = false

	# Sect Trial: the damage becomes Might for the sect's shared pool
	if str(request.get("kind", "")) == "sect_trial":
		if outcome != Outcome.RESTART:
			var dealt := 0
			for unit in core.enemy_units:
				if unit != null:
					dealt += maxi(0, unit.max_hp - unit.current_hp)
			var res: Dictionary = await SectTrial.finish(dealt)
			var line := ""
			if bool(res["ok"]):
				line = "Dealt %s damage  ·  +%d Might" % [NumberFormat.short(dealt), int(res["might"])]
				if bool(res["cleared"]):
					line += "  ·  STAGE CLEARED!"
			else:
				line = "Dealt %s damage, but the sect couldn't be reached: %s" % [NumberFormat.short(dealt), str(res["error"])]
			await _result_banner.show_victory(0, [], RESULT_DELAY, [], line)
		_set_banner("STAGE %d" % GameState.current_stage)
		GameState.stage_changed.emit()
		dungeon_finished.emit(request, true)
		return

	# Arena duel: the Events screen reports the result to the server,
	# since only it knows which opponent this was.
	if str(request.get("kind", "")) == "arena":
		# A duel that was dropped rather than fought has no result to
		# report. Saying nothing leaves the attempt unspent, which is
		# the honest outcome; reporting `won` here meant every restart
		# went up as a defeat.
		if outcome == Outcome.RESTART:
			_set_banner("STAGE %d" % GameState.current_stage)
			GameState.stage_changed.emit()
			dungeon_aborted.emit(request)
			return
		var who := str(request.get("opponent_name", "your rival"))
		if won:
			await _result_banner.show_victory(0, [], RESULT_DELAY, [],
				"You stand over %s." % who)
		else:
			await _result_banner.show_defeat(0, RESULT_DELAY,
				"%s proved the stronger cultivator." % who)
		_set_banner("STAGE %d" % GameState.current_stage)
		GameState.stage_changed.emit()
		dungeon_finished.emit(request, won)
		return

	# Beast Forest hunt: a win gives a Beast Ring and Beast Cores
	if str(request.get("kind", "")) == "beast_hunt":
		if outcome != Outcome.RESTART:
			if won:
				var hunt := Beasts.finish_hunt(request)
				var ring: Dictionary = hunt["ring"]
				var g := int(ring["grade"])
				var ground := Beasts.ground(str(request["ground"]))
				var drops: Array = [
					{"item_id": Beasts.ring_icon_id(g), "amount": 1, "name": Beasts.ring_name(ring)},
					{"item_id": Beasts.CORE_ID, "amount": int(ground.get("cores", 0)), "name": "Beast Core"},
				]
				var line := Beasts.ring_name(ring)
				if bool(hunt["tamed"]):
					line = "%s tamed as a Soul Spirit!  ·  %s" % [Beasts.species_name(str(request["species"])), line]
				await _result_banner.show_victory(0, [], RESULT_DELAY, drops, line)
			else:
				await _result_banner.show_defeat(0, RESULT_DELAY, "The beast escaped. Grow stronger and hunt again.")
		_set_banner("STAGE %d" % GameState.current_stage)
		GameState.stage_changed.emit()
		dungeon_finished.emit(request, won)
		return

	# Fallen God: he can't die, the damage dealt is the score
	if str(request.get("kind", "")) == "fallen_god":
		if outcome != Outcome.RESTART:
			var damage := 0
			for unit in core.enemy_units:
				if unit != null:
					damage += maxi(0, unit.max_hp - unit.current_hp)
			var got := FallenGod.finish(int(request.get("window", 0)), damage)
			var drops: Array = []
			if int(got["essence"]) > 0:
				drops.append({"item_id": Gods.ESSENCE_ID, "amount": int(got["essence"]),
					"name": ItemDB.get_item(Gods.ESSENCE_ID).get("name", "Divine Essence")})
			var line := "Dealt %s damage  ·  +%d Divinity EXP%s" % [NumberFormat.short(damage), int(got["exp"]),
				"  ·  New best!" if bool(got["new_best"]) else ""]
			await _result_banner.show_victory(0, [], RESULT_DELAY, drops, line)
		_set_banner("STAGE %d" % GameState.current_stage)
		GameState.stage_changed.emit()
		dungeon_finished.emit(request, true)
		return

	# Challenge Boss: a win counts as clearing that stage normally
	if str(request.get("kind", "")) == "boss":
		if outcome != Outcome.RESTART:
			if won:
				GameState.current_stage = int(request["stage"])
				await _show_result(true)
			else:
				await _result_banner.show_defeat(int(request["stage"]), RESULT_DELAY,
					"The boss is still too strong. Grow stronger and try again.")
		_set_banner("STAGE %d" % GameState.current_stage)
		GameState.stage_changed.emit()
		_refresh_boss_button()
		return

	if outcome != Outcome.RESTART:
		var drops: Array = []
		if won:
			if str(request.get("kind", "")) == "trial":
				Trials.finish(request)
			else:
				Dungeons.finish(request, true)
		for id in request["rewards"]:
			if id == Dungeons.GEAR_KEY:
				continue
			drops.append({"item_id": id, "amount": request["rewards"][id],
				"name": ItemDB.get_item(id).get("name", id)})
		for piece in request.get("gear_drops", []):
			if piece.has("slot"):
				drops.append({"gear": piece, "item_id": "", "amount": 1, "name": Gear.item_name(piece)})
			else:
				drops.append({"treasure": piece, "item_id": "", "amount": 1,
					"name": Treasures.item_name(piece)})
		if won:
			await _result_banner.show_victory(0, [], RESULT_DELAY, drops, request["subtitle"] + " Cleared")
		else:
			await _result_banner.show_defeat(0, RESULT_DELAY, request["subtitle"] + " Failed")

	# Put the stage name back on the banner
	_set_banner("STAGE %d" % GameState.current_stage)
	GameState.stage_changed.emit()

	print("Dungeon finished (won: %s)" % str(won))
	dungeon_finished.emit(request, won)


## A Soul Spirit rises behind its partner, its rings glowing around them.
func _show_spirit(attacker: CombatUnit, skill: Dictionary) -> void:
	var view = _get_view(attacker)
	if view == null or not (view is Control):
		return
	var v: Control = view
	var inv := get_global_transform().affine_inverse()
	var rect := v.get_global_rect()
	var centre: Vector2 = inv * rect.get_center()
	var unit_size: Vector2 = inv.basis_xform(rect.size)
	var color: Color = skill.get("color", Color.WHITE)

	# The beast, big and faint behind the partner
	var tex := Beasts.species_art(str(skill.get("beast", "")))
	var ghost: TextureRect = null
	if tex != null:
		ghost = TextureRect.new()
		ghost.texture = tex
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.size = unit_size * 1.6
		ghost.position = centre - ghost.size * 0.5 + Vector2(0, -unit_size.y * 0.15)
		ghost.modulate = Color(color.lightened(0.3), 0.0)
		ghost.z_index = BANNER_Z - 4
		add_child(ghost)

	# Its rings, rising up the body in their age colours
	var rings := Beasts.rings_in(Beasts.spirit_of(attacker.partner_id))
	var halo := Control.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.z_index = BANNER_Z - 3
	halo.position = centre
	add_child(halo)
	var rise := [0.0]
	halo.draw.connect(func():
		var w := unit_size.x * 0.75
		for i in rings.size():
			var g := int(rings[i]["grade"])
			var col := Beasts.grade_color(g)
			var y: float = unit_size.y * 0.4 - float(i) * unit_size.y * 0.13 - float(rise[0])
			var pts := PackedVector2Array()
			for k in 41:
				var a := TAU * float(k) / 40.0
				pts.append(Vector2(cos(a) * w * 0.5, y + sin(a) * w * 0.11))
			# Dark rings get a violet edge so they show on the battlefield
			if g == 3:
				halo.draw_polyline(pts, Color(0.55, 0.35, 0.9, 0.7), 7.0, true)
			halo.draw_polyline(pts, Color(col, 0.9), 4.0, true)
	)

	var lift := func(v2: float):
		rise[0] = v2
		if is_instance_valid(halo):
			halo.queue_redraw()
	var t := create_tween().set_parallel()
	if ghost != null:
		t.tween_property(ghost, "modulate:a", 0.55, 0.3)
	t.tween_method(lift, 0.0, unit_size.y * 0.12, 0.6)
	await t.finished
	var out := create_tween().set_parallel()
	if ghost != null:
		out.tween_property(ghost, "modulate:a", 0.0, 0.5)
	out.tween_property(halo, "modulate:a", 0.0, 0.5)
	out.chain().tween_callback(func():
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()
		if is_instance_valid(halo):
			halo.queue_free()
	)


## Fight modifiers from events, e.g. a trial's Dao bonus:
## {"dao": Enums.Path value, "all": bool, "pct": HP and ATK bonus %}.
func _apply_mods(mods: Dictionary) -> void:
	if mods.is_empty() or core == null:
		return
	var pct := float(mods.get("pct", 0))
	if pct <= 0.0:
		return
	var dao := int(mods.get("dao", -1))
	var everyone := bool(mods.get("all", false))
	for unit in core.player_units:
		if everyone or (dao >= 0 and unit.dao == dao):
			unit.apply_team_bonus(1.0 + pct / 100.0)


## Envelope icon in the top-right corner of the battle area.
func _add_mail_button() -> void:
	var button := MailPopup.make_button()
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -MailPopup.ICON_SIZE - 10.0
	button.offset_right = -10.0
	button.offset_top = 6.0
	button.offset_bottom = MailPopup.ICON_SIZE + 6.0
	add_child(button)


## Chat icon in the bottom-left corner of the battle area.
## Skipped entirely when the backend isn't configured, so offline
## play never shows a button that can't open anything.
func _add_chat_button() -> void:
	if not Chat.available():
		return
	var button := ChatBox.make_button()
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = 10.0
	button.offset_right = ChatBox.ICON_SIZE + 10.0
	button.offset_top = -ChatBox.ICON_SIZE - 10.0
	button.offset_bottom = -10.0
	add_child(button)


## "Challenge Boss" button, shown after a boss beats you.
var _boss_button: OrnateButton


func _add_boss_button() -> void:
	_boss_button = OrnateButton.new()
	_boss_button.variant = OrnateButton.Variant.CRIMSON
	_boss_button.add_theme_font_size_override("font_size", 22)
	_boss_button.anchor_left = 0.5
	_boss_button.anchor_right = 0.5
	_boss_button.anchor_top = 1.0
	_boss_button.anchor_bottom = 1.0
	_boss_button.offset_left = -150
	_boss_button.offset_right = 150
	_boss_button.offset_top = -84
	_boss_button.offset_bottom = -20
	_boss_button.pressed.connect(_on_retry_boss)
	add_child(_boss_button)
	_refresh_boss_button()


func _refresh_boss_button() -> void:
	if _boss_button == null:
		return
	var pending := GameState.pending_boss
	_boss_button.visible = pending > 0 and GameState.current_stage < pending
	if _boss_button.visible:
		_boss_button.text = "Challenge Boss  %d" % pending


## Challenge Boss: runs like a dungeon fight, so the current stage
## fight stops at once and the boss gets the dip-to-black intro.
func _on_retry_boss() -> void:
	var stage := GameState.pending_boss
	if stage <= 0 or is_in_dungeon():
		return
	var request := {
		"kind": "boss",
		"stage": stage,
		"enemies": EnemyGenerator.generate(stage),
		"title": "STAGE %d" % stage,
		"subtitle": "Challenge Boss  ·  Stage %d" % stage,
		"rewards": {},
	}
	if start_dungeon(request):
		_challenge_feedback(stage)


## Instant feedback on pressing Challenge Boss, before the dip to black.
func _challenge_feedback(stage: int) -> void:
	# The button pulses, then fades away
	_boss_button.pivot_offset = _boss_button.size * 0.5
	_boss_button.disabled = true
	var bt := _boss_button.create_tween()
	bt.tween_property(_boss_button, "scale", Vector2(1.15, 1.15), 0.08)
	bt.tween_property(_boss_button, "scale", Vector2.ONE, 0.12)
	bt.tween_property(_boss_button, "modulate:a", 0.0, 0.2)
	bt.tween_callback(func():
		_boss_button.visible = false
		_boss_button.modulate.a = 1.0
		_boss_button.disabled = false
	)

	# Crimson flash across the battlefield
	var flash := ColorRect.new()
	flash.color = Color(0.75, 0.08, 0.05, 0.45)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = BANNER_Z + 2
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.6)
	ft.tween_callback(flash.queue_free)

	# "CHALLENGE ACCEPTED"
	var ui := size.x / 1000.0
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = BANNER_Z + 3
	add_child(box)
	box.size = Vector2(size.x, 160)
	box.position = Vector2(0, size.y * 0.42 - 80)
	box.pivot_offset = box.size * 0.5
	for entry in [["CHALLENGE ACCEPTED", 52, Color("ffd9c8")], ["Stage %d Boss" % stage, 26, Color("ffb09a")]]:
		var l := Label.new()
		l.text = str(entry[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(float(entry[1]) * ui))
		l.add_theme_color_override("font_color", entry[2])
		l.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.0, 0.95))
		l.add_theme_constant_override("outline_size", 9)
		l.add_theme_color_override("font_shadow_color", Color(1.0, 0.25, 0.1, 0.5))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 18)
		box.add_child(l)
	box.scale = Vector2(1.4, 1.4)
	box.modulate.a = 0.0
	var tt := box.create_tween()
	tt.tween_property(box, "modulate:a", 1.0, 0.12)
	tt.parallel().tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.tween_interval(0.7)
	tt.tween_property(box, "modulate:a", 0.0, 0.3)
	tt.tween_callback(box.queue_free)


## Writes the battle banner, finding StageLabel if it wasn't linked
## in the Inspector.
var _banner_font_size := 0


func _set_banner(text: String) -> void:
	if stage_label == null:
		var scene := get_tree().current_scene
		if scene != null:
			var found := scene.find_child("StageLabel", true, false)
			if found is Label:
				stage_label = found
	if stage_label == null:
		return

	stage_label.text = text
	_fit_banner()
	# Again next frame, in case the label hasn't been sized yet
	_fit_banner.call_deferred()


## Shrinks the banner text until it fits, so long dungeon names
## aren't cut off. Never goes below BANNER_MIN_FONT.
func _fit_banner() -> void:
	const BANNER_MIN_FONT := 18
	var label := stage_label
	var settings := label.label_settings

	# Remember the size set in the editor the first time
	if _banner_font_size <= 0:
		_banner_font_size = settings.font_size if settings != null else label.get_theme_font_size("font_size")
		if settings != null:
			label.label_settings = settings.duplicate()
			settings = label.label_settings

	var font: Font = settings.font if settings != null and settings.font != null else label.get_theme_font("font")
	var width := label.size.x
	if font == null or width <= 0.0:
		return

	var shown := label.text.to_upper() if label.uppercase else label.text
	var padding := 12.0 + (settings.outline_size if settings != null else 0)
	var target_size := _banner_font_size
	while target_size > BANNER_MIN_FONT \
			and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, target_size).x + padding > width:
		target_size -= 1

	if settings != null:
		settings.font_size = target_size
	else:
		label.add_theme_font_size_override("font_size", target_size)


## Fades to black, shows the floor name, and hands back the overlay
## so the fight can fade in behind it.
func _dungeon_intro(title: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)

	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.anchor_right = 1.0
	black.anchor_bottom = 1.0
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(black)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.modulate.a = 0.0
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color("f2d98a"))
	label.add_theme_color_override("font_shadow_color", Color("e2c27a", 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 14)
	layer.add_child(label)

	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, 0.3)
	t.parallel().tween_property(label, "modulate:a", 1.0, 0.35)
	t.tween_interval(0.55)
	await t.finished
	return layer


## Fades the black away once the dungeon fight is on screen.
func _dungeon_outro(layer: CanvasLayer) -> void:
	if not is_instance_valid(layer):
		return
	var t := create_tween().set_parallel(true)
	for child in layer.get_children():
		if child is ColorRect:
			t.tween_property(child, "color:a", 0.0, 0.45)
		elif child is Label:
			t.tween_property(child, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(layer.queue_free)


## One fight. With no enemies given, fights the current stage.
func _run_one_battle(enemies: Array = [], title := "", mods: Dictionary = {}) -> Outcome:
	var stage: int = GameState.current_stage
	var dungeon := not enemies.is_empty()

	_set_banner(title if dungeon else "STAGE %d" % stage)
	if boss_label != null:
		boss_label.text = "Boss Stage"
		boss_label.visible = not dungeon and EnemyGenerator.is_boss_stage(stage)

	core = BattleCore.new()
	core.setup(
		GameState.get_formation_partners(),
		enemies if dungeon else EnemyGenerator.generate(stage)
	)
	_apply_mods(mods)

	# Hide every slot, then fill the ones that have a fighter.
	for view in player_views.values() + enemy_views.values():
		if view != null:
			view.bind(null)

	for unit in core.player_units + core.enemy_units:
		var view = _get_view(unit)
		if view != null:
			view.bind(unit)

	if not dungeon:
		print("Stage %d begins." % stage)

	await _wait(START_DELAY)

	# Timed fights (the Fallen God) end after a set number of rounds
	var round_cap := int(mods.get("max_rounds", BattleCore.MAX_ROUNDS))
	while core.round_number <= round_cap:
		if _restart_requested:
			return Outcome.RESTART


		for unit in core.build_turn_order():
			if _restart_requested:
				return Outcome.RESTART

			# It may have died earlier in this same round.
			if not unit.is_alive():
				continue

			# A dungeon fight is waiting: drop this stage fight now
			if not _dungeon_request.is_empty():
				return Outcome.RESTART

			# Stunned, frozen or sealed units lose this turn
			if unit.is_stunned():
				var stunned_view = _get_view(unit)
				if stunned_view != null and stunned_view.has_method("play_status"):
					stunned_view.play_status("STUNNED" if not unit.frozen else "FROZEN",
						Statuses.color_of(Statuses.STUN))
				unit.frozen = false
				unit.tick_statuses()
				if stunned_view != null:
					stunned_view.refresh()
				await _wait(TURN_DELAY)
				continue

			await _take_turn(unit)

			var outcome: int = core.check_battle_over()
			if outcome != 0:
				return Outcome.WIN if outcome == 1 else Outcome.LOSS

		# God Path: after every few full rounds, the god takes its own turn
		if Gods.acts_after(core.round_number) and not core.get_living(core.player_units).is_empty():
			await _divine_descent()
			var god_outcome: int = core.check_battle_over()
			if god_outcome != 0:
				return Outcome.WIN if god_outcome == 1 else Outcome.LOSS

		core.round_number += 1
		await _wait(ROUND_DELAY)

	# Ran out of rounds -- counts as a loss.
	return Outcome.LOSS


# ---------------------------------------------------------
# ONE TURN
# ---------------------------------------------------------

func _take_turn(attacker: CombatUnit) -> void:
	# Bleed burns first, and can finish a unit off.
	# Heavenly Bleed takes a share of max HP, so size doesn't save you.
	if attacker.is_alive() and (attacker.has_status(Statuses.BLEED) or attacker.has_status(Statuses.HEAVENLY_BLEED)):
		var bleed := maxi(1, int(attacker.status_power(Statuses.BLEED)))
		if attacker.has_status(Statuses.HEAVENLY_BLEED):
			bleed += maxi(1, int(attacker.max_hp * attacker.status_power(Statuses.HEAVENLY_BLEED) / 100.0))
		attacker.take_damage(bleed)
		var bleeding_view = _get_view(attacker)
		if bleeding_view != null:
			bleeding_view.play_hit({"damage": bleed, "crit": false, "dodged": false,
				"killed": not attacker.is_alive(), "lightning": false, "frozen": false, "events": []})
			if bleeding_view.has_method("play_status"):
				var bleed_id := Statuses.HEAVENLY_BLEED if attacker.has_status(Statuses.HEAVENLY_BLEED) else Statuses.BLEED
				bleeding_view.play_status(Statuses.name_of(bleed_id).to_upper(), Statuses.color_of(bleed_id))
		if not attacker.is_alive():
			if bleeding_view != null:
				await bleeding_view.play_death()
			attacker.tick_statuses()
			return

	# Lotus Sanctuary: mend a little each turn
	if attacker.effects.has("regen") and attacker.is_alive():
		var healed := int(attacker.max_hp * attacker.effects["regen"] / 100.0)
		if healed > 0 and attacker.current_hp < attacker.max_hp:
			attacker.current_hp = mini(attacker.max_hp, attacker.current_hp + healed)
			var healer_view = _get_view(attacker)
			if healer_view != null and healer_view.has_method("play_heal"):
				healer_view.play_heal(healed)

	# A full energy bar means a skill this turn
	if attacker.skill_ready():
		await _use_skill(attacker)
		attacker.tick_statuses()
		return

	# Soul Spirit: every few actions the bonded beast's skill fires
	# (its own charge, the energy bar is untouched)
	if not attacker.beast_skill.is_empty() and attacker.is_alive() and not attacker.is_silenced():
		attacker.beast_charge += 1
		if attacker.beast_charge >= Beasts.BEAST_EVERY:
			attacker.beast_charge = 0
			await _use_skill(attacker, true)
			attacker.tick_statuses()
			return

	# Blue and Green partners: a small chance to unleash their skill
	if attacker.skill_mode == "proc" and attacker.is_alive() and not attacker.is_silenced() \
			and randf() * 100.0 < PartnerSkills.proc_chance(attacker.rarity) \
			and not Skills.for_unit(attacker).is_empty():
		await _use_skill(attacker)
		attacker.tick_statuses()
		return

	var target: CombatUnit = core.pick_target(attacker)
	if target == null:
		attacker.tick_statuses()
		return

	var attacker_view = _get_view(attacker)
	var target_view = _get_view(target)

	if attacker_view != null:
		attacker_view.set_turn(true)
		await _wait(RING_LEAD)
		await attacker_view.play_attack()

	var result: Dictionary = core.resolve_attack(attacker, target)
	attacker.gain_energy()

	if attacker_view != null:
		attacker_view.refresh()

	if result["dodged"]:
		if target_view != null:
			target_view.play_dodge()

	else:
		# play_hit shows the number, flash and shake.
		# Awaited so a crit's short hitstop finishes before a death fade.
		if target_view != null:
			await target_view.play_hit(result)
			if target_view.has_method("play_status"):
				if result["lightning"]:
					target_view.play_status("LIGHTNING", Color("d8c8ff"))
				if result["frozen"]:
					if result.get("sealed", false):
						target_view.play_status("SEALED", Color("c86bff"))
					else:
						target_view.play_status("FROZEN", Color("a8e8ff"))
				if "revived" in result["events"]:
					target_view.play_status("NIRVANA", Color("ffb36b"))
				elif "shield" in result["events"]:
					target_view.play_status("SHIELD", Color("f2d98a"))

		if result["killed"]:
			_award_kill_qi(target, target_view)
			_bloodfeast(attacker)

			if target_view != null:
				await target_view.play_death()

	# Twin Strike: sometimes the blow lands twice
	if attacker.traits.has("twin_strike") and attacker.is_alive() \
			and randf() * 100.0 < attacker.traits["twin_strike"]:
		var second: CombatUnit = core.pick_target(attacker)
		if second != null:
			if attacker_view != null:
				await attacker_view.play_attack()
			var again: Dictionary = core.resolve_attack(attacker, second)
			var second_view = _get_view(second)
			if second_view != null:
				if again["dodged"]:
					second_view.play_dodge()
				else:
					await second_view.play_hit(again)
					if again["killed"]:
						_award_kill_qi(second, second_view)
						_bloodfeast(attacker)
						await second_view.play_death()

	await _wait(TURN_DELAY)
	attacker.tick_statuses()

	if attacker_view != null:
		attacker_view.set_turn(false)
		attacker_view.refresh()


## Plays a skill: banner, flash, hits, then support effects.
func _use_skill(attacker: CombatUnit, beast := false) -> void:
	var attacker_view = _get_view(attacker)
	var skill: Dictionary = attacker.beast_skill if beast else Skills.for_unit(attacker)
	if beast:
		await _show_spirit(attacker, skill)

	if attacker_view != null:
		attacker_view.set_turn(true)
		if attacker_view.has_method("play_skill_glow"):
			attacker_view.play_skill_glow(skill["color"])
	await _show_skill_banner(attacker, skill)

	var out := core.resolve_skill_with(attacker, skill, true) if beast else core.resolve_skill(attacker)

	for hit in out["hits"]:
		var target: CombatUnit = hit["target"]
		var result: Dictionary = hit["result"]
		var target_view = _get_view(target)
		if target_view == null:
			continue
		if result["dodged"]:
			target_view.play_dodge()
			continue
		await target_view.play_hit(result)
		if target_view.has_method("play_status"):
			if result.has("status"):
				target_view.play_status(Statuses.name_of(result["status"]).to_upper(),
					Statuses.color_of(result["status"]))
			elif result.get("immune", false):
				target_view.play_status("IMMUNE", Statuses.color_of(Statuses.IMMUNE))
		if result["killed"]:
			_award_kill_qi(target, target_view)
			await target_view.play_death()
		else:
			target_view.refresh()
		await _wait(SKILL_HIT_GAP)

	for gain in out["support"]:
		var unit: CombatUnit = gain["unit"]
		var view = _get_view(unit)
		if view == null:
			continue
		if int(gain["heal"]) > 0 and view.has_method("play_heal"):
			view.play_heal(int(gain["heal"]))
		elif int(gain["shield"]) > 0 and view.has_method("play_status"):
			view.play_status("SHIELD", Color("f2d98a"))
		view.refresh()

	await _wait(TURN_DELAY)
	if attacker_view != null:
		attacker_view.set_turn(false)
		attacker_view.refresh()


## The active Avatar descends: the battlefield dims, the god fades in
## behind the field with soft edges, its title appears, then beams of
## light carry its divine skill onto the targets.
func _divine_descent() -> void:
	var avatar := Gods.active()
	if avatar.is_empty():
		return
	var skill: Dictionary = avatar["skill"]
	var color: Color = avatar.get("color", Color("ffe6a8"))

	# Settings: "Short" skips the portrait and title, only the strike shows
	var full := not Settings.is_on("short_god")
	var overlay: Array = _god_overlay_in(avatar) if full else []
	if full:
		await _show_divine_title(avatar, skill)

	var out := core.resolve_divine()
	for hit in out["hits"]:
		var target: CombatUnit = hit["target"]
		var result: Dictionary = hit["result"]
		var target_view = _get_view(target)
		if target_view == null:
			continue
		_divine_beam(target_view, color)
		await _wait(0.12)
		if result["dodged"]:
			target_view.play_dodge()
			continue
		await target_view.play_hit(result)
		if target_view.has_method("play_status"):
			if result.has("status"):
				target_view.play_status(Statuses.name_of(result["status"]).to_upper(),
					Statuses.color_of(result["status"]))
			elif result.get("immune", false):
				target_view.play_status("IMMUNE", Statuses.color_of(Statuses.IMMUNE))
		if result["killed"]:
			_award_kill_qi(target, target_view)
			await target_view.play_death()
		else:
			target_view.refresh()
		await _wait(SKILL_HIT_GAP)

	for gain in out["support"]:
		var unit: CombatUnit = gain["unit"]
		var view = _get_view(unit)
		if view == null:
			continue
		if int(gain["shield"]) > 0 and view.has_method("play_status"):
			view.play_status("SHIELD", Color("f2d98a"))
		elif int(gain["energy"]) > 0 and view.has_method("play_status"):
			view.play_status("+ENERGY", Color("8fe4ff"))
		view.refresh()

	_god_overlay_out(overlay)
	await _wait(TURN_DELAY)


## Soft-edged portrait shader: fades the art out towards every edge,
## so the god has no visible rectangle around it.
const GOD_FADE_SHADER := """
shader_type canvas_item;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float fade_x = 0.32;
uniform float fade_top = 0.12;
uniform float fade_bottom = 0.45;
void fragment() {
	vec2 uv = (UV - region.xy) / region.zw;
	vec4 c = texture(TEXTURE, UV);
	float ex = smoothstep(0.0, fade_x, uv.x) * smoothstep(0.0, fade_x, 1.0 - uv.x);
	float ey = smoothstep(0.0, fade_top, uv.y) * smoothstep(0.0, fade_bottom, 1.0 - uv.y);
	COLOR = vec4(c.rgb, c.a * ex * ey);
}
"""
static var _god_fade: Shader


## Dims the field and fades the god in. Returns the nodes to fade out later.
func _god_overlay_in(avatar: Dictionary) -> Array:
	var nodes: Array = []
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.z_index = BANNER_Z - 3
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nodes.append(dim)
	var t := create_tween().set_parallel()
	t.tween_property(dim, "color:a", 0.38, 0.25)

	var tex := Gods.art("avatar", avatar)
	if tex != null:
		if _god_fade == null:
			_god_fade = Shader.new()
			_god_fade.code = GOD_FADE_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = _god_fade
		var region := Vector4(0, 0, 1, 1)
		if tex is AtlasTexture:
			var at := tex as AtlasTexture
			var full := at.atlas.get_size()
			region = Vector4(at.region.position.x / full.x, at.region.position.y / full.y,
				at.region.size.x / full.x, at.region.size.y / full.y)
		mat.set_shader_parameter("region", region)

		var god := TextureRect.new()
		god.texture = tex
		god.material = mat
		god.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		god.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		god.mouse_filter = Control.MOUSE_FILTER_IGNORE
		god.z_index = BANNER_Z - 2
		add_child(god)
		god.size = Vector2(size.x * 0.95, size.y * 1.05)
		god.position = Vector2(size.x * 0.025, -size.y * 0.02)
		god.modulate = Color(1.15, 1.1, 1.0, 0.0)
		nodes.append(god)
		t.tween_property(god, "modulate:a", 0.62, 0.45)
		t.tween_property(god, "position:y", god.position.y - size.y * 0.05, 2.2)
	return nodes


func _god_overlay_out(nodes: Array) -> void:
	var t := create_tween().set_parallel()
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if n is ColorRect:
			t.tween_property(n, "color:a", 0.0, 0.4)
		else:
			t.tween_property(n, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(func():
		for n in nodes:
			if is_instance_valid(n):
				n.queue_free()
	)


## "THUNDER SOVEREIGN DESCENDS" over the divine skill's name.
func _show_divine_title(avatar: Dictionary, skill: Dictionary) -> void:
	var color: Color = skill.get("color", avatar.get("color", Color("ffe6a8")))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = BANNER_Z - 1
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	box.size = Vector2(size.x, 140)
	box.position = Vector2(0, size.y * 0.3 - 70)
	box.pivot_offset = box.size * 0.5

	var scale_ui := size.x / 1000.0
	var who := Label.new()
	who.text = "%s DESCENDS" % str(avatar["name"]).to_upper()
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", int(24 * scale_ui))
	who.add_theme_color_override("font_color", Color("ffe6a8"))
	who.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.95))
	who.add_theme_constant_override("outline_size", 7)
	box.add_child(who)

	var title := Label.new()
	title.text = str(skill["name"]).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(52 * scale_ui))
	title.add_theme_color_override("font_color", color.lightened(0.35))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.95))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 22)
	box.add_child(title)

	box.modulate.a = 0.0
	box.scale = Vector2(1.25, 1.25)
	var t := create_tween().set_parallel()
	t.tween_property(box, "modulate:a", 1.0, 0.2)
	t.tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.9)
	var out := create_tween().set_parallel()
	out.tween_property(box, "modulate:a", 0.0, 0.3)
	out.tween_property(box, "position:y", box.position.y - 30.0, 0.3)
	out.chain().tween_callback(box.queue_free)


## A beam of divine light from the sky onto a unit.
func _divine_beam(target_view: Control, color: Color) -> void:
	# Screen position -> this battle area's own (possibly scaled) coordinates
	var rect := target_view.get_global_rect()
	var inv := get_global_transform().affine_inverse()
	var hit := inv * (rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.75))
	var beam_w := maxf(inv.basis_xform(Vector2(rect.size.x, 0)).x * 0.55, 30.0)
	for layer_i in 2:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(hit.x, -20), hit])
		line.width = beam_w * (1.0 if layer_i == 0 else 0.35)
		var g := Gradient.new()
		var core_col := Color.WHITE if layer_i == 1 else color
		g.set_color(0, Color(core_col, 0.0))
		g.set_color(1, Color(core_col, 0.9 if layer_i == 1 else 0.55))
		line.gradient = g
		line.z_index = BANNER_Z - 1
		add_child(line)
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.45).set_delay(0.1)
		t.tween_callback(line.queue_free)


## Big skill name across the battlefield.
func _show_skill_banner(_attacker: CombatUnit, skill: Dictionary) -> void:
	var label := Label.new()
	label.text = str(skill["name"]).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_right = 1.0
	label.anchor_top = 0.32
	label.anchor_bottom = 0.32
	label.offset_top = -40
	label.offset_bottom = 40
	label.z_index = BANNER_Z - 1
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", skill["color"])
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_shadow_color", Color(skill["color"], 0.4))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 18)
	label.modulate.a = 0.0
	label.scale = Vector2(0.85, 0.85)
	label.pivot_offset = Vector2(size.x * 0.5, 40)
	add_child(label)

	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.14)
	t.parallel().tween_property(label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.35)
	t.tween_property(label, "modulate:a", 0.0, 0.2)
	t.tween_callback(label.queue_free)
	await _wait(SKILL_BANNER_HOLD)


## Bloodfeast: heal the killer.
func _bloodfeast(unit: CombatUnit) -> void:
	if not unit.traits.has("bloodfeast") or not unit.is_alive():
		return
	var healed := int(unit.max_hp * unit.traits["bloodfeast"] / 100.0)
	if healed <= 0 or unit.current_hp >= unit.max_hp:
		return
	unit.current_hp = mini(unit.max_hp, unit.current_hp + healed)
	var view = _get_view(unit)
	if view != null and view.has_method("play_heal"):
		view.play_heal(healed)


# Enemies drop Qi when they die.
func _award_kill_qi(target: CombatUnit, target_view) -> void:
	if target.side != CombatUnit.Side.ENEMY or _in_dungeon:
		return
	# Heavenly Star treasures make kills pay more Qi
	var qi_mult := 1.0 + Treasures.economy_bonus("qi_bonus") / 100.0
	var amount := int(GameState.get_qi_per_kill(GameState.current_stage, target.is_boss) * qi_mult)
	GameState.add_qi(amount)

	if target_view != null:
		target_view.play_qi(amount)


# ---------------------------------------------------------
# RESULT
# ---------------------------------------------------------

func _show_result(player_won: bool) -> void:
	var stage: int = GameState.current_stage

	if player_won:
		var stones: int = 50 + stage * 10
		var qi_bonus: int = GameState.get_qi_stage_bonus(stage)
		var drops := Loot.roll_stage(stage, EnemyGenerator.is_boss_stage(stage))
		GameState.add_spirit_stones(stones)
		GameState.add_qi(qi_bonus)
		GameState.add_items(drops)

		var drop_chips: Array = []
		for id in drops:
			var item := ItemDB.get_item(id)
			drop_chips.append({"item_id": id, "amount": drops[id],
				"name": item.get("name", id)})

		await _result_banner.show_victory(stage, [
			{"icon": spirit_stone_icon, "amount": stones,
				"name": "Spirit Stones", "color": Color("2f5c8f")},
			{"icon": qi_icon, "amount": qi_bonus,
				"name": "Qi", "color": Color("2a7d74")},
		], RESULT_DELAY, drop_chips)

		GameState.advance_stage()

	else:
		# Keep the Qi earned from kills even on a loss.
		GameState.save_game()

		# A boss that beats you knocks you back a stage; you can
		# challenge it again with the button on the battlefield.
		if EnemyGenerator.is_boss_stage(stage) and stage > 1:
			GameState.boss_defeat(stage)
			await _result_banner.show_defeat(stage, RESULT_DELAY,
				"The boss drove you back to Stage %d" % GameState.current_stage)
		else:
			await _result_banner.show_defeat(stage, RESULT_DELAY)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
