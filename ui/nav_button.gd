@tool
extends Button

# One bottom-nav button. Each icon PNG already includes its ring.
# The active button is bright and slightly larger; the rest are dimmed.
#
# Badge: a glowing red dot at the top-right of the medallion, with a
# number when several things are waiting. With auto_badge on (the
# default) it turns on by itself when this tab has something to do
# (see badge_count_for). show_badge only previews it in the editor.

signal nav_selected(nav_id: String)

static var nav_group: ButtonGroup

@export var nav_id := "home"

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply()

@export var label_text := "Home":
	set(value):
		label_text = value
		_apply()

## Editor preview of the badge (in game, auto_badge decides).
@export var show_badge := false:
	set(value):
		show_badge = value
		_apply()

## Turn the badge on and off from game state (see badge_count_for).
@export var auto_badge := true

@export_group("Look")
@export var normal_tint := Color(0.6, 0.64, 0.7)      # dimmed, silvery
@export var selected_tint := Color(1, 1, 1)
@export var selected_scale := 1.12
@export var hover_tint := Color(0.85, 0.88, 0.92)

@export_group("Badge")
## Dot size as a share of the icon's width.
@export var badge_size := 0.24
## Where on the ring it sits: offset from the icon centre, as a share
## of the icon size (x right, y up).
@export var badge_offset := Vector2(0.34, 0.34)
@export var badge_color := Color("e0302a")

const BADGE_REFRESH_SECONDS := 3.0

## Fallbacks if a badge setting comes through empty (can happen with
## @tool scripts when new settings are added to an open scene).
const DEFAULT_BADGE_COLOR := Color("e0302a")
const DEFAULT_BADGE_SIZE := 0.24
const DEFAULT_BADGE_OFFSET := Vector2(0.34, 0.34)

var _count := 0
var _dot: Control
var _pulse: Tween
var _refresh_queued := false


func _ready() -> void:
	# No default button background in any state
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus",
			"normal_mirrored", "hover_mirrored", "pressed_mirrored",
			"hover_pressed_mirrored", "disabled_mirrored"]:
		add_theme_stylebox_override(s, empty)

	_make_dot()
	_apply()

	if Engine.is_editor_hint():
		return

	if nav_group == null:
		nav_group = ButtonGroup.new()

	toggle_mode = true
	button_group = nav_group

	toggled.connect(func(_on): _apply())
	pressed.connect(func(): nav_selected.emit(nav_id))
	mouse_entered.connect(_apply)
	mouse_exited.connect(_apply)

	var icon_rect: TextureRect = %Icon
	icon_rect.resized.connect(func(): icon_rect.pivot_offset = icon_rect.size / 2.0)
	icon_rect.pivot_offset = icon_rect.size / 2.0

	if auto_badge:
		var sigs: Array[Signal] = [GameState.currency_changed, GameState.achievements_changed,
				GameState.expeditions_updated, GameState.mail_changed, GameState.stage_changed,
				GameState.array_changed, GameState.roster_changed, GameState.formation_changed]
		for sig in sigs:
			sig.connect(_queue_refresh)
		# Time-based things (expeditions returning, a new day) need a nudge too
		var timer := Timer.new()
		timer.wait_time = BADGE_REFRESH_SECONDS
		timer.autostart = true
		timer.timeout.connect(_queue_refresh)
		add_child(timer)
		_queue_refresh()


func _apply() -> void:
	if not is_node_ready():
		return

	var icon_rect: TextureRect = %Icon
	var name_label: Label = %NameLabel
	var badge: Control = %Badge

	if icon_texture != null:
		icon_rect.texture = icon_texture
	name_label.text = label_text
	# The old scene badge is replaced by the drawn dot
	badge.visible = false

	var active := button_pressed
	var hovering := not Engine.is_editor_hint() and is_hovered()

	var tint := normal_tint
	if active:
		tint = selected_tint
	elif hovering:
		tint = hover_tint

	icon_rect.modulate = tint
	name_label.modulate = tint
	icon_rect.scale = Vector2.ONE * (selected_scale if active else 1.0)

	var shown := show_badge if (Engine.is_editor_hint() or not auto_badge) else _count > 0
	_set_dot_visible(shown)
	_place_dot.call_deferred()


# ---------------------------------------------------------
# BADGE
# ---------------------------------------------------------

## How many things wait on this tab (0 = no badge).
static func badge_count_for(id: String) -> int:
	match id:
		"growth":
			var n := 0
			for trip in Expeditions.running():
				if Expeditions.is_done(trip):
					n += 1
			if BattleArray.can_upgrade() == "":
				n += 1
			if BattleArray.slots().has("") and not BattleArray.candidates().is_empty():
				n += 1
			return n
		"mission":
			return Missions.total_claimable() + Achievements.claimable_count()
		"events":
			var n := 0
			if Trials.is_unlocked() and Trials.entries_left() > 0:
				n += 1
			if Tribulation.is_unlocked() and not Tribulation.done_today():
				n += 1
			if FallenGod.is_unlocked() and FallenGod.attacks_left() > 0:
				n += 1
			if FallenGod.claimable_rank() > 0:
				n += 1
			if Beasts.is_unlocked() and Beasts.hunts_left() > 0:
				n += 1
			return n
		"more":
			var n := 0
			for m in GameState.mail:
				if not m is Dictionary:
					continue
				var mail_items: Dictionary = m.get("items", {})
				var has_gift: bool = int(m.get("jade", 0)) > 0 or not mail_items.is_empty()
				if (has_gift and not bool(m.get("claimed", false))) or not bool(m.get("read", false)):
					n += 1
			return n
	return 0


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_badge.call_deferred()


func _refresh_badge() -> void:
	_refresh_queued = false
	var n := badge_count_for(nav_id)
	if n == _count:
		return
	_count = n
	if _dot != null:
		_dot.queue_redraw()
	_apply()


func _make_dot() -> void:
	if _dot != null:
		return
	_dot = Control.new()
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	_dot.draw.connect(_draw_dot)
	add_child(_dot, false, Node.INTERNAL_MODE_BACK)
	var icon_rect: TextureRect = %Icon
	icon_rect.item_rect_changed.connect(_place_dot)
	resized.connect(_place_dot)


## Top-right of the medallion, following the icon's size and scale.
func _place_dot() -> void:
	if _dot == null or not is_inside_tree():
		return
	var icon_rect: TextureRect = %Icon
	var icon_size := icon_rect.size
	var size_share: float = badge_size if typeof(badge_size) == TYPE_FLOAT and badge_size > 0.0 else DEFAULT_BADGE_SIZE
	var off_share: Vector2 = badge_offset if typeof(badge_offset) == TYPE_VECTOR2 else DEFAULT_BADGE_OFFSET
	var side := maxf(icon_size.x * size_share, 16.0)
	_dot.size = Vector2(side, side)
	_dot.pivot_offset = _dot.size * 0.5
	var centre := icon_rect.global_position + icon_size * 0.5
	var offset := Vector2(icon_size.x * off_share.x, -icon_size.y * off_share.y) * icon_rect.scale.x
	_dot.global_position = centre + offset - _dot.size * 0.5


func _set_dot_visible(on: bool) -> void:
	if _dot == null or _dot.visible == on:
		return
	_dot.visible = on
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	_dot.scale = Vector2.ONE
	if on and not Engine.is_editor_hint():
		_pulse = _dot.create_tween().set_loops()
		_pulse.tween_property(_dot, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_dot, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _draw_dot() -> void:
	var s := _dot.size
	var c := s * 0.5
	var r := s.x * 0.5
	var col: Color = badge_color if typeof(badge_color) == TYPE_COLOR else DEFAULT_BADGE_COLOR
	# Soft glow, ruby body, gold-white rim, a small shine
	_dot.draw_circle(c, r * 1.45, Color(col, 0.22))
	_dot.draw_circle(c, r, col.darkened(0.25))
	_dot.draw_circle(c - Vector2(0, r * 0.08), r * 0.82, col)
	_dot.draw_arc(c, r, 0.0, TAU, 32, Color("ffe9c4"), maxf(r * 0.16, 1.5), true)
	_dot.draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.2, Color(1, 1, 1, 0.55))

	# A number when more than one thing is waiting
	if _count > 1 and not Engine.is_editor_hint():
		var label := "9+" if _count > 9 else str(_count)
		var font := _dot.get_theme_default_font()
		var fs := int(r * (1.05 if label.length() == 1 else 0.85))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := c + Vector2(-w * 0.5, fs * 0.36)
		_dot.draw_string_outline(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.3, 0.02, 0.0))
		_dot.draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
