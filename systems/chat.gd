class_name Chat

# =========================================================
# Chat: World, Sect and Whispers, through the Backend autoload.
# Save as res://systems/chat.gd
#
# Tables and rules live on the server (supabase_setup_7.sql);
# sending always goes through a server function, so rate limits
# and blocks can't be cheated.
#
# Sect chat still lives in sect_messages (supabase_setup_2.sql)
# and is reached through Sects — this file just routes to it so
# the chat box can treat all three channels the same way.
#
# Everything here is async: `var rows = await Chat.world()`.
# Actions return {"ok": bool, "error": String, "data": ...}.
# =========================================================

enum Channel { WORLD, SECT, WHISPER }

const MAX_LENGTH := 200

## Server-side cooldowns (supabase_setup_7.sql). Mirrored here only
## so the UI can grey the send button instead of bouncing the player
## off a server error.
const WORLD_COOLDOWN := 5.0
const SECT_COOLDOWN := 3.0
const WHISPER_COOLDOWN := 3.0

## How often the chat box refetches while it is OPEN. Polling stops
## when it closes: every player polling forever adds up fast on a
## free-tier project.
const POLL_SECONDS := 5.0

const CHANNEL_NAMES := {
	Channel.WORLD: "World",
	Channel.SECT: "Sect",
	Channel.WHISPER: "Whispers",
}


static func available() -> bool:
	return Backend.is_configured()


## "world" / "sect" / "whisper" — what the server calls each channel.
static func channel_key(channel: int) -> String:
	match channel:
		Channel.SECT:
			return "sect"
		Channel.WHISPER:
			return "whisper"
		_:
			return "world"


static func cooldown(channel: int) -> float:
	match channel:
		Channel.SECT:
			return SECT_COOLDOWN
		Channel.WHISPER:
			return WHISPER_COOLDOWN
		_:
			return WORLD_COOLDOWN


# ---------------------------------------------------------
# READING
# ---------------------------------------------------------

## World chat, oldest first. after_id > 0 fetches only newer messages.
## Read through the server function, never the table: that is what
## applies blocks.
static func world(after_id := 0) -> Array:
	var r: Dictionary = await Backend.call_fn("get_world_messages",
		{"p_after": after_id, "p_limit": 50})
	return r["data"] if r["ok"] and r["data"] is Array else []


## One whisper conversation, oldest first. Also marks their messages
## as seen, so the unread badge clears by opening the thread.
static func whispers(with_user: String, after_id := 0) -> Array:
	var r: Dictionary = await Backend.call_fn("get_whispers",
		{"p_with": with_user, "p_after": after_id, "p_limit": 50})
	return r["data"] if r["ok"] and r["data"] is Array else []


## Unread whispers per sender: [{from_id, from_name, unread}].
static func unread() -> Array:
	var r: Dictionary = await Backend.call_fn("whisper_unread", {})
	return r["data"] if r["ok"] and r["data"] is Array else []


## Total unread whispers, for the red dot on the chat tab.
static func unread_count() -> int:
	var rows := await unread()
	var n := 0
	for row in rows:
		n += int(row["unread"])
	return n


## Messages for any channel, oldest first. sect_id is needed for
## Channel.SECT, target (a user id) for Channel.WHISPER.
static func messages(channel: int, after_id := 0, target := "") -> Array:
	match channel:
		Channel.SECT:
			if target == "":
				return []
			return await Sects.messages(target, after_id)
		Channel.WHISPER:
			if target == "":
				return []
			return await whispers(target, after_id)
		_:
			return await world(after_id)


# ---------------------------------------------------------
# SENDING
# ---------------------------------------------------------

static func send_world(body: String) -> Dictionary:
	var r := await _act("send_world_message", {"p_body": body})
	if r["ok"]:
		GameState.bump("chat_sent")
		GameState.save_game()
	return r


static func send_whisper(to_user: String, body: String) -> Dictionary:
	var r := await _act("send_whisper", {"p_to": to_user, "p_body": body})
	if r["ok"]:
		GameState.bump("chat_sent")
		GameState.save_game()
	return r


## Sends on any channel. target is the user id for Channel.WHISPER
## and is ignored otherwise (sect chat knows your sect server-side).
static func send(channel: int, body: String, target := "") -> Dictionary:
	match channel:
		Channel.SECT:
			var r := await Sects.send(body)
			if r["ok"]:
				GameState.bump("chat_sent")
				GameState.save_game()
			return r
		Channel.WHISPER:
			if target == "":
				return {"ok": false, "data": null, "error": "No one to whisper to."}
			return await send_whisper(target, body)
		_:
			return await send_world(body)


# ---------------------------------------------------------
# MODERATION
# ---------------------------------------------------------
# Blocking is mutual and covers every channel: their world messages
# are hidden and their whispers are refused. It also ends the
# friendship, both ways.

static func block(user_id: String) -> Dictionary:
	return await _act("block_player", {"p_user": user_id})


static func unblock(user_id: String) -> Dictionary:
	return await _act("unblock_player", {"p_user": user_id})


## Everyone this cultivator has blocked: [{id, display_name}].
static func blocked() -> Array:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"player_blocks?select=blocked_id&user_id=eq." + Backend.user_id)
	var rows: Array = r["data"] if r["ok"] and r["data"] is Array else []
	if rows.is_empty():
		return []
	var ids := PackedStringArray()
	for row in rows:
		ids.append(str(row["blocked_id"]))
	var p: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"profiles?select=id,display_name&id=in.(%s)" % ",".join(ids))
	return p["data"] if p["ok"] and p["data"] is Array else []


## Reports a message. The body is copied to the server so the report
## survives the message being deleted. One per target per hour.
static func report(reported_id: String, channel: int, body: String, reason := "") -> Dictionary:
	return await _act("report_message", {
		"p_reported": reported_id,
		"p_channel": channel_key(channel),
		"p_body": body,
		"p_reason": reason,
	})


# ---------------------------------------------------------
# PLUMBING
# ---------------------------------------------------------

static func _act(fn: String, args: Dictionary) -> Dictionary:
	var r: Dictionary = await Backend.call_fn(fn, args)
	return {"ok": r["ok"], "data": r["data"], "error": "" if r["ok"] else _error_text(r)}


## The server's message ("Slow down a little") instead of raw JSON.
static func _error_text(r: Dictionary) -> String:
	var d = r.get("data", null)
	if d is Dictionary and d.has("message"):
		return str(d["message"])
	if str(r.get("error", "")) == "offline":
		return "Can't reach the server. Check your connection."
	return "Something went wrong (%d)." % int(r.get("code", 0))
