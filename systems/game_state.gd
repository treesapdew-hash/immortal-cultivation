extends Node

# =========================================================
# AUTOLOAD. Register in Project Settings as "GameState".
#
# Everything the player owns and has progressed. This is the
# save file. Nothing else in the game should store player
# progress -- if a screen needs to know how many spirit stones
# there are, it asks here.
# =========================================================


signal currency_changed
signal formation_changed
signal stage_changed
signal roster_changed


const SAVE_PATH := "user://save_game.json"

const FORMATION_SIZE := 6

const MAX_STAGE := 10000


# ---------------------------------------------------------
# PLAYER ACCOUNT
# ---------------------------------------------------------

var player_name: String = "Cultivator"

## The player's own cultivation (spec sections 4 and 5).
var realm_index: int = 0
var tier: int = 1

var highest_stage: int = 1
var current_stage: int = 1


# ---------------------------------------------------------
# CURRENCIES  (spec section 13)
# ---------------------------------------------------------

var spirit_stones: int = 1000
var immortal_jade: int = 1000


# ---------------------------------------------------------
# ROSTER AND FORMATION
# ---------------------------------------------------------

## Every partner the player owns.
var roster: Array[OwnedPartner] = []

## Six slots. Holds indices into roster, or -1 for empty.
## Slot order matters -- it drives turn order and lane
## targeting (spec sections 36 and 37).
var formation: Array[int] = [-1, -1, -1, -1, -1, -1]


func _ready():
	if not load_game():
		_create_new_account()


# ---------------------------------------------------------
# NEW ACCOUNT
# ---------------------------------------------------------

func _create_new_account():
	print("GameState: creating new account")

	# Give the player a starting team from whatever partners
	# exist in the database.
	var starter_ids = PartnerDatabase.get_all_ids()

	starter_ids.sort()

	for i in range(mini(FORMATION_SIZE, starter_ids.size())):
		var id = starter_ids[i]

		add_partner(id)

		formation[i] = i

	save_game()


# ---------------------------------------------------------
# ROSTER
# ---------------------------------------------------------

func add_partner(partner_id: String) -> OwnedPartner:
	var data = PartnerDatabase.get_partner(partner_id)

	if data == null:
		return null

	var partner = OwnedPartner.create_new(partner_id, data)

	roster.append(partner)

	roster_changed.emit()

	return partner


func get_partner_in_slot(slot: int) -> OwnedPartner:
	if slot < 0 or slot >= FORMATION_SIZE:
		return null

	var roster_index = formation[slot]

	if roster_index < 0 or roster_index >= roster.size():
		return null

	return roster[roster_index]


## Returns the six formation members, with nulls for empty slots.
func get_formation_partners() -> Array:
	var result: Array = []

	for slot in range(FORMATION_SIZE):
		result.append(get_partner_in_slot(slot))

	return result


func set_formation_slot(slot: int, roster_index: int):
	if slot < 0 or slot >= FORMATION_SIZE:
		return

	# A partner cannot occupy two slots at once.
	for i in range(FORMATION_SIZE):
		if formation[i] == roster_index and i != slot:
			formation[i] = -1

	formation[slot] = roster_index

	formation_changed.emit()

	save_game()


func get_team_power() -> int:
	var total = 0

	for partner in get_formation_partners():
		if partner != null:
			total += partner.get_power()

	return total


# ---------------------------------------------------------
# CURRENCY
# ---------------------------------------------------------

func add_spirit_stones(amount: int):
	spirit_stones = maxi(0, spirit_stones + amount)
	currency_changed.emit()


func add_immortal_jade(amount: int):
	immortal_jade = maxi(0, immortal_jade + amount)
	currency_changed.emit()


func spend_spirit_stones(amount: int) -> bool:
	if spirit_stones < amount:
		return false

	spirit_stones -= amount
	currency_changed.emit()

	return true


func spend_immortal_jade(amount: int) -> bool:
	if immortal_jade < amount:
		return false

	immortal_jade -= amount
	currency_changed.emit()

	return true


# ---------------------------------------------------------
# STAGE PROGRESS
# ---------------------------------------------------------

func advance_stage():
	if current_stage >= MAX_STAGE:
		return

	current_stage += 1

	highest_stage = maxi(highest_stage, current_stage)

	stage_changed.emit()

	save_game()


func get_realm_text() -> String:
	return Enums.format_realm(realm_index, tier)


# ---------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------

func to_dict() -> Dictionary:
	var roster_data: Array = []

	for partner in roster:
		roster_data.append(partner.to_dict())

	return {
		"version": 1,
		"player_name": player_name,
		"realm_index": realm_index,
		"tier": tier,
		"highest_stage": highest_stage,
		"current_stage": current_stage,
		"spirit_stones": spirit_stones,
		"immortal_jade": immortal_jade,
		"roster": roster_data,
		"formation": formation
	}


func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("GameState: could not write save file")
		return

	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return false

	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if parsed == null or not parsed is Dictionary:
		push_error("GameState: save file is corrupt")
		return false

	var dict: Dictionary = parsed

	player_name   = dict.get("player_name", "Cultivator")
	realm_index   = dict.get("realm_index", 0)
	tier          = dict.get("tier", 1)
	highest_stage = dict.get("highest_stage", 1)
	current_stage = dict.get("current_stage", 1)
	spirit_stones = dict.get("spirit_stones", 1000)
	immortal_jade = dict.get("immortal_jade", 1000)

	roster.clear()

	for entry in dict.get("roster", []):
		roster.append(OwnedPartner.from_dict(entry))

	formation = [-1, -1, -1, -1, -1, -1]

	var saved_formation = dict.get("formation", [])

	for i in range(mini(FORMATION_SIZE, saved_formation.size())):
		formation[i] = int(saved_formation[i])

	print("GameState: loaded save with %d partners" % roster.size())

	return true


## Wipes the save. Handy while testing.
func reset_account():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	roster.clear()
	formation = [-1, -1, -1, -1, -1, -1]

	realm_index = 0
	tier = 1
	current_stage = 1
	highest_stage = 1
	spirit_stones = 1000
	immortal_jade = 1000

	_create_new_account()

	roster_changed.emit()
	formation_changed.emit()
	currency_changed.emit()
