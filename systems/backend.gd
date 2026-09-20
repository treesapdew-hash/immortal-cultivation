extends Node

# =========================================================
# Backend: Supabase connection. Save as res://systems/backend.gd
# and add it as an AUTOLOAD named "Backend"
# (Project > Project Settings > Globals > Autoload).
#
# Fill in SUPABASE_URL and SUPABASE_KEY below (Supabase dashboard >
# Project Settings > API: the Project URL and the publishable /
# anon key; NEVER the secret / service_role key).
#
# What it does:
#   - signs the player in automatically (anonymous account, no
#     email needed), and keeps them signed in between launches
#   - rest() / call_fn(): talk to the database (used by Sects)
#   - cloud save: uploads the save at most every UPLOAD_EVERY
#     seconds after a change, and when the app goes to the
#     background or closes; restore_cloud_save() brings it back
#
# If the URL / key are empty or there's no internet, the game
# simply runs offline as before.
# =========================================================

const SUPABASE_URL := "https://wjyrvzkzwjkfvgiodllt.supabase.co"   # e.g. "https://abcdefgh.supabase.co"
const SUPABASE_KEY := "sb_publishable_DKzQktO7RbOAXvwyfYm8AQ_-S2y1mV4"   # publishable (anon) key

const SESSION_PATH := "user://backend_session.json"
const UPLOAD_EVERY := 60.0
const TIMEOUT := 12.0

signal signed_in(user_id: String)
signal cloud_saved
## First launch: no account yet; the welcome screen asks Guest / Log In.
signal needs_account

## Account type: guests are anonymous until they link an email.
var is_guest := true
var email := ""

var user_id := ""
var online := false

var _access_token := ""
var _refresh_token := ""
var _expires_at := 0
var _signing_in := false
var _upload_pending := false
var _uploading := false
var _last_upload := -9999.0


func is_configured() -> bool:
	return SUPABASE_URL != "" and SUPABASE_KEY != ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_configured():
		print("Backend: no Supabase URL/key set, running offline")
		return
	_load_session()
	if _refresh_token == "":
		# First launch: let the player choose Guest or Log In
		print("Backend: no login on this device, showing the welcome screen")
		needs_account.emit()
		AccountPopup.open_welcome(self)
		return
	print("Backend: already logged in on this device (%s), no welcome screen" % ("guest" if is_guest else email))
	if await ensure_session():
		print("Backend: signed in as %s" % user_id)
		# Titles the server awarded while they were away, before the
		# profile goes up, so a new one is worn-able straight away.
		await Showcase.pull_titles()
		await update_profile()
		note_saved()
		# Sect Research bonus for the team
		Sects.refresh_bonus()


func _process(_delta: float) -> void:
	if _upload_pending and not _uploading and online \
			and Time.get_ticks_msec() / 1000.0 - _last_upload >= UPLOAD_EVERY:
		upload_save()


func _notification(what: int) -> void:
	# Going to the background / closing: push the latest save now
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if online and _upload_pending:
			upload_save()


# ---------------------------------------------------------
# SESSION
# ---------------------------------------------------------

## Makes sure we have a valid sign-in. Returns true when online.
func ensure_session() -> bool:
	if not is_configured():
		return false
	var now := int(Time.get_unix_time_from_system())
	if _access_token != "" and now < _expires_at - 60:
		online = true
		return true
	# Another call is already signing in: wait for it
	while _signing_in:
		await get_tree().process_frame
	if _access_token != "" and now < _expires_at - 60:
		return true
	_signing_in = true
	var ok := false
	if _refresh_token != "":
		var r := await _auth("token?grant_type=refresh_token", {"refresh_token": _refresh_token})
		ok = r["ok"]
		if ok:
			_set_session(r["data"])
	if not ok and not is_guest:
		# A linked account's login expired: don't silently replace it
		_signing_in = false
		online = false
		push_warning("Backend: your login expired, please log in again")
		return false
	if not ok:
		# First launch (or the refresh token expired): new anonymous account
		var r2 := await _auth("signup", {"data": {}})
		ok = r2["ok"]
		if ok:
			_set_session(r2["data"])
		else:
			push_warning("Backend: sign-in failed (%s)" % str(r2.get("error", "")))
	_signing_in = false
	online = ok
	return ok


func _set_session(d: Dictionary) -> void:
	_access_token = str(d.get("access_token", ""))
	_refresh_token = str(d.get("refresh_token", _refresh_token))
	_expires_at = int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600))
	var user: Dictionary = d.get("user", {}) if d.get("user") is Dictionary else {}
	if user.has("id"):
		user_id = str(user["id"])
		_read_user(user)
	_save_session()
	online = true
	signed_in.emit(user_id)


func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"user_id": user_id, "refresh_token": _refresh_token,
		"is_guest": is_guest, "email": email}))


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		user_id = str(parsed.get("user_id", ""))
		_refresh_token = str(parsed.get("refresh_token", ""))
		is_guest = bool(parsed.get("is_guest", true))
		email = str(parsed.get("email", ""))


# ---------------------------------------------------------
# REQUESTS
# ---------------------------------------------------------

func _auth(path: String, body: Dictionary) -> Dictionary:
	var headers := PackedStringArray(["apikey: " + SUPABASE_KEY, "Content-Type: application/json"])
	return await _http(HTTPClient.METHOD_POST, SUPABASE_URL + "/auth/v1/" + path, headers, body)


## A database request (PostgREST). path like "saves?user_id=eq.<id>".
## Returns {ok, code, data, error}.
func rest(method: int, path: String, body: Variant = null, extra_headers: Array = []) -> Dictionary:
	if not await ensure_session():
		return {"ok": false, "code": 0, "data": null, "error": "offline"}
	var result := await _http(method, SUPABASE_URL + "/rest/v1/" + path, _rest_headers(extra_headers), body)
	if int(result["code"]) == 401:
		# Token expired early: refresh once and retry
		_access_token = ""
		if await ensure_session():
			result = await _http(method, SUPABASE_URL + "/rest/v1/" + path, _rest_headers(extra_headers), body)
	return result


## Calls a database function (the Sect actions use these).
func call_fn(fn: String, args: Dictionary = {}) -> Dictionary:
	return await rest(HTTPClient.METHOD_POST, "rpc/" + fn, args)


func _rest_headers(extra: Array) -> PackedStringArray:
	var h := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + _access_token,
		"Content-Type: application/json",
	])
	for e in extra:
		h.append(str(e))
	return h


func _http(method: int, url: String, headers: PackedStringArray, body: Variant) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	var payload := "" if body == null else JSON.stringify(body)
	var err := req.request(url, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "request failed (%d)" % err}
	var res: Array = await req.request_completed
	req.queue_free()
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	var ok := int(res[0]) == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	var error := ""
	if not ok:
		error = text if text != "" else "network error (%d)" % int(res[0])
	return {"ok": ok, "code": code, "data": data, "error": error}


# ---------------------------------------------------------
# PROFILE AND CLOUD SAVE
# ---------------------------------------------------------

## Keeps this player's public profile (name, realm, stage, power and
## the showcase others inspect) up to date.
func update_profile() -> void:
	if not online or user_id == "":
		return
	var mc := GameState.get_mc()
	var row := {
		"id": user_id,
		"display_name": str(GameState.mc_name),
		"realm": mc.realm_index if mc != null else 0,
		"highest_stage": int(GameState.highest_stage),
		"power": int(GameState.get_team_power()),
		"showcase": Showcase.build(),
		"title": str(GameState.title_worn),
		"updated_at": Time.get_datetime_string_from_system(true) + "Z",
	}
	await rest(HTTPClient.METHOD_POST, "profiles?on_conflict=id", row,
		["Prefer: resolution=merge-duplicates,return=minimal"])


## GameState calls this after every save; the upload is batched.
func note_saved() -> void:
	_upload_pending = true


func upload_save() -> void:
	if _uploading or not online or user_id == "":
		return
	_uploading = true
	_upload_pending = false
	_last_upload = Time.get_ticks_msec() / 1000.0
	var row := {
		"user_id": user_id,
		"data": GameState.to_dict(),
		"version": int(GameState.SAVE_VERSION),
		"updated_at": Time.get_datetime_string_from_system(true) + "Z",
	}
	var r := await rest(HTTPClient.METHOD_POST, "saves?on_conflict=user_id", row,
		["Prefer: resolution=merge-duplicates,return=minimal"])
	_uploading = false
	if r["ok"]:
		cloud_saved.emit()
		update_profile()
	else:
		_upload_pending = true
		push_warning("Backend: cloud save failed (%s)" % str(r["error"]))


## Downloads the cloud save over the local one. Restart the game after.
## Returns "" on success, otherwise why not.
func restore_cloud_save() -> String:
	if not await ensure_session():
		return "Can't reach the server."
	var r := await rest(HTTPClient.METHOD_GET, "saves?select=data&user_id=eq." + user_id)
	if not r["ok"] or not (r["data"] is Array) or (r["data"] as Array).is_empty():
		return "No cloud save found for this account."
	var data = r["data"][0].get("data", null)
	if not (data is Dictionary):
		return "The cloud save looks damaged."
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return "Couldn't write the save file."
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return ""


# ---------------------------------------------------------
# ACCOUNTS (email + password)
# ---------------------------------------------------------
# Guest -> permanent (same account, nothing lost):
#   link_email(email)  -> Supabase emails a 6-digit code
#   verify_email_code(email, code)
#   set_password(password)
# Existing account on this device: log_in(email, password)
# Forgot password: request_password_reset(email) -> code ->
#   verify_recovery(email, code) -> set_password(new)
# Every function returns "" on success, otherwise the reason.

func _read_user(user: Dictionary) -> void:
	is_guest = bool(user.get("is_anonymous", false)) and str(user.get("email", "")) == ""
	email = str(user.get("email", ""))


## First-launch choice: play as a guest.
func start_guest() -> void:
	is_guest = true
	if await ensure_session():
		print("Backend: signed in as guest %s" % user_id)
		await update_profile()
		note_saved()
		Sects.refresh_bonus()


func link_email(address: String) -> String:
	if not await ensure_session():
		return "Can't reach the server."
	var r := await _user_update({"email": address.strip_edges()})
	return "" if r["ok"] else _auth_error(r)


func verify_email_code(address: String, code: String) -> String:
	var r := await _auth("verify", {"type": "email_change", "email": address.strip_edges(), "token": code.strip_edges()})
	if not r["ok"]:
		return _auth_error(r)
	if r["data"] is Dictionary and (r["data"] as Dictionary).has("access_token"):
		_set_session(r["data"])
	await _refresh_user()
	return ""


func set_password(password: String) -> String:
	if password.length() < 8:
		return "Passwords need at least 8 characters."
	var r := await _user_update({"password": password})
	if not r["ok"]:
		return _auth_error(r)
	await _refresh_user()
	return ""


## Logs in to an existing account. Returns "" on success.
func log_in(address: String, password: String) -> String:
	var r := await _auth("token?grant_type=password",
		{"email": address.strip_edges(), "password": password})
	if not r["ok"]:
		return _auth_error(r)
	_set_session(r["data"])
	await update_profile()
	return ""


func request_password_reset(address: String) -> String:
	var r := await _auth("recover", {"email": address.strip_edges()})
	return "" if r["ok"] else _auth_error(r)


func verify_recovery(address: String, code: String) -> String:
	var r := await _auth("verify", {"type": "recovery", "email": address.strip_edges(), "token": code.strip_edges()})
	if not r["ok"]:
		return _auth_error(r)
	_set_session(r["data"])
	return ""


## Signs out and forgets this device's login. The local save stays.
func log_out() -> void:
	if _access_token != "":
		await _http(HTTPClient.METHOD_POST, SUPABASE_URL + "/auth/v1/logout", _rest_headers([]), {})
	_access_token = ""
	_refresh_token = ""
	user_id = ""
	email = ""
	is_guest = true
	online = false
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)


## Summary of the account's cloud save: {exists, stage, name, updated_at}.
func cloud_save_info() -> Dictionary:
	var r := await rest(HTTPClient.METHOD_GET, "saves?select=updated_at,data->highest_stage,data->mc_name&user_id=eq." + user_id)
	if not r["ok"] or not (r["data"] is Array) or (r["data"] as Array).is_empty():
		return {"exists": false}
	var row: Dictionary = r["data"][0]
	return {"exists": true, "stage": int(row.get("highest_stage", 0)), "name": str(row.get("mc_name", "")),
		"updated_at": str(row.get("updated_at", ""))}


## Uploads this device's save over the cloud one right now.
func upload_now() -> void:
	note_saved()
	await upload_save()


func _user_update(fields: Dictionary) -> Dictionary:
	if not await ensure_session():
		return {"ok": false, "code": 0, "data": null, "error": "offline"}
	return await _http(HTTPClient.METHOD_PUT, SUPABASE_URL + "/auth/v1/user", _rest_headers([]), fields)


func _refresh_user() -> void:
	var r := await _http(HTTPClient.METHOD_GET, SUPABASE_URL + "/auth/v1/user", _rest_headers([]), null)
	if r["ok"] and r["data"] is Dictionary:
		_read_user(r["data"])
		_save_session()


func _auth_error(r: Dictionary) -> String:
	var d = r.get("data", null)
	if d is Dictionary:
		for key in ["msg", "message", "error_description"]:
			if d.has(key):
				return str(d[key])
	if int(r.get("code", 0)) == 0:
		return "Can't reach the server."
	return "Something went wrong (%d)." % int(r.get("code", 0))


## Permanently deletes this account and its server data (Google Play
## requires this). Then forgets the login on this device.
## Returns "" on success, otherwise the reason.
func delete_account() -> String:
	if not await ensure_session():
		return "Can't reach the server. Check your connection."
	var r := await call_fn("delete_my_account", {})
	if not r["ok"]:
		return _auth_error(r)
	_access_token = ""
	_refresh_token = ""
	user_id = ""
	email = ""
	is_guest = true
	online = false
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
	return ""
