class_name Ranking

# =========================================================
# Dungeon leaderboards.
#
# There is no server yet, so the other climbers are simulated:
# each has a pace and climbs a little every day. They behave
# consistently, so the board looks and feels real.
#
# When a server exists, only fetch_board() needs to change.
# =========================================================

const RIVALS := 60
const SHOWN := 20

## Jade paid at the daily reset, by rank.
const REWARDS := [
	[1, 500],
	[3, 300],
	[10, 200],
	[50, 120],
	[999999, 60],
]

const NAMES := [
	"Frost Blade Xu", "Cloudwalker Mei", "Nine Suns Lin", "Silent Sword Ye",
	"Jade Pond Ning", "Thunder Fist Bao", "Moonlit Shen", "Azure Yun",
	"Blood Lotus Qi", "Star Picker Tan", "Iron Vow Gu", "Snowfall Ruo",
	"Dao Seeker Han", "Wind Chaser Fei", "Ember Monk Duan", "Ghost Step Wei",
	"Verdant Yao", "Stone Heart Ma", "Crimson Tang", "Abyss Gazer Luo",
	"Dawn Herald Shu", "Whitejade Rong", "Falling Star Pei", "Mist Oracle Kang",
	"Sable Fang Zhi", "Lotus Dream Xia", "Skyward Jin", "Hollow Bell Cui",
	"Radiant Zhou", "Pale Moon Su",
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


## Other climbers. Replace this with a server call later.
static func fetch_board(dungeon_id: String) -> Array:
	var day := GameState.today()
	var entries: Array = []
	for i in RIVALS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(dungeon_id) + i * 7919
		var pace := rng.randf_range(0.2, 2.2)          # floors per day
		var start := rng.randi_range(0, 12)
		var days_in := (day % 100) + rng.randi_range(5, 60)
		var floor_n := start + int(pace * days_in)
		entries.append({
			"name": NAMES[i % NAMES.size()] + ("" if i < NAMES.size() else " %d" % (int(float(i) / NAMES.size()) + 1)),
			"floor": maxi(floor_n, 0), "is_player": false,
		})
	return entries


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
