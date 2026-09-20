class_name DaoIcons

# Badge PNGs, named after each Dao in Enums.Path (lowercase):
# divine.png, spirit.png, mystic.png, sword.png, martial.png
const FOLDER := "res://assets/dao/"


static func get_icon(dao) -> Texture2D:
	if dao == null:
		return null

	# Path is stored as an enum number, so turn it into its name first.
	var key := ""
	if dao is int:
		var names = Enums.Path.keys()
		if dao < 0 or dao >= names.size():
			return null
		key = str(names[dao]).to_lower()
	else:
		key = str(dao).to_lower()

	var path := FOLDER + key + ".png"
	if ResourceLoader.exists(path):
		return load(path)

	push_warning("DaoIcons: no badge at " + path)
	return null
