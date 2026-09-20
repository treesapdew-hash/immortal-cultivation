extends Control

# Bottom navigation. Tells the rest of the game which tab
# was chosen, and keeps Home selected at the start.

signal tab_changed(nav_id: String)

@export var start_tab := "home"

var current_tab := ""


func _ready() -> void:
	for button in _buttons():
		button.nav_selected.connect(_on_nav_selected)
	select_tab(start_tab)


func _buttons() -> Array:
	var result := []
	for child in $Buttons.get_children():
		if child.has_signal("nav_selected"):
			result.append(child)
	return result


## Selects a tab from code (e.g. a "back to home" button).
func select_tab(nav_id: String) -> void:
	for button in _buttons():
		if button.nav_id == nav_id:
			button.button_pressed = true
	_on_nav_selected(nav_id)


func _on_nav_selected(nav_id: String) -> void:
	if nav_id == current_tab:
		return
	current_tab = nav_id
	tab_changed.emit(nav_id)
	print("NavBar: ", nav_id)   # remove once screens are hooked up


## Turns a button's red dot on or off from anywhere.
func set_badge(nav_id: String, show: bool) -> void:
	for button in _buttons():
		if button.nav_id == nav_id:
			button.show_badge = show
