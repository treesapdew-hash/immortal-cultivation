extends Node

# =========================================================
# AUTOLOAD. Register in Project Settings as "PartnerDatabase".
#
# Scans res://data/partners/ and every subfolder (white/, blue/,
# ... prismatic/) at startup and loads every .tres it finds.
#
# The partner ID is the file's partner_id. If that is empty,
# the file name is used instead (han_li_child.tres -> han_li_child).
#
# Special partners (the MC) are registered from code and are
# kept separate, so they never appear in summons or starter lists.
#
# Art: if a card or sprite texture isn't set in the .tres, it is
# loaded from the standard place:
#   res://assets/partners/<tier>/<id>/<id>_card.png
#   res://assets/partners/<tier>/<id>/<id>_sprite.png
# Partners with no art at all are listed in the Output panel.
# =========================================================


const PARTNER_FOLDER := "res://data/partners/"
const ART_FOLDER := "res://assets/partners/"


# partner_id -> PartnerData
var _partners: Dictionary = {}
var _special: Dictionary = {}
var _missing_art := PackedStringArray()


func _ready():
	_load_all_partners()

	print("PartnerDatabase: loaded %d partners" % _partners.size())
	if not _missing_art.is_empty():
		push_warning("PartnerDatabase: missing art for " + ", ".join(_missing_art))


func _load_all_partners():
	_partners.clear()
	_missing_art.clear()
	_scan_folder(PARTNER_FOLDER)


func _scan_folder(folder: String):
	var dir = DirAccess.open(folder)

	if dir == null:
		push_error("PartnerDatabase: cannot open " + folder)
		return

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_folder(folder + file_name + "/")

		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			_load_partner_file(folder + file_name)

		elif file_name.ends_with(".tres.remap"):
			_load_partner_file(folder + file_name.trim_suffix(".remap"))

		file_name = dir.get_next()

	dir.list_dir_end()


func _load_partner_file(path: String):
	var resource = load(path)

	if resource == null:
		push_error("PartnerDatabase: failed to load " + path)
		return

	if not resource is PartnerData:
		push_error("PartnerDatabase: not a PartnerData: " + path)
		return

	var data: PartnerData = resource
	var file_id := path.get_file().get_basename()

	if data.partner_id.is_empty():
		data.partner_id = file_id

	elif data.partner_id != file_id:
		push_warning("PartnerDatabase: '%s' has partner_id '%s' (expected '%s')"
			% [path, data.partner_id, file_id])

	if _partners.has(data.partner_id):
		push_error("PartnerDatabase: duplicate id '%s' in %s" % [data.partner_id, path])
		return

	_fill_missing_art(data)
	_partners[data.partner_id] = data


## Loads card/sprite art from the standard folder if the .tres left them empty.
func _fill_missing_art(data: PartnerData) -> void:
	var tier := str(Enums.Rarity.keys()[data.rarity]).to_lower()
	var id := data.partner_id
	var folder := ART_FOLDER + tier + "/" + id + "/"

	if data.card_texture == null:
		data.card_texture = _try_load([folder + id + "_card.png", folder + "card.png"])
	if data.sprite_texture == null:
		data.sprite_texture = _try_load([folder + id + "_sprite.png", folder + "sprite.png"])

	var missing := PackedStringArray()
	if data.card_texture == null:
		missing.append("card")
	if data.sprite_texture == null:
		missing.append("sprite")
	if not missing.is_empty():
		_missing_art.append("%s (%s)" % [id, " + ".join(missing)])


func _try_load(paths: Array) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Registers a partner built in code (the MC). Replaces any
## previous one with the same id.
func register_special(data: PartnerData) -> void:
	_special[data.partner_id] = data


# ---------------------------------------------------------
# QUERIES
# ---------------------------------------------------------

func get_partner(partner_id: String) -> PartnerData:
	if _special.has(partner_id):
		return _special[partner_id]

	if not _partners.has(partner_id):
		push_warning("PartnerDatabase: unknown id '%s'" % partner_id)
		return null

	return _partners[partner_id]


func has_partner(partner_id: String) -> bool:
	return _special.has(partner_id) or _partners.has(partner_id)


## Card partners only (never includes the MC).
func get_all_ids() -> Array:
	return _partners.keys()


func get_all() -> Array:
	return _partners.values()


func get_by_rarity(rarity: Enums.Rarity) -> Array:
	var result: Array = []

	for data in _partners.values():
		if data.rarity == rarity:
			result.append(data)

	return result


func get_by_path(path: Enums.Path) -> Array:
	var result: Array = []

	for data in _partners.values():
		if data.path == path:
			result.append(data)

	return result
