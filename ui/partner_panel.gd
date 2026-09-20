extends Control

# Shows one owned partner (or the MC). Tapping a formation slot
# shows that unit here. Ascend and Awaken are test versions for
# now (no costs yet).

@export var slot_row: Node                          # optional; found automatically if empty

@export_group("Costs")
## Label for your Qi ("Qi 1,250 / 3,400"). Uses QiLabel if left empty.
@export var ascend_cost_label: Label
## Optional label for Awaken costs ("3 / 5 pills").
@export var awaken_cost_label: Label
@export var qi_bar_color := Color("5fd8f0")
@export var pill_bar_color := Color("e8a23a")
@export var pip_color := Color("f2c85b")
@export var bar_height := 4.0
@export var bar_inset := 18.0
@export var bar_bottom := 6.0
@export var toast_font_size := 26

@export_group("MC Team Bonus")
## Optional label showing the MC's team bonus. Hidden for partners.
@export var team_bonus_label: Label

@export_group("Rename")
## Optional custom edit button. If empty, a pencil icon is added
## next to the MC's name automatically.
@export var rename_button: BaseButton
## Optional pencil image for the automatic icon (built-in one otherwise).
@export var rename_icon_texture: Texture2D
@export var rename_icon_color := Color("e0b85a")
## Shown in the rename popup next to the cost.
@export var jade_icon: Texture2D
@export_group("")

@export_group("Stars")
@export var star_empty: Texture2D                   # star_gray
@export var star_tiers: Array[Texture2D] = []       # blue, green, red, gold

@export_group("Card Frames")
## Tall card frames in order: white, blue, green, purple, red, gold, prismatic
@export var card_tier_frames: Array[Texture2D] = []

@export_group("Stat Rows")
@export var stat_font_size := 22
@export var name_width := 150
@export var bullet_color := Color("5fd0e8")
@export var realm_color := Color("5fd0e8")

@onready var card: Control = %PartnerCard
@onready var card_art: TextureRect = card.get_node("%CardArt")
@onready var dao_badge: TextureRect = card.get_node("%DaoBadge")
@onready var card_frame: TextureRect = card.get_node("Frame")
@onready var name_label: Label = %NameLabel
@onready var realm_label = %RealmLabel      # untyped: Label or RichTextLabel both work
@onready var stars: HBoxContainer = %Stars
@onready var qi_label: Label = %QiLabel   # was PowerLabel; Power is hidden (PvP only)
@onready var stat_grid: GridContainer = %StatGrid
@onready var ascend_button: Button = %AscendButton
@onready var awaken_button: Button = %AwakenButton

# Reading order: left column then right column, row by row
const STATS := [
	["hp", "HP"], ["atk", "ATK"],
	["def", "DEF"], ["mdef", "MDEF"],
	["spd", "SPD"], ["crit", "CRIT"],
	["eva", "EVA"], ["en_regen", "EN Regen"],
]

const PENCIL_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><path fill="#ffffff" d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zm17.71-10.21a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>"""

var current: OwnedPartner = null

## Standalone mode (e.g. the Battle Array popup): shows fixed_partner
## instead of following the formation's SlotRow. Set both before
## adding the panel to the tree.
var standalone := false
var fixed_partner: OwnedPartner = null
var _rename_icon: BaseButton

var _ascend_text := ""
var _awaken_text := ""
var _qi_bar: Control
var _pips: Control
var _pill_bar: Control
var _ready_glows := {}      # Button -> looping Tween
var _rename_pulse: Tween
var current_slot := 0
var _value_labels := {}


func _ready() -> void:
	if realm_label is RichTextLabel:
		realm_label.bbcode_enabled = true
		realm_label.fit_content = true
		realm_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Long realm names can run past the label instead of being cut off
	realm_label.clip_contents = false
	if realm_label is Label:
		realm_label.clip_text = false
		realm_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_build_stat_rows()

	ascend_button.pressed.connect(_on_ascend_pressed)
	awaken_button.pressed.connect(_on_awaken_pressed)

	# Keep the button text you set in the editor.
	_ascend_text = ascend_button.text
	_awaken_text = awaken_button.text
	_qi_bar = _make_bar(ascend_button, qi_bar_color)
	_pill_bar = _make_bar(awaken_button, pill_bar_color)
	_pips = _make_pips(awaken_button)
	if ascend_cost_label == null:
		ascend_cost_label = qi_label

	# Tap the MC's name to rename
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.gui_input.connect(_on_name_input)
	_setup_rename_icon()
	_setup_gear_slots()
	_setup_treasure_slots()
	_setup_artifact_slots()
	name_label.resized.connect(_place_rename_icon)
	GameState.mc_changed.connect(_update_rename_hint)

	GameState.currency_changed.connect(_update_costs)
	GameState.roster_changed.connect(_refresh)
	GameState.formation_changed.connect(_refresh)

	if standalone:
		show_partner(fixed_partner)
		return

	# Find SlotRow if it wasn't set in the Inspector
	if slot_row == null and get_tree().current_scene != null:
		slot_row = get_tree().current_scene.find_child("SlotRow", true, false)

	if slot_row != null and slot_row.has_signal("slot_selected"):
		slot_row.slot_selected.connect(_on_slot_selected)
	else:
		push_warning("PartnerPanel: SlotRow not found")

	_on_slot_selected(0)


func _on_slot_selected(index: int) -> void:
	current_slot = index
	show_partner(GameState.get_partner_in_slot(index))


func _refresh() -> void:
	if standalone:
		show_partner(fixed_partner)
		return
	_on_slot_selected(current_slot)


# ---------------------------------------------------------
# DISPLAY
# ---------------------------------------------------------

func show_partner(p: OwnedPartner) -> void:
	current = p
	var data: PartnerData = null
	if p != null:
		data = p.get_data()

	if data == null:
		_show_empty()
		return

	# Card
	card_art.texture = data.card_texture
	_set_card_frame(data.rarity)

	var badge := DaoIcons.get_icon(data.path)
	dao_badge.texture = badge
	dao_badge.visible = badge != null

	_refresh_gear_slots()
	_refresh_treasure_slots()
	_refresh_artifact_slots()

	# Header
	name_label.text = data.display_name
	var is_mc := _is_mc(p)
	name_label.mouse_default_cursor_shape = \
		Control.CURSOR_POINTING_HAND if is_mc else Control.CURSOR_ARROW
	if _rename_icon != null:
		_rename_icon.visible = is_mc
		_place_rename_icon.call_deferred()
	_set_realm_text(p.get_realm_text())   # "Qi Condensation 1"

	stars.visible = true
	_set_stars(p.stars)

	# MC team bonus
	if team_bonus_label != null:
		team_bonus_label.visible = is_mc
		var pct := GameState.get_mc_team_bonus()
		team_bonus_label.text = "Team Bonus:  +%d%% HP  ·  +%d%% ATK" % [pct, pct]

	# Power and stats

	_set_stat("hp", _fmt(p.get_max_hp()))
	_set_stat("atk", _fmt(p.get_atk()))
	_set_stat("def", _fmt(p.get_def()))
	_set_stat("mdef", _fmt(p.get_mdef()))
	_set_stat("spd", _fmt(p.get_spd()))
	_set_stat("crit", "%.2f%%" % p.get_crit())
	_set_stat("eva", "%.2f%%" % p.get_eva())
	_set_stat("en_regen", _fmt(p.get_energy_regen()))

	# Buttons
	_update_costs()


func _show_empty() -> void:
	card_art.texture = null
	if card_frame != null:
		card_frame.texture = null
	dao_badge.visible = false
	name_label.text = "Empty Slot"
	_refresh_gear_slots()
	_refresh_treasure_slots()
	_refresh_artifact_slots()
	if team_bonus_label != null:
		team_bonus_label.visible = false
	name_label.mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _rename_icon != null:
		_rename_icon.visible = false
	_set_realm_text("")
	stars.visible = false
	for key in _value_labels:
		_set_stat(key, "-")
	_update_costs()


# "Realm : " in the normal colour, the realm name in realm_color.
func _set_realm_text(realm: String) -> void:
	if realm == "":
		realm_label.text = ""
	elif realm_label is RichTextLabel:
		realm_label.text = "Realm : [color=#%s]%s[/color]" % [realm_color.to_html(false), realm]
	else:
		# A plain Label can't mix colours, so the whole line uses realm_color.
		realm_label.text = "Realm : %s" % realm
		realm_label.add_theme_color_override("font_color", realm_color)


func _set_card_frame(rarity: int) -> void:
	var i := Realms.tier_index(rarity)
	if i < card_tier_frames.size() and card_tier_frames[i] != null:
		card_frame.texture = card_tier_frames[i]


# ---------------------------------------------------------
# EQUIPMENT SLOTS
# The four EquipmentSlot nodes under %EquipSlots are, in order:
# Weapon, Armor, Ring, Boots. A GearIcon sits on top of each.
# ---------------------------------------------------------

var _gear_icons: Array = []
var _set_box: VBoxContainer


func _setup_gear_slots() -> void:
	var holder := get_node_or_null("%EquipSlots")
	if holder == null:
		push_warning("PartnerPanel: %EquipSlots not found, equipment slots disabled")
		return
	var slots: Array = holder.get_children().filter(func(n): return n is Control)
	for i in mini(4, slots.size()):
		var icon := GearIcon.new()
		icon.custom_minimum_size = Vector2.ZERO
		icon.hide_empty = true
		icon.show_owner = false
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.setup_empty(i)
		icon.pressed.connect(_on_gear_slot.bind(i))
		slots[i].add_child(icon)
		_gear_icons.append(icon)
	# Active set bonuses, listed under the slots
	_set_box = VBoxContainer.new()
	_set_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_box.add_theme_constant_override("separation", 1)
	var parent := holder.get_parent()
	if parent != null:
		parent.add_child(_set_box)
		parent.move_child(_set_box, holder.get_index() + 1)

	GameState.gear_updated.connect(_refresh_gear_slots)


# ---------------------------------------------------------
# TREASURE SLOTS (3)
# ---------------------------------------------------------

var _treasure_icons: Array = []


func _setup_treasure_slots() -> void:
	var holder := _find_slot_holder(["%TreasureSlots", "TreasureSlots", "TreasuresSlots", "TreasureRow"])
	if holder == null:
		push_warning("PartnerPanel: treasure slots not found")
		return
	var slots: Array = holder.get_children().filter(func(n): return n is Control)
	for i in mini(Treasures.SLOTS, slots.size()):
		var icon := TreasureIcon.new()
		icon.custom_minimum_size = Vector2.ZERO
		icon.hide_empty = true
		icon.show_owner = false
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.setup_empty()
		icon.pressed.connect(_on_treasure_slot.bind(i))
		slots[i].add_child(icon)
		_treasure_icons.append(icon)

	GameState.treasures_updated.connect(_refresh_treasure_slots)


## Finds a slot container by any of the names it might have.
func _find_slot_holder(names: Array) -> Node:
	for n in names:
		var found := get_node_or_null(n)
		if found != null:
			return found
	# Inside this panel first, so a second copy never grabs another panel's slots
	for n in names:
		var own := find_child(str(n).trim_prefix("%"), true, false)
		if own != null:
			return own
	var scene := get_tree().current_scene
	if scene != null:
		for n in names:
			var plain: String = str(n).trim_prefix("%")
			var found2 := scene.find_child(plain, true, false)
			if found2 != null:
				return found2
	return null


func _refresh_treasure_slots() -> void:
	var worn: Array = []
	if current != null:
		worn = GameState.treasures_of(current.partner_id)

	for i in _treasure_icons.size():
		var icon: TreasureIcon = _treasure_icons[i]
		if i < worn.size():
			icon.setup(worn[i])
		else:
			icon.setup_empty()
		icon.show_alert = current != null and Treasures.better_available(current.partner_id, i)

	# The set line lives in the wide row under Equipment
	_refresh_set_box()


func _on_treasure_slot(slot: int) -> void:
	if current == null:
		return
	var worn := GameState.treasures_of(current.partner_id)
	if slot < worn.size():
		TreasurePopup.open_details(self, int(worn[slot]["uid"]), current.partner_id)
	else:
		TreasurePopup.open_picker(self, current.partner_id, slot)


# ---------------------------------------------------------
# ARTIFACT SLOTS (3) AND THE LIFEBOUND ARTIFACT
# ---------------------------------------------------------

var _artifact_icons: Array = []
var _lifebound_icon: LifeboundIcon
## Soul Spirit button beside the Lifebound icon (see SoulSpiritPopup).
var _spirit_button: Button


func _setup_artifact_slots() -> void:
	var holder := _find_slot_holder(["%ArtifactSlots", "ArtifactSlots", "ArtifactsSlots", "ArtifactRow"])
	if holder == null:
		push_warning("PartnerPanel: artifact slots not found")
		return
	var slots: Array = holder.get_children().filter(func(n): return n is Control)
	for i in mini(Artifacts.SLOTS, slots.size()):
		var icon := ArtifactIcon.new()
		icon.custom_minimum_size = Vector2.ZERO
		icon.hide_empty = true
		icon.show_owner = false
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.setup_empty()
		icon.pressed.connect(_on_artifact_slot.bind(i))
		slots[i].add_child(icon)
		_artifact_icons.append(icon)

	# Lifebound Artifact: its own icon beside the artifact slots
	_lifebound_icon = LifeboundIcon.new()
	_lifebound_icon.tooltip_text = "Lifebound Artifact"
	_lifebound_icon.pressed.connect(_on_lifebound)
	var lb_slot := find_child("LifeboundSlot", true, false) as Control
	if lb_slot != null:
		# Your scene's slot: the icon fills it
		_lifebound_icon.custom_minimum_size = Vector2.ZERO
		lb_slot.add_child(_lifebound_icon)
		_lifebound_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		# No slot in the scene: add one at the end of the row
		_lifebound_icon.custom_minimum_size = Vector2(56, 56)
		holder.add_child(_lifebound_icon)
		_match_lifebound_size.call_deferred(holder)
	_add_hover_glow(_lifebound_icon)

	_setup_spirit_slot()

	GameState.artifacts_updated.connect(_refresh_artifact_slots)


func _refresh_artifact_slots() -> void:
	var worn: Array = []
	if current != null:
		worn = GameState.artifacts_of(current.partner_id)
	for i in _artifact_icons.size():
		var icon: ArtifactIcon = _artifact_icons[i]
		if i < worn.size():
			icon.setup(worn[i])
		else:
			icon.setup_empty()
		icon.show_alert = current != null and Artifacts.better_available(current.partner_id, i)

	if _lifebound_icon != null:
		if current != null:
			var life := Lifebound.get_for(current.partner_id)
			_lifebound_icon.setup(life)
			# Red dot: no seed bonded yet, and you own a seed to bond
			var seeds := 0
			for star in GameState.lifebound_seeds:
				seeds += int(GameState.lifebound_seeds[star])
			_lifebound_icon.show_alert = int(life.get("stars", 0)) <= 0 and seeds > 0
		else:
			_lifebound_icon.setup_empty()
			_lifebound_icon.show_alert = false
	if _spirit_button != null:
		var bonded := Beasts.spirit_of(current.partner_id) if current != null else {}
		if _spirit_art != null:
			_spirit_art.texture = null if bonded.is_empty() else Beasts.species_art(str(bonded["species"]))
		_spirit_button.queue_redraw()
		if _spirit_overlay != null:
			_spirit_overlay.queue_redraw()
		if _spirit_slot_icon != null:
			_spirit_slot_icon.visible = current == null or Beasts.spirit_of(current.partner_id).is_empty()


func _on_artifact_slot(slot: int) -> void:
	if current == null:
		return
	var worn := GameState.artifacts_of(current.partner_id)
	if slot < worn.size():
		ArtifactPopup.open_details(self, int(worn[slot]["uid"]), current.partner_id)
	else:
		ArtifactPopup.open_picker(self, current.partner_id, slot)


var _spirit_in_scene := false
var _spirit_art: TextureRect
var _spirit_overlay: Control
## Your SpiritSlot's own placeholder icon, hidden while a beast is bonded.
var _spirit_slot_icon: CanvasItem


## Brightens a slot while hovered or pressed, like the gear slots.
func _add_hover_glow(button: BaseButton) -> void:
	button.mouse_entered.connect(func(): button.modulate = Color(1.25, 1.2, 1.05))
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	button.button_down.connect(func(): button.modulate = Color(1.45, 1.35, 1.1))
	button.button_up.connect(func(): button.modulate = Color(1.25, 1.2, 1.05) if button.is_hovered() else Color.WHITE)


## True when the Soul Spirit slot has something to do (red diamond).
func _spirit_alert() -> bool:
	if current == null:
		return false
	var spirit := Beasts.spirit_of(current.partner_id)
	if spirit.is_empty():
		return not Beasts.free_spirits().is_empty()
	return Beasts.rings_in(spirit).size() < Beasts.open_slots(spirit) and not Beasts.spare_rings().is_empty()


## Soul Spirit slot: at the end of the Equipment row (a real container,
## so it always lays out), after a small gap so it reads as its own thing.
func _setup_spirit_slot() -> void:
	_spirit_button = Button.new()
	_spirit_button.flat = true
	_spirit_button.focus_mode = Control.FOCUS_NONE
	_spirit_button.tooltip_text = "Soul Spirit"
	for state in ["normal", "hover", "pressed", "focus"]:
		_spirit_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_spirit_button.draw.connect(_draw_spirit_button)
	_spirit_button.pressed.connect(_on_spirit)
	_spirit_button.clip_contents = true
	# The beast's art as a real image node (same as the Soul Spirit screen)
	_spirit_art = TextureRect.new()
	_spirit_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spirit_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_spirit_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spirit_button.add_child(_spirit_art)
	_spirit_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spirit_art.offset_left = 6
	_spirit_art.offset_top = 6
	_spirit_art.offset_right = -6
	_spirit_art.offset_bottom = -6
	# Ring dots and the red dot, above the art
	_spirit_overlay = Control.new()
	_spirit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spirit_overlay.draw.connect(_draw_spirit_overlay)
	_spirit_button.add_child(_spirit_overlay)
	_spirit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_add_hover_glow(_spirit_button)
	var sp_slot := find_child("SpiritSlot", true, false) as Control
	if sp_slot != null:
		# Your scene's slot: the button fills it, drawn on top of its frame
		_spirit_in_scene = true
		_spirit_slot_icon = sp_slot.find_child("Icon", true, false) as CanvasItem
		sp_slot.add_child(_spirit_button)
		_spirit_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var equip_slots := find_child("EquipSlots", true, false) as Container
	if equip_slots == null:
		push_warning("PartnerPanel: SpiritSlot / EquipSlots not found, Soul Spirit slot not added")
		return
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(28, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_slots.add_child(gap)
	equip_slots.add_child(_spirit_button)
	_match_slot_size.call_deferred()


## The Lifebound icon, same size as an artifact slot.
func _match_lifebound_size(holder: Node) -> void:
	if _lifebound_icon == null or holder == null:
		return
	for c in holder.get_children():
		if c is Control and c != _lifebound_icon:
			var slot: Control = c
			var want := slot.size if slot.size.x > 0.0 else slot.get_combined_minimum_size()
			if want.x > 0.0:
				_lifebound_icon.custom_minimum_size = want
			return


## Same size as a gear slot.
func _match_slot_size() -> void:
	var equip_slots := find_child("EquipSlots", true, false) as Control
	if equip_slots == null or _spirit_button == null:
		return
	for c in equip_slots.get_children():
		if c is Control and c != _spirit_button:
			var slot: Control = c
			var want := slot.size if slot.size.x > 0.0 else slot.get_combined_minimum_size()
			if want.x > 0.0:
				_spirit_button.custom_minimum_size = want
			return


func _on_spirit() -> void:
	if current == null:
		return
	var popup := SoulSpiritPopup.open(self, current.partner_id)
	popup.tree_exited.connect(_refresh_artifact_slots)


func _draw_spirit_button() -> void:
	var b := _spirit_button
	var side := minf(b.size.x, b.size.y)
	# Not laid out yet: nothing to draw
	if side < 16.0:
		return
	var box := Rect2((b.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	# Frame like the other slots (your scene's SpiritSlot has its own)
	if not _spirit_in_scene:
		b.draw_rect(box.grow(-2.0), Color(0.04, 0.07, 0.14, 0.9))
		b.draw_rect(box.grow(-2.0), Color("e2c27a", 0.6), false, 2.0)
	var spirit := Beasts.spirit_of(current.partner_id) if current != null else {}
	if spirit.is_empty():
		# Your scene slot shows its own empty look
		if _spirit_in_scene:
			return
		var font := b.get_theme_default_font()
		var fs := maxi(8, int(side * 0.16))
		var label := "+ Spirit"
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		b.draw_string(font, box.get_center() + Vector2(-w * 0.5, fs * 0.35), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 0.66, 0.75))
		return
	var species := str(spirit["species"])
	var inner := box.grow(-6.0)
	# Dark backdrop behind the art (the art itself is a TextureRect child)
	b.draw_rect(inner, Color(0.03, 0.05, 0.1, 0.95))
	if Beasts.species_art(species) == null:
		# No art yet: the beast's name in its colour
		var entry: Array = Beasts.SPECIES.get(species, [])
		var col := Color(str(entry[6])) if entry.size() > 6 else Color(0.8, 0.85, 0.95)
		var font := b.get_theme_default_font()
		var fs := maxi(8, int(side * 0.13))
		var words := Beasts.species_name(species).split(" ")
		var y := inner.get_center().y - float(words.size() - 1) * fs * 0.55
		for word in words:
			var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			b.draw_string(font, Vector2(inner.get_center().x - ww * 0.5, y + fs * 0.35), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			y += fs * 1.1


## Above the art: the red dot and one small dot per ring.
func _draw_spirit_overlay() -> void:
	var o := _spirit_overlay
	var side := minf(o.size.x, o.size.y)
	if side < 16.0:
		return
	var box := Rect2((o.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	if _spirit_alert():
		var w := o.size.x
		var p := Vector2(w - w * 0.13, w * 0.13)
		o.draw_circle(p, w * 0.1, Color(0, 0, 0, 0.5))
		o.draw_circle(p, w * 0.075, Color("ff4d4d"))
		o.draw_circle(p - Vector2(w * 0.02, w * 0.02), w * 0.028, Color(1, 1, 1, 0.7))
	var spirit := Beasts.spirit_of(current.partner_id) if current != null else {}
	if spirit.is_empty():
		return
	var rings := Beasts.rings_in(spirit)
	var r := side * 0.045
	var gap := r * 2.6
	var start := box.get_center().x - (rings.size() - 1) * gap * 0.5
	for i in rings.size():
		var g := int(rings[i]["grade"])
		var dot := Vector2(start + i * gap, box.end.y - r * 2.6)
		o.draw_circle(dot, r + 1.5, Color(0.55, 0.35, 0.9, 0.8) if g == 3 else Color(0, 0, 0, 0.6))
		o.draw_circle(dot, r, Beasts.grade_color(g))


func _on_lifebound() -> void:
	if current != null:
		ArtifactPopup.open_lifebound(self, current.partner_id)


func _refresh_gear_slots() -> void:
	for i in _gear_icons.size():
		var icon: GearIcon = _gear_icons[i]
		var item := {}
		if current != null:
			item = GameState.gear_in_slot(current.partner_id, i)
		if item.is_empty():
			icon.setup_empty(i)
		else:
			icon.setup(item)
		icon.show_alert = current != null and Gear.better_available(current.partner_id, i)

	_refresh_set_box()


## One row per set the partner is wearing, with what it gives.
func _refresh_set_box() -> void:
	if _set_box == null:
		return
	for c in _set_box.get_children():
		_set_box.remove_child(c)
		c.queue_free()
	if current == null:
		return

	# Treasures first: the completed set, or how close you are
	var active := Treasures.active_set(current.partner_id)
	if not active.is_empty():
		var t_def := Treasures.set_def(active["set"])
		var t_row := HBoxContainer.new()
		t_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t_row.add_theme_constant_override("separation", 10)
		_set_box.add_child(t_row)
		t_row.add_child(_panel_label("%s 3/3" % t_def.get("name", ""), 16,
			t_def.get("color", Color.WHITE).lightened(0.2)))
		var t_marquee := MarqueeLabel.new()
		t_marquee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_marquee.setup(Treasures.set_effect_text(active["set"], int(active["grade"])), 15, Color("9fb3cc"))
		t_row.add_child(t_marquee)
	else:
		var held := GameState.treasures_of(current.partner_id)
		if not held.is_empty():
			var counts := {}
			for t in held:
				counts[Treasures.set_of(t)] = int(counts.get(Treasures.set_of(t), 0)) + 1
			var parts := PackedStringArray()
			for set_id in counts:
				parts.append("%s %d/3" % [Treasures.set_def(set_id).get("name", ""), counts[set_id]])
			_set_box.add_child(_panel_label("  ·  ".join(parts) + "   (fill all 3 with one set)",
				15, Color("7f8ea3")))

	for entry in Gear.set_summary(current.partner_id):
		var count: int = entry["count"]
		var color: Color = entry["color"]

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		_set_box.add_child(row)

		row.add_child(_panel_label("%s %d/4" % [entry["name"], count], 16,
			color.lightened(0.2) if count >= 2 else Color("7f8ea3")))

		# Long bonus text scrolls by itself instead of being cut off
		var bonus := Gear.active_bonus_short(current.partner_id, _set_id_of(entry["name"]))
		if count < 2:
			bonus = "wear 2 pieces for a bonus"
		var marquee := MarqueeLabel.new()
		marquee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marquee.setup(bonus, 15, Color("9fb3cc") if count >= 2 else Color("5f6d80"))
		row.add_child(marquee)


func _set_id_of(set_title: String) -> String:
	for id in Gear.SETS:
		if Gear.SETS[id]["name"] == set_title:
			return id
	return ""


func _panel_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _on_gear_slot(slot: int) -> void:
	if current == null:
		return
	var item := GameState.gear_in_slot(current.partner_id, slot)
	if item.is_empty():
		GearPopup.open_picker(self, current.partner_id, slot)
	else:
		GearPopup.open_details(self, int(item["uid"]), current.partner_id)


# ---------------------------------------------------------
# RENAME (MC only)
# ---------------------------------------------------------

func _is_mc(p: OwnedPartner) -> bool:
	return p != null and p.partner_id == GameState.MC_ID


func _on_name_input(event) -> void:
	# Touch also arrives as a mouse click, so this covers phones.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_open_rename()


func _open_rename() -> void:
	if not _is_mc(current):
		return
	RenameDialog.open(self, name_label.get_theme_font("font"), jade_icon)


## Uses the custom button if one is set, otherwise makes a pencil.
func _setup_rename_icon() -> void:
	if rename_button != null:
		_rename_icon = rename_button
	else:
		var tex := rename_icon_texture
		if tex == null:
			var img := Image.new()
			if img.load_svg_from_string(PENCIL_SVG) == OK:
				tex = ImageTexture.create_from_image(img)

		var b := TextureButton.new()
		b.texture_normal = tex
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.modulate = rename_icon_color
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "Rename"
		name_label.add_child(b)
		_rename_icon = b

	_rename_icon.pressed.connect(_open_rename)
	_rename_icon.visible = false
	_update_rename_hint()


## Puts the automatic pencil just after the end of the name text.
func _place_rename_icon() -> void:
	# Custom buttons stay where you placed them.
	if _rename_icon == null or _rename_icon == rename_button:
		return

	var font := name_label.get_theme_font("font")
	var font_size := name_label.get_theme_font_size("font_size")
	var ls := name_label.label_settings
	if ls != null:
		if ls.font != null:
			font = ls.font
		font_size = ls.font_size
	if font == null:
		return

	var text := name_label.text
	if name_label.uppercase:
		text = text.to_upper()
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var icon_size := font_size * 0.85
	var x := text_w + 14.0
	match name_label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = (name_label.size.x + text_w) * 0.5 + 14.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = name_label.size.x + 14.0

	_rename_icon.size = Vector2(icon_size, icon_size)
	_rename_icon.position = Vector2(x, (name_label.size.y - icon_size) * 0.5)


## The pencil gently pulses until the player has used their free rename.
func _update_rename_hint() -> void:
	if _rename_icon == null:
		return

	if _rename_pulse != null:
		_rename_pulse.kill()
		_rename_pulse = null
	_rename_icon.self_modulate = Color.WHITE

	if GameState.mc_rename_count == 0:
		_rename_pulse = create_tween().set_loops()
		_rename_pulse.tween_property(_rename_icon, "self_modulate:a", 0.35, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_rename_pulse.tween_property(_rename_icon, "self_modulate:a", 1.0, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------
# BUTTONS  (test versions: free, no costs yet)
# ---------------------------------------------------------

func _on_ascend_pressed() -> void:
	var p := current
	if p == null:
		return

	if p.is_capped_by_mc():
		_toast(ascend_button, "Raise your own realm first", Color("ff9a8a"))
		return

	# Level 10: risky breakthrough into the next realm
	if GameState.is_breakthrough(p):
		_open_breakthrough(p)
		return

	var cost := p.get_ascend_cost()
	if GameState.qi < cost:
		_toast(ascend_button, "Need %s more Qi" % _fmt(cost - GameState.qi), Color("ff9a8a"))
		return

	var error := GameState.try_ascend(p)
	if error != "":
		_toast(ascend_button, error, Color("ff9a8a"))
	else:
		_toast(ascend_button, "Breakthrough!", qi_bar_color)


func _on_awaken_pressed() -> void:
	var p := current
	if p == null:
		return

	# At the star cap this button is Evolve (see _update_costs).
	if p.stars >= p.get_star_cap() and not SummonSystem.next_forms(p.partner_id).is_empty():
		_on_evolve_pressed(p)
		return

	var need_copies := p.get_awaken_copies()
	var have_copies := GameState.get_copies(p.partner_id)
	var need_pills := p.get_awaken_pills()

	if have_copies < need_copies:
		var missing := need_copies - have_copies
		_toast(awaken_button, "Need %d more Soul Fragment%s" % [missing, "" if missing == 1 else "s"], Color("ff9a8a"))
		return
	if GameState.starup_pills < need_pills:
		_toast(awaken_button, "Need %s more Star-up Pills" % _fmt(need_pills - GameState.starup_pills), Color("ff9a8a"))
		return

	var bonus_before := GameState.get_mc_team_bonus()
	var error := GameState.try_awaken(p)
	if error != "":
		_toast(awaken_button, error, Color("ff9a8a"))
	elif p.is_mc() and GameState.get_mc_team_bonus() > bonus_before:
		_toast(awaken_button, "Tier up! Team +%d%%" % GameState.get_mc_team_bonus(), pip_color)
	else:
		_toast(awaken_button, "Awakened!", pip_color)


# ---------------------------------------------------------
# BREAKTHROUGH POPUP
# ---------------------------------------------------------

var _bt_layer: CanvasLayer
var _bt_partner: OwnedPartner
var _bt_pills := 0
var _bt_owned := 0
var _bt_max := 0
var _bt_chance: Label
var _bt_panel: PanelContainer
var _bt_pill_count: Label
var _bt_body: VBoxContainer
var _bt_buttons: HBoxContainer


func _open_breakthrough(p: OwnedPartner) -> void:
	_close_breakthrough()
	_bt_partner = p
	_bt_pill_count = null
	var pill_id := GameState.get_breakthrough_pill(p)
	var have_pill := GameState.get_item_count(pill_id)
	# Suggest enough pills for 100%, or all you have if that's fewer.
	var certain := GameState.get_base_breakthrough_chance(p.realm_index) >= 100
	_bt_owned = have_pill
	_bt_max = mini(have_pill, GameState.pills_for_certain(p))
	_bt_pills = _bt_max
	var cost := p.get_ascend_cost()
	var gold := Color("e2c27a")

	_bt_layer = CanvasLayer.new()
	_bt_layer.layer = 60
	get_tree().root.add_child(_bt_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	_bt_layer.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bt_layer.add_child(center)

	_bt_panel = PanelContainer.new()
	_bt_panel.custom_minimum_size = Vector2(840, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1629")
	sb.border_color = gold
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(32)
	sb.shadow_color = Color(gold, 0.2)
	sb.shadow_size = 22
	_bt_panel.add_theme_stylebox_override("panel", sb)
	_bt_panel.resized.connect(func(): _bt_panel.pivot_offset = _bt_panel.size * 0.5)
	center.add_child(_bt_panel)

	_bt_body = VBoxContainer.new()
	_bt_body.add_theme_constant_override("separation", 14)
	_bt_panel.add_child(_bt_body)
	var v := _bt_body

	v.add_child(_bt_label("Breakthrough", 42, Color("f2d98a")))
	var from := Realms.get_label(p.realm_index, p.tier)
	var to := Realms.get_label(p.realm_index + 1, 1)
	v.add_child(_bt_label("%s   →   %s" % [from, to], 24, Color("c9d4e3")))

	v.add_child(_bt_label("Success Chance", 22, Color("7f8ea3")))
	_bt_chance = _bt_label("", 72, Color.WHITE)
	v.add_child(_bt_chance)

	# Pill row
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 16)
	v.add_child(pill_row)

	var slot := ItemSlot.new()
	slot.custom_minimum_size = Vector2(96, 96)
	slot.disabled = true
	slot.setup_item(pill_id, have_pill)
	pill_row.add_child(slot)

	var pill_info := VBoxContainer.new()
	pill_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill_info.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_row.add_child(pill_info)
	var item := ItemDB.get_item(pill_id)
	var name_l := _bt_label(item.get("name", "Pill"), 24, ItemDB.grade_color(item.get("grade", 0)).lightened(0.2))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pill_info.add_child(name_l)
	var pill_note := _bt_label("Owned %s  ·  +%d%% each  ·  used up either way" % [
		NumberFormat.short(have_pill), GameState.BREAKTHROUGH_PILL_BONUS], 18, Color("7f8ea3"))
	pill_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pill_info.add_child(pill_note)

	if have_pill > 0 and not certain:
		var stepper := HBoxContainer.new()
		stepper.add_theme_constant_override("separation", 6)
		stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill_row.add_child(stepper)
		for entry in [["−", -1], ["+", 1], ["Max", 0]]:
			var b := OrnateButton.new()
			b.text = entry[0]
			b.variant = OrnateButton.Variant.DARK
			b.custom_minimum_size = Vector2(58 if entry[0] != "Max" else 84, 56)
			b.pressed.connect(_on_bt_pill_step.bind(entry[1]))
			stepper.add_child(b)
			if entry[0] == "−":
				_bt_pill_count = _bt_label("", 26, Color.WHITE)
				_bt_pill_count.custom_minimum_size = Vector2(56, 0)
				stepper.add_child(_bt_pill_count)
	elif certain:
		pill_note.text = "Not needed: this breakthrough is certain."
	else:
		var craft := OrnateButton.new()
		craft.text = "Craft in Abode"
		craft.variant = OrnateButton.Variant.DARK
		craft.custom_minimum_size = Vector2(220, 60)
		craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		craft.pressed.connect(_go_to_abode)
		pill_row.add_child(craft)

	# Cost and risk
	var cost_l := _bt_label("Qi cost:  %s   (you have %s)" % [
		NumberFormat.short(cost), NumberFormat.short(GameState.qi)], 22,
		Color("8ff0ff") if GameState.qi >= cost else Color("ff7a7a"))
	v.add_child(cost_l)
	v.add_child(_bt_label("If it fails:  lose %s Qi (%d%%)" % [
		NumberFormat.short(int(cost * GameState.BREAKTHROUGH_FAIL_LOSS)),
		int(GameState.BREAKTHROUGH_FAIL_LOSS * 100)], 20, Color("ff9a8a")))

	_bt_buttons = HBoxContainer.new()
	_bt_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_bt_buttons.add_theme_constant_override("separation", 20)
	v.add_child(_bt_buttons)

	var cancel := OrnateButton.new()
	cancel.text = "Not Yet"
	cancel.variant = OrnateButton.Variant.DARK
	cancel.custom_minimum_size = Vector2(240, 76)
	cancel.pressed.connect(_close_breakthrough)
	_bt_buttons.add_child(cancel)

	var attempt := OrnateButton.new()
	attempt.text = "Attempt"
	attempt.custom_minimum_size = Vector2(280, 76)
	attempt.add_theme_font_size_override("font_size", 28)
	attempt.disabled = GameState.qi < cost
	attempt.pressed.connect(_on_bt_attempt)
	_bt_buttons.add_child(attempt)

	_update_bt_chance()

	# Pop in
	_bt_panel.scale = Vector2(0.9, 0.9)
	var t := _bt_panel.create_tween()
	t.tween_property(_bt_panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_breakthrough() -> void:
	if is_instance_valid(_bt_layer):
		_bt_layer.queue_free()
	_bt_layer = null


## -1 / +1 steps, 0 = as many as useful.
func _on_bt_pill_step(step: int) -> void:
	if step == 0:
		_bt_pills = _bt_max
	else:
		_bt_pills = clampi(_bt_pills + step, 0, _bt_max)
	_update_bt_chance()


func _update_bt_chance() -> void:
	var chance := GameState.get_breakthrough_chance(_bt_partner, _bt_pills)
	_bt_chance.text = "%d%%" % chance
	var col := Color("7dffa8") if chance >= 70 else (Color("ffd36b") if chance >= 40 else Color("ff7a7a"))
	_bt_chance.add_theme_color_override("font_color", col)
	if _bt_pill_count != null and is_instance_valid(_bt_pill_count):
		_bt_pill_count.text = "×%d" % _bt_pills


func _on_bt_attempt() -> void:
	var partner := _bt_partner
	var from_major := Realms.get_major(partner.realm_index)
	var result := GameState.attempt_breakthrough(partner, _bt_pills)
	if not result.get("ok", false):
		_toast(ascend_button, result.get("error", "Can't attempt now."), Color("ff9a8a"))
		_close_breakthrough()
		return

	# Close the chance window and play the ceremony
	var success: bool = result["success"]
	var major := success and Realms.get_major(partner.realm_index) != from_major
	_close_breakthrough()
	BreakthroughCeremony.play(self, partner, success, int(result.get("qi_lost", 0)), major)


func _go_to_abode() -> void:
	_close_breakthrough()
	var scene := get_tree().current_scene
	var router = scene.find_child("LowerStack", true, false) if scene != null else null
	if router != null and router.has_method("open_tab"):
		router.call("open_tab", "Growth")


func _bt_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Updates the progress bars, the copy pips and each button's ready glow.
## Runs whenever Qi changes too.
func _update_costs() -> void:
	var p := current
	ascend_button.text = _ascend_text
	awaken_button.text = _awaken_text

	if p == null:
		ascend_button.disabled = true
		awaken_button.disabled = true
		_qi_bar.visible = false
		_pill_bar.visible = false
		_pips.visible = false
		_set_ready(ascend_button, false)
		_set_ready(awaken_button, false)
		_set_cost_label(ascend_cost_label, "Qi  %s" % _fmt(GameState.qi), true)
		_set_cost_label(awaken_cost_label, "", true)
		return

	# Ascend: Qi bar
	if p.is_max_realm():
		ascend_button.disabled = true
		_qi_bar.visible = false
		_set_ready(ascend_button, false)
		_set_cost_label(ascend_cost_label, "Qi  %s  ·  Max Realm" % _fmt(GameState.qi), true)
	else:
		var cost := p.get_ascend_cost()
		var ratio := 1.0 if cost <= 0 else clampf(float(GameState.qi) / cost, 0.0, 1.0)
		var capped := p.is_capped_by_mc()
		ascend_button.disabled = false
		_qi_bar.visible = true
		_qi_bar.set_meta("ratio", ratio)
		_qi_bar.queue_redraw()
		_set_ready(ascend_button, ratio >= 1.0 and not capped)
		if capped:
			_set_cost_label(ascend_cost_label, "Qi  %s  ·  Realm limit" % _fmt(GameState.qi), false)
		else:
			_set_cost_label(ascend_cost_label,
				"Qi  %s / %s" % [_fmt(GameState.qi), _fmt(cost)], ratio >= 1.0)

	# Awaken: pill bar (+ copy pips for partners)
	if p.stars >= p.get_star_cap():
		_pill_bar.visible = false
		_pips.visible = false
		# At the star cap Awaken is dead, so the button becomes Evolve —
		# but only once it can actually be done. A button that is there
		# and refuses reads as broken, so until then this stays "Max".
		if GameState.can_evolve(p) == "":
			awaken_button.text = "Evolve"
			awaken_button.disabled = false
			_set_ready(awaken_button, true)
			_set_cost_label(awaken_cost_label,
				"%d Essence" % GameState.evolve_cost(p), true)
		else:
			awaken_button.disabled = true
			_set_ready(awaken_button, false)
			_set_cost_label(awaken_cost_label, "Max", true)
	else:
		var need_copies := p.get_awaken_copies()
		var have_copies := GameState.get_copies(p.partner_id)
		var need_pills := p.get_awaken_pills()
		var pill_ratio := 1.0 if need_pills <= 0 else clampf(float(GameState.starup_pills) / need_pills, 0.0, 1.0)
		var ok := have_copies >= need_copies and pill_ratio >= 1.0

		awaken_button.disabled = false
		_pill_bar.visible = need_pills > 0
		_pill_bar.set_meta("ratio", pill_ratio)
		_pill_bar.queue_redraw()
		_pips.visible = need_copies > 0
		_pips.set_meta("need", need_copies)
		_pips.set_meta("have", have_copies)
		_pips.queue_redraw()
		_set_ready(awaken_button, ok)

		var parts := PackedStringArray()
		if need_copies > 0:
			parts.append("%d / %d fragments" % [have_copies, need_copies])
		parts.append("%s / %s pills" % [_fmt(GameState.starup_pills), _fmt(need_pills)])
		_set_cost_label(awaken_cost_label, "  ·  ".join(parts), ok)


func _set_cost_label(label: Label, text: String, ok: bool) -> void:
	if label == null:
		return
	label.text = text
	label.add_theme_color_override("font_color", Color("8ff0ff") if ok else Color("ff7a7a"))


## Ready = normal brightness with a slow glow. Not ready = dimmed.
func _set_ready(button: Button, is_ready: bool) -> void:
	var glow: Tween = _ready_glows.get(button)

	if is_ready:
		if glow != null and glow.is_valid():
			return
		button.self_modulate = Color.WHITE
		glow = create_tween().set_loops()
		glow.tween_property(button, "self_modulate", Color(1.3, 1.3, 1.3), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow.tween_property(button, "self_modulate", Color.WHITE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ready_glows[button] = glow
	else:
		if glow != null:
			glow.kill()
			_ready_glows.erase(button)
		button.self_modulate = Color(0.65, 0.65, 0.72)


## Thin progress bar along the bottom edge of a button.
func _make_bar(button: Button, color: Color) -> Control:
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = bar_inset
	bar.offset_right = -bar_inset
	bar.offset_top = -bar_bottom - bar_height
	bar.offset_bottom = -bar_bottom
	bar.set_meta("ratio", 0.0)

	bar.draw.connect(func():
		var r := float(bar.get_meta("ratio"))
		var full := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(full, Color(0, 0, 0, 0.55))
		if r > 0.0:
			var fill := Rect2(Vector2.ZERO, Vector2(bar.size.x * r, bar.size.y))
			bar.draw_rect(fill.grow(1.5), Color(color, 0.25))
			bar.draw_rect(fill, color)
			# Bright tip at the leading edge
			bar.draw_rect(Rect2(fill.end.x - 3.0, 0.0, 3.0, bar.size.y), Color(1, 1, 1, 0.9))
	)
	button.add_child(bar)
	return bar


## Row of small diamonds along the bottom of a button.
func _make_pips(button: Button) -> Control:
	var pips := Control.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.anchor_left = 0.0
	pips.anchor_right = 1.0
	pips.anchor_top = 1.0
	pips.anchor_bottom = 1.0
	pips.offset_bottom = -bar_bottom - bar_height - 3.0
	pips.offset_top = pips.offset_bottom - 12.0
	pips.set_meta("need", 0)
	pips.set_meta("have", 0)

	pips.draw.connect(func():
		var need := int(pips.get_meta("need"))
		var have := int(pips.get_meta("have"))
		var gap := 16.0
		var d := 5.0
		var start_x := pips.size.x * 0.5 - (need - 1) * gap * 0.5
		var y := pips.size.y * 0.5
		for i in need:
			var c := Vector2(start_x + i * gap, y)
			var shape := PackedVector2Array([
				c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)
			])
			if i < have:
				pips.draw_colored_polygon(shape, pip_color)
			else:
				shape.append(shape[0])
				pips.draw_polyline(shape, Color(pip_color, 0.6), 1.5, true)
	)
	button.add_child(pips)
	return pips


## Small message that floats up from a button and fades.
## Evolves the shown partner. Most lines have one next form and go
## straight through; Lin Qiye's Red can become Nyx or Merlin, so that
## one asks first.
func _on_evolve_pressed(p) -> void:
	var blocked := GameState.can_evolve(p)
	if blocked != "":
		_toast(awaken_button, blocked, Color("ff9a8a"))
		return

	var forms: Array = SummonSystem.next_forms(p.partner_id)
	if forms.size() <= 1:
		_finish_evolve(p, str(forms[0]) if not forms.is_empty() else "")
		return

	var note := "Choose their next form. This cannot be undone."
	var popup := CardChoicePopup.open(self, "Evolution", forms, Enums.Rarity.GOLD, note)
	var on_chosen := func(partner_id: String) -> void:
		_finish_evolve(p, partner_id)
	popup.chosen.connect(on_chosen)


func _finish_evolve(p, target: String) -> void:
	var problem := GameState.evolve_partner(p, target)
	if problem != "":
		_toast(awaken_button, problem, Color("ff9a8a"))
		return
	var data = PartnerDatabase.get_partner(p.partner_id)
	_toast(awaken_button, "Evolved into %s!" % (data.display_name if data != null else "a new form"), pip_color)


func _toast(button: Control, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.top_level = true
	l.z_index = 50
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", toast_font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)

	l.size = l.get_minimum_size()
	var rect := button.get_global_rect()
	l.global_position = Vector2(rect.get_center().x - l.size.x * 0.5, rect.position.y - l.size.y)

	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 40.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t.tween_callback(l.queue_free)


func _fmt(value: int) -> String:
	return NumberFormat.short(value)


# ---------------------------------------------------------
# STAT ROWS  (built in code, so there are no 8 rows to lay out)
# ---------------------------------------------------------

func _build_stat_rows() -> void:
	for child in stat_grid.get_children():
		child.queue_free()
	_value_labels.clear()

	for s in STATS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var bullet := Label.new()
		bullet.text = "◆"
		bullet.add_theme_color_override("font_color", bullet_color)
		bullet.add_theme_font_size_override("font_size", int(stat_font_size * 0.6))
		bullet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var stat_name := Label.new()
		stat_name.text = s[1] + " :"
		stat_name.custom_minimum_size.x = name_width
		stat_name.add_theme_font_size_override("font_size", stat_font_size)

		var value := Label.new()
		value.text = "-"
		value.add_theme_font_size_override("font_size", stat_font_size)

		row.add_child(bullet)
		row.add_child(stat_name)
		row.add_child(value)
		stat_grid.add_child(row)

		_value_labels[s[0]] = value


func _set_stat(key: String, text: String) -> void:
	if _value_labels.has(key):
		_value_labels[key].text = text


# Same rules as the formation slot:
# blue 1-5, green 6-10, red 11-15, gold 16-20
func _set_stars(count: int) -> void:
	var per_tier := 5
	count = clampi(count, 0, per_tier * star_tiers.size())

	var tier := 0
	var filled := 0
	if count > 0:
		tier = int((count - 1) / float(per_tier))
		filled = count - tier * per_tier

	for i in stars.get_child_count():
		var star_icon: TextureRect = stars.get_child(i)
		if i < filled:
			star_icon.texture = star_tiers[tier]
		elif tier > 0:
			star_icon.texture = star_tiers[tier - 1]
		else:
			star_icon.texture = star_empty
