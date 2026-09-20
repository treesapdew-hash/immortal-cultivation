class_name Ads

# =========================================================
# Rewarded ads. Save as res://systems/ads.gd
#
#   if await Ads.watch(self, "fortune"):
#       ...give the reward...
#
# Each PLACEMENT has a daily limit (resets with the game's day).
# TEST_MODE shows a 5-second fake ad (works in the editor), so every
# placement can be built and tested before real ads exist. For real
# ads: set up AdMob + the Godot AdMob plugin, then fill in
# _show_real() and set TEST_MODE to false (see the notes there).
# =========================================================

const TEST_MODE := true
const FAKE_AD_SECONDS := 5

## placement: [name, per day]
const PLACEMENTS := {
	"fortune": ["Heavenly Fortune", 5],
	"free_summon": ["Free Summon", 1],
	"extra_hunt": ["Extra Beast Hunt", 1],
	"offline_double": ["Double Offline Rewards", 3],
}

## Daily ad chests: opened by the total ads watched today, across
## every placement. [ads needed, reward]
const AD_CHESTS := [
	[3, {"jade": 40, "beast_core": 40}],
	[6, {"summon_scroll": 1, "stones_hours": 1}],
	[9, {"jade": 100, "select_scroll_purple": 1}],
]

## Heavenly Fortune: the reward for the 1st, 2nd ... 5th ad of the day.
const FORTUNE_REWARDS := [
	{"jade": 20},
	{"stones_hours": 1},
	{"beast_core": 30},
	{"jade": 30},
	{"summon_scroll": 1},
]


# ---------------------------------------------------------
# LIMITS
# ---------------------------------------------------------

static func _state() -> Dictionary:
	var st := GameState.ads_state
	if int(st.get("day", 0)) != GameState.today():
		st["day"] = GameState.today()
		st["used"] = {}
		st["chests"] = []
	return st


static func used(placement: String) -> int:
	var u: Dictionary = _state()["used"]
	return int(u.get(placement, 0))


static func left(placement: String) -> int:
	var per_day := int(PLACEMENTS.get(placement, ["", 0])[1])
	return maxi(0, per_day - used(placement))


static func can_watch(placement: String) -> bool:
	return left(placement) > 0


static func _record(placement: String) -> void:
	var u: Dictionary = _state()["used"]
	u[placement] = int(u.get(placement, 0)) + 1
	GameState.bump("ads_watched")
	GameState.save_game()


# ---------------------------------------------------------
# WATCHING
# ---------------------------------------------------------

## Shows a rewarded ad. Returns true only if it was watched to the end
## (then the placement's daily count goes up and you give the reward).
static func watch(host: Node, placement: String) -> bool:
	if not can_watch(placement):
		return false
	var ok := false
	if TEST_MODE:
		ok = await _show_fake(host, placement)
	else:
		ok = await _show_real(host, placement)
	if ok:
		_record(placement)
	return ok


## Real ads (AdMob). To switch on, when you're ready:
##   1. Create an AdMob account and app, and a Rewarded ad unit.
##   2. Install the Godot 4 AdMob plugin (e.g. Poing Studios'
##      "godot-admob-plugin") and enable it for the Android export.
##   3. Load a rewarded ad at start-up, show it here, and return true
##      in its "user earned reward" callback.
##   4. Set TEST_MODE to false.
## Until then this returns false, so nothing is given.
static func _show_real(_host: Node, _placement: String) -> bool:
	push_warning("Ads: real ads aren't set up yet (TEST_MODE is off)")
	return false


## Test mode: a full-screen fake ad with a countdown, then Claim.
## Closing early gives nothing, like a real rewarded ad.
static func _show_fake(host: Node, placement: String) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 125
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.get_tree().root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.97)
	layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _ad_label("ADVERTISEMENT (test)", 34, Color("f2d98a"))
	box.add_child(title)
	box.add_child(_ad_label("Watching for: %s" % str(PLACEMENTS.get(placement, [placement])[0]), 22, Color("c9d4e3")))
	var count := _ad_label("", 60, Color.WHITE)
	box.add_child(count)
	var claim := Button.new()
	claim.text = "Claim Reward"
	claim.custom_minimum_size = Vector2(360, 80)
	claim.add_theme_font_size_override("font_size", 28)
	claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	claim.visible = false
	box.add_child(claim)
	var close := Button.new()
	close.text = "Close (no reward)"
	close.flat = true
	close.add_theme_font_size_override("font_size", 20)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(close)

	var result := [0]    # 0 waiting, 1 claimed, 2 closed
	claim.pressed.connect(func(): result[0] = 1)
	close.pressed.connect(func(): result[0] = 2)
	var remaining := float(FAKE_AD_SECONDS)
	while result[0] == 0 and is_instance_valid(layer):
		if remaining > 0.0:
			count.text = str(ceili(remaining))
			remaining -= host.get_process_delta_time() if host.is_inside_tree() else 0.016
			if remaining <= 0.0:
				count.text = "Thank you!"
				claim.visible = true
		await host.get_tree().process_frame
	layer.queue_free()
	return result[0] == 1


static func _ad_label(value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# ---------------------------------------------------------
# HEAVENLY FORTUNE
# ---------------------------------------------------------

## The next Fortune reward (resolved amounts), or {} when done today.
static func next_fortune() -> Dictionary:
	var i := used("fortune")
	if i >= FORTUNE_REWARDS.size():
		return {}
	return FORTUNE_REWARDS[i]


## Gives a Fortune reward. Returns a short text of what was given.
static func give_fortune(reward: Dictionary) -> String:
	var parts := PackedStringArray()
	var items := {}
	for key in reward:
		match str(key):
			"jade":
				GameState.add_immortal_jade(int(reward[key]))
				parts.append("+%d Jade" % int(reward[key]))
			"stones_hours":
				var got: Dictionary = Missions._offline(float(reward[key]), false)
				GameState.add_spirit_stones(int(got["stones"]))
				parts.append("+%s Spirit Stones" % NumberFormat.short(int(got["stones"])))
			_:
				items[str(key)] = int(reward[key])
				parts.append("+%d %s" % [int(reward[key]), str(ItemDB.get_item(str(key)).get("name", key))])
	if not items.is_empty():
		GameState.add_items(items)
	GameState.save_game()
	return ", ".join(parts)


# ---------------------------------------------------------
# DAILY AD CHESTS
# ---------------------------------------------------------

## Ads watched today, all placements together.
static func total_today() -> int:
	var n := 0
	var u: Dictionary = _state()["used"]
	for k in u:
		n += int(u[k])
	return n


static func chest_claimed(index: int) -> bool:
	var claimed: Array = _state().get("chests", [])
	return claimed.has(index)


static func chest_ready(index: int) -> bool:
	return not chest_claimed(index) and total_today() >= int(AD_CHESTS[index][0])


## Opens a chest. Returns what was given ("" if it wasn't ready).
static func claim_chest(index: int) -> String:
	if not chest_ready(index):
		return ""
	var st := _state()
	var claimed: Array = st.get("chests", [])
	claimed.append(index)
	st["chests"] = claimed
	return give_fortune(AD_CHESTS[index][1])
