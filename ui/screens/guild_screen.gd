extends PanelContainer

# =========================================================
# Guild (Sect) screen. Save as res://ui/screens/guild_screen.gd
# (the Guild button opens it). Online only: uses Sects /
# Backend (Supabase).
#
# Not in a sect:  Browse (search, join / apply) and Create.
# In a sect:      Hall, Members, Requests (leader & elders).
#
# Sect chat is NOT here any more: it is a channel in the floating
# chat box on Home (ui/chat_box.gd), alongside World and Whispers.
# =========================================================

const COL_BG_TOP := Color("0d1a31")
const COL_BG_BOTTOM := Color("060c1a")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")

var _title: Label
var _status: Label
var _tabs_row: HFlowContainer
var _body: VBoxContainer

var _tab := ""
var _busy := false
var _membership: Variant = null
var _sect := {}
var _members: Array = []
var _requests: Array = []
var _search := ""
## Loaded at least once: later refreshes happen quietly in the background
var _loaded := false
var _research := {}

const HALL_ART := "res://assets/ui/sect/sect_hall.png"
const RESEARCH_ICON := "res://assets/ui/sect/research_%s.png"


func _ready() -> void:
	name = "GuildScreen"
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	draw.connect(_draw_backdrop)
	resized.connect(queue_redraw)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title = _label("Sect", 36, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_status = _label("", 17, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_status)

	_tabs_row = HFlowContainer.new()
	_tabs_row.add_theme_constant_override("h_separation", 8)
	_tabs_row.add_theme_constant_override("v_separation", 8)
	root.add_child(_tabs_row)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 20)
	scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	pad.add_child(_body)

	refresh()


## Called by the router each time the tab opens: shows what was
## there, then updates quietly.
func on_opened() -> void:
	refresh(_loaded)


# ---------------------------------------------------------
# LOADING
# ---------------------------------------------------------

## silent: keep the screen as it is while reloading, then redraw with
## the new data (no "Connecting..." message).
func refresh(silent := false) -> void:
	if _busy:
		return
	_busy = true
	if silent and _loaded:
		await _reload_quietly()
		_busy = false
		return
	_clear()
	_set_tabs([])
	if not Sects.available():
		_status.text = ""
		_note("Sects need the online server. Set up the Backend (Supabase URL and key) to use them.")
		_busy = false
		return
	_status.text = "Connecting..."
	_note("Connecting to the sect registry...")
	if not await Backend.ensure_session():
		_status.text = "Offline"
		_clear()
		_note("Can't reach the server. Check your internet connection and try again.")
		_retry_button()
		_busy = false
		return
	_membership = await Sects.my_membership()
	if _membership == null:
		_status.text = "Offline"
		_clear()
		_note("Couldn't load your sect. Try again in a moment.")
		_retry_button()
		_busy = false
		return
	var m: Dictionary = _membership
	if m.is_empty():
		_sect = {}
		if not GameState.sect_bonus.is_empty():
			GameState.sect_bonus = {}
			GameState.save_game()
			GameState.roster_changed.emit()
		_status.text = "No sect"
		_title.text = "Sect"
		_busy = false
		_loaded = true
		_show_tab("Browse" if _tab not in ["Browse", "Create"] else _tab)
		return
	_sect = await Sects.get_sect(str(m["sect_id"]))
	_members = await Sects.members(str(m["sect_id"]))
	if _is_officer():
		_requests = await Sects.requests(str(m["sect_id"]))
	_research = await Sects.research(str(m["sect_id"]))
	var bonus := Sects.bonus_from(_research)
	if bonus != GameState.sect_bonus:
		GameState.sect_bonus = bonus
		GameState.save_game()
		GameState.roster_changed.emit()
	_title.text = str(_sect.get("name", "Sect"))
	_status.text = Sects.ROLE_NAMES.get(_my_role(), "")
	_busy = false
	_loaded = true
	_show_tab(_tab if _tab.split(" ")[0] in _tab_names() else "Hall")


## Reloads the data without touching the screen, then redraws the
## current tab. Falls back to a full refresh if the sect changed.
func _reload_quietly() -> void:
	if not await Backend.ensure_session():
		_toast("Can't reach the server.", COL_BAD)
		return
	var m = await Sects.my_membership()
	if m == null:
		_toast("Couldn't update. Try again in a moment.", COL_BAD)
		return
	var old_sect := str(_sect.get("id", ""))
	var new_sect := str((m as Dictionary).get("sect_id", "")) if m is Dictionary else ""
	if new_sect != old_sect:
		# Joined, left or was removed: rebuild everything
		_loaded = false
		_busy = false
		refresh()
		return
	_membership = m
	if new_sect == "":
		_show_tab(_tab if _tab in ["Browse", "Create"] else "Browse")
		return
	_sect = await Sects.get_sect(new_sect)
	_members = await Sects.members(new_sect)
	if _is_officer():
		_requests = await Sects.requests(new_sect)
	_research = await Sects.research(new_sect)
	var bonus := Sects.bonus_from(_research)
	if bonus != GameState.sect_bonus:
		GameState.sect_bonus = bonus
		GameState.save_game()
		GameState.roster_changed.emit()
	_status.text = Sects.ROLE_NAMES.get(_my_role(), "")
	_show_tab(_tab)


## Tab names without their counters ("Requests (2)" -> "Requests").
func _tab_names() -> Array:
	return _in_sect_tabs().map(func(t): return str(t).split(" ")[0])


func _mine() -> Dictionary:
	return _membership if _membership is Dictionary else {}


func _my_balance() -> int:
	return int(_mine().get("balance", 0))


func _my_role() -> String:
	if _membership is Dictionary:
		return str((_membership as Dictionary).get("role", ""))
	return ""


func _is_officer() -> bool:
	return _my_role() in ["leader", "elder"]


func _in_sect_tabs() -> Array:
	var tabs := ["Hall", "Members"]
	if _is_officer():
		tabs.append("Requests (%d)" % _requests.size() if not _requests.is_empty() else "Requests")
	tabs.append("Trial")
	tabs.append("Research")
	tabs.append("Shop")
	return tabs


func _show_tab(tab: String) -> void:
	_tab = tab.split(" ")[0]
	var in_sect := not _sect.is_empty()
	_set_tabs(_in_sect_tabs() if in_sect else ["Browse", "Create"])
	# Tabs that fetch their own data clear the screen once it arrives,
	# so there's no blank flash in between
	if _tab not in ["Trial", "Shop"]:
		_clear()
	match _tab:
		"Browse":
			_build_browse()
		"Create":
			_build_create()
		"Hall":
			_build_hall()
		"Members":
			_build_members()
		"Requests":
			_build_requests()
		"Trial":
			_build_trial()
		"Research":
			_build_research()
		"Shop":
			_build_shop()


# ---------------------------------------------------------
# NOT IN A SECT
# ---------------------------------------------------------

func _build_browse() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	var search := _line_edit("Search sect names...", 16)
	search.text = _search
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(search)
	var go := OrnateButton.new()
	go.text = "Search"
	go.custom_minimum_size = Vector2(160, 56)
	row.add_child(go)
	go.pressed.connect(_on_search.bind(search))
	search.text_submitted.connect(func(_t: String): _on_search(search))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_body.add_child(list)
	list.add_child(_label("Loading sects...", 18, COL_DIM))
	var pending: Array = await Sects.my_requests()
	var sects: Array = await Sects.list_sects(_search)
	if not is_instance_valid(list):
		return
	for c in list.get_children():
		c.queue_free()
	var applied := {}
	for p in pending:
		applied[str(p["sect_id"])] = true
	if not pending.is_empty():
		var names := PackedStringArray()
		for p in pending:
			var sect_info = p.get("sects")
			names.append(str(sect_info.get("name", "?")) if sect_info is Dictionary else "?")
		list.add_child(_label("Your applications: " + ", ".join(names), 17, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	if sects.is_empty():
		list.add_child(_label("No sects found. Be the first to create one!", 19, COL_DIM))
	for s in sects:
		list.add_child(_sect_row(s, applied.has(str(s["id"]))))


func _sect_row(s: Dictionary, applied: bool) -> Control:
	var panel := _panel(COL_GOLD, 0.05)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var level := int(s["level"])
	v.add_child(_label("%s   Lv %d" % [s["name"], level], 22, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT))
	var rules := "Open to all" if str(s["join_mode"]) == "open" else "Needs approval"
	if int(s["min_realm"]) > 0:
		rules += "  ·  %s+" % str(Realms.get_label(int(s["min_realm"]), 1))
	v.add_child(_label("Members %d / %d  ·  %s" % [int(s["member_count"]), Sects.capacity(level), rules], 16,
		COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if str(s["notice"]) != "":
		var n := _label(str(s["notice"]), 16, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	var b := OrnateButton.new()
	b.custom_minimum_size = Vector2(170, 54)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sect_id := str(s["id"])
	if applied:
		b.text = "Cancel"
		b.variant = OrnateButton.Variant.DARK
		b.pressed.connect(_do.bind("cancel_request", [sect_id], "Application cancelled."))
	else:
		b.text = "Join" if str(s["join_mode"]) == "open" else "Apply"
		b.disabled = int(s["member_count"]) >= Sects.capacity(level)
		b.pressed.connect(_join.bind(sect_id))
	h.add_child(b)
	return panel


func _on_search(search: LineEdit) -> void:
	_search = search.text
	_show_tab("Browse")


func _join(sect_id: String) -> void:
	var r: Dictionary = await _run("join", [sect_id])
	if r["ok"]:
		_toast("Welcome to the sect!" if str(r["data"]) == "joined" else "Application sent.", COL_OK)
		refresh(true)


func _build_create() -> void:
	_body.add_child(_label("Found your own sect. You'll be its Sect Master.", 19, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(_label("Sect name (2-16 characters)", 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var name_edit := _line_edit("e.g. Azure Cloud Sect", 16)
	_body.add_child(name_edit)
	_body.add_child(_label("Notice (optional)", 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var notice := _line_edit("A few words for people browsing sects", 200)
	_body.add_child(notice)
	var mode := _option(["Open to all", "Needs approval"])
	_body.add_child(_labelled("Joining", mode))
	var realm := _realm_option(0)
	_body.add_child(_labelled("Minimum realm", realm))
	var create := OrnateButton.new()
	create.text = "Found Sect"
	create.custom_minimum_size = Vector2(280, 64)
	create.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(_on_create.bind(name_edit, notice, mode, realm))
	_body.add_child(create)


func _on_create(name_edit: LineEdit, notice: LineEdit, mode: OptionButton, realm: OptionButton) -> void:
	var n := name_edit.text.strip_edges()
	if n.length() < 2 or n.length() > 16:
		_toast("Sect names need 2 to 16 characters.", COL_BAD)
		return
	var r: Dictionary = await _run("create", [n, notice.text.strip_edges(),
		"approval" if mode.selected == 1 else "open", realm.get_selected_id()])
	if r["ok"]:
		_toast("The %s is founded!" % n, COL_OK)
		refresh(true)


# ---------------------------------------------------------
# IN A SECT
# ---------------------------------------------------------

func _build_hall() -> void:
	var level := int(_sect.get("level", 1))
	var card := _panel(COL_GOLD, 0.06)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(_label(str(_sect.get("name", "")), 32, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_label("Level %d  ·  Members %d / %d  ·  You: %s" % [level, int(_sect.get("member_count", 0)),
		Sects.capacity(level), Sects.ROLE_NAMES.get(_my_role(), "")], 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var notice_text := str(_sect.get("notice", ""))
	var n := _label(notice_text if notice_text != "" else "No notice yet.", 18,
		COL_GOLD if notice_text != "" else COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	if ResourceLoader.exists(HALL_ART):
		var art := TextureRect.new()
		art.texture = load(HALL_ART) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(0, 220)
		art.clip_contents = true
		_body.add_child(art)
	_body.add_child(card)

	# Level progress and Treasury
	var exp_now := int(_sect.get("exp", 0))
	var need := Sects.exp_needed(level)
	var maxed := level >= Sects.MAX_LEVEL
	v.add_child(_label("Sect EXP  %s" % ("MAX" if maxed else "%s / %s" % [NumberFormat.short(exp_now), NumberFormat.short(need)]),
		16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_bar(1.0 if maxed else float(exp_now) / float(maxi(need, 1)), COL_GOLD))
	v.add_child(_label("Treasury: %s funds  ·  Your Contribution: %s" % [
		NumberFormat.short(int(_sect.get("funds", 0))), NumberFormat.short(_my_balance())], 17, COL_OK,
		HORIZONTAL_ALIGNMENT_LEFT))

	# Daily sign-in and donation
	_body.add_child(_label("Daily Duties", 22, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	var today := Sects.today_utc()
	var signed := str(_mine().get("last_signin", "")) == today
	var sign_button := OrnateButton.new()
	sign_button.text = "Signed In Today" if signed else "Sign In  (+%d EXP, +%d Contribution)" % [Sects.SIGNIN_EXP, Sects.SIGNIN_CONTRIBUTION]
	sign_button.custom_minimum_size = Vector2(0, 56)
	sign_button.disabled = signed
	sign_button.pressed.connect(_do.bind("signin", [], "Signed in! +%d Contribution" % Sects.SIGNIN_CONTRIBUTION))
	_body.add_child(sign_button)
	var donated := str(_mine().get("last_donate", "")) == today
	_body.add_child(_label("Donate once a day (resets at 00:00 UTC):" if not donated else "You've donated today. Thank you!",
		16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for i in Sects.DONATIONS.size():
		var d: Dictionary = Sects.DONATIONS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var cost := "%s %s" % [NumberFormat.short(int(d["cost"])), "Spirit Stones" if str(d["currency"]) == "stones" else "Jade"]
		var l := _label("%s:  %s  →  +%d EXP, +%d Contribution" % [d["name"], cost, int(d["exp"]), int(d["contribution"])],
			17, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		var b := _small_button("Donate", _do.bind("donate", [i], "Donated! +%d Contribution" % int(d["contribution"])))
		b.disabled = donated
		row.add_child(b)
		_body.add_child(row)

	if _is_officer():
		_body.add_child(_label("Sect Settings", 22, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
		var notice := _line_edit("Sect notice", 200)
		notice.text = notice_text
		_body.add_child(notice)
		var mode := _option(["Open to all", "Needs approval"])
		mode.selected = 1 if str(_sect.get("join_mode", "open")) == "approval" else 0
		_body.add_child(_labelled("Joining", mode))
		var realm := _realm_option(int(_sect.get("min_realm", 0)))
		_body.add_child(_labelled("Minimum realm", realm))
		var save := OrnateButton.new()
		save.text = "Save Settings"
		save.custom_minimum_size = Vector2(260, 56)
		save.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		save.pressed.connect(_on_save_settings.bind(notice, mode, realm))
		_body.add_child(save)

	var leave := OrnateButton.new()
	leave.text = "Disband Sect" if _my_role() == "leader" and int(_sect.get("member_count", 1)) <= 1 else "Leave Sect"
	leave.variant = OrnateButton.Variant.DARK
	leave.custom_minimum_size = Vector2(240, 54)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(_confirm.bind("%s?" % leave.text, _on_leave))
	_body.add_child(leave)


func _on_save_settings(notice: LineEdit, mode: OptionButton, realm: OptionButton) -> void:
	var r: Dictionary = await _run("update", [notice.text.strip_edges(),
		"approval" if mode.selected == 1 else "open", realm.get_selected_id()])
	if r["ok"]:
		_toast("Sect settings saved.", COL_OK)
		refresh(true)


func _on_leave() -> void:
	var r: Dictionary = await _run("leave", [])
	if r["ok"]:
		_toast("You left the sect." if str(r["data"]) == "left" else "The sect was disbanded.", COL_OK)
		_tab = ""
		refresh(true)


func _build_members() -> void:
	_body.add_child(_label("%d members" % _members.size(), 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for m in _members:
		_body.add_child(_member_row(m))


func _member_row(m: Dictionary) -> Control:
	var prof: Dictionary = m.get("profiles", {}) if m.get("profiles") is Dictionary else {}
	var role := str(m["role"])
	var uid := str(m["user_id"])
	var me := uid == Backend.user_id
	var panel := _panel(COL_GOLD if role == "leader" else Color("6a8ab8"), 0.05)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label("%s%s" % [str(prof.get("display_name", "Cultivator")), "  (You)" if me else ""], 21,
		COL_OK if me else COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_label("%s  ·  %s  ·  Stage %d" % [Sects.ROLE_NAMES.get(role, role),
		str(Realms.get_label(int(prof.get("realm", 0)), 1)), int(prof.get("highest_stage", 1))], 15, COL_DIM,
		HORIZONTAL_ALIGNMENT_LEFT))

	if me:
		return panel
	var my := _my_role()
	var who := str(prof.get("display_name", "them"))
	if my == "leader":
		if role == "member":
			h.add_child(_small_button("Make Elder", _do.bind("set_role", [uid, "elder"], "Promoted to Elder.")))
		elif role == "elder":
			h.add_child(_small_button("Demote", _do.bind("set_role", [uid, "member"], "Now a Disciple.")))
		h.add_child(_small_button("Make Master", _confirm.bind("Hand leadership to %s? You'll become an Elder." % who,
			_do.bind("set_role", [uid, "leader"], "Leadership handed over."))))
	if my == "leader" or (my == "elder" and role == "member"):
		h.add_child(_small_button("Remove", _confirm.bind("Remove %s from the sect?" % who,
			_do.bind("kick", [uid], "Member removed."))))
	return panel


func _build_requests() -> void:
	if _requests.is_empty():
		_body.add_child(_label("No one is waiting to join.", 19, COL_DIM))
		return
	for r in _requests:
		var prof: Dictionary = r.get("profiles", {}) if r.get("profiles") is Dictionary else {}
		var uid := str(r["user_id"])
		var panel := _panel(Color("6a8ab8"), 0.05)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		panel.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(str(prof.get("display_name", "Cultivator")), 21, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(_label("%s  ·  Stage %d" % [str(Realms.get_label(int(prof.get("realm", 0)), 1)),
			int(prof.get("highest_stage", 1))], 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		h.add_child(_small_button("Accept", _do.bind("review", [uid, true], "Accepted!")))
		h.add_child(_small_button("Reject", _do.bind("review", [uid, false], "Request rejected.")))
		_body.add_child(panel)


# ---------------------------------------------------------
# SECT TRIAL
# ---------------------------------------------------------

func _build_trial() -> void:
	var st: Dictionary = await SectTrial.state()
	var ranking: Array = await SectTrial.ranking(str(_sect.get("id", "")))
	if _tab != "Trial":
		return
	_clear()
	if st.is_empty():
		_note("Couldn't load the Sect Trial. Try again in a moment.")
		_retry_button()
		return
	var stage := int(st["stage"])
	var g: Array = SectTrial.guardian(stage)
	var color := Color(str(g[2]))

	# The guardian
	var card := _panel(color, 0.07)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	var art := TextureRect.new()
	art.texture = SectTrial.guardian_art(stage)
	art.custom_minimum_size = Vector2(220, 260)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(art)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	v.add_child(_label("Trial Stage %d" % stage, 30, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_label(str(g[1]), 22, color.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT))
	var hp_left := int(st["hp_left"])
	var hp_max := int(st["hp_max"])
	v.add_child(_label("Guardian Might  %s / %s" % [NumberFormat.short(hp_left), NumberFormat.short(hp_max)], 17,
		COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_bar(float(hp_left) / float(maxi(hp_max, 1)), Color("ff5a4a")))
	var used := int(st["attacks_used"])
	var left := maxi(0, SectTrial.ATTACKS_PER_DAY - used)
	v.add_child(_label("Your attacks today: %d / %d  ·  Your Might this week: %s" % [left,
		SectTrial.ATTACKS_PER_DAY, NumberFormat.short(int(st["my_might"]))], 16, COL_OK, HORIZONTAL_ALIGNMENT_LEFT))
	var attack := OrnateButton.new()
	attack.text = "Attack" if left > 0 else "No Attacks Left"
	attack.custom_minimum_size = Vector2(260, 60)
	attack.disabled = left <= 0
	attack.pressed.connect(_on_trial_attack.bind(stage))
	v.add_child(attack)
	_body.add_child(card)
	_body.add_child(_label("Each attack is a %d-round fight. Your damage is measured against your own progress, "
		% SectTrial.ROUNDS + "so every member helps equally. Progress never resets: the sect keeps climbing.",
		15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	# Rewards
	var cleared := int(st["cleared"])
	var claimed := int(st["claimed"])
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 10)
	var next := stage
	var next_items := SectTrial.stage_rewards(next)
	var parts := PackedStringArray(["%d Contribution" % SectTrial.stage_contribution(next)])
	for id in next_items:
		parts.append("%s ×%d" % [str(ItemDB.get_item(str(id)).get("name", id)), int(next_items[id])])
	var rl := _label("Clearing stage %d gives every member: %s" % [next, ", ".join(parts)], 16, COL_GOLD,
		HORIZONTAL_ALIGNMENT_LEFT)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_row.add_child(rl)
	if cleared > claimed:
		var claim := OrnateButton.new()
		claim.text = "Claim %d Stage%s" % [cleared - claimed, "" if cleared - claimed == 1 else "s"]
		claim.custom_minimum_size = Vector2(240, 56)
		claim.pressed.connect(_do.bind("trial_claim", [], "Stage rewards claimed!"))
		reward_row.add_child(claim)
	_body.add_child(reward_row)

	# This week's ranking
	_body.add_child(_label("This Week's Might", 22, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT, true))
	if ranking.is_empty():
		_body.add_child(_label("No attacks yet this week.", 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for i in ranking.size():
		var row: Dictionary = ranking[i]
		var prof: Dictionary = row.get("profiles", {}) if row.get("profiles") is Dictionary else {}
		var me := str(row.get("user_id", "")) == Backend.user_id
		var line := HBoxContainer.new()
		var who := _label("#%d  %s" % [i + 1, str(prof.get("display_name", "Cultivator"))], 18,
			COL_OK if me else (COL_GOLD if i < 3 else COL_TEXT), HORIZONTAL_ALIGNMENT_LEFT)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(who)
		line.add_child(_label(NumberFormat.short(int(row.get("might", 0))), 18, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		_body.add_child(line)


func _on_trial_attack(stage: int) -> void:
	var error := SectTrial.challenge(self, stage)
	if error != "":
		_toast(error, COL_BAD)


# ---------------------------------------------------------
# RESEARCH
# ---------------------------------------------------------

func _build_research() -> void:
	var funds := int(_sect.get("funds", 0))
	var level := int(_sect.get("level", 1))
	_body.add_child(_label("Research benefits every member of the sect. Treasury: %s funds" % NumberFormat.short(funds),
		18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	if not _is_officer():
		_body.add_child(_label("Only the Sect Master and Elders can start research.", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for node in Sects.RESEARCH:
		var def: Array = Sects.RESEARCH[node]
		var lv := int(_research.get(node, 0))
		var panel := _panel(COL_GOLD, 0.05)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)
		var icon_path := RESEARCH_ICON % node
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path) as Texture2D
			icon.custom_minimum_size = Vector2(80, 80)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.add_child(icon)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var label := str(Codex.STAT_LABELS.get(str(def[1]), def[1]))
		v.add_child(_label("%s   Lv %d / %d" % [def[0], lv, Sects.RESEARCH_MAX], 21, COL_TITLE, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(_label("+%s%% %s for every partner (next level +%s%%)" % [
			str(snappedf(float(def[2]) * lv, 0.1)).trim_suffix(".0"), label,
			str(snappedf(float(def[2]), 0.1)).trim_suffix(".0")], 16, COL_OK, HORIZONTAL_ALIGNMENT_LEFT))
		if lv < Sects.RESEARCH_MAX:
			var cost := Sects.research_cost(node, lv)
			var why := ""
			if lv >= level:
				why = "  ·  needs sect Lv %d" % (lv + 1)
			v.add_child(_label("Next level: %s funds%s" % [NumberFormat.short(cost), why], 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
			if _is_officer():
				var b := _small_button("Research", _do.bind("upgrade", [node], "Research complete!"))
				b.disabled = funds < cost or lv >= level
				h.add_child(b)
		_body.add_child(panel)


# ---------------------------------------------------------
# SHOP
# ---------------------------------------------------------

func _build_shop() -> void:
	var items: Array = await Sects.shop_state()
	if _tab != "Shop":
		return
	_clear()
	_body.add_child(_label("Your Contribution: %s  ·  limits reset every Monday (UTC)" % NumberFormat.short(_my_balance()),
		19, COL_OK, HORIZONTAL_ALIGNMENT_LEFT))
	if items.is_empty():
		_note("Couldn't load the shop. Try again in a moment.")
		return
	for entry in items:
		var id := str(entry["item_id"])
		var bought := int(entry["bought"])
		var limit := int(entry["weekly_limit"])
		var cost := int(entry["cost"])
		var panel := _panel(Color("6a8ab8"), 0.05)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)
		var icon := ItemSlot.new()
		icon.custom_minimum_size = Vector2(80, 80)
		icon.setup_item(id, int(entry["amount"]))
		icon.pressed.connect(func(): ItemInfoPopup.open(self, id))
		h.add_child(icon)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label("%s  ×%d" % [str(ItemDB.get_item(id).get("name", id)), int(entry["amount"])], 20, COL_TEXT,
			HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(_label("%s Contribution  ·  %d / %d this week" % [NumberFormat.short(cost), bought, limit], 16,
			COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		var b := _small_button("Buy", _do.bind("buy", [id], "Purchased!"))
		b.disabled = bought >= limit or _my_balance() < cost
		h.add_child(b)
		_body.add_child(panel)


# ---------------------------------------------------------
# ACTION HELPERS
# ---------------------------------------------------------

## Runs a Sects action by name with a busy guard; shows the server's
## error if it fails.
func _run(op: String, a: Array) -> Dictionary:
	if _busy:
		return {"ok": false, "data": null, "error": ""}
	_busy = true
	var r: Dictionary = {}
	match op:
		"join":
			r = await Sects.join(str(a[0]))
		"cancel_request":
			r = await Sects.cancel_request(str(a[0]))
		"create":
			r = await Sects.create(str(a[0]), str(a[1]), str(a[2]), int(a[3]))
		"update":
			r = await Sects.update(str(a[0]), str(a[1]), int(a[2]))
		"leave":
			r = await Sects.leave()
		"kick":
			r = await Sects.kick(str(a[0]))
		"set_role":
			r = await Sects.set_role(str(a[0]), str(a[1]))
		"review":
			r = await Sects.review(str(a[0]), bool(a[1]))
		"signin":
			r = await Sects.signin()
		"donate":
			r = await Sects.donate(int(a[0]))
		"buy":
			r = await Sects.buy(str(a[0]))
		"upgrade":
			r = await Sects.upgrade(str(a[0]))
		"trial_claim":
			var c := await SectTrial.claim()
			r = {"ok": c["ok"], "data": c, "error": str(c.get("error", ""))}
		_:
			r = {"ok": false, "data": null, "error": "Unknown action"}
	_busy = false
	if not r["ok"] and str(r["error"]) != "":
		_toast(str(r["error"]), COL_BAD)
	return r


## An action that just needs a message and a refresh on success.
func _do(op: String, a: Array, success: String) -> void:
	var r: Dictionary = await _run(op, a)
	if r["ok"]:
		_toast(success, COL_OK)
		refresh(true)


func _confirm(question: String, on_yes: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(COL_GOLD, 0.0)
	panel.custom_minimum_size.x = 640
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var q := _label(question, 22, COL_TEXT)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(q)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var no := OrnateButton.new()
	no.text = "Cancel"
	no.variant = OrnateButton.Variant.DARK
	no.custom_minimum_size = Vector2(200, 56)
	no.pressed.connect(layer.queue_free)
	row.add_child(no)
	var yes := OrnateButton.new()
	yes.text = "Confirm"
	yes.custom_minimum_size = Vector2(200, 56)
	yes.pressed.connect(_confirm_yes.bind(layer, on_yes))
	row.add_child(yes)


func _confirm_yes(layer: CanvasLayer, on_yes: Callable) -> void:
	layer.queue_free()
	on_yes.call()


# ---------------------------------------------------------
# UI HELPERS
# ---------------------------------------------------------

func _set_tabs(tabs: Array) -> void:
	for c in _tabs_row.get_children():
		c.queue_free()
	for t in tabs:
		var b := OrnateButton.new()
		b.text = str(t)
		b.custom_minimum_size = Vector2(160, 52)
		b.add_theme_font_size_override("font_size", 18)
		b.variant = OrnateButton.Variant.GOLD if str(t).split(" ")[0] == _tab else OrnateButton.Variant.DARK
		b.pressed.connect(func(): _show_tab(str(t)))
		_tabs_row.add_child(b)


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _note(text_value: String) -> void:
	var l := _label(text_value, 20, COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)


func _retry_button() -> void:
	var b := OrnateButton.new()
	b.text = "Try Again"
	b.custom_minimum_size = Vector2(220, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(refresh)
	_body.add_child(b)


func _small_button(text_value: String, on_press: Callable) -> OrnateButton:
	var b := OrnateButton.new()
	b.text = text_value
	b.variant = OrnateButton.Variant.DARK
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	return b


func _bar(fill: float, color: Color) -> Control:
	var f := clampf(fill, 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 2, bar.size.x, 10), Color(0, 0, 0, 0.5))
		bar.draw_rect(Rect2(0, 2, bar.size.x * f, 10), color)
	)
	return bar


func _panel(color: Color, fill: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, fill) if fill > 0.0 else Color("0b1629")
	sb.border_color = Color(color, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _line_edit(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 56)
	e.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.9)
	sb.border_color = Color(COL_GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	return e


func _option(items: Array) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(str(items[i]), i)
	o.custom_minimum_size = Vector2(320, 50)
	o.add_theme_font_size_override("font_size", 18)
	return o


## "Any" plus the first level of each realm; the item id is the realm index.
func _realm_option(selected_realm: int) -> OptionButton:
	var o := OptionButton.new()
	o.add_item("Any realm", 0)
	for i in range(1, Realms.count()):
		o.add_item(str(Realms.get_label(i, 1)), i)
	o.custom_minimum_size = Vector2(320, 50)
	o.add_theme_font_size_override("font_size", 18)
	var idx := o.get_item_index(selected_realm)
	o.selected = idx if idx >= 0 else 0
	return o


func _labelled(title: String, control: Control) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := _label(title, 18, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size.x = 200
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(control)
	return h


func _toast(message: String, color: Color) -> void:
	var l := _label(message, 24, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.top_level = true
	add_child(l)
	var r := get_global_rect()
	l.size = Vector2(r.size.x, 40)
	l.global_position = Vector2(r.position.x, r.position.y + r.size.y * 0.45)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 50.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(1.1)
	tw.tween_callback(l.queue_free)


func _draw_backdrop() -> void:
	var s := size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([COL_BG_TOP, COL_BG_TOP, COL_BG_BOTTOM, COL_BG_BOTTOM]))
	draw_rect(Rect2(Vector2.ONE, s - Vector2(2, 2)), Color(COL_GOLD, 0.4), false, 2.0)


func _label(value: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, glow := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	# Long text wraps, so no single line can make the screen wider
	# than the phone (short labels like names and numbers stay on one line)
	if value.length() > 34:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 1
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(COL_GOLD, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
