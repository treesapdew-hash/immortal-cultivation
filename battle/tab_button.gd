@tool
extends Control

# Each unit: Vector3(x, y, scale)
# x = 0..1 across the battle area (where the unit's centre stands)
# y = 0..1 down the battle area (where the unit's FEET touch)
# Tweak these numbers, save, then reload the scene to see changes.
const SPOTS := {
	"EnemyBackRow/E4": Vector3(0.20, 0.28, 0.80),
	"EnemyBackRow/E5": Vector3(0.42, 0.28, 0.80),
	"EnemyBackRow/E6": Vector3(0.64, 0.28, 0.80),
	"EnemyFrontRow/E1": Vector3(0.36, 0.40, 0.85),
	"EnemyFrontRow/E2": Vector3(0.58, 0.40, 0.85),
	"EnemyFrontRow/E3": Vector3(0.80, 0.40, 0.85),
	"PlayerFrontRow/P1": Vector3(0.20, 0.75, 1.00),
	"PlayerFrontRow/P2": Vector3(0.42, 0.75, 1.00),
	"PlayerFrontRow/P3": Vector3(0.64, 0.75, 1.00),
	"PlayerBackRow/P4": Vector3(0.36, 0.92, 1.08),
	"PlayerBackRow/P5": Vector3(0.58, 0.92, 1.08),
	"PlayerBackRow/P6": Vector3(0.80, 0.92, 1.08),
}


func _ready() -> void:
	# Make every row cover the whole formation area
	for row in get_children():
		if row is Control:
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for path in SPOTS:
		var unit := get_node_or_null(path) as Control
		if unit == null:
			push_warning("Formation: can't find " + path)
			continue
		var spot: Vector3 = SPOTS[path]
		unit.anchor_left = spot.x
		unit.anchor_right = spot.x
		unit.anchor_top = spot.y
		unit.anchor_bottom = spot.y
		unit.offset_left = 0
		unit.offset_right = 0
		unit.offset_top = 0
		unit.offset_bottom = 0
		unit.grow_horizontal = Control.GROW_DIRECTION_BOTH
		unit.grow_vertical = Control.GROW_DIRECTION_BEGIN
		unit.scale = Vector2(spot.z, spot.z)
