class_name Settings

# =========================================================
# Player settings. Save as
#   res://systems/settings.gd
#
# Kept in their own file (user://settings.cfg), separate from
# the game save, so resetting the account keeps them.
#
#   Settings.get_value("damage_numbers")   read a setting
#   Settings.set_value("fps", 60)          change, save and apply it
#   Settings.load_and_apply()              once at start-up
# =========================================================

const PATH := "user://settings.cfg"
const SECTION := "settings"

## Shown in Settings and bug reports. Keep this in step with each build.
const VERSION := "Alpha 0.1.0"

## Privacy policy page (app stores require one before launch).
## Your hosted legal pages (see the legal/ folder): replace with your real links.
const PRIVACY_URL := "https://treesapdew-hash.github.io/immortal-cultivation/legal/privacy.html"
const TERMS_URL := "https://treesapdew-hash.github.io/immortal-cultivation/legal/terms.html"
const DELETE_ACCOUNT_URL := "https://treesapdew-hash.github.io/immortal-cultivation/legal/delete-account.html"

## Every setting and its default.
const DEFAULTS := {
	# Gameplay
	"damage_numbers": true,
	"screen_effects": true,      # flashes and screen shake
	"stage_banner": "full",      # full / short / off
	"fast_ceremony": false,      # breakthrough ceremony skips straight to the result
	"short_god": false,          # god's turn: strike only, no portrait or title
	# Audio (0-100)
	"music_volume": 80,
	"sfx_volume": 80,
	"mute": false,
	# Performance
	"fps": 60,                   # 30 or 60
	# Account
	"player_id": "",
}

static var _values := {}
static var _loaded := false


static func load_and_apply() -> void:
	_load()
	apply()


static func get_value(key: String) -> Variant:
	_load()
	return _values.get(key, DEFAULTS.get(key))


static func is_on(key: String) -> bool:
	return bool(get_value(key))


static func set_value(key: String, value: Variant) -> void:
	_load()
	_values[key] = value
	_save()
	apply()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in DEFAULTS:
			if cfg.has_section_key(SECTION, key):
				_values[key] = cfg.get_value(SECTION, key)
	if str(_values["player_id"]) == "":
		_values["player_id"] = _new_player_id()
		_save()


static func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value(SECTION, key, _values[key])
	cfg.save(PATH)


## Frame rate and audio, applied straight away.
static func apply() -> void:
	Engine.max_fps = int(get_value("fps"))
	var mute := is_on("mute")
	_set_bus("Master", 100, mute)
	_set_bus("Music", int(get_value("music_volume")), false)
	_set_bus("SFX", int(get_value("sfx_volume")), false)


## Sets a bus volume if the bus exists (add "Music" and "SFX" buses
## when sound arrives; until then only Master is used).
static func _set_bus(bus_name: String, volume: int, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, mute or volume <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(volume) / 100.0, 0.001)))


## Short random id like "IC-7F3A-92C1", made once per install.
static func _new_player_id() -> String:
	var hex := "%08X" % (randi() & 0x7FFFFFFF)
	return "IC-%s-%s" % [hex.substr(0, 4), hex.substr(4, 4)]


# ---------------------------------------------------------
# BUG REPORT
# ---------------------------------------------------------

## Everything useful for a bug report, ready to paste.
static func bug_report() -> String:
	var mc := GameState.get_mc()
	var lines := PackedStringArray([
		"Immortal Cultivation bug report",
		"Version: %s" % VERSION,
		"Player ID: %s" % str(get_value("player_id")),
		"Device: %s %s (%s)" % [OS.get_name(), OS.get_version(), OS.get_model_name()],
		"Stage: %d (highest %d)" % [GameState.current_stage, GameState.highest_stage],
		"MC realm: %s" % (mc.get_realm_text() if mc != null else "-"),
		"Time: %s" % Time.get_datetime_string_from_system(),
		"",
		"What happened:",
		"",
		"",
		"Recent log:",
	])
	lines.append_array(_recent_log(25))
	return "\n".join(lines)


## The last lines of Godot's log file, if logging is on.
static func _recent_log(count: int) -> PackedStringArray:
	var out := PackedStringArray()
	var path := "user://logs/godot.log"
	if not FileAccess.file_exists(path):
		out.append("(no log file)")
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out.append("(log unreadable)")
		return out
	var all := f.get_as_text().split("\n")
	for i in range(maxi(0, all.size() - count), all.size()):
		out.append(all[i])
	return out
