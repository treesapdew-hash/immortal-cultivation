extends Node

# =========================================================
# AUTOLOAD. Register in Project Settings as "PartnerDatabase".
#
# Scans res://data/partners/ at startup and loads every .tres
# it finds. Adding partner number 200 means dropping a file in
# that folder -- no code changes anywhere.
# =========================================================


const PARTNER_FOLDER := "res://data/partners/"


# partner_id -> PartnerData
var _partners: Dictionary = {}


func _ready():
	_load_all_partners()

	print("PartnerDatabase: loaded %d partners" % _partners.size())


func _load_all_partners():
	_partners.clear()

	var dir = DirAccess.open(PARTNER_FOLDER)

	if dir == null:
		push_error("PartnerDatabase: cannot open " + PARTNER_FOLDER)
		return

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":

		# Exported builds rename .tres to .res, so accept both.
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			_load_partner_file(PARTNER_FOLDER + file_name)

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

	if data.partner_id.is_empty():
		push_error("PartnerDatabase: empty partner_id in " + path)
		return

	if _partners.has(data.partner_id):
		push_error("PartnerDatabase: duplicate id '%s'" % data.partner_id)
		return

	_partners[data.partner_id] = data


# ---------------------------------------------------------
# QUERIES
# ---------------------------------------------------------

func get_partner(partner_id: String) -> PartnerData:
	if not _partners.has(partner_id):
		push_warning("PartnerDatabase: unknown id '%s'" % partner_id)
		return null

	return _partners[partner_id]


func has_partner(partner_id: String) -> bool:
	return _partners.has(partner_id)


func get_all_ids() -> Array:
	return _partners.keys()


func get_all() -> Array:
	return _partners.values()


## Used by the gacha later -- spec section 19 caps normal
## summons at the lower rarities.
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
