class_name Unlocks

# =========================================================
# Feature unlocks. Save as res://systems/unlocks.gd
#
# Every feature opens at a highest-stage or MC-realm milestone, so
# new players meet systems one at a time. Locked tabs are dimmed
# and say what opens them; a banner announces each new unlock
# (and the tutorial for it starts, see Tutorial).
#
# FEATURES: id -> [name, stage needed, realm index needed (-1 none),
#                  where it lives ("nav:Growth", "quick:Guild",
#                  "growth:Forge", "events:beast_forest"...), blurb]
# Tune by editing the numbers.
# =========================================================

const FEATURES := {
	"inventory": ["Inventory", 5, -1, "quick:Inventory", "Your items, pills and materials."],
	"missions": ["Missions", 10, -1, "nav:Mission", "Daily and weekly tasks with chests of rewards."],
	"growth": ["Growth", 20, -1, "nav:Growth", "Your cave abode and expeditions."],
	"forge": ["Forge", 40, -1, "growth:Forge", "Forge and refine equipment."],
	"codex": ["Codex", 30, -1, "nav:Codex", "Every partner, beast and treasure, with set bonuses."],
	"events": ["Events", 50, -1, "nav:Events", "Dungeons and daily challenges."],
	"achievements": ["Achievements", 50, -1, "mission:Achievements", "Long-term goals with rewards."],
	"beast_forest": ["Beast Forest", 120, -1, "events:beast_forest", "Hunt spirit beasts for Soul Spirits and rings."],
	"trials": ["Daily Trials", 150, -1, "events:trials", "A themed challenge every day."],
	"guild": ["Sects", 200, -1, "quick:Guild", "Join a sect: daily duties, research, a shop and the Sect Trial."],
	"arena": ["Arena", 75, -1, "events:arena", "Duel other cultivators of your realm for rank and Arena Tokens."],
	"battle_array": ["Battle Array", 300, -1, "growth:Array", "Bench partners lend their strength to your team."],
	"tribulation": ["Tribulation Lightning", 500, -1, "events:tribulation", "Endure the heavens' lightning for rewards."],
	"god_path": ["God Path", 0, 9, "growth:God Path", "Walk the path of a god; the Fallen God descends."],
}


static func is_unlocked(id: String) -> bool:
	if not FEATURES.has(id):
		return true
	var f: Array = FEATURES[id]
	if GameState.highest_stage < int(f[1]):
		return false
	if int(f[2]) >= 0:
		var mc := GameState.get_mc()
		if mc == null or mc.realm_index < int(f[2]):
			return false
	return true


## The feature behind a place ("nav:Growth", "growth:Forge"...), or "".
static func feature_at(place: String) -> String:
	for id in FEATURES:
		if str(FEATURES[id][3]) == place:
			return str(id)
	return ""


## True if nothing locks this place.
static func place_open(place: String) -> bool:
	var id := feature_at(place)
	return id == "" or is_unlocked(id)


static func feature_name(id: String) -> String:
	return str(FEATURES[id][0]) if FEATURES.has(id) else id


## "Unlocks at Stage 200" / "Unlocks at Ascendant 1"
static func requirement_text(id: String) -> String:
	if not FEATURES.has(id):
		return ""
	var f: Array = FEATURES[id]
	if int(f[2]) >= 0:
		return "%s unlocks at %s." % [f[0], str(Realms.get_label(int(f[2]), 1))]
	return "%s unlocks at Stage %d." % [f[0], int(f[1])]


## Features that just unlocked (not announced yet). Marks them seen.
## Players who already passed them when this system arrived aren't
## flooded: everything already open is marked seen silently once.
static func check_new() -> Array:
	var seen: Dictionary = GameState.unlocks_seen
	var first_time := not seen.has("_init")
	var out: Array = []
	for id in FEATURES:
		if is_unlocked(str(id)) and not seen.has(str(id)):
			seen[str(id)] = true
			if not first_time or GameState.highest_stage <= 1:
				out.append(str(id))
	if first_time:
		seen["_init"] = true
	if not out.is_empty() or first_time:
		GameState.save_game()
	return out


## A short message floating over a screen ("Sects unlocks at Stage 200.").
static func toast(host: Control, message: String) -> void:
	var l := Label.new()
	l.text = message
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("ffd36b"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.top_level = true
	l.z_index = 100
	host.add_child(l)
	var r := host.get_global_rect()
	l.size = Vector2(r.size.x, 44)
	l.global_position = Vector2(r.position.x, r.position.y + r.size.y * 0.45)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 50.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(1.1)
	tw.tween_callback(l.queue_free)


## A big "NEW!  Sects unlocked" banner across a screen.
static func announce(host: Control, id: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 58
	host.add_child(layer)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var vp := host.get_viewport_rect().size
	box.size = Vector2(vp.x, 200)
	box.position = Vector2(0, vp.y * 0.32)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.6)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(vp.x, 200)
	band.position = box.position
	layer.add_child(band)
	layer.move_child(band, 0)
	for entry in [["NEW!", 30, Color("7dffa8")], ["%s unlocked" % feature_name(id), 46, Color("f2d98a")],
			[str(FEATURES[id][4]) if FEATURES.has(id) else "", 20, Color("c9d4e3")]]:
		var l := Label.new()
		l.text = str(entry[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(entry[1]))
		l.add_theme_color_override("font_color", entry[2])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		box.add_child(l)
	box.modulate.a = 0.0
	band.modulate.a = 0.0
	var tw := layer.create_tween().set_parallel()
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_property(band, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(2.0)
	tw.chain().tween_property(box, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(band, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(layer.queue_free)
