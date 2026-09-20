class_name Skills

# =========================================================
# Skills. A unit at full energy uses its skill instead of a
# normal attack (unless it's Silenced).
#
#   MC       -> the skill of their Dao (BY_DAO)
#   Partners -> their own skill (PARTNER_SKILLS), by partner id
#               or by "skill_id" on their PartnerData. Without one
#               they use a plainer Dao skill (DEFAULT_BY_DAO).
#   Monsters -> their own skill (MONSTER_SKILLS)
#
# To give a partner a signature skill, add an entry to
# PARTNER_SKILLS keyed by their partner id, e.g. "xiao_yan".
# =========================================================

## [Enums.Path] = skill
const BY_DAO := {
	Enums.Path.SWORD: {
		"name": "Ten Thousand Sword Rain",
		"desc": "Sword qi falls on 3 foes and leaves them bleeding.",
		"color": Color("9fe4ff"),
		"targets": 3,
		"power": 1.35,            # x ATK per hit
		"status": Statuses.BLEED,
		"status_chance": 100.0,
		"status_turns": 2,
		"status_power": 18.0,     # bleed = % of the attacker's ATK per turn
		"fx": "slash",
	},
	Enums.Path.MARTIAL: {
		"name": "Mountain-Crushing Fist",
		"desc": "One devastating blow, with a chance to stun.",
		"color": Color("ffb36b"),
		"targets": 1,
		"power": 2.8,
		"status": Statuses.STUN,
		"status_chance": 55.0,
		"status_turns": 1,
		"status_power": 0.0,
		"fx": "impact",
	},
	Enums.Path.MYSTIC: {
		"name": "Nine Seals of Silence",
		"desc": "Seals the qi of 3 foes so they cannot use skills.",
		"color": Color("c9a0ff"),
		"targets": 3,
		"power": 1.2,
		"status": Statuses.SILENCE,
		"status_chance": 80.0,
		"status_turns": 2,
		"status_power": 0.0,
		"fx": "seal",
	},
	Enums.Path.DIVINE: {
		"name": "Heaven's Judgment",
		"desc": "Smites the strongest foe and mends your weakest ally.",
		"color": Color("ffe6a8"),
		"targets": 1,
		"power": 2.3,
		"status": Statuses.ARMOR_BREAK,
		"status_chance": 70.0,
		"status_turns": 2,
		"status_power": 25.0,     # % more damage taken
		"target_rule": "strongest",
		"heal_ally": 25.0,        # % of the weakest ally's max HP
		"fx": "beam",
	},
	Enums.Path.SPIRIT: {
		"name": "Verdant Aegis",
		"desc": "Shields the whole team and stirs their qi.",
		"color": Color("8fffc4"),
		"targets": 0,             # no attack
		"power": 0.0,
		"shield_team": 18.0,      # % of each ally's max HP
		"energy_team": 30,
		"heal_ally": 12.0,
		"fx": "aura",
	},
}

## Signature partner skills, keyed by partner id (or skill_id).
## Add entries as you write them; anything missing uses DEFAULT_BY_DAO.
const PARTNER_SKILLS := {
	# "xiao_yan": {
	#     "name": "Falling Heart Flame",
	#     "color": Color("ff7a4a"), "targets": 3, "power": 1.5,
	#     "status": Statuses.HEAVENLY_BLEED, "status_chance": 60.0,
	#     "status_turns": 2, "status_power": 2.0, "fx": "beam",
	# },
}

## Plainer skills for partners without a signature one.
const DEFAULT_BY_DAO := {
	Enums.Path.SWORD: {
		"name": "Flying Sword Strike", "color": Color("9fe4ff"), "targets": 2, "power": 1.5,
		"status": Statuses.BLEED, "status_chance": 50.0, "status_turns": 2, "status_power": 12.0,
		"fx": "slash",
	},
	Enums.Path.MARTIAL: {
		"name": "Iron Body Blow", "color": Color("ffb36b"), "targets": 1, "power": 2.3,
		"status": Statuses.ARMOR_BREAK, "status_chance": 45.0, "status_turns": 2, "status_power": 18.0,
		"fx": "impact",
	},
	Enums.Path.MYSTIC: {
		"name": "Binding Talisman", "color": Color("c9a0ff"), "targets": 2, "power": 1.4,
		"status": Statuses.SILENCE, "status_chance": 50.0, "status_turns": 1, "status_power": 0.0,
		"fx": "seal",
	},
	Enums.Path.DIVINE: {
		"name": "Radiant Mercy", "color": Color("ffe6a8"), "targets": 1, "power": 1.9,
		"heal_ally": 18.0,
		"fx": "beam",
	},
	Enums.Path.SPIRIT: {
		"name": "Spirit Ward", "color": Color("8fffc4"), "targets": 0, "power": 0.0,
		"shield_team": 12.0, "energy_team": 15,
		"fx": "aura",
	},
}


## One skill per monster (see MonsterDB ids).
const MONSTER_SKILLS := {
	# --- mobs ---
	"bat_demon": {
		"name": "Blood Drain", "color": Color("c86bff"), "targets": 1, "power": 2.2,
		"status": Statuses.BLEED, "status_chance": 70.0, "status_turns": 2, "status_power": 20.0,
		"fx": "impact",
	},
	"grey_spirit_wolf": {
		"name": "Pack Howl", "color": Color("b9c8d8"), "targets": 2, "power": 1.3,
		"status": Statuses.WEAKEN, "status_chance": 50.0, "status_turns": 2, "status_power": 20.0,
		"fx": "impact",
	},
	"jiangshi": {
		"name": "Corpse Grip", "color": Color("8fb8a0"), "targets": 1, "power": 2.0,
		"status": Statuses.STUN, "status_chance": 40.0, "status_turns": 1, "status_power": 0.0,
		"fx": "impact",
	},
	"moss_monkey": {
		"name": "Branch Flurry", "color": Color("9fd86b"), "targets": 3, "power": 1.1,
		"fx": "slash",
	},
	"rock_boar": {
		"name": "Boulder Charge", "color": Color("c9a27a"), "targets": 1, "power": 2.4,
		"status": Statuses.ARMOR_BREAK, "status_chance": 60.0, "status_turns": 2, "status_power": 20.0,
		"fx": "impact",
	},
	"swamp_toad": {
		"name": "Venom Spray", "color": Color("8fd86b"), "targets": 3, "power": 1.0,
		"status": Statuses.WEAKEN, "status_chance": 60.0, "status_turns": 2, "status_power": 18.0,
		"fx": "seal",
	},

	# --- bosses ---
	"calamity_roc": {
		"name": "Storm of Calamity", "color": Color("ff6b4a"), "targets": 6, "power": 1.5,
		"status": Statuses.SILENCE, "status_chance": 45.0, "status_turns": 2, "status_power": 0.0,
		"fx": "slash",
	},
	"heavenly_qilin": {
		"name": "Sacred Flame", "color": Color("ffd36b"), "targets": 3, "power": 1.8,
		"status": Statuses.HEAVENLY_BLEED, "status_chance": 70.0, "status_turns": 3, "status_power": 3.0,
		"fx": "beam",
	},
	"jadehorn_moonfang": {
		"name": "Moonfang Rend", "color": Color("a8e8c8"), "targets": 1, "power": 3.0,
		"status": Statuses.HEAVENLY_BLEED, "status_chance": 80.0, "status_turns": 3, "status_power": 4.0,
		"fx": "slash",
	},
	"mistpeak_king": {
		"name": "Mountain Quake", "color": Color("c9c9d8"), "targets": 6, "power": 1.4,
		"status": Statuses.STUN, "status_chance": 30.0, "status_turns": 1, "status_power": 0.0,
		"fx": "impact",
	},
	"nine_tailed_empress": {
		"name": "Nine-Tail Charm", "color": Color("ffb3d9"), "targets": 3, "power": 1.5,
		"status": Statuses.SILENCE, "status_chance": 60.0, "status_turns": 2, "status_power": 0.0,
		"heal_ally": 15.0,
		"fx": "seal",
	},
	"voidmoon_mantis": {
		"name": "Void Scythe", "color": Color("b476ff"), "targets": 1, "power": 3.2,
		"status": Statuses.ARMOR_BREAK, "status_chance": 80.0, "status_turns": 3, "status_power": 30.0,
		"fx": "slash",
	},
}

## Fallback for any monster without its own skill.
const ENEMY_SKILL := {
	"name": "Savage Onslaught",
	"desc": "A wild strike that can weaken its prey.",
	"color": Color("ff8a7a"),
	"targets": 1,
	"power": 2.2,
	"status": Statuses.WEAKEN,
	"status_chance": 50.0,
	"status_turns": 2,
	"status_power": 25.0,
	"fx": "impact",
}


static func for_dao(dao: int) -> Dictionary:
	return BY_DAO.get(dao, BY_DAO[Enums.Path.MARTIAL])


## The skill a unit will use.
static func for_unit(unit: CombatUnit) -> Dictionary:
	if unit.side == CombatUnit.Side.ENEMY:
		return MONSTER_SKILLS.get(unit.monster_id, ENEMY_SKILL)

	# The MC fights with the Dao they chose
	if unit.partner_id == GameState.MC_ID:
		return for_dao(unit.dao)

	# Signature skill from PartnerSkills, scaled for the partner's tier
	var signature := PartnerSkills.skill_for(unit.partner_id, unit.rarity)
	if not signature.is_empty():
		return _with_ring_boosts(signature, unit)

	# Partners use their signature skill when they have one
	if unit.skill_id != "" and PARTNER_SKILLS.has(unit.skill_id):
		return PARTNER_SKILLS[unit.skill_id]
	if PARTNER_SKILLS.has(unit.partner_id):
		return PARTNER_SKILLS[unit.partner_id]
	# Unlisted partners use their Dao's default, scaled for their tier
	var fallback: Dictionary = DEFAULT_BY_DAO.get(unit.dao, DEFAULT_BY_DAO[Enums.Path.MARTIAL])
	if unit.rarity >= 0:
		return PartnerSkills.apply_tier(fallback, unit.rarity)
	return fallback


## Beast Ring boosts on a partner's signature skill.
static func _with_ring_boosts(skill: Dictionary, unit: CombatUnit) -> Dictionary:
	if unit.ring_skill.is_empty():
		return skill
	var s := skill.duplicate()
	var boost: Dictionary = unit.ring_skill
	if boost.has("skill_power"):
		s["power"] = float(s.get("power", 0.0)) * (1.0 + float(boost["skill_power"]) / 100.0)
	if s.has("status"):
		if boost.has("skill_chance"):
			s["status_chance"] = minf(100.0, float(s.get("status_chance", 0.0)) + float(boost["skill_chance"]))
		if boost.has("skill_turns"):
			s["status_turns"] = int(s.get("status_turns", 1)) + int(boost["skill_turns"])
	return s


## The skill an owned partner would use (for the partner panel).
static func for_partner(partner: OwnedPartner) -> Dictionary:
	if partner == null:
		return {}
	if partner.partner_id == GameState.MC_ID:
		return for_dao(GameState.mc_path)
	var data = partner.get_data()
	if data != null:
		var tier := int(data.rarity)
		var mode := PartnerSkills.mode_for(tier)
		if mode == "none":
			return {"name": "No signature skill", "desc": "White partners fight with basic attacks.",
				"color": Color("b8c2d4"), "targets": 0, "power": 0.0, "mode": "none"}
		var signature := PartnerSkills.skill_for(partner.partner_id, tier)
		if not signature.is_empty():
			signature["mode"] = mode
			if mode == "proc":
				signature["desc"] = "%s  (%d%% chance on each attack)" % [str(signature["desc"]),
					int(PartnerSkills.proc_chance(tier))]
			return signature
	if data != null and data.get("skill_id") != null and PARTNER_SKILLS.has(str(data.get("skill_id"))):
		return PARTNER_SKILLS[str(data.get("skill_id"))]
	if PARTNER_SKILLS.has(partner.partner_id):
		return PARTNER_SKILLS[partner.partner_id]
	var dao := int(data.get("path")) if data != null and data.get("path") != null else -1
	return DEFAULT_BY_DAO.get(dao, DEFAULT_BY_DAO[Enums.Path.MARTIAL])


## Short line for the partner panel, e.g.
## "Hits 3 foes, applies Bleed for 2 turns".
static func summary(skill: Dictionary) -> String:
	var parts := PackedStringArray()
	var targets := int(skill.get("targets", 0))
	if targets == 1:
		parts.append("%sx ATK on one foe" % String.num(skill["power"], 2))
	elif targets > 1:
		parts.append("%sx ATK on %d foes" % [String.num(skill["power"], 2), targets])
	if skill.has("status"):
		parts.append("%d%% chance of %s (%d turns)" % [int(skill["status_chance"]),
			Statuses.name_of(skill["status"]), int(skill["status_turns"])])
	if skill.has("shield_team"):
		parts.append("shields the team for %d%% HP" % int(skill["shield_team"]))
	if skill.has("energy_team"):
		parts.append("+%d energy to allies" % int(skill["energy_team"]))
	if skill.has("heal_ally"):
		parts.append("heals %d%% HP" % int(skill["heal_ally"]))
	return ", ".join(parts).capitalize()
