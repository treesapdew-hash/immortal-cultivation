class_name MarqueeLabel
extends Control

# =========================================================
# A one-line label that scrolls itself when the text is too
# wide for the space, and sits still when it fits.
#
#   var m := MarqueeLabel.new()
#   m.setup("Crit DMG +26.5%  ·  Lightning 50%", 15, Color("9fb3cc"))
# =========================================================

## Pixels per second while scrolling.
const SPEED := 28.0
## Pause at each end, in seconds.
const PAUSE := 1.2

var _label: Label
var _tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	resized.connect(_restart)


func setup(text: String, font_size: int, color: Color) -> void:
	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	custom_minimum_size.y = _label.get_minimum_size().y
	_restart()


func set_color(color: Color) -> void:
	_label.add_theme_color_override("font_color", color)


func _restart() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_label.position.x = 0.0
	_label.size = _label.get_minimum_size()

	var overflow := _label.size.x - size.x
	if overflow <= 1.0 or size.x <= 0.0:
		return

	# Slide to the end, pause, slide back, pause, forever
	var travel := overflow / SPEED
	_tween = create_tween().set_loops()
	_tween.tween_interval(PAUSE)
	_tween.tween_property(_label, "position:x", -overflow, travel)
	_tween.tween_interval(PAUSE)
	_tween.tween_property(_label, "position:x", 0.0, travel)
