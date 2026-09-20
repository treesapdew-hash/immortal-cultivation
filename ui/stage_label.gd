extends Label

# Shows the current stage and updates after every clear.

@export var format := "Stage %d"


func _ready() -> void:
	GameState.stage_changed.connect(refresh)
	refresh()


func refresh() -> void:
	text = format % GameState.current_stage
