class_name Showcase

# =========================================================
# What other cultivators see of you. Save as
#   res://systems/showcase.gd
#
# A public snapshot of your team and their equipment, stored on
# your profile (setup_11_showcase.sql) so every surface showing a
# name can offer an Inspect: World chat, Whispers, friends, sect
# member lists, the Arena and its board.
#
# Display only. Nothing here is read back into anyone's save, so a
# tampered showcase makes someone look impressive and does nothing
# else. Real stats for a fight come from the Arena snapshot.
# =========================================================

## Gear slots, in the order they are worn.
const SLOTS := 4


static func available() -> bool:
	return Backend.is_configured()


# ---------------------------------------------------------
# BUILDING YOUR OWN
# ---------------------------------------------------------

## Your formation and what each of them is wearing.
static func build() -> Dictionary:
	var team: Array = []
	for index in GameState.formation:
		var i := int(index)
		if i < 0 or i >= GameState.roster.size():
			continue
		var p = GameState.roster[i]
		if p == null:
			continue
		team.append(_entry(p))
	return {
		"team": team,
		"array": _battle_array_names(),
		"built": GameState.now_unix(),
	}


static func _entry(p) -> Dictionary:
	var data = p.get_data()
	var entry := {
		"partner_id": p.partner_id,
		"name": p.get_display_name(),
		"rarity": int(data.rarity) if data != null else -1,
		"stars": p.stars,
		"realm": p.get_realm_text(),
		"power": p.get_power(),
		"gear": [],
	}
	for slot in SLOTS:
		var item: Dictionary = GameState.gear_in_slot(p.partner_id, slot)
		if item.is_empty():
			continue
		entry["gear"].append({
			"slot": slot,
			"name": Gear.item_name(item),
			"tier": int(item.get("tier", 0)),
			"sub": int(item.get("sub", 0)),
			"refine": int(item.get("refine", 0)),
			"set": str(item.get("set", "")),
		})
	return entry


## The names of the partners lending strength from the bench.
static func _battle_array_names() -> Array:
	var out: Array = []
	for id in GameState.battle_array:
		var owned = GameState.find_owned(str(id))
		if owned != null:
			out.append(owned.get_display_name())
	return out


# Nothing uploads this on its own: Backend.update_profile() writes
# the column in the same upsert that refreshes name, realm and
# power, so the snapshot rides along with every profile sync.


# ---------------------------------------------------------
# READING SOMEONE ELSE'S
# ---------------------------------------------------------

## The titles the server has awarded this player (Arena placements,
## tester codes). Merged into what they already hold.
static func pull_titles() -> Array:
	if not available():
		return []
	var r: Dictionary = await Backend.call_fn("my_titles", {})
	if not r["ok"] or not (r["data"] is Array):
		return []
	# Replaces rather than merges: a placement that has run out on the
	# server has to stop counting here too.
	return Titles.sync_server(r["data"])


## {id, name, realm, stage, power, title, showcase} or {} if they are
## blocked, gone, or have never synced.
static func fetch(user_id: String) -> Dictionary:
	if user_id == "" or not available():
		return {}
	var r: Dictionary = await Backend.call_fn("get_showcase", {"p_user": user_id})
	return r["data"] if r["ok"] and r["data"] is Dictionary else {}


## "Peak-grade Immortal Artifact +12" for one entry of a fetched
## showcase. Clamped, because this came off someone else's profile.
static func gear_text(g: Dictionary) -> String:
	var tier := clampi(int(g.get("tier", 0)), 0, Gear.TIER_NAMES.size() - 1)
	var sub := clampi(int(g.get("sub", 0)), 0, Gear.SUB_NAMES.size() - 1)
	var text := "%s %s" % [str(Gear.SUB_NAMES[sub]), str(Gear.TIER_NAMES[tier])]
	var refine := clampi(int(g.get("refine", 0)), 0, Gear.MAX_REFINE)
	return text + (" +%d" % refine if refine > 0 else "")


## The colour of a fetched entry's tier.
static func gear_color(g: Dictionary) -> Color:
	return ItemDB.grade_color(clampi(int(g.get("tier", 0)), 0, Gear.TIER_NAMES.size() - 1))


static func slot_name(slot: int) -> String:
	var i := clampi(slot, 0, Gear.SLOT_NAMES.size() - 1)
	return str(Gear.SLOT_NAMES[i])
