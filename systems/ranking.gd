class_name Ranking

# =========================================================
# Dungeon leaderboards. Real cultivators, from the server
# (setup_18_boards.sql).
#
# These used to be sixty invented climbers, each with an invented
# pace. It read convincingly, and it cost real players rewards:
# the board pays by rank, so the inventions pushed everyone sixty
# places down it.
#
# The board is cached and handed back synchronously, because the
# dungeon cards ask for it while they are being built. refresh()
# goes and gets a fresh one, and sends up your own best floor at the
# same time.
# =========================================================

const SHOWN := 20

## Jade paid at the daily reset, by rank.
const REWARDS := [
	[1, 500],
	[3, 300],
	[10, 200],
	[50, 120],
	[999999, 60],
]

## The board for a dungeon, best first: [{name, floor, is_player}]
static func board(dungeon_id: String) -> Array:
	var def := Dungeons.get_def(dungeon_id)
	var entries := fetch_board(dungeon_id)
	entries.append({
		"name": GameState.mc_name, "floor": Dungeons.highest(def), "is_player": true,
	})
	entries.sort_custom(func(a, b): return int(a["floor"]) > int(b["floor"]))
	return entries


## Other climbers, as last fetched. Cached and returned straight so
## the dungeon cards stay synchronous; refresh() goes and gets it.
static var _cache: Dictionary = {}


static func fetch_board(dungeon_id: String) -> Array:
	var rows: Array = _cache.get(dungeon_id, [])
	var out: Array = []
	for row in rows:
		# Skip our own server row: board() adds the live local one,
		# which is fresher than whatever was last uploaded.
		if str(row.get("id", "")) == Backend.user_id:
			continue
		out.append({
			"name": str(row.get("name", "Cultivator")),
			"floor": int(row.get("floor", 0)),
			"is_player": false,
		})
	return out


static func available() -> bool:
	return Backend.is_configured()


## Sends this dungeon's best floor up and brings the board back.
## Returns true if the board changed, so a screen can redraw.
static func refresh(dungeon_id: String) -> bool:
	if not available():
		return false
	var def := Dungeons.get_def(dungeon_id)
	var best := int(Dungeons.highest(def))
	if best > 0:
		await Backend.call_fn("submit_dungeon_floor",
			{"p_dungeon": dungeon_id, "p_floor": best})
	var r: Dictionary = await Backend.call_fn("dungeon_board",
		{"p_dungeon": dungeon_id, "p_limit": SHOWN + 5})
	if not r["ok"] or not (r["data"] is Array):
		return false
	# Compared as text rather than with !=, which on arrays of
	# dictionaries is not dependable enough to drive a redraw.
	var before := JSON.stringify(_cache.get(dungeon_id, []))
	_cache[dungeon_id] = r["data"]
	return before != JSON.stringify(r["data"])


## The player's place on a dungeon's board (1 = first).
static func player_rank(dungeon_id: String) -> int:
	var list := board(dungeon_id)
	for i in list.size():
		if list[i]["is_player"]:
			return i + 1
	return list.size()


static func reward_for_rank(rank: int) -> int:
	for row in REWARDS:
		if rank <= int(row[0]):
			return int(row[1])
	return 0


## Rows for the reward table: [{label, jade}]
static func reward_table() -> Array:
	var rows: Array = []
	for row in REWARDS:
		var upper: int = row[0]
		var label := "Everyone else"
		if upper == 1:
			label = "Rank 1"
		elif upper < 999999:
			label = "Top %d" % upper
		rows.append({"label": label, "jade": int(row[1])})
	return rows


## Pays out yesterday's ranks once per day, by mail.
static func check_daily() -> void:
	var day := GameState.today()
	if GameState.ranking_day == day:
		return
	var first_time := GameState.ranking_day == 0
	GameState.ranking_day = day
	if first_time:
		GameState.save_game()
		return

	var total := 0
	var lines: Array = []
	for def in Dungeons.LIST:
		if not def.get("open", false) or Dungeons.highest(def) <= 0:
			continue
		var rank := player_rank(def["id"])
		var jade := reward_for_rank(rank)
		total += jade
		lines.append("%s — rank %d — %d Jade" % [def["name"], rank, jade])

	if total > 0:
		Mail.send("Dungeon Rankings", "Yesterday's standings:\n" + "\n".join(lines), total)
	GameState.save_game()
