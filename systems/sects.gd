class_name Sects

# =========================================================
# Sects (guilds): talks to Supabase through the Backend autoload.
# Save as res://systems/sects.gd
#
# Tables and rules live on the server (supabase_setup_2.sql);
# every change goes through a server function, so the rules
# (one sect per player, roles, member limits) can't be cheated.
#
# Everything here is async: `var r = await Sects.list_sects("")`.
# Actions return {"ok": bool, "error": String, "data": ...}.
# =========================================================

const ROLE_ORDER := {"leader": 0, "elder": 1, "member": 2}
const ROLE_NAMES := {"leader": "Sect Master", "elder": "Elder", "member": "Disciple"}
const MAX_ELDERS := 4
const MAX_LEVEL := 10

# ---------------------------------------------------------
# PROGRESSION (keep in sync with supabase_setup_3.sql)
# ---------------------------------------------------------
## Daily donation tiers: the game takes the cost, the server gives
## Sect EXP (also Treasury funds) and Contribution.
const DONATIONS := [
	{"name": "Spirit Stones", "currency": "stones", "cost": 20000, "exp": 20, "contribution": 30},
	{"name": "Immortal Jade", "currency": "jade", "cost": 50, "exp": 60, "contribution": 80},
	{"name": "Grand Offering", "currency": "jade", "cost": 200, "exp": 200, "contribution": 250},
]
const SIGNIN_EXP := 10
const SIGNIN_CONTRIBUTION := 20

## Sect Research: node -> [name, stat, bonus per level, base cost]
## Cost of the next level = base x (level + 1). Max 10, never above the sect level.
const RESEARCH := {
	"hp": ["Vitality Scriptures", "hp_pct", 1.0, 300],
	"atk": ["Blade Scriptures", "atk_pct", 1.0, 300],
	"def": ["Guardian Scriptures", "def_pct", 1.5, 200],
	"crit": ["Insight Scriptures", "crit", 0.3, 400],
}
const RESEARCH_MAX := 10

## Sect Shop: the item list, prices and weekly limits live on the
## server (table sect_shop_items in supabase_setup_5.sql).
const CONTRIBUTION_ID := "sect_contribution"


static func exp_needed(level: int) -> int:
	return 500 * level * level


static func research_cost(node: String, level: int) -> int:
	return int(RESEARCH[node][3]) * (level + 1)


## "2026-09-21": the server's day (UTC).
static func today_utc() -> String:
	return Time.get_date_string_from_system(true)


static func capacity(level: int) -> int:
	return mini(50, 20 + 5 * (level - 1))


static func available() -> bool:
	return Backend.is_configured()


# ---------------------------------------------------------
# READING
# ---------------------------------------------------------

## {sect_id, role} for the player, or {} if not in a sect (null if offline).
static func my_membership() -> Variant:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"sect_members?select=sect_id,role,contribution,balance,last_signin,last_donate&user_id=eq." + Backend.user_id)
	if not r["ok"]:
		return null
	var rows: Array = r["data"] if r["data"] is Array else []
	return rows[0] if not rows.is_empty() else {}


static func get_sect(sect_id: String) -> Dictionary:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET, "sects?select=*&id=eq." + sect_id)
	if not r["ok"] or not (r["data"] is Array) or (r["data"] as Array).is_empty():
		return {}
	return r["data"][0]


## Sects to browse, best first. search = part of a name ("" for all).
static func list_sects(search: String) -> Array:
	var path := "sects?select=*&order=level.desc,exp.desc,member_count.desc&limit=40"
	var term := search.strip_edges()
	if term != "":
		path += "&name=ilike.*" + term.uri_encode() + "*"
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET, path)
	return r["data"] if r["ok"] and r["data"] is Array else []


## Members with their profile (name, realm, stage), leader first.
static func members(sect_id: String) -> Array:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"sect_members?select=user_id,role,contribution,joined_at,profiles(display_name,realm,highest_stage)"
		+ "&sect_id=eq." + sect_id)
	var rows: Array = r["data"] if r["ok"] and r["data"] is Array else []
	var by_rank := func(a, b) -> bool:
		var ra := int(ROLE_ORDER.get(str(a["role"]), 3))
		var rb := int(ROLE_ORDER.get(str(b["role"]), 3))
		if ra != rb:
			return ra < rb
		return int(a["contribution"]) > int(b["contribution"])
	rows.sort_custom(by_rank)
	return rows


## Join requests to the player's sect (leader / elders only see them).
static func requests(sect_id: String) -> Array:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"sect_requests?select=user_id,created_at,profiles(display_name,realm,highest_stage)"
		+ "&sect_id=eq." + sect_id + "&order=created_at.asc")
	return r["data"] if r["ok"] and r["data"] is Array else []


## Sects the player has applied to.
static func my_requests() -> Array:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"sect_requests?select=sect_id,created_at,sects(name)&user_id=eq." + Backend.user_id)
	return r["data"] if r["ok"] and r["data"] is Array else []


## Latest chat messages, oldest first. after_id > 0 = only newer ones.
static func messages(sect_id: String, after_id := 0) -> Array:
	var path := "sect_messages?select=id,user_id,name,body,created_at&sect_id=eq." + sect_id
	if after_id > 0:
		path += "&id=gt.%d" % after_id
	path += "&order=id.desc&limit=50"
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET, path)
	var rows: Array = r["data"] if r["ok"] and r["data"] is Array else []
	rows.reverse()
	return rows


# ---------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------

static func create(sect_name: String, notice: String, join_mode: String, min_realm: int) -> Dictionary:
	return await _act("create_sect", {"p_name": sect_name, "p_notice": notice,
		"p_join_mode": join_mode, "p_min_realm": min_realm})


## "joined" (open sect) or "applied" (needs approval) in data.
static func join(sect_id: String) -> Dictionary:
	return await _act("join_sect", {"p_sect": sect_id})


static func cancel_request(sect_id: String) -> Dictionary:
	return await _act("cancel_request", {"p_sect": sect_id})


static func review(user_id: String, accept: bool) -> Dictionary:
	return await _act("review_request", {"p_user": user_id, "p_accept": accept})


static func leave() -> Dictionary:
	return await _act("leave_sect", {})


static func kick(user_id: String) -> Dictionary:
	return await _act("kick_member", {"p_user": user_id})


## role: "elder", "member", or "leader" (hands over leadership).
static func set_role(user_id: String, role: String) -> Dictionary:
	return await _act("set_member_role", {"p_user": user_id, "p_role": role})


static func update(notice: String, join_mode: String, min_realm: int) -> Dictionary:
	return await _act("update_sect", {"p_notice": notice, "p_join_mode": join_mode, "p_min_realm": min_realm})


static func send(body: String) -> Dictionary:
	return await _act("send_sect_message", {"p_body": body})


static func _act(fn: String, args: Dictionary) -> Dictionary:
	var r: Dictionary = await Backend.call_fn(fn, args)
	return {"ok": r["ok"], "data": r["data"], "error": "" if r["ok"] else _error_text(r)}


## The server's message ("That sect name is taken") instead of raw JSON.
static func _error_text(r: Dictionary) -> String:
	var d = r.get("data", null)
	if d is Dictionary and d.has("message"):
		return str(d["message"])
	if str(r.get("error", "")) == "offline":
		return "Can't reach the server. Check your connection."
	return "Something went wrong (%d)." % int(r.get("code", 0))


# ---------------------------------------------------------
# PROGRESSION
# ---------------------------------------------------------

static func signin() -> Dictionary:
	return await _act("sect_signin", {})


## Takes the donation's cost, then asks the server; refunds if it refuses.
static func donate(tier: int) -> Dictionary:
	var d: Dictionary = DONATIONS[tier]
	var paid := false
	if str(d["currency"]) == "stones":
		paid = GameState.spend_spirit_stones(int(d["cost"]))
	else:
		paid = GameState.spend_immortal_jade(int(d["cost"]))
	if not paid:
		return {"ok": false, "data": null, "error": "Not enough %s." % d["name"]}
	var r := await _act("sect_donate", {"p_tier": tier})
	if not r["ok"]:
		if str(d["currency"]) == "stones":
			GameState.add_spirit_stones(int(d["cost"]))
		else:
			GameState.add_immortal_jade(int(d["cost"]))
	GameState.save_game()
	return r


## The Sect Shop from the server: [{item_id, amount, cost, weekly_limit, bought}].
static func shop_state() -> Array:
	var r: Dictionary = await Backend.call_fn("sect_shop_state", {})
	return r["data"] if r["ok"] and r["data"] is Array else []


## Buys an item: the server checks the limit and balance and says
## exactly what to give; only that is added.
static func buy(item_id: String) -> Dictionary:
	var r := await _act("buy_sect_item", {"p_item": item_id})
	if r["ok"] and r["data"] is Dictionary:
		var d: Dictionary = r["data"]
		GameState.add_items({str(d["item_id"]): int(d["amount"])})
		GameState.save_game()
	return r


static func research(sect_id: String) -> Dictionary:
	var r: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"sect_research?select=node,level&sect_id=eq." + sect_id)
	var out := {}
	for node in RESEARCH:
		out[node] = 0
	if r["ok"] and r["data"] is Array:
		for row in r["data"]:
			out[str(row["node"])] = int(row["level"])
	return out


static func upgrade(node: String) -> Dictionary:
	return await _act("upgrade_research", {"p_node": node})


## Research levels -> stat bonus for every partner (OwnedPartner uses it).
static func bonus_from(levels: Dictionary) -> Dictionary:
	var out := {}
	for node in RESEARCH:
		var lv := int(levels.get(node, 0))
		if lv > 0:
			var stat := str(RESEARCH[node][1])
			out[stat] = float(out.get(stat, 0.0)) + float(RESEARCH[node][2]) * lv
	return out


## Reloads the sect's research into GameState.sect_bonus (cleared if
## you're not in a sect). Called on start-up and by the Guild screen.
static func refresh_bonus() -> void:
	if not available():
		return
	var m = await my_membership()
	if m == null:
		return
	var levels := {}
	if m is Dictionary and not (m as Dictionary).is_empty():
		levels = await research(str(m["sect_id"]))
	GameState.sect_bonus = bonus_from(levels)
	GameState.save_game()
	GameState.roster_changed.emit()
