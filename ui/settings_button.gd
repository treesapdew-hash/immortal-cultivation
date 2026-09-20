extends TextureButton

# =========================================================
# The gear in the top bar. Attach this script to that
# TextureButton (home_screen > TopBar > ... > TextureButton).
# Opens Settings, and applies saved settings at start-up.
#
# Hover: brightens, grows a little and turns like a gear.
# Press: presses in, then springs back (phones have no hover).
# =========================================================

const HOVER_BRIGHT := Color(1.35, 1.3, 1.15)
const HOVER_SCALE := 1.1
const PRESS_SCALE := 0.9
const TURN_DEGREES := 45.0

var _tween: Tween
var _hovered := false


func _ready() -> void:
	Settings.load_and_apply()
	pressed.connect(func(): SettingsPopup.open(self))

	resized.connect(_center_pivot)
	_center_pivot()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _on_hover(on: bool) -> void:
	_hovered = on
	_animate(HOVER_BRIGHT if on else Color.WHITE, HOVER_SCALE if on else 1.0,
		deg_to_rad(TURN_DEGREES) if on else 0.0, 0.25)


func _on_down() -> void:
	_animate(HOVER_BRIGHT, PRESS_SCALE, rotation, 0.08)


func _on_up() -> void:
	# Spring back with a small extra turn
	_animate(HOVER_BRIGHT if _hovered else Color.WHITE, HOVER_SCALE if _hovered else 1.0,
		rotation + deg_to_rad(TURN_DEGREES * 0.5), 0.3)


func _animate(tint: Color, grow: float, turn: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate", tint, seconds).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2.ONE * grow, seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", turn, seconds).set_trans(Tween.TRANS_SINE)
