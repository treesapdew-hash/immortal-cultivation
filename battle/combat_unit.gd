class_name CombatUnit
extends RefCounted

# One fighter inside a single battle. Built when the battle
# starts, thrown away when it ends. Never saved.

enum Side { PLAYER, ENEMY }

var side: int = Side.PLAYER

# 0-5. Slot 1 is index 0.
# Front row = 0,1,2   Back row = 3,4,5
# Lane = index % 3, so lane 0 holds indices 0 and 3.
var slot_index: int = 0

var display_name: String = ""

var max_hp: int = 100
var current_hp: int = 100

var atk: int = 10
var defense: int = 0
var mdef: int = 0
var spd: int = 100

var crit: float = 10.0
var crit_damage: float = 150.0
var eva: float = 5.0
var accuracy: float = 90.0

# Spec section 28. Fills as the unit acts; skills come in Step 6.
var energy: int = 0
var energy_regen: int = 20
var max_energy: int = 100

var sprite_texture: Texture2D
var name_color: Color = Color.WHITE

var is_boss: bool = false


func is_alive() -> bool:
	return current_hp > 0


func get_lane() -> int:
	return slot_index % 3


func is_front_row() -> bool:
	return slot_index < 3


func take_damage(amount: int):
	current_hp = maxi(0, current_hp - amount)


func gain_energy():
	energy = mini(max_energy, energy + energy_regen)


static func from_partner(partner: OwnedPartner, index: int) -> CombatUnit:
	var unit = CombatUnit.new()

	unit.side = Side.PLAYER
	unit.slot_index = index

	var data = partner.get_data()

	unit.display_name = partner.get_display_name()

	unit.max_hp = partner.get_max_hp()
	unit.current_hp = unit.max_hp

	unit.atk = partner.get_atk()
	unit.defense = partner.get_def()
	unit.mdef = partner.get_mdef()
	unit.spd = partner.get_spd()

	unit.crit = partner.get_crit()
	unit.crit_damage = partner.get_crit_damage()
	unit.eva = partner.get_eva()
	unit.accuracy = partner.get_accuracy()

	unit.energy_regen = partner.get_energy_regen()

	if data != null:
		unit.sprite_texture = data.sprite_texture
		unit.name_color = data.get_rarity_color()

	return unit


static func from_enemy(enemy: Dictionary, index: int) -> CombatUnit:
	var unit = CombatUnit.new()

	unit.side = Side.ENEMY
	unit.slot_index = index

	unit.display_name = enemy.get("name", "Enemy")

	unit.max_hp = enemy.get("hp", 100)
	unit.current_hp = unit.max_hp

	unit.atk = enemy.get("atk", 10)
	unit.defense = enemy.get("def", 0)
	unit.mdef = enemy.get("mdef", 0)
	unit.spd = enemy.get("spd", 100)

	unit.crit = enemy.get("crit", 10.0)
	unit.crit_damage = enemy.get("crit_damage", 150.0)
	unit.eva = enemy.get("eva", 5.0)
	unit.accuracy = enemy.get("accuracy", 85.0)

	unit.energy_regen = enemy.get("energy_regen", 15)

	unit.is_boss = enemy.get("is_boss", false)
	unit.sprite_texture = enemy.get("sprite", null)
	unit.name_color = enemy.get("color", Color(1.0, 0.6, 0.6))

	return unit
