class_name Arena

# =========================================================
# Arena: asynchronous PvP. Save as res://systems/arena.gd
#
# You fight a stored snapshot of another cultivator's team, so
# nobody has to be online. Brackets are the four major realms —
# a Mortal Realm cultivator only ever meets Mortal Realm ones.
#
# Points, attempts and the Elo maths live on the server
# (supabase_setup_9.sql). The client reports who won; the server
# decides what that is worth and refuses results a real battle
# could not produce.
#
# Empty brackets are topped up with generated cultivators. Those
# never reach the server, so beating one moves nothing and cannot
# be farmed — they exist so the Arena is playable on day one.
# =========================================================

## Keep in sync with arena_free_attacks() / arena_max_extra().
const FREE_ATTACKS := 10
const MAX_EXTRA := 10
## Jade for one more attempt. Rises with each one bought today.
const EXTRA_COST_BASE := 50
const EXTRA_COST_STEP := 25

## Opponents offered at once. Real ones first, then generated.
const OPPONENT_COUNT := 5

## Arena currency.
const TOKEN_ID := "arena_token"

## Below this many cultivators duelling in a bracket, only the base
## standing reward pays out. Must match arena_min_bracket() in
## setup_12_arena_rewards.sql; the server is what enforces it.
const MIN_BRACKET_FOR_RANK := 5
## Tokens for a win and a loss. Losing still pays a little, so a
## bad run is not a wasted session.
const TOKENS_WIN := 12
const TOKENS_LOSS := 4

## Bracket emblems, by Realms.Major.
const BRACKET_ART := [
	"res://assets/ui/mortal_realm.png",
	"res://assets/ui/spirit_realm.png",
	"res://assets/ui/sovereign_realm.png",
	"res://assets/ui/immortal_realm.png",
]

## Names for generated opponents, built from two halves so a small
## list yields plenty of plausible cultivators.
const NPC_FIRST := [
	"Frost", "Cloud", "Thunder", "Jade", "Azure", "Crimson", "Silent", "Iron",
	"Moonlit", "Star", "Ember", "Verdant", "Hollow", "Radiant", "Pale", "Dawn",
	"Abyss", "Mist", "Sable", "Golden",
]
const NPC_SECOND := [
	"Blade Xu", "Walker Mei", "Fist Bao", "Pond Ning", "Sword Ye", "Vow Gu",
	"Seeker Han", "Chaser Fei", "Monk Duan", "Step Wei", "Heart Ma", "Gazer Luo",
	"Herald Shu", "Star Pei", "Oracle Kang", "Fang Zhi", "Dream Xia", "Bell Cui",
	"Moon Su", "Lotus Qi",
]


static func available() -> bool:
	return Backend.is_configured()


## The bracket the player belongs to: 0 Mortal ... 3 Immortal.
static func bracket() -> int:
	var mc := GameState.get_mc()
	if mc == null:
		return 0
	return clampi(int(Realms.get_major(mc.realm_index)), 0, 3)


static func bracket_name(major := -1) -> String:
	var b := bracket() if major < 0 else clampi(major, 0, 3)
	return str(Realms.MAJOR_NAMES[b])


static func bracket_art(major := -1) -> String:
	var b := bracket() if major < 0 else clampi(major, 0, 3)
	return str(BRACKET_ART[b])


## Jade for the next extra attempt, given how many were bought today.
static func extra_cost(bought: int) -> int:
	return EXTRA_COST_BASE + EXTRA_COST_STEP * maxi(bought, 0)


# ---------------------------------------------------------
# THE PLAYER'S TEAM
# ---------------------------------------------------------

## The formation as the snapshot others fight.
##
## Final stats, not identity: gear, treasures, beasts, codex, sect
## and Path bonuses are all baked in here. Rebuilding an opponent
## from partner_id alone would read the VIEWER's gear for that id,
## which would be wrong in both directions.
##
## partner_id and dao ride along anyway, because PartnerSkills is
## global data — so an opponent still fights with their real skill.
static func my_team() -> Array:
	var out: Array = []
	for index in GameState.formation:
		var i := int(index)
		if i < 0 or i >= GameState.roster.size():
			continue
		var p = GameState.roster[i]
		if p == null:
			continue
		var data = p.get_data()
		out.append({
			"name": p.get_display_name(),
			"partner_id": p.partner_id,
			"rarity": int(data.rarity) if data != null else -1,
			"dao": int(data.path) if data != null else -1,
			"hp": p.get_max_hp(),
			"atk": p.get_atk(),
			"def": p.get_def(),
			"mdef": p.get_mdef(),
			"spd": p.get_spd(),
			"crit": p.get_crit(),
			"crit_damage": p.get_crit_damage(),
			"eva": p.get_eva(),
			"accuracy": p.get_accuracy(),
			"energy_regen": p.get_energy_regen(),
			"power": p.get_power(),
		})
	return out


## A stored snapshot turned into the enemy dictionaries BattleCore
## expects. Skills come back via partner_id; the sprite is looked up
## locally, since art is shipped with the game rather than stored.
static func to_enemies(team: Array) -> Array:
	var out: Array = []
	for entry in team:
		var e: Dictionary = entry if entry is Dictionary else {}
		if e.is_empty():
			continue
		var foe := e.duplicate()
		var pid := str(e.get("partner_id", ""))
		if pid != "":
			var data = PartnerDatabase.get_partner(pid)
			if data != null:
				foe["sprite"] = data.sprite_texture
				foe["skill_mode"] = PartnerSkills.mode_for(int(data.rarity))
		out.append(foe)
	return out


# ---------------------------------------------------------
# SERVER
# ---------------------------------------------------------

## Registers the player and refreshes their snapshot. Call when the
## Arena opens: without it there is nothing for others to fight.
static func sync() -> Dictionary:
	return await _act("arena_sync", {
		"p_bracket": bracket(),
		"p_power": GameState.get_team_power(),
		"p_team": my_team(),
	})


## {joined, bracket, points, wins, losses, attacks_left, rank, in_bracket}
static func state() -> Dictionary:
	var r: Dictionary = await Backend.call_fn("arena_state", {})
	return r["data"] if r["ok"] and r["data"] is Dictionary else {}


## Real opponents in the bracket, nearest in points first.
static func real_opponents(count := OPPONENT_COUNT) -> Array:
	var r: Dictionary = await Backend.call_fn("arena_opponents", {"p_limit": count})
	return r["data"] if r["ok"] and r["data"] is Array else []


## Opponents to show: real cultivators first, generated ones after,
## so the Arena is never empty.
static func opponents(points: int) -> Array:
	var list := await real_opponents()
	var i := 0
	while list.size() < OPPONENT_COUNT:
		list.append(_make_npc(points, i))
		i += 1
	return list


## Reports a fight. Generated opponents are settled locally and
## never touch the server, so they cannot move anyone's rank.
## Returns {ok, error, points, delta, attacks_left}.
static func report(opponent: Dictionary, won: bool) -> Dictionary:
	if bool(opponent.get("npc", false)):
		_give_tokens(won)
		return {"ok": true, "error": "", "points": 0, "delta": 0, "npc": true}

	var r: Dictionary = await Backend.call_fn("arena_report", {
		"p_defender": str(opponent.get("id", "")), "p_won": won})
	if not r["ok"]:
		return {"ok": false, "error": _error_text(r)}
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if not bool(d.get("ok", false)):
		return {"ok": false, "error": str(d.get("error", "That fight could not be recorded."))}
	_give_tokens(won)
	return {"ok": true, "error": "", "points": int(d.get("points", 0)),
		"delta": int(d.get("delta", 0)), "attacks_left": int(d.get("attacks_left", 0))}


## Buys one more attempt with Jade. Takes the Jade first and refunds
## it if the server refuses.
static func buy_attack(bought_today: int) -> Dictionary:
	var cost := extra_cost(bought_today)
	if not GameState.spend_immortal_jade(cost):
		return {"ok": false, "error": "Not enough Immortal Jade."}
	var r: Dictionary = await Backend.call_fn("arena_buy_attack", {})
	var d: Dictionary = r["data"] if r["ok"] and r["data"] is Dictionary else {}
	if not r["ok"] or not bool(d.get("ok", false)):
		GameState.add_immortal_jade(cost)
		GameState.save_game()
		return {"ok": false, "error": str(d.get("error", _error_text(r)))}
	GameState.save_game()
	return {"ok": true, "error": "", "attacks_left": int(d.get("attacks_left", 0))}


# ---------------------------------------------------------
# THE EXCHANGE
# ---------------------------------------------------------

## Stock with this week's purchase counts:
## [{item_id, amount, cost, weekly_limit, bought}]
static func shop_state() -> Array:
	var r: Dictionary = await Backend.call_fn("arena_shop_state", {})
	return r["data"] if r["ok"] and r["data"] is Array else []


## Buys one. Tokens are taken first and refunded if the server
## refuses, so a failed call never costs anything.
static func buy(item_id: String, cost: int) -> Dictionary:
	if GameState.get_item_count(TOKEN_ID) < cost:
		return {"ok": false, "error": "Not enough Arena Tokens."}
	if not GameState.spend_item(TOKEN_ID, cost):
		return {"ok": false, "error": "Not enough Arena Tokens."}

	var r: Dictionary = await Backend.call_fn("buy_arena_item", {"p_item": item_id})
	var d: Dictionary = r["data"] if r["ok"] and r["data"] is Dictionary else {}
	if not r["ok"] or not bool(d.get("ok", false)):
		GameState.add_items({TOKEN_ID: cost})
		GameState.save_game()
		return {"ok": false, "error": str(d.get("error", _error_text(r)))}

	# Only what the server says was bought is granted.
	GameState.add_items({str(d["item_id"]): int(d["amount"])})
	GameState.save_game()
	return {"ok": true, "error": "", "item_id": str(d["item_id"]), "amount": int(d["amount"])}


# ---------------------------------------------------------
# STANDING REWARDS
# ---------------------------------------------------------

## Collects any standing rewards the server has settled and posts
## them to the mailbox. There is nothing to press: a period closes,
## the server freezes the standings, and the letters are waiting the
## next time the Arena is opened.
##
## The server marks each reward delivered as it hands it over, so a
## letter is written once even if this is called twice. Returns how
## many arrived.
static func collect_rewards() -> int:
	var r: Dictionary = await Backend.call_fn("arena_collect_rewards", {})
	if not r["ok"] or not (r["data"] is Array):
		return 0
	var rows: Array = r["data"]
	var posted := 0
	for row in rows:
		if row is Dictionary:
			_post_reward(row)
			posted += 1
	if posted > 0:
		GameState.save_game()
	return posted


static func _post_reward(row: Dictionary) -> void:
	var weekly := str(row.get("kind", "daily")) == "weekly"
	var rank := int(row.get("rank", 0))
	var tokens := int(row.get("tokens", 0))
	var jade := int(row.get("jade", 0))
	var period := str(row.get("period", ""))

	var title := "%s Arena Standing" % ("Weekly" if weekly else "Daily")
	var body := "The %s closed on %s.\n\nYou finished rank %d of %s in the %s bracket." % [
		"week" if weekly else "day", period, rank,
		NumberFormat.short(int(row.get("bracket_size", 0))), bracket_name(bracket())]
	# Say so plainly rather than letting it look like a bad roll.
	if int(row.get("bracket_size", 0)) < MIN_BRACKET_FOR_RANK:
		body += "\n\nToo few cultivators duelled in your bracket for the" \
			+ " higher places to pay out, so this is the base reward."
	var items := {}
	if tokens > 0:
		items[TOKEN_ID] = tokens
	Mail.send(title, body, jade, items)


## The bracket's top cultivators.
static func board(count := 20) -> Array:
	var r: Dictionary = await Backend.call_fn("arena_board", {"p_limit": count})
	return r["data"] if r["ok"] and r["data"] is Array else []


# ---------------------------------------------------------
# GENERATED OPPONENTS
# ---------------------------------------------------------

## A plausible cultivator near the player's standing. Seeded on the
## day and slot, so the same opponents persist through a session
## instead of reshuffling on every refresh.
static func _make_npc(points: int, slot: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("arena_npc_%d_%d_%d" % [GameState.today(), bracket(), slot])

	var team_power := GameState.get_team_power()
	# Roughly even: a little weaker to a little stronger.
	var ratio := rng.randf_range(0.78, 1.22)
	var name_text := "%s %s" % [NPC_FIRST[rng.randi() % NPC_FIRST.size()],
		NPC_SECOND[rng.randi() % NPC_SECOND.size()]]

	return {
		"id": "",
		"npc": true,
		"name": name_text,
		"points": maxi(0, points + rng.randi_range(-120, 120)),
		"power": maxi(1, int(team_power * ratio)),
		"wins": rng.randi_range(0, 40),
		"losses": rng.randi_range(0, 40),
		"realm": GameState.get_mc().realm_index if GameState.get_mc() != null else 0,
		"team": [],
	}


static func _give_tokens(won: bool) -> void:
	var n := TOKENS_WIN if won else TOKENS_LOSS
	GameState.add_items({TOKEN_ID: n})
	GameState.bump("arena_fights")
	if won:
		GameState.bump("arena_wins")
	GameState.save_game()


# ---------------------------------------------------------
# PLUMBING
# ---------------------------------------------------------

static func _act(fn: String, args: Dictionary) -> Dictionary:
	var r: Dictionary = await Backend.call_fn(fn, args)
	return {"ok": r["ok"], "data": r["data"], "error": "" if r["ok"] else _error_text(r)}


static func _error_text(r: Dictionary) -> String:
	var d = r.get("data", null)
	if d is Dictionary and d.has("message"):
		return str(d["message"])
	if str(r.get("error", "")) == "offline":
		return "Can't reach the server. Check your connection."
	return "Something went wrong (%d)." % int(r.get("code", 0))
