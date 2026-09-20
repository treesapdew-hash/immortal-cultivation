class_name Redeem

# =========================================================
# Redeem codes. Save as res://systems/redeem.gd
#
# The server owns the codes (supabase_setup_8.sql): what each is
# worth, whether it has expired, and whether this player already
# used it. The client only grants what comes back, so a code can't
# be forged or claimed twice.
#
#   var r = await Redeem.claim("WELCOME2026")
#   if r["ok"]: print(r["text"])   # "+100 Jade, +1 Summon Scroll"
#
# Unlike the other systems here, redeem_code() returns its errors
# instead of raising them — raising would roll back the failed
# attempt log that throttles code guessing. So read d["ok"], not
# just the HTTP result.
# =========================================================

## Longest a code can be, to keep obvious junk off the wire.
const MAX_LENGTH := 32


static func available() -> bool:
	return Backend.is_configured()


## Tidies what the player typed: codes are matched uppercase.
static func normalise(code: String) -> String:
	return code.strip_edges().to_upper()


## {"ok": bool, "text": String, "error": String}
## text is a summary of what was granted, e.g. "+100 Jade".
static func claim(code: String) -> Dictionary:
	var tidy := normalise(code)
	if tidy == "":
		return {"ok": false, "text": "", "error": "Enter a code."}
	if tidy.length() > MAX_LENGTH:
		return {"ok": false, "text": "", "error": "That code is not valid."}
	if not available():
		return {"ok": false, "text": "", "error": "Codes need the online server."}

	var r: Dictionary = await Backend.call_fn("redeem_code", {"p_code": tidy})
	if not r["ok"]:
		return {"ok": false, "text": "", "error": _error_text(r)}

	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if not bool(d.get("ok", false)):
		return {"ok": false, "text": "", "error": str(d.get("error", "That code is not valid."))}

	var rewards: Dictionary = d["rewards"] if d.get("rewards", null) is Dictionary else {}
	if rewards.is_empty():
		return {"ok": false, "text": "", "error": "That code has nothing to give."}

	# give_fortune() lives on Ads but is a plain reward granter: it
	# understands jade / stones_hours / item ids, which is exactly the
	# shape the server stores. Reused rather than duplicated.
	var text := Ads.give_fortune(rewards)
	GameState.bump("codes_redeemed")
	GameState.save_game()
	return {"ok": true, "text": text, "error": ""}


## The server's message instead of raw JSON.
static func _error_text(r: Dictionary) -> String:
	var d = r.get("data", null)
	if d is Dictionary and d.has("message"):
		return str(d["message"])
	if str(r.get("error", "")) == "offline":
		return "Can't reach the server. Check your connection."
	return "Something went wrong (%d)." % int(r.get("code", 0))
