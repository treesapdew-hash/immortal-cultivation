class_name ResultBanner
extends Control

# =========================================================
# Stage / dungeon result banner. Save as
#   res://ui/result_banner.gd
#
# A slim plaque across the upper battle area, so the fight
# stays visible. Three looks:
#   normal stage   jade plaque, quick
#   boss stage     red-gold plaque (every 10th stage, and
#                  dungeon / trial clears)
#   major boss     red-gold plaque + light burst (every 100th)
#   defeat         grey stone plaque
#
# Called by home_battle.gd:
#   await show_victory(stage, currencies, delay, drops, title)
#   await show_defeat(stage, delay, subtitle)
# currencies: [{icon, amount, name, color}]
# drops: [{item_id, amount, name}] or {gear: piece} / {treasure: piece}
#
# Art in assets/ui/banners/ (drawn fallback if missing):
#   banner_victory.png, banner_boss.png, banner_defeat.png,
#   banner_burst.png
# =========================================================

const ART_DIR := "res://assets/ui/banners/"

## Share of each banner image that is end ornament (kept unstretched).
const END_SHARE := 0.17
## The plain inner panel, as shares of the banner: text stays inside it
## and shrinks to fit. Raise INNER_TOP / INNER_BOTTOM if text touches the
## gold border, INNER_SIDE if it runs into the end ornaments.
const INNER_TOP := 0.22
const INNER_BOTTOM := 0.22
const INNER_SIDE := 0.9   # x end ornament width

## Banner width (share of the battle area), and height as a share of
## that width, so it looks the same however the battle area is scaled.
const WIDTH_SHARE := 0.94
const HEIGHT_NORMAL := 0.22
const HEIGHT_BOSS := 0.27
const HEIGHT_DEFEAT := 0.2

## When trimming empty space off the art, pixels fainter than this
## count as empty (generated images often have a faint haze around).
const ALPHA_CUTOFF := 0.35
## Text and icon sizes below are for a banner this wide; they scale
## with the real width.
const DESIGN_WIDTH := 1000.0
## Vertical centre of the banner (share of the battle area height).
const CENTER_Y := 0.30

const MAX_DROP_ICONS := 6
const DROP_ICON := 46.0
const DROP_ICON_SMALL := 36.0
const Z := 45   # above the stage banner (home_battle BANNER_Z = 40)

const COL_GOLD := Color("ffe6a8")
const COL_TEXT := Color("f4ecd8")
const COL_SUB := Color("d9ccb0")
const COL_DEFEAT := Color("d8dde6")
const COL_DEFEAT_SUB := Color("9aa6b8")

static var _art := {}
## Part of each image that isn't transparent padding.
static var _regions := {}



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = Z


# ---------------------------------------------------------
# PUBLIC
# ---------------------------------------------------------

## Victory. stage 0 = a dungeon or trial clear (uses `title`).
func show_victory(stage: int, currencies: Array, delay: float, drops: Array = [], title := "") -> void:
	var major := stage > 0 and stage % 100 == 0
	var boss := stage <= 0 or EnemyGenerator.is_boss_stage(stage)
	var heading := "VICTORY"
	var sub := title
	if stage > 0:
		if major:
			heading = "GREAT BOSS DEFEATED"
			sub = "Stage %s reached" % _commas(stage)
		elif boss:
			heading = "BOSS DEFEATED"
			sub = "Stage %s cleared" % _commas(stage)
		else:
			heading = "STAGE %s CLEARED" % _commas(stage)
			sub = ""
	# Settings: ordinary stage clears can be short or hidden
	# (bosses, dungeons and trials always show)
	if stage > 0 and not boss:
		var mode := str(Settings.get_value("stage_banner"))
		if mode == "off":
			return
		if mode == "short":
			delay *= 0.5
	var art := "banner_boss" if boss else "banner_victory"
	var h_share := HEIGHT_BOSS if boss else HEIGHT_NORMAL
	await _play(art, h_share, boss, heading, sub, currencies, drops, major, false, delay)


func show_defeat(stage: int, delay: float, subtitle := "") -> void:
	var sub := subtitle
	if sub == "":
		sub = "Stage %s  ·  Strengthen your team and try again" % _commas(stage) if stage > 0 \
			else "Strengthen your team and try again"
	await _play("banner_defeat", HEIGHT_DEFEAT, false, "DEFEATED", sub, [], [], false, true, delay)


# ---------------------------------------------------------
# BUILD AND ANIMATE
# ---------------------------------------------------------

func _play(art: String, h_share: float, big: bool, heading: String, sub: String, currencies: Array,
		drops: Array, burst: bool, defeat: bool, delay: float) -> void:
	# One banner at a time: a new one replaces the old one
	for c in get_children():
		c.queue_free()

	var area := size
	var w := area.x * WIDTH_SHARE
	var h := w * h_share
	var ui_scale := w / DESIGN_WIDTH
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(w, h)
	holder.position = Vector2((area.x - w) * 0.5, area.y * CENTER_Y - h * 0.5)
	holder.pivot_offset = holder.size * 0.5
	add_child(holder)

	# Light burst behind great bosses
	var burst_node: TextureRect = null
	if burst:
		var burst_tex := _texture("banner_burst")
		if burst_tex != null:
			burst_node = TextureRect.new()
			burst_node.texture = burst_tex
			burst_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			burst_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			burst_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var side := h * 2.6
			burst_node.size = Vector2(side, side)
			burst_node.position = Vector2(w * 0.5 - side * 0.5, h * 0.5 - side * 0.5)
			burst_node.pivot_offset = burst_node.size * 0.5
			holder.add_child(burst_node)

	# The plaque
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(w, h)
	var tex := _texture(art)
	frame.draw.connect(_draw_frame.bind(frame, tex, defeat))
	holder.add_child(frame)

	# Text and rewards, centred in the plaque's inner panel
	var end_w := _end_width(tex, h)
	var inner := Rect2(end_w * INNER_SIDE, h * INNER_TOP,
		w - end_w * INNER_SIDE * 2.0, h * (1.0 - INNER_TOP - INNER_BOTTOM))
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = inner.position
	box.size = inner.size
	box.pivot_offset = inner.size * 0.5
	holder.add_child(box)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	box.add_child(content)

	content.add_child(_text(heading, 40 if big else 32, COL_DEFEAT if defeat else COL_GOLD, true))
	if sub != "":
		content.add_child(_text(sub, 18, COL_DEFEAT_SUB if defeat else COL_SUB, false))
	var row := _reward_row(currencies, drops, DROP_ICON if big else DROP_ICON_SMALL)
	if row != null:
		content.add_child(row)

	# Shrink to fit the inner panel if there's a lot to show. The box
	# can't be smaller than its content, so centre it on the panel first.
	var need := content.get_combined_minimum_size()
	var box_size := Vector2(maxf(inner.size.x, need.x), maxf(inner.size.y, need.y))
	box.size = box_size
	box.position = inner.position + (inner.size - box_size) * 0.5
	box.pivot_offset = box_size * 0.5
	# Scale to the real banner size, but never past what fits
	var fit := minf(ui_scale, minf(inner.size.x / maxf(need.x, 1.0), inner.size.y / maxf(need.y, 1.0)))
	box.scale = Vector2(fit, fit)

	# In: grow and fade in. Great bosses hold a little longer.
	holder.modulate.a = 0.0
	holder.scale = Vector2(0.86, 0.86)
	var t_in := create_tween().set_parallel()
	t_in.tween_property(holder, "modulate:a", 1.0, 0.18)
	t_in.tween_property(holder, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if burst_node != null:
		burst_node.modulate.a = 0.0
		var spin := burst_node.create_tween().set_parallel()
		spin.tween_property(burst_node, "modulate:a", 0.9, 0.3)
		spin.tween_property(burst_node, "rotation", 0.6, delay + 1.0)
	await t_in.finished

	var hold := delay * (1.6 if burst else 1.0)
	await get_tree().create_timer(hold).timeout

	if not is_instance_valid(holder):
		return
	var t_out := create_tween().set_parallel()
	t_out.tween_property(holder, "modulate:a", 0.0, 0.22)
	t_out.tween_property(holder, "position:y", holder.position.y - 24.0, 0.22)
	await t_out.finished
	if is_instance_valid(holder):
		holder.queue_free()


## Currencies ("+13.5K Spirit Stones") then drop icons.
func _reward_row(currencies: Array, drops: Array, icon_size: float) -> Control:
	if currencies.is_empty() and drops.is_empty():
		return null
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for c in currencies:
		var amount := int(c.get("amount", 0))
		if amount <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 5)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon = c.get("icon")
		if icon is Texture2D:
			var t := TextureRect.new()
			t.texture = icon
			t.custom_minimum_size = Vector2(26, 26)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.add_child(t)
		chip.add_child(_text("+%s" % NumberFormat.short(amount), 21, COL_TEXT, false, true))
		chip.add_child(_text(str(c.get("name", "")), 15, COL_SUB, false))
		row.add_child(chip)

	var shown := 0
	for d in drops:
		if shown >= MAX_DROP_ICONS:
			break
		var icon_node := _drop_icon(d, icon_size)
		if icon_node != null:
			row.add_child(icon_node)
			shown += 1
	if drops.size() > shown:
		row.add_child(_text("+%d" % (drops.size() - shown), 20, COL_SUB, false))
	return row


func _drop_icon(d: Dictionary, icon_size: float) -> Control:
	var icon: Control = null
	if d.has("gear"):
		var g := GearIcon.new()
		g.setup(d["gear"])
		icon = g
	elif d.has("treasure"):
		var treasure_icon := TreasureIcon.new()
		treasure_icon.setup(d["treasure"])
		icon = treasure_icon
	else:
		var id := str(d.get("item_id", ""))
		if id == "":
			return null
		if id == Dungeons.JADE_KEY:
			return _text("+%s Jade" % NumberFormat.short(int(d.get("amount", 0))), 20, Color("9dffc4"), false, true)
		var slot := ItemSlot.new()
		slot.setup_item(id, int(d.get("amount", 1)))
		icon = slot
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


# ---------------------------------------------------------
# DRAWING
# ---------------------------------------------------------

static func _texture(art_name: String) -> Texture2D:
	if not _art.has(art_name):
		var path := ART_DIR + art_name + ".png"
		var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		_art[art_name] = tex
		if tex != null:
			_regions[tex.get_rid()] = _visible_region(tex)
	return _art[art_name]


## The rectangle of the image that actually has pixels, so empty
## transparent space around the plaque is ignored.
static func _visible_region(tex: Texture2D) -> Rect2:
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img == null:
		return full
	if img.is_compressed():
		if img.decompress() != OK:
			return full
	var iw := img.get_width()
	var ih := img.get_height()
	var top := 0
	while top < ih - 1 and not _row_solid(img, top):
		top += 1
	var bottom := ih - 1
	while bottom > top and not _row_solid(img, bottom):
		bottom -= 1
	var left := 0
	while left < iw - 1 and not _col_solid(img, left, top, bottom):
		left += 1
	var right := iw - 1
	while right > left and not _col_solid(img, right, top, bottom):
		right -= 1
	if right - left < 8 or bottom - top < 8:
		return full
	return Rect2(left, top, right - left + 1, bottom - top + 1)


## True if a row has clearly visible pixels (sampled every 3 px).
static func _row_solid(img: Image, y: int) -> bool:
	for x in range(0, img.get_width(), 3):
		if img.get_pixel(x, y).a >= ALPHA_CUTOFF:
			return true
	return false


static func _col_solid(img: Image, x: int, y_from: int, y_to: int) -> bool:
	for y in range(y_from, y_to + 1, 3):
		if img.get_pixel(x, y).a >= ALPHA_CUTOFF:
			return true
	return false


static func _region(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	if not _regions.has(tex.get_rid()):
		_regions[tex.get_rid()] = _visible_region(tex)
	return _regions[tex.get_rid()]


## On-screen width of one end ornament at this banner height.
func _end_width(tex: Texture2D, h: float) -> float:
	if tex == null:
		return h * 0.5
	var r := _region(tex)
	return r.size.x * END_SHARE * (h / maxf(r.size.y, 1.0))


## Draws the plaque: ends keep their shape, the middle stretches.
func _draw_frame(frame: Control, tex: Texture2D, defeat: bool) -> void:
	var w := frame.size.x
	var h := frame.size.y
	if tex == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("22262e", 0.92) if defeat else Color("12302a", 0.92)
		sb.border_color = Color("8a93a3") if defeat else Color("e2c27a")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		frame.draw_style_box(sb, Rect2(Vector2.ZERO, frame.size))
		return
	var r := _region(tex)
	var x0 := r.position.x
	var y0 := r.position.y
	var rw := r.size.x
	var rh := r.size.y
	var src_end := rw * END_SHARE
	var dst_end := _end_width(tex, h)
	# left end, stretched middle, right end (padding trimmed off)
	frame.draw_texture_rect_region(tex, Rect2(0, 0, dst_end, h), Rect2(x0, y0, src_end, rh))
	frame.draw_texture_rect_region(tex, Rect2(dst_end, 0, w - dst_end * 2.0, h),
		Rect2(x0 + src_end, y0, rw - src_end * 2.0, rh))
	frame.draw_texture_rect_region(tex, Rect2(w - dst_end, 0, dst_end, h),
		Rect2(x0 + rw - src_end, y0, src_end, rh))


func _text(value: String, font_size: int, color: Color, heading: bool, number := false) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 7 if heading else 5)
	if number:
		var f := DamageNumber.get_number_font()
		if f != null:
			l.add_theme_font_override("font", f)
	if heading:
		l.add_theme_color_override("font_shadow_color", Color(1.0, 0.8, 0.35, 0.35))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 14)
	return l


static func _commas(n: int) -> String:
	var digits := str(n)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
