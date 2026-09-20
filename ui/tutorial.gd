class_name Tutorial
extends CanvasLayer

# =========================================================
# Tutorials: a mentor walks the player through the game.
# Save as res://ui/tutorial.gd
#
#   Tutorial.start("intro", from)            after character creation
#   Tutorial.start_unlock(feature_id, from)  when a feature unlocks
#
# Each step can spotlight something on screen (the rest dims and
# can't be tapped), and either waits for a tap anywhere, for the
# highlighted button to be pressed, or for something to happen
# (the summon reveal to end, a partner to join the team).
# Every tutorial runs once (GameState.tutorials_done); Skip is
# always there.
#
# Targets: "nav:Growth", "quick:Summon", "text:Summon ×1" (a button
# whose text contains that), "node:PartnerPanel" (a node by name),
# "battle", "" (nothing).
# context: the screen to open before a step ("home", "nav:Growth",
# "quick:Summon"). Quick-menu targets go back to Home by themselves.
# =========================================================

const MENTOR_NAME := "Elder Yunhe"
const MENTOR_ART := "res://assets/ui/tutorial/mentor.png"
const LAYER := 110

const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("e6ecf5")
const COL_DIM := Color("9aa6b8")

## Step keys: text, target, black (a dark screen with only the mentor,
## like a cutscene), tap (press the target to continue),
## free (don't block the screen), until ("ceremony_done", "team2"),
## give ({item: amount}, given once even if the tutorial resumes),
## skip_if ("summoned", "team2": skip the step when already true).
##
## Progress is saved: a tutorial cut short (app closed, disconnect)
## resumes from its step on the next launch (Tutorial.resume).
const INTRO := [
	{"text": "Welcome, {name}. I am Elder Yunhe, and I will guide your first steps on the path to immortality.",
		"black": true},
	{"text": "Your team fights on its own. Every victory pushes you to the next stage, and your cultivators keep growing even while you are away.",
		"target": "battle"},
	{"text": "No cultivator walks alone. Tap Summon to call your first companion.",
		"target": "quick:Summon", "tap": true, "skip_if": "summoned"},
	{"text": "Here is a Summon Scroll, a gift from the sect. Your first summon is guaranteed Purple or better. Tap Summon ×1!",
		"target": "text:Summon ×1", "tap": true, "give": {"summon_scroll": 1}, "skip_if": "summoned",
		"context": "quick:Summon"},
	{"text": "", "free": true, "hidden": true, "until": "ceremony_done"},
	{"text": "A fine companion! Now bring them into battle. Tap Formation.",
		"target": "quick:Formation", "tap": true, "skip_if": "team2"},
	{"text": "Tap your new partner to place them in an empty slot of your team.",
		"free": true, "until": "team2", "skip_if": "team2", "context": "quick:Formation"},
	{"text": "Well done. Now look at your own cultivation. Tap Partner.",
		"target": "quick:Partner", "tap": true},
	{"text": "When your Qi is full, Ascend to rise a level, and break through to a new realm. Each breakthrough makes you far stronger.",
		"target": "node:PartnerPanel", "context": "quick:Partner"},
	{"text": "That is all for now. New paths will open as you grow stronger, and I will be here to guide you each time. Go forth, {name}!"},
]

## Extra lines for each feature's unlock tutorial (after it's opened).
const UNLOCK_LINES := {
	"inventory": ["Everything you collect is kept here: pills, materials, scrolls and more. Tap an item to see what it does."],
	"missions": ["Complete daily and weekly missions to fill the chests at the top. Open them for rewards!"],
	"growth": ["Your Abode is where your cultivation grows. Send partners on Expeditions to bring back resources while you rest."],
	"forge": ["Forge equipment for your partners and refine it to make it stronger."],
	"codex": ["Every partner, spirit beast and treasure you find is recorded here. Complete a set for a permanent bonus to your whole team."],
	"events": ["Dungeons test your team for valuable materials. Check back every day: some challenges only open on certain days."],
	"achievements": ["Achievements reward long-term goals. There is always another tier to reach."],
	"beast_forest": ["Hunt spirit beasts in the Beast Forest. Defeating a beast can tame it as a Soul Spirit, and it drops spirit rings.",
		"Bond a Soul Spirit to a partner from their Equipment row, then place rings in it to awaken its Beast Skill."],
	"trials": ["A new Daily Trial opens each day, with a bonus for partners of its Dao. Climb as high as you can!"],
	"guild": ["Join a sect, or found your own. Sign in and donate each day, research techniques for everyone, and challenge the Sect Trial together."],
	"arena": ["The Arena pits you against other cultivators of your own realm. Ten duels a day, and a win or a loss both pay Arena Tokens.",
		"Spend Tokens at the Exchange. A Premium Selection Scroll waits there for the patient.",
		"Your standing is settled when the day and the week close, and the rewards arrive by mail. There is nothing to claim."],
	"battle_array": ["Partners not in your team can still help: place them in the Battle Array to lend part of their strength to your fighters."],
	"tribulation": ["Endure the heavens' lightning. Each wave you survive earns rewards, and the storm only grows fiercer."],
	"god_path": ["You have reached Ascendant. Choose a god to follow, earn Divinity, and face the Fallen God when he descends."],
}

static var _queue: Array = []
static var _running: Tutorial = null

var _id := ""
var _steps: Array = []
var _shade: Control
var _blockers: Array = []
var _catcher: Button
var _dialog: PanelContainer
var _text: Label
var _target: Control = null
var _advance := false
## 0..1: how dark the "black" cutscene backdrop is (tweened)
var _black := 0.0
var _black_tween: Tween
## True on steps that continue with a tap (the dialogue box counts too)
var _tap_to_continue := false
var _skip_button: Button
var _hint: Label


# ---------------------------------------------------------
# STARTING
# ---------------------------------------------------------

static func is_done(id: String) -> bool:
	return GameState.tutorials_done.has(id)


## Starts a tutorial (or queues it behind the one running).
static func start(id: String, from: Node) -> void:
	if is_done(id) or _queue.has(id) or (_running != null and is_instance_valid(_running) and _running._id == id):
		return
	# Remembered in the save, so it resumes after a disconnect
	if not GameState.tutorials_pending.has(id):
		GameState.tutorials_pending.append(id)
		GameState.save_game()
	_queue.append(id)
	if _running == null or not is_instance_valid(_running):
		_run_next(from)


static func start_unlock(feature_id: String, from: Node) -> void:
	start("unlock_" + feature_id, from)


## Forgets every finished tutorial, so each one plays again as you
## reach that feature, and starts the intro straight away.
## Steps with "skip_if" still skip themselves for a player who has
## already done the thing, so this doesn't hand out the starter
## Summon Scroll a second time.
static func replay(from: Node) -> void:
	GameState.tutorials_done.clear()
	GameState.tutorials_pending.clear()
	GameState.tutorial_step.clear()
	GameState.save_game()

	# Drop anything queued or on screen, or the old run would carry on
	# over the top of the restarted intro.
	_queue.clear()
	if _running != null and is_instance_valid(_running):
		_running.queue_free()
	_running = null

	start("intro", from)


## On launch: continue any tutorial that was cut short.
static func resume(from: Node) -> void:
	for id in GameState.tutorials_pending.duplicate():
		if is_done(str(id)):
			GameState.tutorials_pending.erase(id)
		else:
			start(str(id), from)


static func _run_next(from: Node) -> void:
	if _queue.is_empty() or from == null or not from.is_inside_tree():
		_running = null
		return
	var id := str(_queue.pop_front())
	var steps := _steps_for(id)
	if steps.is_empty():
		GameState.tutorials_done[id] = true
		_run_next(from)
		return
	var t := Tutorial.new()
	t._id = id
	t._steps = steps
	_running = t
	from.get_tree().root.add_child(t)


static func _steps_for(id: String) -> Array:
	if id == "intro":
		return INTRO
	if not id.begins_with("unlock_"):
		return []
	var feature := id.trim_prefix("unlock_")
	if not Unlocks.FEATURES.has(feature):
		return []
	var f: Array = Unlocks.FEATURES[feature]
	var fname := str(f[0])
	var place := str(f[3])
	var steps: Array = []
	var parts := place.split(":")
	match parts[0]:
		"nav", "quick":
			steps.append({"text": "%s is now open! Tap here to take a look." % fname, "target": place, "tap": true})
		"growth":
			steps.append({"text": "Something new awaits in Growth. Tap Growth.", "target": "nav:Growth", "tap": true})
			steps.append({"text": "Now open %s." % fname, "target": "text:" + parts[1], "tap": true,
				"context": "nav:Growth"})
		"mission":
			steps.append({"text": "Something new awaits in Missions. Tap Missions.", "target": "nav:Mission", "tap": true})
			steps.append({"text": "Now open %s." % fname, "target": "text:" + parts[1], "tap": true,
				"context": "nav:Mission"})
		"events":
			steps.append({"text": "%s is now open in Events. Tap Events." % fname, "target": "nav:Events", "tap": true})
	for line in UNLOCK_LINES.get(feature, [str(f[4])]):
		steps.append({"text": str(line)})
	return steps


# ---------------------------------------------------------
# RUNNING
# ---------------------------------------------------------

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_run()


func _run() -> void:
	# Let whatever just happened (a banner, a screen change) settle
	await get_tree().create_timer(0.6).timeout
	var from_step := int(GameState.tutorial_step.get(_id, 0))
	if from_step > 0:
		await _do_step({"text": "Let us continue where we left off, {name}."})
	for i in range(from_step, _steps.size()):
		if not is_inside_tree():
			return
		var step: Dictionary = _steps[i]
		# Save the step we're on, so a disconnect resumes here
		GameState.tutorial_step[_id] = i
		GameState.save_game()
		if _already_true(str(step.get("skip_if", ""))):
			continue
		if step.has("give"):
			var gift_key := "%s#gift%d" % [_id, i]
			if not GameState.tutorials_done.has(gift_key):
				GameState.tutorials_done[gift_key] = true
				GameState.add_items(step["give"])
				GameState.save_game()
		await _do_step(step)
	_finish()


func _already_true(check: String) -> bool:
	match check:
		"summoned":
			return GameState.first_summon_done
		"team2":
			return _condition("team2")
	return false


func _do_step(step: Dictionary) -> void:
	var is_free := bool(step.get("free", false))
	var hidden := bool(step.get("hidden", false))
	var black := bool(step.get("black", false))
	_set_black(black)
	# Make sure the right screen is open first (the player may be
	# anywhere, e.g. on More, or resuming after a restart)
	var ctx := str(step.get("context", ""))
	var key0 := str(step.get("target", ""))
	if ctx == "" and (key0.begins_with("quick:") or key0 == "battle"):
		ctx = "home"
	if ctx != "":
		_open_context(ctx)
		await get_tree().create_timer(0.25).timeout
	_target = await _find_target(key0)
	var text_value := str(step.get("text", "")).replace("{name}", str(GameState.mc_name))
	_text.text = text_value
	_dialog.visible = not hidden and text_value != ""
	_place_dialog(is_free, black)
	_advance = false

	var target_key := str(step.get("target", ""))
	var tap := bool(step.get("tap", false)) and target_key != ""
	var until := str(step.get("until", ""))
	# Spotlight and blockers: none on free steps
	_shade.visible = not is_free
	for b in _blockers:
		(b as Control).visible = not is_free
	_catcher.visible = not is_free and not tap and until == ""
	_tap_to_continue = not tap and until == ""
	_hint.visible = _tap_to_continue
	_update_hole()

	if tap:
		# Screens can rebuild their buttons at any moment (e.g. the altar
		# redraws when the gift scroll arrives): keep following the
		# current button with this text until it's pressed
		var pressed := [false]
		var on_press := func(): pressed[0] = true
		var hooked: BaseButton = null
		var missing := 0.0
		while not pressed[0] and is_inside_tree():
			# Safety net: the button never appeared, so don't freeze the
			# player: turn this into a tap-to-continue step
			if hooked == null:
				missing += get_process_delta_time()
				if missing > 4.0:
					_become_tap_to_continue()
					while not _advance and is_inside_tree():
						await get_tree().process_frame
					break
			if hooked == null or not is_instance_valid(hooked) or not hooked.is_visible_in_tree():
				hooked = null
				var found := _resolve(target_key)
				if found is BaseButton and found.is_visible_in_tree() and found.size.x > 0.0:
					hooked = found as BaseButton
					hooked.pressed.connect(on_press, CONNECT_ONE_SHOT)
					await _scroll_into_view(hooked)
					_target = hooked
					_place_dialog()
				else:
					_target = null
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
	elif until != "":
		while is_inside_tree() and not _condition(until):
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(0.4).timeout
	else:
		# Tap anywhere (after a short moment, so it isn't skipped by accident)
		await get_tree().create_timer(0.4).timeout
		while not _advance and is_inside_tree():
			await get_tree().process_frame


func _become_tap_to_continue() -> void:
	_target = null
	_advance = false
	_tap_to_continue = true
	_hint.visible = true
	_shade.visible = true
	for b in _blockers:
		(b as Control).visible = false
	_catcher.visible = false
	_update_hole()


func _open_context(ctx: String) -> void:
	var scene := get_tree().current_scene
	var router: Node = scene.find_child("LowerStack", true, false) if scene != null else null
	if router == null:
		return
	if ctx == "home":
		router.call("open_tab", "Home")
	elif ctx.begins_with("nav:"):
		router.call("open_tab", ctx.trim_prefix("nav:"))
	elif ctx.begins_with("quick:"):
		router.call("open_quick", ctx.trim_prefix("quick:"))


## The tutorial running right now ("" if none), e.g. to hold back
## "Summon again" during the intro.
static func active_id() -> String:
	if _running != null and is_instance_valid(_running):
		return _running._id
	return ""


func _condition(until: String) -> bool:
	match until:
		"ceremony_done":
			for c in get_tree().root.get_children():
				if c is SummonCeremony:
					return false
			return _seen_ceremony_or_timeout()
		"team2":
			var n := 0
			for i in GameState.formation:
				if int(i) >= 0:
					n += 1
			return n >= 2
	return true


var _waited := 0.0
var _ceremony_seen := false


## The reveal may take a moment to open: wait for it to appear first.
func _seen_ceremony_or_timeout() -> bool:
	_waited += 0.2
	return _ceremony_seen or _waited > 3.0


func _process(_delta: float) -> void:
	for c in get_tree().root.get_children():
		if c is SummonCeremony:
			_ceremony_seen = true
	_update_hole()


func _finish() -> void:
	GameState.tutorials_done[_id] = true
	GameState.tutorials_pending.erase(_id)
	GameState.tutorial_step.erase(_id)
	GameState.save_game()
	var host := get_tree().root
	queue_free()
	_running = null
	if not _queue.is_empty():
		Tutorial._run_next(host)


func _skip() -> void:
	# Skipping marks this tutorial done (and the queued ones stay queued)
	_finish()


# ---------------------------------------------------------
# TARGETS
# ---------------------------------------------------------

func _find_target(key: String) -> Control:
	if key == "":
		return null
	# Screens build after a tab opens: look for up to 3 seconds
	for i in 30:
		var c := _resolve(key)
		if c != null and c.is_visible_in_tree() and c.size.x > 0.0:
			await _scroll_into_view(c)
			return c
		await get_tree().create_timer(0.1).timeout
	return null


## Scrolls every scroll area the target sits in so it sits in the
## upper-middle of that area (clear of the nav bar and the dialogue).
func _scroll_into_view(c: Control) -> void:
	var node := c.get_parent()
	var scrolled := false
	while node != null:
		if node is ScrollContainer:
			var sc := node as ScrollContainer
			# `scroll_to`, not `offset`: CanvasLayer already has an
			# `offset` property and this would shadow it.
			var scroll_to := c.get_global_rect().position.y - sc.get_global_rect().position.y + float(sc.scroll_vertical)
			sc.scroll_vertical = int(maxf(0.0, scroll_to - sc.size.y * 0.3))
			scrolled = true
		node = node.get_parent()
	if scrolled:
		# Let the scroll settle before measuring the spotlight
		await get_tree().process_frame
		await get_tree().process_frame


func _resolve(key: String) -> Control:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var router := scene.find_child("LowerStack", true, false)
	if key == "battle":
		return Dungeons.find_battle(scene) as Control
	if key.begins_with("nav:") and router != null:
		var buttons = router.get("_nav_buttons")
		if buttons is Dictionary:
			return (buttons as Dictionary).get(key.trim_prefix("nav:")) as Control
	if key.begins_with("quick:") and router != null:
		var quick = router.get("_quick_menu")
		if quick is Node:
			return (quick as Node).find_child(key.trim_prefix("quick:") + "Tab", true, false) as Control
	if key.begins_with("text:"):
		var want := key.trim_prefix("text:").to_lower()
		return _find_button(get_tree().root, want)
	if key.begins_with("node:"):
		return scene.find_child(key.trim_prefix("node:"), true, false) as Control
	return null


func _find_button(node: Node, want: String) -> Control:
	for c in node.get_children():
		if c == self:
			continue
		if c is BaseButton and (c as Control).is_visible_in_tree():
			var t = c.get("text")
			if t != null and str(t).to_lower().contains(want):
				return c as Control
		var found := _find_button(c, want)
		if found != null:
			return found
	return null


# ---------------------------------------------------------
# DRAWING
# ---------------------------------------------------------

func _build() -> void:
	# Dim everything except the target (drawn), with four blockers
	# around the hole so only the target can be tapped
	_shade = Control.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.draw.connect(_draw_shade)
	for i in 4:
		var b := Control.new()
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(b)
		_blockers.append(b)

	# Tap-anywhere to continue
	_catcher = Button.new()
	_catcher.flat = true
	_catcher.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		_catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_catcher.pressed.connect(func(): _advance = true)
	add_child(_catcher)
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The mentor's dialogue box
	_dialog = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 0.94)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(18)
	_dialog.add_theme_stylebox_override("panel", sb)
	add_child(_dialog)
	_dialog.gui_input.connect(_on_dialog_input)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_dialog.add_child(h)
	if ResourceLoader.exists(MENTOR_ART):
		var art := TextureRect.new()
		art.texture = load(MENTOR_ART) as Texture2D
		art.custom_minimum_size = Vector2(170, 210)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(art)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var who := _label(MENTOR_NAME, 24, COL_TITLE)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	var skip := Button.new()
	_skip_button = skip
	skip.text = "Skip"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 18)
	skip.add_theme_color_override("font_color", COL_DIM)
	skip.pressed.connect(_skip)
	top.add_child(skip)
	_text = _label("", 22, COL_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 1
	v.add_child(_text)
	_hint = _label("Tap to continue  »", 16, COL_GOLD)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	# Nothing inside the dialogue should eat taps
	for c in [h, v, top, _text, _hint]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_dialog_input(event: InputEvent) -> void:
	if _tap_to_continue and event is InputEventMouseButton and event.pressed:
		_advance = true


## Tap-to-continue steps listen to every tap on the screen directly,
## so nothing drawn on top (the portrait, the text) can swallow it.
func _input(event: InputEvent) -> void:
	if not _tap_to_continue or not visible:
		return
	var tapped := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and not _over_skip(event):
		_advance = true


## Taps on Skip shouldn't also count as "continue".
func _over_skip(event: InputEvent) -> bool:
	if _skip_button == null or not _skip_button.is_visible_in_tree():
		return false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton:
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	return _skip_button.get_global_rect().has_point(pos)


func _set_black(on: bool) -> void:
	if _black_tween != null:
		_black_tween.kill()
	var apply := func(v: float):
		_black = v
		if _shade != null:
			_shade.queue_redraw()
	_black_tween = create_tween()
	_black_tween.tween_method(apply, _black, 1.0 if on else 0.0, 0.25 if on else 0.6)


func _place_dialog(at_top := false, centred := false) -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * 0.92
	_dialog.size = Vector2(w, 0)
	_dialog.reset_size()
	_dialog.size.x = w
	# Below the target if it's in the top half, above it otherwise
	var y := vp.y * 0.62
	if centred:
		y = (vp.y - _dialog.size.y) * 0.5
	elif at_top:
		y = vp.y * 0.04
	elif _target != null:
		var r := _target.get_global_rect()
		y = r.end.y + 30.0 if r.get_center().y < vp.y * 0.5 else r.position.y - _dialog.size.y - 60.0
	y = clampf(y, vp.y * 0.04, vp.y - _dialog.size.y - vp.y * 0.03)
	_dialog.position = Vector2((vp.x - w) * 0.5, y)


func _hole() -> Rect2:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return Rect2()
	return _target.get_global_rect().grow(10.0)


func _update_hole() -> void:
	if _shade == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var hole := _hole()
	if hole.size == Vector2.ZERO:
		hole = Rect2(Vector2(-10, -10), Vector2.ZERO)
	# Blockers: above, below, left and right of the hole
	var rects := [
		Rect2(0, 0, vp.x, maxf(hole.position.y, 0.0)),
		Rect2(0, hole.end.y, vp.x, maxf(vp.y - hole.end.y, 0.0)),
		Rect2(0, hole.position.y, maxf(hole.position.x, 0.0), hole.size.y),
		Rect2(hole.end.x, hole.position.y, maxf(vp.x - hole.end.x, 0.0), hole.size.y),
	]
	for i in 4:
		var b: Control = _blockers[i]
		b.position = rects[i].position
		b.size = rects[i].size
	_shade.queue_redraw()


func _draw_shade() -> void:
	var vp := _shade.size
	var hole := _hole()
	var dim := Color(0, 0, 0, 0.62)
	if _black > 0.0:
		# Cutscene: everything dark, only the mentor
		_shade.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.02, 0.96 * _black))
		if _black >= 0.99:
			return
	if hole.size == Vector2.ZERO:
		_shade.draw_rect(Rect2(Vector2.ZERO, vp), dim)
		return
	_shade.draw_rect(Rect2(0, 0, vp.x, hole.position.y), dim)
	_shade.draw_rect(Rect2(0, hole.end.y, vp.x, vp.y - hole.end.y), dim)
	_shade.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), dim)
	_shade.draw_rect(Rect2(hole.end.x, hole.position.y, vp.x - hole.end.x, hole.size.y), dim)
	# Pulsing gold outline and a bouncing arrow pointing at the target
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.55 + 0.45 * sin(t * 4.0)
	_shade.draw_rect(hole, Color(1.0, 0.85, 0.4, pulse), false, 4.0)
	_shade.draw_rect(hole.grow(6.0), Color(1.0, 0.85, 0.4, pulse * 0.35), false, 3.0)
	var bob := sin(t * 5.0) * 10.0
	var above := hole.position.y > 120.0
	var tip := Vector2(hole.get_center().x, (hole.position.y - 14.0 if above else hole.end.y + 14.0) + bob * (1.0 if above else -1.0))
	var dir := -1.0 if above else 1.0
	var pts := PackedVector2Array([tip, tip + Vector2(-26, 40 * dir), tip + Vector2(26, 40 * dir)])
	_shade.draw_colored_polygon(pts, Color(1.0, 0.85, 0.4, 0.95))


func _label(value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
