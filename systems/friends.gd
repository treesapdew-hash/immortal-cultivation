class_name Friends

# =========================================================
# Friends: list, requests and the daily gift exchange.
# Save as res://systems/friends.gd
#
# Tables and rules live on the server (supabase_setup_7.sql).
# The server decides what a claimed gift is worth, so the amounts
# below are only for preview text — claim() grants whatever the
# server actually returns.
#
# Everything here is async: `var s = await Friends.state()`.
# Actions return {"ok": bool, "error": String, "data": ...}.
# =========================================================

## Keep in sync with friend_limit() on the server.
const MAX_FRIENDS := 50

## Keep in sync with gift_reward() on the server. Preview only.
const GIFT_REWARD := {"jade": 5, "beast_core": 10}


static func available() -> bool:
	return Backend.is_configured()


# ---------------------------------------------------------
# READING
# ---------------------------------------------------------

## Everything the Friends panel needs, in one call:
##   {"friends": [{id, name, realm, power, sent_today}],
##    "requests": [{id, name, realm}],
##    "unclaimed": int}
static func state() -> Dictionary:
	var r: Dictionary = await Backend.call_fn("friend_state", {})
	return r["data"] if r["ok"] and r["data"] is Dictionary else {}


## Search cultivators by name for the Add Friend box. Never returns
## you, anyone you blocked, or anyone who blocked you.
static func find(name_part: String) -> Array:
	var term := name_part.strip_edges()
	if term == "":
		return []
	var r: Dictionary = await Backend.call_fn("find_players", {"p_name": term, "p_limit": 20})
	return r["data"] if r["ok"] and r["data"] is Array else []


# ---------------------------------------------------------
# REQUESTS
# ---------------------------------------------------------

## "requested", or "accepted" when they had already asked you.
static func request(user_id: String) -> Dictionary:
	var r := await _act("request_friend", {"p_user": user_id})
	if r["ok"] and str(r["data"]) == "accepted":
		GameState.bump("friends_added")
		GameState.save_game()
	return r


static func accept(user_id: String) -> Dictionary:
	var r := await _act("accept_friend", {"p_user": user_id})
	if r["ok"]:
		GameState.bump("friends_added")
		GameState.save_game()
	return r


static func reject(user_id: String) -> Dictionary:
	return await _act("reject_friend", {"p_user": user_id})


static func remove(user_id: String) -> Dictionary:
	return await _act("remove_friend", {"p_user": user_id})


# ---------------------------------------------------------
# DAILY GIFTS
# ---------------------------------------------------------
# One gift to each friend per UTC day. Sending costs nothing: it is
# a retention loop, not a currency sink. Claiming grants whatever
# the server says was waiting.

static func send_gift(user_id: String) -> Dictionary:
	var r := await _act("send_gift", {"p_user": user_id})
	if r["ok"]:
		GameState.bump("gifts_sent")
		GameState.save_game()
	return r


## Sends to every friend not yet sent to today. data = how many went.
static func send_all() -> Dictionary:
	var r := await _act("send_all_gifts", {})
	if r["ok"]:
		var n := int(r["data"]) if r["data"] != null else 0
		if n > 0:
			GameState.bump("gifts_sent", n)
			GameState.save_game()
	return r


## Claims every waiting gift. The server returns the totals; only
## those are granted, so the client can't inflate the reward.
static func claim() -> Dictionary:
	var r := await _act("claim_gifts", {})
	if not r["ok"] or not (r["data"] is Dictionary):
		return r
	var d: Dictionary = r["data"]
	var n := int(d.get("count", 0))
	if n <= 0:
		return r
	var jade := int(d.get("jade", 0))
	var cores := int(d.get("beast_core", 0))
	if jade > 0:
		GameState.add_immortal_jade(jade)
	if cores > 0:
		GameState.add_items({"beast_core": cores})
	GameState.bump("gifts_claimed", n)
	GameState.save_game()
	return r


## "+5 Jade, +10 Beast Cores" — preview text for one gift.
static func gift_text() -> String:
	var parts := PackedStringArray()
	parts.append("+%d Jade" % int(GIFT_REWARD["jade"]))
	parts.append("+%d %s" % [int(GIFT_REWARD["beast_core"]),
		str(ItemDB.get_item("beast_core").get("name", "Beast Cores"))])
	return ", ".join(parts)


# ---------------------------------------------------------
# PLUMBING
# ---------------------------------------------------------

static func _act(fn: String, args: Dictionary) -> Dictionary:
	var r: Dictionary = await Backend.call_fn(fn, args)
	return {"ok": r["ok"], "data": r["data"], "error": "" if r["ok"] else _error_text(r)}


## The server's message ("Your friend list is full") instead of raw JSON.
static func _error_text(r: Dictionary) -> String:
	var d = r.get("data", null)
	if d is Dictionary and d.has("message"):
		return str(d["message"])
	if str(r.get("error", "")) == "offline":
		return "Can't reach the server. Check your connection."
	return "Something went wrong (%d)." % int(r.get("code", 0))
