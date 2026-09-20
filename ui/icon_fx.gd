class_name IconFX

# =========================================================
# Hover and press feedback for the floating icon buttons
# (mail, chat). Save as res://ui/icon_fx.gd
#
#   IconFX.attach(button)
#
# Scales and tints the whole button, so it works whether the icon
# is a texture or drawn in code.
#
# On a phone there is no hover, so only the press state fires there
# — which is the one that matters for feeling responsive to a tap.
# Hover is for the editor and any desktop build.
# =========================================================

const HOVER_SCALE := 1.08
const PRESS_SCALE := 0.92
const HOVER_TINT := Color(1.15, 1.12, 1.0)
const PRESS_TINT := Color(0.78, 0.78, 0.86)
const SPEED := 0.12


static func attach(b: Button) -> void:
	b.pivot_offset = b.size * 0.5
	var on_resized := func() -> void:
		b.pivot_offset = b.size * 0.5
	b.resized.connect(on_resized)

	# Shared by the handlers below: lambdas capture by value, so the
	# flags live in a Dictionary, which is a reference.
	var state := {"hover": false, "down": false, "tween": null}

	var apply := func() -> void:
		if not is_instance_valid(b):
			return
		var prev = state.get("tween", null)
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()

		var to_scale := 1.0
		var to_tint := Color.WHITE
		if bool(state["down"]):
			to_scale = PRESS_SCALE
			to_tint = PRESS_TINT
		elif bool(state["hover"]):
			to_scale = HOVER_SCALE
			to_tint = HOVER_TINT

		var t := b.create_tween().set_parallel(true)
		t.tween_property(b, "scale", Vector2.ONE * to_scale, SPEED) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "modulate", to_tint, SPEED)
		state["tween"] = t

	var on_enter := func() -> void:
		state["hover"] = true
		apply.call()

	var on_exit := func() -> void:
		state["hover"] = false
		state["down"] = false
		apply.call()

	var on_down := func() -> void:
		state["down"] = true
		apply.call()

	var on_up := func() -> void:
		state["down"] = false
		apply.call()

	b.mouse_entered.connect(on_enter)
	b.mouse_exited.connect(on_exit)
	b.button_down.connect(on_down)
	b.button_up.connect(on_up)
