class_name AccountPopup
extends CanvasLayer

# =========================================================
# Accounts: welcome screen, log in, link a guest account, forgot
# password, and choosing between the cloud save and this device.
# Save as res://ui/account_popup.gd
#
#   AccountPopup.open_welcome(host)   first launch (Backend does this)
#   AccountPopup.open_account(host)   from Settings
#
# Email verification and password reset use a 6-digit code sent
# by email (the Supabase email templates must include {{ .Token }}).
# =========================================================

## Above everything, including character creation: players logging in
## to an existing account must never have to create a new character first.
const LAYER := 120
## Title screen art (optional): your logo and a full-screen background
const LOGO := "res://assets/ui/title/logo.png"
const TITLE_BG := "res://assets/ui/title/title_bg.png"

const COL_PANEL := Color("0b1629")
const COL_GOLD := Color("e2c27a")
const COL_TITLE := Color("f2d98a")
const COL_TEXT := Color("c9d4e3")
const COL_DIM := Color("7f8ea3")
const COL_OK := Color("7dffa8")
const COL_BAD := Color("ff7a7a")

var _mode := "welcome"
var _body: VBoxContainer
var _msg: Label
var _busy := false
## Remembered between steps (link / reset flows)
var _email := ""
var _bg: TextureRect
var _panel: PanelContainer
## The title-screen layout (welcome only): art, logo at the top, buttons
## at the bottom. The other account screens use the panel.
var _title_root: Control
## Black curtain for dip transitions
var _fader: ColorRect


static func open_welcome(host: Node) -> AccountPopup:
	return _open(host, "welcome")


static func open_account(host: Node) -> AccountPopup:
	return _open(host, "account")


static func _open(host: Node, mode: String) -> AccountPopup:
	var p := AccountPopup.new()
	p._mode = mode
	host.get_tree().root.add_child.call_deferred(p)
	return p


func _ready() -> void:
	layer = LAYER
	# Keep working while the game is paused (character creation pauses it)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Title background (welcome screen only)
	if ResourceLoader.exists(TITLE_BG):
		_bg = TextureRect.new()
		_bg.texture = load(TITLE_BG) as Texture2D
		_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)
	_panel = panel

	_title_root = Control.new()
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_root)
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	v.add_child(_body)
	_msg = _label("", 18, COL_BAD)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fader)
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_show(_mode)


## Dips to black, runs `then` (e.g. switching screens), then fades back.
func _dip(then: Callable) -> void:
	_fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var down := create_tween()
	down.tween_property(_fader, "color:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	await down.finished
	then.call()
	await get_tree().process_frame
	var up := create_tween()
	up.tween_property(_fader, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	await up.finished
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show(mode: String) -> void:
	_mode = mode
	_msg.text = ""
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	# The title art and layout show only on the welcome screen
	var welcome := mode == "welcome"
	if _bg != null:
		_bg.visible = welcome
	if _panel != null:
		_panel.visible = not welcome
	if _title_root != null:
		_title_root.visible = welcome
		for c in _title_root.get_children():
			c.queue_free()
	match mode:
		"welcome":
			_build_welcome()
		"account":
			_build_account()
		"login":
			_build_login()
		"link_email":
			_build_link_email()
		"link_code":
			_build_code("Check your email", "We sent a 6-digit code to %s." % _email, _on_link_code)
		"link_password":
			_build_new_password("Choose a password", "Last step: this is how you'll log in on other devices.")
		"reset_email":
			_build_reset_email()
		"reset_code":
			_build_code("Reset your password", "We sent a 6-digit code to %s." % _email, _on_reset_code)
		"reset_password":
			_build_new_password("New password", "Choose a new password for %s." % _email)
		"delete":
			_build_delete()


# ---------------------------------------------------------
# SCREENS
# ---------------------------------------------------------

func _build_welcome() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Your logo, large at the top, floating gently
	var logo_tex: Texture2D = load(LOGO) as Texture2D if ResourceLoader.exists(LOGO) else null
	if logo_tex != null:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := minf(vp.x * 0.72, vp.y * 0.36)
		logo.size = Vector2(side, side)
		logo.position = Vector2((vp.x - side) * 0.5, vp.y * 0.07)
		logo.pivot_offset = logo.size * 0.5
		if _has_dark_background(logo_tex):
			# A logo on a solid black background: a glow blend makes the
			# black disappear and keeps the bright parts
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			logo.material = add
		_title_root.add_child(logo)
		logo.modulate.a = 0.0
		var t := logo.create_tween()
		t.tween_property(logo, "modulate:a", 1.0, 0.9)
		var drift := logo.create_tween().set_loops()
		drift.tween_property(logo, "position:y", logo.position.y - 10.0, 2.2).set_trans(Tween.TRANS_SINE)
		drift.tween_property(logo, "position:y", logo.position.y, 2.2).set_trans(Tween.TRANS_SINE)
	else:
		var title := _outlined("Immortal Cultivation", 56, COL_TITLE)
		title.size = Vector2(vp.x, 80)
		title.position = Vector2(0, vp.y * 0.16)
		_title_root.add_child(title)

	# Soft dark fade along the bottom, under the buttons
	var shade := Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.draw.connect(func():
		var h := shade.size.y
		var w := shade.size.x
		var top := h * 0.52
		shade.draw_polygon(
			PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.01, 0.02, 0.05, 0.85), Color(0.01, 0.02, 0.05, 0.85)]))
	)

	# Buttons at the bottom
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_END
	var bw := minf(vp.x * 0.78, 760.0)
	box.size = Vector2(bw, vp.y * 0.4)
	box.position = Vector2((vp.x - bw) * 0.5, vp.y * 0.56)
	_title_root.add_child(box)
	box.add_child(_outlined("Welcome, cultivator.", 30, COL_TITLE))
	var guest := _button("Start as Guest", OrnateButton.Variant.GOLD, _on_guest)
	guest.custom_minimum_size = Vector2(0, 84)
	box.add_child(guest)
	box.add_child(_outlined("Play right away. Link an account later in Settings.", 19, COL_TEXT))
	var login := _button("Log In", OrnateButton.Variant.DARK, _dip.bind(_show.bind("login")))
	login.custom_minimum_size = Vector2(0, 76)
	box.add_child(login)
	box.add_child(_outlined("Already have an account? Continue your journey here.", 19, COL_TEXT))
	var gap := Control.new()
	gap.custom_minimum_size.y = vp.y * 0.03
	box.add_child(gap)
	box.add_child(_outlined(Settings.VERSION, 15, COL_DIM))
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.6).set_delay(0.3)


## True if the image's corners are solid and dark (a logo on black).
func _has_dark_background(tex: Texture2D) -> bool:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return false
	if img.is_compressed():
		img.decompress()
	var w := img.get_width() - 1
	var h := img.get_height() - 1
	for p in [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]:
		var c := img.get_pixelv(p)
		if c.a < 0.9 or c.get_luminance() > 0.15:
			return false
	return true


## Text with a dark outline, readable over any art.
func _outlined(value: String, font_size: int, color: Color) -> Label:
	var l := _label(value, font_size, color, false, true)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	return l


func _build_account() -> void:
	_body.add_child(_label("Login & Cloud Save", 34, COL_TITLE, true))
	if not Backend.is_configured():
		_body.add_child(_label("The online server isn't set up in this build.", 18, COL_DIM))
		_body.add_child(_button("Close", OrnateButton.Variant.DARK, queue_free))
		return
	if Backend.is_guest:
		_body.add_child(_label("You're playing as a Guest.", 22, COL_TEXT))
		_body.add_child(_label("Your progress is only on this device. If you uninstall the game or change phones, "
			+ "it's lost. Link an account to keep it safe: nothing will change in your game.", 17, COL_BAD, false, true))
		_body.add_child(_button("Link Account", OrnateButton.Variant.GOLD, _show.bind("link_email")))
		_body.add_child(_button("Log In to Another Account", OrnateButton.Variant.DARK, _show.bind("login")))
	else:
		_body.add_child(_label("Linked to %s" % Backend.email, 22, COL_OK))
		_body.add_child(_label("Your progress is saved to the cloud. Log in with this email on any device to continue.",
			17, COL_DIM, false, true))
		_body.add_child(_button("Log Out", OrnateButton.Variant.DARK, _on_log_out))
	_body.add_child(_button("Delete Account", OrnateButton.Variant.CRIMSON, _show.bind("delete")))
	_body.add_child(_button("Close", OrnateButton.Variant.DARK, queue_free))


func _build_delete() -> void:
	_body.add_child(_label("Delete Account", 34, COL_BAD, true))
	_body.add_child(_label("This permanently deletes your account, your cloud save and all your progress on our "
		+ "servers, and removes you from your sect. It can't be undone.", 18, COL_TEXT, false, true))
	_body.add_child(_label("Type DELETE to confirm.", 18, COL_DIM))
	var confirm := _text_field("DELETE", false)
	_body.add_child(confirm)
	_body.add_child(_button("Delete My Account Forever", OrnateButton.Variant.CRIMSON, _on_delete.bind(confirm)))
	_body.add_child(_button("Cancel", OrnateButton.Variant.DARK, _show.bind("account")))


func _on_delete(confirm: LineEdit) -> void:
	if confirm.text.strip_edges().to_upper() != "DELETE":
		_fail("Type DELETE to confirm.")
		return
	if not _start():
		return
	var error: String = await Backend.delete_account()
	_busy = false
	if error != "":
		_fail(error)
		return
	# Wipe this device's progress too, then close the game
	GameState.reset_account()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_msg.text = ""
	_body.add_child(_label("Your account has been deleted.", 24, COL_OK, false, true))
	_body.add_child(_label("Thank you for walking the path with us. The game will now close.", 18, COL_TEXT, false, true))
	_body.add_child(_button("Close Game", OrnateButton.Variant.DARK, func(): get_tree().quit()))


func _build_login() -> void:
	_body.add_child(_label("Log In", 34, COL_TITLE, true))
	if Backend.is_guest and Backend.user_id != "":
		_body.add_child(_label("Your current guest account isn't linked. After logging in you'll choose which "
			+ "save to keep, but the guest account itself can't be reached again.", 16, COL_BAD, false, true))
	var mail := _text_field("Email", false)
	_body.add_child(mail)
	var pw := _text_field("Password", true)
	_body.add_child(pw)
	_body.add_child(_button("Log In", OrnateButton.Variant.GOLD, _on_log_in.bind(mail, pw)))
	_body.add_child(_button("Forgot password?", OrnateButton.Variant.DARK, _show.bind("reset_email")))
	_body.add_child(_button("Back", OrnateButton.Variant.DARK, _back))


func _build_link_email() -> void:
	_body.add_child(_label("Link Account", 34, COL_TITLE, true))
	_body.add_child(_label("Enter your email. We'll send a 6-digit code to confirm it.", 18, COL_TEXT, false, true))
	var mail := _text_field("Email", false)
	_body.add_child(mail)
	_body.add_child(_button("Send Code", OrnateButton.Variant.GOLD, _on_link_email.bind(mail)))
	_body.add_child(_button("Back", OrnateButton.Variant.DARK, _show.bind("account")))


func _build_reset_email() -> void:
	_body.add_child(_label("Forgot Password", 34, COL_TITLE, true))
	_body.add_child(_label("Enter your account's email. We'll send a 6-digit code.", 18, COL_TEXT, false, true))
	var mail := _text_field("Email", false)
	_body.add_child(mail)
	_body.add_child(_button("Send Code", OrnateButton.Variant.GOLD, _on_reset_email.bind(mail)))
	_body.add_child(_button("Back", OrnateButton.Variant.DARK, _show.bind("login")))


func _build_code(title: String, info: String, on_submit: Callable) -> void:
	_body.add_child(_label(title, 34, COL_TITLE, true))
	_body.add_child(_label(info + " It can take a minute. Check your spam folder too.", 17, COL_TEXT, false, true))
	var code := _text_field("6-digit code", false)
	code.max_length = 10
	_body.add_child(code)
	_body.add_child(_button("Confirm", OrnateButton.Variant.GOLD, on_submit.bind(code)))
	_body.add_child(_button("Back", OrnateButton.Variant.DARK, _back))


func _build_new_password(title: String, info: String) -> void:
	_body.add_child(_label(title, 34, COL_TITLE, true))
	_body.add_child(_label(info, 17, COL_TEXT, false, true))
	var pw := _text_field("Password (at least 8 characters)", true)
	_body.add_child(pw)
	var pw2 := _text_field("Repeat password", true)
	_body.add_child(pw2)
	_body.add_child(_button("Save Password", OrnateButton.Variant.GOLD, _on_password.bind(pw, pw2)))


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

func _on_guest() -> void:
	if _busy:
		return
	_busy = true
	# The Backend signs the guest in on its own; the title screen dips
	# to black and fades away to reveal character creation
	Backend.start_guest()
	_fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var down := create_tween()
	down.tween_property(_fader, "color:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	await down.finished
	for c in get_children():
		if c != _fader:
			(c as CanvasItem).visible = false
	var up := create_tween()
	up.tween_property(_fader, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	await up.finished
	queue_free()


func _on_log_in(mail: LineEdit, pw: LineEdit) -> void:
	if not _start():
		return
	var error: String = await Backend.log_in(mail.text, pw.text)
	_busy = false
	if error != "":
		_fail(error)
		return
	await _choose_save()


func _on_link_email(mail: LineEdit) -> void:
	if not _start():
		return
	_email = mail.text.strip_edges()
	var error: String = await Backend.link_email(_email)
	_busy = false
	if error != "":
		_fail(error)
		return
	_show("link_code")


func _on_link_code(code: LineEdit) -> void:
	if not _start():
		return
	var error: String = await Backend.verify_email_code(_email, code.text)
	_busy = false
	if error != "":
		_fail(error)
		return
	_show("link_password")


func _on_reset_email(mail: LineEdit) -> void:
	if not _start():
		return
	_email = mail.text.strip_edges()
	var error: String = await Backend.request_password_reset(_email)
	_busy = false
	if error != "":
		_fail(error)
		return
	_show("reset_code")


func _on_reset_code(code: LineEdit) -> void:
	if not _start():
		return
	var error: String = await Backend.verify_recovery(_email, code.text)
	_busy = false
	if error != "":
		_fail(error)
		return
	_show("reset_password")


func _on_password(pw: LineEdit, pw2: LineEdit) -> void:
	if pw.text != pw2.text:
		_fail("The passwords don't match.")
		return
	if not _start():
		return
	var error: String = await Backend.set_password(pw.text)
	_busy = false
	if error != "":
		_fail(error)
		return
	if _mode == "reset_password":
		await _choose_save()
		return
	# Linked: same account, nothing changes in the game
	Backend.upload_now()
	_done("Account linked! Your progress is now safe in the cloud.")


func _on_log_out() -> void:
	if not _start():
		return
	await Backend.upload_now()
	await Backend.log_out()
	_busy = false
	_show("welcome")


## After logging in: keep the cloud save or this device's progress.
func _choose_save() -> void:
	var info: Dictionary = await Backend.cloud_save_info()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_msg.text = ""
	var local_stage := int(GameState.highest_stage)
	if not bool(info.get("exists", false)):
		# New account with no cloud save yet: this device's progress becomes it
		await Backend.upload_now()
		_done("Logged in! Your progress on this device is now saved to this account.")
		return
	if local_stage <= 1:
		# Nothing to lose on this device: take the cloud save
		await _use_cloud()
		return
	_body.add_child(_label("Which progress do you want?", 30, COL_TITLE, true))
	_body.add_child(_label("Cloud save: %s, stage %d" % [str(info.get("name", "")), int(info.get("stage", 0))],
		20, COL_OK))
	_body.add_child(_label("This device: %s, stage %d" % [str(GameState.mc_name), local_stage], 20, COL_TEXT))
	_body.add_child(_button("Use Cloud Save", OrnateButton.Variant.GOLD, _use_cloud))
	_body.add_child(_button("Keep This Device's Progress", OrnateButton.Variant.DARK, _keep_local))
	_body.add_child(_label("The one you don't pick is replaced.", 16, COL_DIM))


func _use_cloud() -> void:
	var error: String = await Backend.restore_cloud_save()
	if error != "":
		_fail(error)
		return
	# Load the downloaded save and rebuild the game around it
	GameState.load_game()
	queue_free()
	# Character creation may have paused the game; the loaded save
	# already has an MC, so it won't be there to unpause it
	get_tree().paused = false
	get_tree().reload_current_scene()


func _keep_local() -> void:
	await Backend.upload_now()
	_done("Done. This device's progress is now saved to your account.")


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

func _back() -> void:
	if _mode in ["login", "link_email"] and Backend.user_id == "":
		_dip(_show.bind("welcome"))
	elif _mode == "login" or _mode == "link_email":
		_show("account" if Backend.user_id != "" else "welcome")
	elif _mode == "reset_code" or _mode == "reset_email":
		_show("login")
	else:
		_show("account")


func _start() -> bool:
	if _busy:
		return false
	_busy = true
	_msg.add_theme_color_override("font_color", COL_DIM)
	_msg.text = "Please wait..."
	return true


func _fail(error: String) -> void:
	_msg.add_theme_color_override("font_color", COL_BAD)
	_msg.text = error


func _done(message: String) -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_msg.text = ""
	_body.add_child(_label(message, 22, COL_OK, false, true))
	_body.add_child(_button("Continue", OrnateButton.Variant.GOLD, queue_free))


func _button(text_value: String, variant: OrnateButton.Variant, on_press: Callable) -> OrnateButton:
	var b := OrnateButton.new()
	b.text = text_value
	b.variant = variant
	b.custom_minimum_size = Vector2(0, 64)
	b.pressed.connect(on_press)
	return b


func _text_field(placeholder: String, secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 62)
	e.add_theme_font_size_override("font_size", 22)
	if not secret:
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS if placeholder == "Email" \
			else LineEdit.KEYBOARD_TYPE_DEFAULT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.95)
	sb.border_color = Color(COL_GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	return e


func _label(value: String, font_size: int, color: Color, glow := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if glow:
		l.add_theme_color_override("font_shadow_color", Color(COL_GOLD, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
	return l
