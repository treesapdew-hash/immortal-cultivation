@tool
extends EditorScript

# =========================================================
# Apply partner Daos (editor tool). Save as
#   res://tools/apply_partner_daos.gd
#
# Run it: open in the Script editor, then File > Run (Ctrl+Shift+X).
#
# Sets the Dao ("path") in every partner .tres under
# res://data/partners/ to the one chosen in PartnerSkills.FAMILIES.
# Only the Dao changes; partners not listed there are left alone.
# Set DRY_RUN to true to only print what would change.
# =========================================================

const DATA_FOLDER := "res://data/partners/"
const DRY_RUN := false


func _run() -> void:
	var names: Array = Enums.Path.keys()
	var changed := PackedStringArray()
	var unlisted := PackedStringArray()
	var files: Array = []
	_collect(DATA_FOLDER, files)

	for path in files:
		var data := load(str(path)) as PartnerData
		if data == null:
			continue
		var id := data.partner_id if data.partner_id != "" else str(path).get_file().get_basename()
		var dao := PartnerSkills.dao_for(id)
		if dao < 0:
			unlisted.append(id)
			continue
		if int(data.path) == dao:
			continue
		changed.append("%s: %s -> %s" % [id, names[int(data.path)], names[dao]])
		if not DRY_RUN:
			data.path = dao as Enums.Path
			var err := ResourceSaver.save(data, str(path))
			if err != OK:
				push_error("Could not save %s (error %d)" % [path, err])

	print("")
	print("=== Apply partner Daos ===")
	print("%s %d partner%s." % ["Would change" if DRY_RUN else "Changed", changed.size(), "" if changed.size() == 1 else "s"])
	for line in changed:
		print("  " + line)
	if not unlisted.is_empty():
		print("Not in PartnerSkills (left as they are): " + ", ".join(unlisted))


func _collect(folder: String, out: Array) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not str(sub).begins_with("."):
			_collect(folder + str(sub) + "/", out)
	for f in dir.get_files():
		var file := str(f)
		if file.ends_with(".tres"):
			out.append(folder + file)
