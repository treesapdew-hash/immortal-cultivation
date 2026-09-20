@tool
extends EditorScript

# =========================================================
# Partner data generator (editor tool). Save as
#   res://tools/generate_partner_data.gd
#
# Run it: open this script in the Script editor, then
#   File > Run   (or Ctrl + Shift + X)
#
# For every partner art folder in the tiers below
#   res://assets/partners/<tier>/<id>/
# that has no data file yet, it creates
#   res://data/partners/<tier>/<id>.tres
# with the id, a display name, the tier's rarity, a Dao, the
# default base stats (tier strength comes from Enums'
# RARITY_STAT_MULTIPLIER) and links to its card and sprite.
#
# Existing .tres files are NEVER changed. Run it again any time
# (e.g. after adding Gold and Prismatic to TIERS).
#
# Set DRY_RUN to true to only print what it would do.
# =========================================================

const ART_FOLDER := "res://assets/partners/"
const DATA_FOLDER := "res://data/partners/"

## Tiers to generate. Add "gold" and "prismatic" when their art is ready.
const TIERS := ["white", "blue", "green", "purple", "red", "gold", "prismatic"]

const DRY_RUN := false


func _run() -> void:
	var existing := _existing_ids()
	var daos: Array = Enums.Path.values()
	var dao_names: Array = Enums.Path.keys()
	var created := 0
	var skipped := 0
	var no_art := PackedStringArray()
	var dao_list := PackedStringArray()
	var next_dao := 0

	for tier in TIERS:
		var tier_key := str(tier).to_upper()
		if not Enums.Rarity.has(tier_key):
			push_warning("Unknown tier '%s' (not in Enums.Rarity)" % tier)
			continue
		var art_dir := ART_FOLDER + str(tier) + "/"
		var dir := DirAccess.open(art_dir)
		if dir == null:
			print("  (no art folder: %s)" % art_dir)
			continue

		var ids: Array = []
		for sub in dir.get_directories():
			if not str(sub).begins_with("."):
				ids.append(str(sub))
		ids.sort()

		for id in ids:
			if existing.has(id):
				skipped += 1
				continue

			var folder := art_dir + str(id) + "/"
			var card := _find(folder, str(id), "card")
			var sprite := _find(folder, str(id), "sprite")
			if card == "" and sprite == "":
				no_art.append("%s/%s" % [tier, id])

			var data := PartnerData.new()
			data.partner_id = str(id)
			data.display_name = _pretty(str(id))
			data.rarity = Enums.Rarity[tier_key]
			# Daos are spread evenly; check them afterwards
			data.path = daos[next_dao % daos.size()]
			dao_list.append("%s: %s" % [id, dao_names[next_dao % daos.size()]])
			next_dao += 1
			if card != "":
				data.card_texture = load(card) as Texture2D
			if sprite != "":
				data.sprite_texture = load(sprite) as Texture2D

			var out_dir := DATA_FOLDER + str(tier) + "/"
			var out_path := out_dir + str(id) + ".tres"
			if DRY_RUN:
				print("  would create %s" % out_path)
			else:
				DirAccess.make_dir_recursive_absolute(out_dir)
				var err := ResourceSaver.save(data, out_path)
				if err != OK:
					push_error("Could not save %s (error %d)" % [out_path, err])
					continue
			created += 1

	print("")
	print("=== Partner data generator ===")
	print("%s %d new partner file%s, skipped %d that already exist." % [
		"Would create" if DRY_RUN else "Created", created, "" if created == 1 else "s", skipped])
	if not no_art.is_empty():
		print("No card or sprite found for: " + ", ".join(no_art))
	if not dao_list.is_empty():
		print("Daos were assigned evenly. Check and fix these in the Inspector:")
		for line in dao_list:
			print("  " + line)
	if not DRY_RUN and created > 0:
		EditorInterface.get_resource_filesystem().scan()


## Every partner id that already has a data file, in any tier folder.
func _existing_ids() -> Dictionary:
	var ids := {}
	_collect(DATA_FOLDER, ids)
	return ids


func _collect(folder: String, ids: Dictionary) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not str(sub).begins_with("."):
			_collect(folder + str(sub) + "/", ids)
	for f in dir.get_files():
		var file := str(f)
		if file.ends_with(".tres") or file.ends_with(".res"):
			ids[file.get_basename()] = true


## <id>_card.png or card.png (either style), any capitalisation of .png.
func _find(folder: String, id: String, kind: String) -> String:
	for name_try in [id + "_" + kind, kind]:
		for ext in [".png", ".PNG", ".webp", ".jpg"]:
			var path := folder + str(name_try) + str(ext)
			if FileAccess.file_exists(path) or ResourceLoader.exists(path):
				if ext != ".png":
					push_warning("Rename to lowercase .png for Android: " + path)
				return path
	return ""


## "xiao_yan_youth" -> "Xiao Yan Youth"
func _pretty(id: String) -> String:
	var words := PackedStringArray()
	for w in id.split("_"):
		if w != "":
			words.append(w.capitalize())
	return " ".join(words)
