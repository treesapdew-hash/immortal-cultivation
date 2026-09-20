extends Container

# Fills the six formation slots from GameState and keeps them
# up to date. Slot order here matches GameState.formation.

signal slot_selected(slot_index: int)


func _ready() -> void:
	GameState.formation_changed.connect(refresh)
	GameState.roster_changed.connect(refresh)

	var index := 0
	for slot in get_children():
		if slot.has_method("set_partner"):
			slot.pressed.connect(_on_slot_pressed.bind(index))
			index += 1

	refresh()


func refresh() -> void:
	var partners: Array = GameState.get_formation_partners()
	var index := 0

	for slot in get_children():
		if not slot.has_method("set_partner"):
			continue
		var partner: OwnedPartner = null
		if index < partners.size():
			partner = partners[index]
		slot.set_partner(partner)
		index += 1


func _on_slot_pressed(index: int) -> void:
	slot_selected.emit(index)
