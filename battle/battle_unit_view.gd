extends Control

# Display only. Shows one fighter and plays its animations.
# All numbers come from the CombatUnit it is given.

const BAR_TWEEN_TIME := 0.25
const BOSS_SIZE_MULT := 1.55
## Bosses draw above the other enemies instead of behind them.
const BOSS_Z := 5

# Ring shown under the unit while it is taking its turn.
# Set both in the Inspector on battle_unit_view.tscn's root.
@export var player_ring: Texture2D
@export var enemy_ring: Texture2D

# Unique names (%) find these nodes wherever they sit in the tree.
@onready var sprite: TextureRect = $Sprite
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var path_badge: TextureRect = %PathBadge
@onready var turn_ring: TextureRect = $TurnRing

var unit: CombatUnit = null

# Remembered so bosses can grow and normal units go back.
var base_min_size: Vector2

var bar_tween: Tween
var ring_tween: Tween
var move_tween: Tween

# Sprite's resting position. Lunges, shakes and sidesteps always
# return here, so overlapping tweens can't leave it off-centre.
var sprite_home: Vector2

# Short pause after a crit lands so it reads before anything else happens.
const CRIT_HITSTOP := 0.12


func _ready():
	base_min_size = custom_minimum_size
	sprite_home = sprite.position


func bind(new_unit: CombatUnit):
	unit = new_unit

	if unit == null:
		visible = false
		return

	visible = true
	modulate = Color.WHITE
	sprite.modulate = Color.WHITE
	set_turn(false)

	name_label.text = unit.display_name
	name_label.add_theme_color_override("font_color", unit.name_color)

	# Dao badge (hidden if the unit has none yet)
	var badge = unit.get("dao_badge")
	path_badge.texture = badge
	path_badge.visible = badge != null

	if unit.sprite_texture != null:
		sprite.texture = unit.sprite_texture

	# Enemies face the other way.
	sprite.flip_h = (unit.side == CombatUnit.Side.ENEMY)

	# Bosses stand bigger. The unit grows upward from its feet,
	# so it stays planted in its slot.
	if unit.is_boss:
		custom_minimum_size = base_min_size * BOSS_SIZE_MULT
	else:
		custom_minimum_size = base_min_size

	sprite.self_modulate = unit.tint
	_set_boss_aura(unit.is_boss)
	_set_rarity_seal(unit.rarity)
	_ensure_status_row()

	# Bosses are huge, so they stand in front of the mobs
	z_index = BOSS_Z if unit.is_boss else 0

	refresh(false)


# ---------------------------------------------------------
# RARITY SEAL (partners)
# A tier-coloured ring on the ground under the unit, so its card
# tier reads at a glance. Red pulses, Gold and Prismatic sparkle,
# Prismatic cycles through the rainbow.
# ---------------------------------------------------------

var _seal: Control
var _seal_rarity := -1
var _seal_tier := 0
var _seal_time := 0.0


func _set_rarity_seal(rarity: int) -> void:
	_seal_rarity = rarity
	if rarity < 0:
		if _seal != null:
			_seal.visible = false
		set_process(false)
		return
	_seal_tier = Realms.tier_index(rarity)
	if _seal == null:
		_seal = Control.new()
		_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_seal.draw.connect(_draw_seal)
		add_child(_seal)
		# Just above the shadow, under the sprite
		var shadow := get_node_or_null("Shadow") as Control
		if shadow != null:
			move_child(_seal, shadow.get_index() + 1)
			shadow.item_rect_changed.connect(_place_seal)
		else:
			move_child(_seal, 0)
		sprite.item_rect_changed.connect(_place_seal)
	_seal.visible = true
	_place_seal.call_deferred()
	# Only the animated tiers (Red and up) need to redraw every frame
	set_process(_seal_tier >= 4)
	_seal.queue_redraw()


func _place_seal() -> void:
	if _seal == null:
		return
	var shadow := get_node_or_null("Shadow") as Control
	var foot: Rect2
	if shadow != null:
		foot = Rect2(shadow.position, shadow.size)
	else:
		foot = Rect2(sprite.position + Vector2(0, sprite.size.y * 0.85), Vector2(sprite.size.x, sprite.size.y * 0.15))
	# A little wider than the shadow, centred on it
	var w := maxf(foot.size.x * 1.15, 40.0)
	var h := maxf(foot.size.y * 1.1, 14.0)
	var c := foot.position + foot.size * 0.5
	_seal.position = c - Vector2(w, h) * 0.5
	_seal.size = Vector2(w, h)
	_seal.queue_redraw()


func _process(delta: float) -> void:
	if _seal != null and _seal.visible:
		_seal_time += delta
		_seal.queue_redraw()


func _seal_color() -> Color:
	if _seal_tier >= 6:
		# Prismatic: the hue slowly cycles
		return Color.from_hsv(fmod(_seal_time * 0.25, 1.0), 0.55, 1.0)
	var col: Color = ItemDB.grade_color(_seal_tier)
	return col


func _ellipse(rect_size: Vector2, scale_by: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := rect_size * 0.5
	var rx := rect_size.x * 0.5 * scale_by
	var ry := rect_size.y * 0.5 * scale_by
	for i in 33:
		var a := TAU * float(i) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_seal() -> void:
	var s := _seal.size
	var col := _seal_color()
	if _seal_tier <= 0:
		# White: a faint silver ring only
		_seal.draw_polyline(_ellipse(s, 1.0), Color(0.85, 0.88, 0.95, 0.35), 2.0, true)
		return
	var pulse := 1.0
	if _seal_tier >= 4:
		pulse = 0.75 + 0.25 * sin(_seal_time * 3.0)
	# Soft inner glow, then two rings
	var glow := _ellipse(s, 0.95)
	glow.remove_at(glow.size() - 1)
	_seal.draw_colored_polygon(glow, Color(col, 0.18 * pulse + (0.08 if _seal_tier >= 5 else 0.0)))
	_seal.draw_polyline(_ellipse(s, 1.0), Color(col, 0.9 * pulse), 3.0 if _seal_tier >= 3 else 2.0, true)
	_seal.draw_polyline(_ellipse(s, 0.72), Color(col.lightened(0.3), 0.45 * pulse), 1.5, true)

	# Gold and Prismatic: little sparkles rising from the ring
	if _seal_tier >= 5:
		for k in 5:
			var t := fmod(_seal_time * 0.6 + float(k) * 0.2, 1.0)
			var a := TAU * (float(k) / 5.0 + _seal_time * 0.05)
			var base := s * 0.5 + Vector2(cos(a) * s.x * 0.45, sin(a) * s.y * 0.45)
			var p := base + Vector2(0, -t * s.y * 2.2)
			_seal.draw_circle(p, 2.5 * (1.0 - t) + 1.0, Color(col.lightened(0.4), (1.0 - t) * 0.9))


# ---------------------------------------------------------
# BOSS AURA
# ---------------------------------------------------------

var _aura: TextureRect
var _aura_tween: Tween


## A pulsing crimson glow behind bosses.
func _set_boss_aura(on: bool) -> void:
	if not on:
		if _aura != null:
			_aura.visible = false
		if _aura_tween != null:
			_aura_tween.kill()
			_aura_tween = null
		return

	if _aura == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.width = 128
		tex.height = 128
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)

		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

		_aura = TextureRect.new()
		_aura.texture = tex
		_aura.material = add
		_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_aura.stretch_mode = TextureRect.STRETCH_SCALE
		_aura.show_behind_parent = true
		sprite.add_child(_aura)

	_aura.visible = true
	_aura.modulate = Color(1.0, 0.2, 0.15, 0.55)
	# Sized after layout, around the sprite's lower body
	_fit_aura.call_deferred()
	if not sprite.resized.is_connected(_fit_aura):
		sprite.resized.connect(_fit_aura)

	if _aura_tween != null:
		_aura_tween.kill()
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(_aura, "modulate:a", 0.25, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aura_tween.tween_property(_aura, "modulate:a", 0.6, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _fit_aura() -> void:
	if _aura != null and _aura.visible:
		_aura.size = sprite.size * Vector2(1.3, 0.9)
		_aura.position = Vector2(sprite.size.x * -0.15, sprite.size.y * 0.2)


# Updates both bars. animate = false snaps them instantly
# (used when a new battle starts).
func refresh(animate: bool = true):
	if unit == null:
		return

	if _status_row != null:
		_status_row.queue_redraw()

	hp_bar.max_value = unit.max_hp
	energy_bar.max_value = unit.max_energy

	if bar_tween != null:
		bar_tween.kill()

	if not animate:
		hp_bar.value = unit.current_hp
		energy_bar.value = unit.energy
		return

	bar_tween = create_tween().set_parallel(true)
	bar_tween.tween_property(hp_bar, "value", float(unit.current_hp), BAR_TWEEN_TIME)
	bar_tween.tween_property(energy_bar, "value", float(unit.energy), BAR_TWEEN_TIME)


# Shows or hides the turn ring. Blue for players, red for enemies.
func set_turn(active: bool):
	if ring_tween != null:
		ring_tween.kill()
		ring_tween = null

	if not active or unit == null:
		turn_ring.visible = false
		return

	if unit.side == CombatUnit.Side.ENEMY:
		turn_ring.texture = enemy_ring
	else:
		turn_ring.texture = player_ring

	turn_ring.visible = true
	turn_ring.modulate.a = 1.0

	# Gentle pulse while active
	ring_tween = create_tween().set_loops()
	ring_tween.tween_property(turn_ring, "modulate:a", 0.55, 0.3)
	ring_tween.tween_property(turn_ring, "modulate:a", 1.0, 0.3)


# ---------------------------------------------------------
# ANIMATIONS
#
# Each returns after its tween finishes, so the battle loop
# can await them and stay in step with what is on screen.
# ---------------------------------------------------------

# Re-reads the resting position when the sprite is standing still
# (layout or boss resizing can move it), then returns a fresh tween.
func _new_move_tween() -> Tween:
	if move_tween != null and move_tween.is_running():
		move_tween.kill()
	else:
		sprite_home = sprite.position

	move_tween = create_tween()
	return move_tween


func play_attack():
	var tween = _new_move_tween()
	var start = sprite_home

	# Player units lunge up, enemies lunge down.
	var direction = Vector2(0, -24)

	if unit != null and unit.side == CombatUnit.Side.ENEMY:
		direction = Vector2(0, 24)

	tween.tween_property(sprite, "position", start + direction, 0.10)
	tween.tween_property(sprite, "position", start, 0.10)

	await tween.finished


# Takes the result dictionary from BattleCore.resolve_attack().
# Await it so a crit's hitstop finishes before the death fade starts.
func play_hit(result: Dictionary):
	refresh()

	var is_crit: bool = result.get("crit", false)

	_spawn_number(
		result.get("damage", 0),
		DamageNumber.Kind.CRIT if is_crit else DamageNumber.Kind.NORMAL
	)
	_spawn_slash(is_crit)

	# Flash: red tint on normal hits, bright white-hot on crits
	# (modulate above 1 brightens the sprite).
	sprite.modulate = Color(3.0, 2.6, 2.2) if is_crit else Color(1.0, 0.35, 0.35)
	var flash = create_tween()
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.25 if is_crit else 0.20)

	# Shake, much stronger on crits. Always returns to sprite_home.
	var shake = _new_move_tween()
	var strength := 20.0 if is_crit else 7.0

	for i in 5:
		var offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.4, strength * 0.4)
		)
		shake.tween_property(sprite, "position", sprite_home + offset, 0.03)
		strength *= 0.7

	shake.tween_property(sprite, "position", sprite_home, 0.04)

	if is_crit:
		await get_tree().create_timer(CRIT_HITSTOP).timeout


func play_dodge():
	_spawn_number(0, DamageNumber.Kind.DODGE)

	# Quick sidestep
	var tween = _new_move_tween()
	tween.tween_property(sprite, "position", sprite_home + Vector2(18, 0), 0.08)
	tween.tween_property(sprite, "position", sprite_home, 0.12)


## "+12 Qi" floating up from a defeated enemy.
func play_qi(amount: int):
	_spawn_number(amount, DamageNumber.Kind.QI)


## Small coloured tags beside the bars: STN, SIL, BLD...
## They stack downward in one column, newest at the bottom.
var _status_row: Control

## Tag height and the gap between stacked tags.
const STATUS_TAG_H := 16.0
const STATUS_TAG_GAP := 3.0


func _ensure_status_row() -> void:
	if _status_row != null:
		return
	_status_row = Control.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.custom_minimum_size = Vector2(0, STATUS_TAG_H)
	_status_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_row.draw.connect(_draw_statuses)
	add_child(_status_row)


func _draw_statuses() -> void:
	if unit == null or unit.statuses.is_empty():
		return
	var font := get_theme_default_font()
	var fs := 13
	var x := 4.0
	var y := name_label.position.y + name_label.size.y + 26.0 if name_label != null else 26.0

	# One width for the whole column, so the tags line up neatly
	var labels: Array = []
	var col_w := 0.0
	for id in unit.statuses:
		var tag_text := "%s%d" % [Statuses.tag_of(id), int(unit.statuses[id]["turns"])]
		labels.append([id, tag_text])
		col_w = maxf(col_w, font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0)

	for entry in labels:
		var id = entry[0]
		var tag_text: String = entry[1]
		var tag_color: Color = Statuses.color_of(id)
		_status_row.draw_rect(Rect2(x, y, col_w, STATUS_TAG_H), Color(0, 0, 0, 0.55))
		_status_row.draw_rect(Rect2(x, y, col_w, STATUS_TAG_H), tag_color, false, 1.0)
		_status_row.draw_string(font, Vector2(x + 4, y + 12), tag_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tag_color)
		y += STATUS_TAG_H + STATUS_TAG_GAP


## Glow in the Dao's colour as a skill fires.
func play_skill_glow(color: Color) -> void:
	sprite.self_modulate = color.lerp(Color.WHITE, 0.3) * 1.6
	var t := create_tween()
	t.tween_property(sprite, "self_modulate", unit.tint if unit != null else Color.WHITE, 0.5)
	scale = Vector2(1.08, 1.08)
	var s := create_tween()
	s.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Status word above the unit ("FROZEN", "SHIELD", "NIRVANA"...).
func play_status(text: String, color: Color):
	var fx = get_tree().get_first_node_in_group("battle_fx")
	if fx == null:
		fx = self
	var rect := sprite.get_global_rect()
	DamageNumber.spawn_text(fx, Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.25), text, color)
	refresh()


func play_heal(amount: int):
	refresh()
	_spawn_number(amount, DamageNumber.Kind.HEAL)


# Sword light across the target, stronger on crits.
func _spawn_slash(strong: bool):
	var fx = get_tree().get_first_node_in_group("battle_fx")

	if fx == null:
		fx = self

	DamageNumber.spawn_slash(fx, sprite.get_global_rect().get_center(), strong)


# Numbers go on the shared FxLayer (group "battle_fx") so they
# draw above every unit and don't fade out with a dying unit.
func _spawn_number(amount: int, kind: DamageNumber.Kind):
	var fx = get_tree().get_first_node_in_group("battle_fx")

	if fx == null:
		fx = self

	var rect := sprite.get_global_rect()
	var at := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.3)

	DamageNumber.spawn(fx, at, amount, kind)


func play_death():
	set_turn(false)

	var tween = create_tween()

	tween.tween_property(self, "modulate:a", 0.0, 0.35)

	await tween.finished
