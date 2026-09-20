extends Control

# Shows one currency from GameState and updates it live.
# Attach to the root of resource_pill.tscn, then on each pill in
# home_screen pick which currency it shows in the Inspector.

signal plus_pressed(currency: int)

enum Currency { SPIRIT_STONES, IMMORTAL_JADE, QI, STARUP_PILLS }

@export var currency: Currency = Currency.SPIRIT_STONES

## The number label. Found automatically if left empty.
@export var amount_label: Label
## The "+" button (for a future shop). Optional.
@export var plus_button: BaseButton

@export var gain_color := Color("7dffa8")
@export var loss_color := Color("ff7a7a")

var _shown := 0
var _count_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	if amount_label == null:
		amount_label = _find_label(self)
	if amount_label == null:
		push_warning("ResourcePill: no Label found in " + name)
		return

	# The "+" button: use the one set in the Inspector, or find it.
	if plus_button == null:
		var found := find_children("*", "BaseButton", true, false)
		if not found.is_empty():
			plus_button = found[0]
	if plus_button != null:
		plus_button.pressed.connect(_on_plus)

	GameState.currency_changed.connect(_on_currency_changed)

	_shown = _get_amount()
	amount_label.text = format_amount(_shown)


## Opens the shop's Top Up tab (Jade packs / Stones exchange).
func _on_plus() -> void:
	plus_pressed.emit(currency)
	var scene := get_tree().current_scene
	var router = scene.find_child("LowerStack", true, false) if scene != null else null
	if router != null and router.has_method("open_more"):
		# Spirit Stones: jump to the exchange at the bottom
		var anchor := "stones" if currency == Currency.SPIRIT_STONES else ""
		router.call("open_more", "Top Up", anchor)


func _get_amount() -> int:
	match currency:
		Currency.IMMORTAL_JADE:
			return GameState.immortal_jade
		Currency.QI:
			return GameState.qi
		Currency.STARUP_PILLS:
			return GameState.starup_pills
		_:
			return GameState.spirit_stones


func _on_currency_changed() -> void:
	var target := _get_amount()
	if target == _shown:
		return

	_flash(target > _shown)

	# Count up/down to the new amount
	if _count_tween != null:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_method(_set_shown, _shown, target, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_shown(value: int) -> void:
	_shown = value
	amount_label.text = format_amount(value)


## Green flash and a little pop on gain, red on loss.
func _flash(gained: bool) -> void:
	if _flash_tween != null:
		_flash_tween.kill()

	amount_label.pivot_offset = amount_label.size * 0.5
	amount_label.modulate = gain_color if gained else loss_color
	amount_label.scale = Vector2(1.15, 1.15)

	_flash_tween = create_tween().set_parallel(true)
	_flash_tween.tween_property(amount_label, "modulate", Color.WHITE, 0.6)
	_flash_tween.tween_property(amount_label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Uses the shared formatter: 99,999 / 100K / 1.23M / 10B ...
static func format_amount(value: int) -> String:
	return NumberFormat.short(value)


func _find_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
		var found := _find_label(child)
		if found != null:
			return found
	return null
