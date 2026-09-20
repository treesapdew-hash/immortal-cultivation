extends Container

# Shows the MC's cultivation in the top bar and updates it
# whenever the MC ascends. Long cultivation names shrink to fit.
#
# The biggest font size is whatever you set on each label in the
# editor (its Label Settings, or its theme font size override).
# Text only ever shrinks from there, down to min_font_size.

## Optional: one emblem per major realm (Mortal, Spirit, Sovereign, Immortal)
@export var major_emblems: Array[Texture2D] = []

## Smallest font size the text may shrink to
@export var min_font_size := 12

@onready var realm_label: Label = $MarginContainer/RealmLabel
@onready var cultivation_label: Label = $MarginContainer2/CultivationLabel
@onready var realm_emblem: TextureRect = $EmblemSlot/RealmEmblem

# label -> its original (largest) font size
var _base_sizes := {}


func _ready() -> void:
	# Only the cultivation text is fitted. The major realm names are
	# short, and its box sizes itself from its text, so clipping it
	# would squash it to nothing.
	for label in [cultivation_label]:
		# Without this, a Label's minimum width grows with its text,
		# so it always "fits" and never shrinks -- it just gets cut off.
		label.clip_text = true

		# Labels with Label Settings ignore theme font size overrides,
		# so give each one its own copy we can resize freely.
		if label.label_settings != null:
			label.label_settings = label.label_settings.duplicate()

		_base_sizes[label] = _get_font_size(label)
		label.resized.connect(_fit_label.bind(label))

	GameState.realm_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var mc: OwnedPartner = GameState.get_mc()
	if mc == null:
		return

	realm_label.text = mc.get_major_realm_text()
	cultivation_label.text = mc.get_realm_text()

	var major := Realms.get_major(mc.realm_index)
	if major < major_emblems.size() and major_emblems[major] != null:
		realm_emblem.texture = major_emblems[major]

	# Wait one frame so the labels have their final width
	await get_tree().process_frame
	_fit_label(cultivation_label)


## Shrinks a label's font until its text fits the label's width.
func _fit_label(label: Label) -> void:
	var width := label.size.x
	var font := _get_font(label)
	if font == null or width <= 0:
		return

	var text := label.text
	if label.uppercase:
		text = text.to_upper()

	# Outlines and a little breathing room make text wider than
	# the plain measurement says.
	var padding := 6.0 + _get_outline_size(label)

	var font_size: int = _base_sizes.get(label, 22)
	while font_size > min_font_size and \
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + padding > width:
		font_size -= 1

	_set_font_size(label, font_size)


# ---------------------------------------------------------
# Helpers that work with or without Label Settings
# ---------------------------------------------------------

func _get_font(label: Label) -> Font:
	var ls := label.label_settings
	if ls != null and ls.font != null:
		return ls.font
	return label.get_theme_font("font")


func _get_font_size(label: Label) -> int:
	if label.label_settings != null:
		return label.label_settings.font_size
	return label.get_theme_font_size("font_size")


func _get_outline_size(label: Label) -> float:
	if label.label_settings != null:
		return label.label_settings.outline_size
	return label.get_theme_constant("outline_size")


func _set_font_size(label: Label, font_size: int) -> void:
	# Only change it when needed, so resizing can't loop forever.
	if _get_font_size(label) == font_size:
		return

	if label.label_settings != null:
		label.label_settings.font_size = font_size
	else:
		label.add_theme_font_size_override("font_size", font_size)
