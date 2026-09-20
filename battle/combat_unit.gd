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

# Fills as the unit acts; skills come later.
var energy: int = 0
var energy_regen: int = 20
var max_energy: int = 100

var sprite_texture: Texture2D
var name_color: Color = Color.WHITE
## Card tier (Enums.Rarity) for partners; -1 for enemies.
var rarity: int = -1
## How this unit uses its skill (see PartnerSkills): "active" casts at
## full energy, "proc" has a chance on each attack, "none" never.
var skill_mode := "active"

# Dao (Path) badge shown beside the HP bar. Null = no badge.
var dao_badge: Texture2D = null
## Which Dao this unit follows (decides its skill). -1 = none.
var dao: int = -1

var is_boss: bool = false

## Colour applied to the sprite (bosses get a crimson tint).
var tint: Color = Color.WHITE

## 4-piece set effects: {"shield": 15.0, "revive": 30.0, ...}
var effects: Dictionary = {}
## Spirit ring boosts to this unit's signature skill: {skill_power, skill_chance, skill_turns}.
var ring_skill: Dictionary = {}
## The bonded Soul Spirit's Beast Skill ({} if none) and its charge:
## it fires on every Beasts.BEAST_EVERY-th action.
var beast_skill: Dictionary = {}
var beast_charge := 0
var shield: int = 0
var revive_ready := false
var frozen := false

## Debuffs and buffs: {"bleed": {"turns": 2, "power": 18.0}, ...}
var statuses: Dictionary = {}

## Bosses deep in the game shrug off every debuff.
var immune_to_debuffs := false

## Artifact traits: {"executioner": 22.0, ...} (see Artifacts)
var traits: Dictionary = {}
## First Blood and Second Wind each fire once a battle.
var first_attack_done := false
var second_wind_used := false

## Which monster this is, for its skill (see MonsterDB).
var monster_id := ""

## Who this unit is, for partner skills. The MC uses GameState.MC_ID.
var partner_id := ""
## Optional override set on PartnerData ("skill_id").
var skill_id := ""

## Set by take_damage for the view: "shield", "revived"
var last_events: Array = []


func is_alive() -> bool:
	return current_hp > 0


func get_lane() -> int:
	return slot_index % 3


func is_front_row() -> bool:
	return slot_index < 3


## Multiplies HP and ATK, e.g. 1.1 for +10%. Call before the fight starts.
func apply_team_bonus(multiplier: float):
	max_hp = int(max_hp * multiplier)
	current_hp = max_hp
	atk = int(atk * multiplier)


## Flat HP / ATK / DEF lent by the Battle Array. Call before the fight starts.
func add_flat_bonus(bonus_hp: int, bonus_atk: int, bonus_def: int) -> void:
	max_hp += bonus_hp
	current_hp = max_hp
	atk += bonus_atk
	defense += bonus_def


## Gear effects that apply when a battle starts. Call after team bonuses.
func apply_start_effects() -> void:
	if effects.has("shield"):
		shield = int(max_hp * effects["shield"] / 100.0)
	revive_ready = effects.has("revive")
	if effects.has("energy"):
		energy = mini(max_energy, int(effects["energy"]))
	# Swift Start
	if traits.has("swift_start"):
		energy = mini(max_energy, energy + int(traits["swift_start"]))
	first_attack_done = false
	second_wind_used = false


# ---------------------------------------------------------
# STATUS EFFECTS (see Statuses)
# ---------------------------------------------------------

## Adds a status. Returns false when Immunity blocked it.
func add_status(id: String, turns: int, power := 0.0) -> bool:
	if Statuses.is_debuff(id) and is_immune():
		return false
	var current: Dictionary = statuses.get(id, {"turns": 0, "power": 0.0})
	statuses[id] = {
		"turns": maxi(int(current["turns"]), turns),
		"power": maxf(float(current["power"]), power),
	}
	return true


func is_immune() -> bool:
	return immune_to_debuffs or has_status(Statuses.IMMUNE)


func has_status(id: String) -> bool:
	return statuses.has(id) and int(statuses[id]["turns"]) > 0


func status_power(id: String) -> float:
	return float(statuses[id]["power"]) if has_status(id) else 0.0


func is_stunned() -> bool:
	return has_status(Statuses.STUN) or frozen


func is_silenced() -> bool:
	return has_status(Statuses.SILENCE)


## Counts every status down by one turn. Call at the end of the unit's turn.
func tick_statuses() -> void:
	for id in statuses.keys():
		statuses[id]["turns"] = int(statuses[id]["turns"]) - 1
		if int(statuses[id]["turns"]) <= 0:
			statuses.erase(id)


## Damage dealt multiplier (Weaken).
func attack_mult() -> float:
	return maxf(0.1, 1.0 - status_power(Statuses.WEAKEN) / 100.0)


## Damage taken multiplier (Armor Break).
func damage_taken_mult() -> float:
	return 1.0 + status_power(Statuses.ARMOR_BREAK) / 100.0


func clear_statuses() -> void:
	statuses.clear()
	frozen = false


func take_damage(amount: int):
	last_events.clear()
	# Unyielding: tougher when badly hurt
	if traits.has("unyielding") and float(current_hp) / maxf(max_hp, 1) < 0.3:
		amount = int(amount * maxf(0.1, 1.0 - traits["unyielding"] / 100.0))
	if shield > 0:
		var absorbed := mini(shield, amount)
		shield -= absorbed
		amount -= absorbed
		last_events.append("shield")
	current_hp = maxi(0, current_hp - amount)

	# Second Wind: the first time it drops below 30%
	if current_hp > 0 and not second_wind_used and traits.has("second_wind") \
			and float(current_hp) / maxf(max_hp, 1) < 0.3:
		second_wind_used = true
		current_hp = mini(max_hp, current_hp + int(max_hp * traits["second_wind"] / 100.0))
		last_events.append("second_wind")

	# Crimson Phoenix: rise again once
	if current_hp <= 0 and revive_ready:
		revive_ready = false
		current_hp = maxi(1, int(max_hp * effects["revive"] / 100.0))
		last_events.append("revived")


func gain_energy():
	energy = mini(max_energy, energy + energy_regen)


## Ready to use its skill? (Only units whose tier casts at full energy.)
func skill_ready() -> bool:
	return skill_mode == "active" and energy >= max_energy and not is_silenced() and is_alive()


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
	unit.traits = Artifacts.traits_for(partner.partner_id)
	unit.effects = Gear.effects_for(partner.partner_id)
	var treasure_fx := Treasures.effects_for(partner.partner_id)
	for effect in treasure_fx:
		unit.effects[effect] = maxf(float(unit.effects.get(effect, 0.0)), float(treasure_fx[effect]))

	# Beast Rings: specials add onto the gear effects, skill effects go aside
	var ring_fx := Beasts.effects_for(partner.partner_id)
	var ring_keys := {"start_shield": "shield", "start_energy": "energy", "boss_damage": "boss_dmg", "lifesteal": "lifesteal"}
	for key in ring_fx:
		if ring_keys.has(key):
			var eff := str(ring_keys[key])
			unit.effects[eff] = float(unit.effects.get(eff, 0.0)) + float(ring_fx[key])
		elif key == "crit_damage":
			unit.crit_damage += float(ring_fx[key])
		else:
			unit.ring_skill[key] = float(ring_fx[key])
	unit.beast_skill = Beasts.beast_skill_for(partner.partner_id)

	if data != null:
		unit.sprite_texture = data.sprite_texture
		unit.name_color = data.get_rarity_color()
		unit.rarity = int(data.rarity)
		# The MC always casts its Dao skill; partners follow their tier
		if partner.partner_id != GameState.MC_ID:
			unit.skill_mode = PartnerSkills.mode_for(unit.rarity)

	# Dao: the owned copy's own value first (the MC's chosen Dao),
	# otherwise the Dao from the card's data file.
	var path = partner.get("path")
	if path == null and data != null:
		path = data.get("path")
	unit.dao_badge = DaoIcons.get_icon(path)
	unit.dao = int(path) if path != null else -1
	unit.partner_id = partner.partner_id
	if data != null and data.get("skill_id") != null:
		unit.skill_id = str(data.get("skill_id"))

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
	unit.tint = enemy.get("tint", Color.WHITE)
	unit.name_color = enemy.get("color", Color(1.0, 0.6, 0.6))

	# Enemies can have a Dao too, e.g. {"path": Enums.Path.SWORD}
	unit.dao_badge = DaoIcons.get_icon(enemy.get("path", null))
	unit.monster_id = str(enemy.get("monster_id", ""))
	unit.immune_to_debuffs = bool(enemy.get("immune", false))

	return unit
