extends Button

# One group shared by every slot, so only one can be selected at a time
static var slot_group := ButtonGroup.new()

# Untick in the Inspector to keep the test art visible on a slot
@export var start_empty := true

@export_group("Stars")
@export var star_empty: Texture2D                  # star_gray
@export var star_tiers: Array[Texture2D] = []      # blue, green, red, gold (in order)
@export_range(0, 20) var preview_stars := 7        # for testing when start_empty is off

@export_group("Tier Frames")
## Square slot frames in order: white, blue, green, purple, red, gold, prismatic
@export var tier_frames: Array[Texture2D] = []

@onready var portrait: TextureRect = $PortraitWindow/Portrait
@onready var frame_overlay: TextureRect = $FrameOverlay
@onready var path_badge: TextureRect = $PathBadge
@onready var stars: HBoxContainer = $Stars
@onready var realm_label: Label = $RealmLabel
@onready var empty_icon: TextureRect = $EmptyIcon
@onready var select_glow: TextureRect = $SelectGlow


func _ready() -> void:
	# Remove the button's own background in every state
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus",
			"normal_mirrored", "hover_mirrored", "pressed_mirrored",
			"hover_pressed_mirrored", "disabled_mirrored"]:
		add_theme_stylebox_override(s, empty)

	# Only one slot selected at a time
	toggle_mode = true
	button_group = slot_group

	# Glow on hover and selection
	toggled.connect(_on_toggled)
	mouse_entered.connect(_update_glow)
	mouse_exited.connect(_update_glow)
	_update_glow()

	if start_empty:
		set_partner(null)
	else:
		set_stars(preview_stars)


func _on_toggled(_on: bool) -> void:
	_update_glow()


func _update_glow() -> void:
	if button_pressed:
		select_glow.visible = true
		select_glow.modulate.a = 1.0   # selected: full glow
	elif is_hovered():
		select_glow.visible = true
		select_glow.modulate.a = 0.4   # hovered: faint glow
	else:
		select_glow.visible = false


# Shows 0-20 stars on the 5 icons.
# Each colour covers 5 stars: blue 1-5, green 6-10, red 11-15, gold 16-20.
func set_stars(count: int) -> void:
	var per_tier := 5
	count = clampi(count, 0, per_tier * star_tiers.size())

	var tier := 0       # which colour is being filled
	var filled := 0     # how many icons show that colour
	if count > 0:
		tier = int((count - 1) / float(per_tier))
		filled = count - tier * per_tier

	for i in stars.get_child_count():
		var star_icon: TextureRect = stars.get_child(i)
		if i < filled:
			star_icon.texture = star_tiers[tier]
		elif tier > 0:
			star_icon.texture = star_tiers[tier - 1]   # previous colour
		else:
			star_icon.texture = star_empty


# Swaps the frame to match a tier. Empty entries keep the current frame.
func set_tier_frame(rarity: int) -> void:
	var i := Realms.tier_index(rarity)
	if i < tier_frames.size() and tier_frames[i] != null:
		frame_overlay.texture = tier_frames[i]


# Fill the slot with an owned partner, or pass null to show it as empty
func set_partner(p: OwnedPartner) -> void:
	var data: PartnerData = null
	if p != null:
		data = p.get_data()

	var has: bool = data != null
	portrait.visible = has
	path_badge.visible = has
	stars.visible = has
	realm_label.visible = has
	empty_icon.visible = not has

	# Uncomment to make empty slots unclickable
	# disabled = not has

	if not has:
		if tier_frames.size() > 0 and tier_frames[0] != null:
			frame_overlay.texture = tier_frames[0]
		return

	set_tier_frame(data.rarity)
	portrait.texture = data.get_portrait()
	realm_label.text = p.get_realm_text()
	set_stars(p.stars)

	var badge := DaoIcons.get_icon(data.path)
	path_badge.texture = badge
	path_badge.visible = badge != null
