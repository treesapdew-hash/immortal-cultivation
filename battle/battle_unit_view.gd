extends Control

# Display only. Shows one fighter and plays its animations.
# All numbers come from the CombatUnit it is given.

@onready var sprite: TextureRect = $Sprite
@onready var name_label: Label = $InfoPlate/InfoLayout/NameLabel
@onready var hp_bar: ProgressBar = $InfoPlate/InfoLayout/HPBar

var unit: CombatUnit = null


func bind(new_unit: CombatUnit):
	unit = new_unit

	if unit == null:
		visible = false
		return

	visible = true
	modulate = Color.WHITE

	name_label.text = unit.display_name
	name_label.add_theme_color_override("font_color", unit.name_color)

	if unit.sprite_texture != null:
		sprite.texture = unit.sprite_texture

	# Enemies face the other way.
	sprite.flip_h = (unit.side == CombatUnit.Side.ENEMY)

	# Bosses take up more room (spec section 39).
	if unit.is_boss:
		custom_minimum_size = Vector2(220, 150)

	refresh()


func refresh():
	if unit == null:
		return

	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.current_hp


# ---------------------------------------------------------
# ANIMATIONS
#
# Each returns after its tween finishes, so the battle loop
# can await them and stay in step with what is on screen.
# ---------------------------------------------------------

func play_attack():
	var start = sprite.position

	# Player units lunge up, enemies lunge down.
	var direction = Vector2(0, -18)

	if unit != null and unit.side == CombatUnit.Side.ENEMY:
		direction = Vector2(0, 18)

	var tween = create_tween()

	tween.tween_property(sprite, "position", start + direction, 0.10)
	tween.tween_property(sprite, "position", start, 0.10)

	await tween.finished


func play_hit():
	sprite.modulate = Color(1.0, 0.35, 0.35)

	var tween = create_tween()

	tween.tween_property(sprite, "modulate", Color.WHITE, 0.20)

	refresh()


func play_death():
	var tween = create_tween()

	tween.tween_property(self, "modulate:a", 0.25, 0.25)

	await tween.finished


func show_popup(text: String, color: Color, big: bool = false):
	var popup = Label.new()

	popup.text = text
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100

	popup.add_theme_font_size_override("font_size", 22 if big else 16)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 4)

	add_child(popup)

	popup.position = Vector2(size.x * 0.5 - 20, 20)

	var end_position = popup.position + Vector2(0, -50)

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(popup, "position", end_position, 0.55)
	tween.tween_property(popup, "modulate:a", 0.0, 0.55)

	tween.finished.connect(popup.queue_free)
