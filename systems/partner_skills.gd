class_name PartnerSkills

# =========================================================
# Partner signature skills. Save as
#   res://systems/partner_skills.gd
#
# Every character FAMILY (the same person across tiers, e.g.
# Xiao Yan Youth -> Heavy Ruler -> Fallen Heart Flame -> Dou Zun)
# shares one signature skill. The partner's TIER decides how it's
# used and how strong it is (TIER_RULES):
#   White      no skill, basic attacks only
#   Blue       proc: small chance on each attack, weak version
#   Green      proc: better chance, stronger
#   Purple+    active: cast when the energy bar is full
#   Red+       stronger, higher status chance, longer statuses
#
# A skill = a TEMPLATE (what it does) + the family's name,
# description and colour. Partners not listed here fall back to
# their Dao's default skill (skills.gd).
# =========================================================

# ---------------------------------------------------------
# TIER RULES
# ---------------------------------------------------------

## mode: "none", "proc" or "active"
## proc: % chance per attack (proc tiers only)
## power: x skill power (also scales heals, shields, energy)
## chance_mult / chance_add: status chance = base x mult + add
## turns_add: extra status turns
const TIER_RULES := {
	Enums.Rarity.WHITE: {"mode": "none"},
	Enums.Rarity.BLUE: {"mode": "proc", "proc": 8.0, "power": 0.6, "chance_mult": 0.0, "chance_add": 0.0, "turns_add": 0},
	Enums.Rarity.GREEN: {"mode": "proc", "proc": 15.0, "power": 0.8, "chance_mult": 0.5, "chance_add": 0.0, "turns_add": 0},
	Enums.Rarity.PURPLE: {"mode": "active", "power": 1.0, "chance_mult": 1.0, "chance_add": 0.0, "turns_add": 0},
	Enums.Rarity.RED: {"mode": "active", "power": 1.25, "chance_mult": 1.0, "chance_add": 15.0, "turns_add": 1},
	Enums.Rarity.GOLD: {"mode": "active", "power": 1.5, "chance_mult": 1.0, "chance_add": 25.0, "turns_add": 1},
	Enums.Rarity.PRISMATIC: {"mode": "active", "power": 1.8, "chance_mult": 1.0, "chance_add": 35.0, "turns_add": 1},
}


# ---------------------------------------------------------
# TEMPLATES (Purple strength)
# ---------------------------------------------------------
# targets: foes hit (0 = none)   power: x ATK per hit
# target_rule: "strongest" (most HP) or "weakest" (least HP)
# status fields as in skills.gd; heal_ally / shield_team are % of
# max HP, energy_team is flat energy.

const TEMPLATES := {
	"burst": {"targets": 1, "power": 2.8, "target_rule": "strongest", "fx": "impact"},
	"burst_ab": {"targets": 1, "power": 2.6, "target_rule": "strongest", "fx": "impact",
		"status": Statuses.ARMOR_BREAK, "status_chance": 70.0, "status_turns": 2, "status_power": 25.0},
	"burst_stun": {"targets": 1, "power": 2.5, "fx": "impact",
		"status": Statuses.STUN, "status_chance": 45.0, "status_turns": 1, "status_power": 0.0},
	"burst_silence": {"targets": 1, "power": 2.4, "target_rule": "strongest", "fx": "seal",
		"status": Statuses.SILENCE, "status_chance": 55.0, "status_turns": 2, "status_power": 0.0},
	"burst_guard": {"targets": 1, "power": 2.4, "target_rule": "strongest", "fx": "impact", "shield_team": 8.0},
	"execute": {"targets": 1, "power": 3.2, "target_rule": "weakest", "fx": "slash"},
	"duo_stun": {"targets": 2, "power": 1.6, "fx": "impact",
		"status": Statuses.STUN, "status_chance": 50.0, "status_turns": 1, "status_power": 0.0},
	"duo_silence": {"targets": 2, "power": 1.6, "fx": "seal",
		"status": Statuses.SILENCE, "status_chance": 50.0, "status_turns": 1, "status_power": 0.0},
	"triple": {"targets": 3, "power": 1.45, "fx": "slash"},
	"triple_stun": {"targets": 3, "power": 1.3, "fx": "beam",
		"status": Statuses.STUN, "status_chance": 30.0, "status_turns": 1, "status_power": 0.0},
	"triple_ab": {"targets": 3, "power": 1.3, "fx": "slash",
		"status": Statuses.ARMOR_BREAK, "status_chance": 60.0, "status_turns": 2, "status_power": 20.0},
	"triple_silence": {"targets": 3, "power": 1.25, "fx": "beam",
		"status": Statuses.SILENCE, "status_chance": 40.0, "status_turns": 1, "status_power": 0.0},
	"sweep": {"targets": 6, "power": 0.85, "fx": "slash"},
	"sweep_bleed": {"targets": 6, "power": 0.75, "fx": "aura",
		"status": Statuses.BLEED, "status_chance": 60.0, "status_turns": 2, "status_power": 16.0},
	"sweep_weaken": {"targets": 6, "power": 0.7, "fx": "aura",
		"status": Statuses.WEAKEN, "status_chance": 60.0, "status_turns": 2, "status_power": 20.0},
	"sweep_stun": {"targets": 6, "power": 0.7, "fx": "beam",
		"status": Statuses.STUN, "status_chance": 25.0, "status_turns": 1, "status_power": 0.0},
	"boss_killer": {"targets": 1, "power": 2.0, "target_rule": "strongest", "fx": "beam",
		"status": Statuses.HEAVENLY_BLEED, "status_chance": 75.0, "status_turns": 3, "status_power": 2.5},
	"heal": {"targets": 1, "power": 1.2, "heal_ally": 22.0, "fx": "beam"},
	"heal_team": {"targets": 0, "power": 0.0, "heal_ally": 18.0, "shield_team": 8.0, "fx": "aura"},
	"shield": {"targets": 0, "power": 0.0, "shield_team": 16.0, "fx": "aura"},
	"shield_heal": {"targets": 0, "power": 0.0, "shield_team": 12.0, "heal_ally": 12.0, "fx": "aura"},
	"rally": {"targets": 1, "power": 1.6, "energy_team": 25, "fx": "impact"},
	"rally_team": {"targets": 0, "power": 0.0, "energy_team": 30, "shield_team": 6.0, "fx": "aura"},
}


# ---------------------------------------------------------
# FAMILIES
# ---------------------------------------------------------
# family: [skill name, description, template, colour, Dao, [member partner ids]]

const FAMILIES := {
	# --- Red families (and their lower forms) ---
	"wang_lin": ["Ji Realm: Slaughter Thunder", "Red lightning of the Ji Realm strikes 3 foes and may stun them.",
		"triple_stun", "ff5a4a", Enums.Path.MYSTIC, ["wang_lin_youth", "wang_lin_disciple", "wang_lin_nascent", "wang_lin_ascendant", "wang_lin_life_death", "wang_lin_ancient_god"]],
	"xiao_yan": ["Buddha's Fury Lotus", "A lotus of fused flames bursts over every foe and leaves them burning.",
		"sweep_bleed", "ff8a3a", Enums.Path.MYSTIC, ["xiao_yan_youth", "xiao_yan_heavy_ruler", "xiao_yan_fallen_heart_flame", "xiao_yan_douzun", "xiao_yan_dou_sheng", "xiao_yan_flame_emperor"]],
	"shi_hao": ["Kunpeng Art", "The Kunpeng's strike tears through 3 foes and breaks their guard.",
		"triple_ab", "8fd4ff", Enums.Path.MARTIAL, ["shi_hao_child", "shi_hao_supreme_bone", "shi_hao_imperial_pass", "shi_hao_blood_drop", "shi_hao_immortal_king"]],
	"han_li": ["Green Bamboo Bee Cloud Swords", "A storm of green bamboo flying swords rains on every foe.",
		"sweep", "7dffa8", Enums.Path.SWORD, ["han_li_child", "han_li_foundation", "han_li_core_formation", "han_li_nascent"]],
	"bai_xiaochun": ["Undying Live Forever Art", "An undying body shields the whole team and mends the weakest.",
		"shield_heal", "fff0a8", Enums.Path.MARTIAL, ["bai_xiaochun_outer_disciple", "bai_xiaochun_heavendao", "bai_xiaochun_blood_stream", "bai_xiaochun_young_ancestor"]],
	"nie_li": ["Shadow Devil Fusion", "Merges with his demon spirit for one crushing blow that silences.",
		"burst_silence", "b476ff", Enums.Path.SPIRIT, ["nie_li_reborn", "nie_li_fanged_panda", "nie_li_legend", "nie_li_shadow_devil"]],
	"yang_kai": ["Golden Blood Dragon Transformation", "Golden dragon blood surges into one armour-breaking strike.",
		"burst_ab", "ffd36b", Enums.Path.MARTIAL, ["yang_kai_golden_skeleton", "yang_kai_dragon_transformation", "yang_kai_late_dragon", "yang_kai_open_heaven", "yang_kai_world_creation_realm"]],
	"tang_san": ["Buddha's Wrath Tang Lotus", "The deadliest hidden weapon: it eats a share of the strongest foe's life every turn.",
		"boss_killer", "b8a0ff", Enums.Path.SPIRIT, ["tang_san_village", "tang_san_shrek", "tang_san_sea_god", "tang_san_asura_god", "tang_san_dual_god"]],
	"huo_yuhao": ["Ice Jade Emperor's Wrath", "Freezing soul power washes over every foe and may freeze them.",
		"sweep_stun", "9fe8ff", Enums.Path.SPIRIT, ["huo_yuhao_spirit_eyes", "huo_yuhao_ice_jade_emperor"]],
	"luo_feng": ["Golden Horned Charge", "The Golden Horned Beast rams the strongest foe.",
		"burst", "ffcf4a", Enums.Path.MARTIAL, ["luo_feng_student", "luo_feng_warrior", "luo_feng_golden_horned", "luo_feng_peak"]],
	"lin_dong": ["Great Desolate Stele", "Ancestral symbols press down on every foe, weakening them.",
		"sweep_weaken", "c9a0ff", Enums.Path.MYSTIC, ["lin_dong_youth", "lin_dong_stone_talisman", "lin_dong_yuan_gate"]],
	"mu_chen": ["Nine Nether Sparrow Flame", "Nine Nether flames sweep every foe and keep burning.",
		"sweep_bleed", "b476ff", Enums.Path.MYSTIC, ["mu_chen_academy", "mu_chen_spiritual_road", "mu_chen_nine_nether_flame_form"]],
	"qin_yu": ["Star Transformation: Meteor Tear", "Starlight-forged fists shatter the guard of 3 foes.",
		"triple_ab", "8fb8ff", Enums.Path.MARTIAL, ["qin_yu_prince", "qin_yu_meteor_tear", "qin_yu_god_realm", "qin_yu_god_king", "qin_yu_hongmeng_controller"]],
	"zhang_xiaofan": ["Divine Sword Invoking Thunder", "A thunder-calling sword strikes 3 foes and may stun them.",
		"triple_stun", "9fe4ff", Enums.Path.SWORD, ["zhang_xiaofan_young", "zhang_xiaofan_ghost_li"]],
	"meng_chuan": ["Lightning Blade", "A lightning-fast blade that may stun its target.",
		"burst_stun", "d9c8ff", Enums.Path.MARTIAL, ["meng_chuan_youth", "meng_chuan_base", "meng_chuan_lightning_form", "meng_chuan_saint", "meng_chuan_body_refining_saint"]],
	"lin_qiye": ["Seraph's Judgment", "Michael's divine light judges 3 foes and may silence them.",
		"triple_silence", "fff0c0", Enums.Path.DIVINE, ["lin_qiye_blindfolded", "lin_qiye_night_watcher", "lin_qiye_nyx", "lin_qiye_merlin"]],
	"medusa": ["Swallowing Python Gaze", "The snake queen's gaze may turn 2 foes to stone.",
		"duo_stun", "b0ff8a", Enums.Path.SPIRIT, ["medusa_snake_queen", "medusa_dou_sheng", "medusa_nine_colored_python"]],
	"xuner": ["Golden Emperor Burning Heaven Flame", "Ancient golden flames eat away at the strongest foe every turn.",
		"boss_killer", "ffe07a", Enums.Path.DIVINE, ["gu_xuner_gu_clan", "gu_xuner_divine_bloodline"]],
	"yun_yun": ["Cloud Wind Sword Art", "Gale-edged sword qi weakens every foe.",
		"sweep_weaken", "a8f0ff", Enums.Path.SWORD, ["yun_yun", "yun_yun_hua_sect"]],
	"zi_yan": ["Dragon Might", "A true dragon's blow that may stun.",
		"burst_stun", "d98aff", Enums.Path.MARTIAL, ["zi_yan", "zi_yan_mature_dragon", "ziyan_ancient_void_dragon"]],
	"yao_lao": ["Bone Chilling Flame Pill", "Refines a healing pill for the weakest ally and steadies the team.",
		"heal_team", "8fe4ff", Enums.Path.MYSTIC, ["yao_lao_soul", "yao_lao_restored_body", "yao_lao_medicine_saint"]],
	"bibi_dong": ["Death Spider Emperor", "Soul-devouring spider venom poisons every foe.",
		"sweep_bleed", "c060ff", Enums.Path.SPIRIT, ["bibi_dong", "bibi_dong_limit_douluo", "bibi_dong_rakshasa"]],
	"qian_renxue": ["Seraph Holy Sword", "A holy blade cleaves the strongest foe and breaks its armour.",
		"burst_ab", "ffe6a8", Enums.Path.DIVINE, ["qian_renxue", "qian_renxue_limit_douluo", "qian_renxue_angel"]],
	"long_haochen": ["Divine Knight's Holy Shield", "Holy light shields the team and mends the weakest.",
		"shield_heal", "fff0a8", Enums.Path.DIVINE, ["long_haochen_squire", "long_haochen_divine_knight", "long_hao_chen_throne"]],
	"sheng_caier": ["Nightmare Strike", "An assassin's strike that finishes the weakest foe.",
		"execute", "9a8aff", Enums.Path.SPIRIT, ["sheng_cai_er_assasin", "sheng_caier_reincarnation"]],
	"abao": ["Demon God Descends", "Demon god power weakens every foe.",
		"sweep_weaken", "ff5a8a", Enums.Path.SPIRIT, ["abao_demon_prince", "abao_demonized_form"]],
	"fang_han": ["Great Immortality Palm", "One overwhelming palm on the strongest foe.",
		"burst", "ffcf8a", Enums.Path.MARTIAL, ["fang_han_mature"]],
	"luo_zheng": ["Hundred Refinements Body", "A body-tempered strike, then a shield for the team.",
		"burst_guard", "e0b080", Enums.Path.MARTIAL, ["luo_zheng_late_form"]],
	"mo_fan": ["Demon Element: Thunder-Fire", "Fused thunder and fire scorch every foe.",
		"sweep_bleed", "ff6a3a", Enums.Path.MYSTIC, ["mo_fan_demon_element"]],
	"chen_ping_an": ["Sword Qi River", "A river of sword qi breaks the guard of 3 foes.",
		"triple_ab", "9fe4ff", Enums.Path.SWORD, ["chen_ping_an_swordbearer"]],
	"qin_mu": ["Emperor-Slaying Slash", "A reverse-grip blade that finishes the weakest foe.",
		"execute", "ffb36b", Enums.Path.SWORD, ["qin_mu_devil_cult"]],
	"jing_jiu": ["Thousand Flying Swords", "A sky of flying swords rains on every foe.",
		"sweep", "c8e8ff", Enums.Path.SWORD, ["jing_jiu_peak"]],
	"wu_geng": ["Monochrome Divine Power", "Suppressing divine power crushes one foe and silences it.",
		"burst_silence", "e0e0e0", Enums.Path.MARTIAL, ["wu_geng_late_king"]],
	"zi_yu": ["Heaven Punisher", "A god-slaying sword that burns the strongest foe's life every turn.",
		"boss_killer", "ff8a6b", Enums.Path.SWORD, ["zi_yu"]],
	"ni_tian_er_xing": ["Mingzu War Cry", "Strikes one foe and fills the team's energy.",
		"rally", "ffb36b", Enums.Path.MARTIAL, ["ni_tian_er_xing"]],
	"baili_dongjun": ["Drunken Wine Sword", "A wine-soaked sword strike that lifts the team's energy.",
		"rally", "ffd9a0", Enums.Path.SWORD, ["baili_dongjun_young_brewmaster", "baili_dongjun_mature"]],
	"wuxin": ["Heart Demon Seal", "Seals the hearts of 2 foes, silencing them.",
		"duo_silence", "ff9ad8", Enums.Path.SPIRIT, ["wuxin_late"]],
	"xiao_se": ["Wuji Staff Art", "Staff strikes on 2 foes that may stun.",
		"duo_stun", "d0c090", Enums.Path.MARTIAL, ["xiao_se_late"]],
	"ye_dingzhi": ["Demon Lord's Fist", "A demon lord's fist crashes over every foe.",
		"sweep", "c04a6a", Enums.Path.MARTIAL, ["ye_dingzhi"]],
	"ye_fan": ["Holy Body: Nine Secrets", "The Holy Body's strike, then a shield for the team.",
		"burst_guard", "ffd36b", Enums.Path.MARTIAL, ["ye_fan_earth", "ye_fan_sacred_body"]],
	"jiang_taixu": ["Divine King Fist", "A divine king's fist breaks the guard of 3 foes.",
		"triple_ab", "ffe6a8", Enums.Path.DIVINE, ["jiang_taixu_divine_king"]],
	"xu_yang": ["Hundred Millennia Qi", "An ocean of Qi weakens every foe.",
		"sweep_weaken", "a0f0d0", Enums.Path.MYSTIC, ["xu_yang"]],
	"chu_feng": ["Divine Forbidden: Thunder Dragon", "A thunder dragon strikes every foe and may stun.",
		"sweep_stun", "b0c8ff", Enums.Path.MYSTIC, ["chu_feng"]],
	"zhuo_fan": ["Nine Nether Demonic Art", "Demonic qi poisons every foe.",
		"sweep_bleed", "a040a0", Enums.Path.SPIRIT, ["zhuo_fan_demon_emperor"]],

	# --- Gold-only characters ---
	"liu_shen": ["Willow Deity's Sanctuary", "The ancient willow's boughs shelter the team and heal the weakest.",
		"shield_heal", "8fffc4", Enums.Path.DIVINE, ["liu_shen"]],
	"tu_si": ["Ancient God's Wrath", "An ancient god's fist crushes the strongest foe and shatters its armour.",
		"burst_ab", "c8a070", Enums.Path.MARTIAL, ["tu_si"]],
	"nyx": ["Eternal Night", "The goddess of night silences 3 foes in darkness.",
		"triple_silence", "8a7ab8", Enums.Path.SPIRIT, ["nyx"]],
	"merlin": ["Grand Magic of Avalon", "The great wizard's spell strikes every foe and may stun them.",
		"sweep_stun", "a8c8ff", Enums.Path.MYSTIC, ["merlin"]],
	"fengxiu": ["Demon God Emperor's Descent", "Demonic power pours over every foe, leaving them bleeding.",
		"sweep_bleed", "c03a5a", Enums.Path.SPIRIT, ["fengxiu"]],
	"electrolux": ["Electrolux's Dominion", "Overwhelming power strikes 3 foes and may silence them.",
		"triple_silence", "c9a0ff", Enums.Path.MYSTIC, ["electrolux"]],
	"asura_god": ["Asura's Slaughter", "The god of killing finishes the weakest foe.",
		"execute", "c0303a", Enums.Path.SWORD, ["asura_god"]],
	"sea_god": ["Sea God's Trident", "A tide of divine power crashes on every foe and may stun them.",
		"sweep_stun", "4ab8ff", Enums.Path.DIVINE, ["sea_god"]],
	"tang_hao": ["Clear Sky Hammer", "A world-shaking hammer blow that may stun.",
		"burst_stun", "8090a8", Enums.Path.MARTIAL, ["tang_hao_clear_sky"]],
	"gu_yuan": ["Gu Clan Ancestral Flame", "Ancient golden flame burns away the strongest foe's life every turn.",
		"boss_killer", "ffe07a", Enums.Path.DIVINE, ["gu_yuan"]],
	"hun_tian_di": ["Soul Emperor's Devour", "Devours one foe's soul, crushing and silencing it.",
		"burst_silence", "6a3a9a", Enums.Path.SPIRIT, ["hun_tian_di"]],
	"xiao_xuan": ["Emperor Xiao's Might", "An ancestor's overwhelming might crashes over every foe.",
		"sweep", "ffcf4a", Enums.Path.MARTIAL, ["xiao_xuan"]],
	"meng_tianzheng": ["Heavenly Might", "A peerless strike that breaks the guard of 3 foes.",
		"triple_ab", "e0c080", Enums.Path.MARTIAL, ["meng_tianzheng"]],
	"hen_ren_da_di": ["Ruthless Empress's Palm", "A merciless palm that shatters the strongest foe's armour.",
		"burst_ab", "f0f0ff", Enums.Path.MARTIAL, ["hen_ren_da_di"]],
	"wu_shi_da_di": ["Beginningless Bell", "The great bell tolls over 3 foes and may stun them.",
		"triple_stun", "ffe6a8", Enums.Path.DIVINE, ["wu_shi_da_di"]],
	"black_dragon_tian": ["Black Dragon's Dominion", "Dark dragon power poisons every foe.",
		"sweep_bleed", "8a7ab8", Enums.Path.SPIRIT, ["black_dragon_tian"]],
	"qian_qu_demon_saint": ["Demon Saint's Descent", "A demon saint's aura weakens every foe.",
		"sweep_weaken", "c04a6a", Enums.Path.SPIRIT, ["qian_qu_demon_saint"]],
	"che_hou_yuan": ["Heavenly Venerable's Decree", "A venerable's decree strikes 3 foes and may silence them.",
		"triple_silence", "c9a0ff", Enums.Path.MYSTIC, ["che_hou_yuan"]],

	# --- Purple-only families ---
	"an_qingyu": ["Absolute Analysis", "Reads 3 foes' weak points and breaks their guard.",
		"triple_ab", "a0d8ff", Enums.Path.MYSTIC, ["an_qingyu"]],
	"black_emperor": ["Divine Formation Seal", "Ancient formations bind 3 foes and may silence them.",
		"triple_silence", "c9a0ff", Enums.Path.MYSTIC, ["black_emperor"]],
	"bo_saixi": ["Sea God's Tide", "The Sea God's tide mends the weakest and shields the team.",
		"heal_team", "6bd8ff", Enums.Path.DIVINE, ["bo_saixi", "bo_saixi_high_priest"]],
	"cao_yuan": ["Black King Rampage", "An unstoppable blow that may stun.",
		"burst_stun", "ff6a5a", Enums.Path.MARTIAL, ["cao_yuan"]],
	"chen_muye": ["Dreamland", "Pulls 2 foes into a dream, silencing them.",
		"duo_silence", "b8a0ff", Enums.Path.SPIRIT, ["chen_muye"]],
	"gongsun_wan_er": ["Swallow Flight Sword", "Swift sword light on 3 foes.",
		"triple", "ff9ad8", Enums.Path.SWORD, ["gongsun_wan_er"]],
	"huo_linger": ["Spirit Flame", "Spirit fire sweeps every foe and keeps burning.",
		"sweep_bleed", "ff7a4a", Enums.Path.MYSTIC, ["huo_linger", "huo_ling_er_mature"]],
	"ling_qingzhu": ["Frost Moon Sword", "Icy sword light on 3 foes that may freeze them.",
		"triple_stun", "a8e8ff", Enums.Path.SWORD, ["ling_qingzhu", "ling_qingzhu_mature"]],
	"nine_nether": ["Nine Nether Sparrow Wings", "Nether wings cut 3 foes and break their guard.",
		"triple_ab", "b476ff", Enums.Path.SPIRIT, ["nine_nether"]],
	"qing_yi": ["Verdant Blessing", "Healing light for the weakest ally, and a blow to one foe.",
		"heal", "8fffc4", Enums.Path.DIVINE, ["qing_yi"]],
	"shi_yi": ["Double Pupil Gaze", "Double pupils see through one foe, crushing and silencing it.",
		"burst_silence", "ffd36b", Enums.Path.DIVINE, ["shi_yi_dual_pupils"]],
	"thunder_god": ["Heavenly Thunder Descends", "Thunder falls on every foe and may stun.",
		"sweep_stun", "d9c8ff", Enums.Path.MYSTIC, ["thunder_god"]],
	"xie_yan": ["Nether Assassin's Cut", "Finishes the weakest foe.",
		"execute", "c04a6a", Enums.Path.SPIRIT, ["xie_yan_mature"]],
	"ying_huanhuan": ["Song of Illusion", "Fills the team's energy and wraps them in a light shield.",
		"rally_team", "ffb8e0", Enums.Path.SPIRIT, ["ying_huanhuan", "ying_huanhuan_mature"]],
	"yuan_yao": ["Profound Healing Art", "Mends the weakest ally and shields the team.",
		"heal_team", "a8ffd8", Enums.Path.MYSTIC, ["yuan_yao"]],
	"zhao_layue": ["Heavenly Sword Intent", "A sword intent that breaks the guard of 3 foes.",
		"triple_ab", "c8e8ff", Enums.Path.SWORD, ["zhao_layue"]],
	"zhou_ru": ["Silent Sword", "A silent strike that finishes the weakest foe.",
		"execute", "a0c8ff", Enums.Path.SWORD, ["zhou_ru"]],
	"zi_ling": ["Purple Spirit Mist", "Violet mist weakens every foe.",
		"sweep_weaken", "c78aff", Enums.Path.MYSTIC, ["zi_ling"]],

	# --- Green-only families (proc skills) ---
	"cao_yusheng": ["Triple Edge", "Quick strikes on 3 foes.", "triple", "ffb36b", Enums.Path.MARTIAL, ["cao_yusheng"]],
	"hai_bodong": ["Ice Emperor's Frost", "Frost sweeps every foe and may freeze them.",
		"sweep_stun", "9fe8ff", Enums.Path.MYSTIC, ["hai_bodong"]],
	"hong": ["Crimson Fist", "A heavy blow on the strongest foe.", "burst", "ff6a5a", Enums.Path.MARTIAL, ["hong"]],
	"pang_bo": ["Iron Body Guard", "An iron body shields the team.", "shield", "d0c090", Enums.Path.MARTIAL, ["pang_bo"]],
	"shan_qing_luo": ["Flowing Sword", "Sword light on 3 foes.", "triple", "a8f0ff", Enums.Path.SWORD, ["shan_qing_luo"]],
	"situ_nan": ["Soul Devour", "A devouring soul strike that silences.", "burst_silence", "b476ff", Enums.Path.SPIRIT, ["situ_nan_soul"]],
	"song_junwan": ["Spring Rain Remedy", "Mends the weakest ally.", "heal", "8fffc4", Enums.Path.MYSTIC, ["song_junwan"]],
	"xiao_chen": ["Clan Rally", "Strikes one foe and lifts the team's energy.", "rally", "ffd36b", Enums.Path.MARTIAL, ["xiao_chen_early"]],
	"xiao_diao": ["Stunning Talon", "Claws 2 foes and may stun them.", "duo_stun", "e0b080", Enums.Path.SPIRIT, ["xiao_diao"]],

	# --- Blue-only families (proc skills, mostly support) ---
	"biyao": ["Heartbroken Bell", "A sorrowful bell shields the team and mends the weakest.",
		"shield_heal", "8fffc4", Enums.Path.SPIRIT, ["biyao"]],
	"chen_qiaoqian": ["Gentle Remedy", "Mends the weakest ally.", "heal", "a8ffd8", Enums.Path.MYSTIC, ["chen_qiaoqian"]],
	"du_lingfei": ["Swift Blade", "Blade light on 3 foes.", "triple", "a0c8ff", Enums.Path.SWORD, ["du_lingfei"]],
	"ji_ziyue": ["Moonlit Ward", "A moonlit ward shields the team.", "shield", "e0e8ff", Enums.Path.DIVINE, ["ji_ziyue"]],
	"li_muwan": ["Pill Refining", "A refined pill mends the weakest and steadies the team.",
		"heal_team", "8fe4ff", Enums.Path.MYSTIC, ["li_muwan"]],
	"liu_mei": ["Charming Gaze", "Beguiles 2 foes, silencing them.", "duo_silence", "ff9ad8", Enums.Path.SPIRIT, ["liu_mei"]],
	"lu_xueqi": ["Heavenly Frost Sword", "Frozen sword light on 3 foes that may freeze them.",
		"triple_stun", "c8e8ff", Enums.Path.SWORD, ["lu_xueqi"]],
	"luo_li": ["Luo God Sword", "A noble sword breaks the guard of 3 foes.", "triple_ab", "ffe6a8", Enums.Path.SWORD, ["luo_li"]],
	"nalan_yanran": ["Wind Sect Gale", "A gale weakens every foe.", "sweep_weaken", "a8f0ff", Enums.Path.MYSTIC, ["nalan_yanran"]],
	"nangong_wan": ["Jade Ward", "A jade ward shields the team.", "shield", "a8ffd8", Enums.Path.SPIRIT, ["nangong_wan"]],
	"ning_rongrong": ["Seven Treasure Pagoda", "The Glazed Tile Pagoda fills the team's energy and shields them.",
		"rally_team", "ffe07a", Enums.Path.SPIRIT, ["ning_rongrong"]],
	"qing_lin": ["Three Flowers Eyes", "Emerald snake eyes may stun 2 foes.", "duo_stun", "8fff9a", Enums.Path.SPIRIT, ["qing_lin"]],
	"su_yan": ["Soothing Light", "Mends the weakest ally.", "heal", "fff0c0", Enums.Path.DIVINE, ["su_yan"]],
	"su_youwei": ["Withering Mist", "Mist weakens every foe.", "sweep_weaken", "c9a0ff", Enums.Path.MYSTIC, ["su_youwei"]],
	"xia_ning_chang": ["Snowfall Sword", "Sword light on 3 foes.", "triple", "c8e8ff", Enums.Path.SWORD, ["xia_ning_chang"]],
	"xia_qingyue": ["Moon God's Veil", "A veil of moonlight shields the team.", "shield", "e0e8ff", Enums.Path.DIVINE, ["xia_qingyue"]],
	"xiao_ninger": ["Healing Spring", "Mends the weakest ally.", "heal", "8fffc4", Enums.Path.SPIRIT, ["xiao_ninger"]],
	"xiao_yi_xian": ["Poison Body Miasma", "Poison seeps into every foe.", "sweep_bleed", "a0ff6a", Enums.Path.SPIRIT, ["xiao_yi_xian"]],
	"xin_ruyin": ["Echoing Ward", "A resonant ward shields the team.", "shield", "d8c8ff", Enums.Path.MYSTIC, ["xin_ruyin"]],
	"xu_xin": ["Tender Care", "Mends the weakest ally.", "heal", "ffd8e8", Enums.Path.DIVINE, ["xu_xin"]],
	"ya_fei": ["Merchant's Blessing", "Fills the team's energy and wraps them in a light shield.",
		"rally_team", "ffb8a0", Enums.Path.MYSTIC, ["ya_fei"]],
	"ye_ziyun": ["Ice Spirit Melody", "Mends the weakest ally and shields the team.", "heal_team", "a8e8ff", Enums.Path.MYSTIC, ["ye_ziyun"]],
	"yun_xi": ["Cloud Veil", "A veil of cloud shields the team.", "shield", "e0f0ff", Enums.Path.DIVINE, ["yun_xi"]],
	"zhu_zhuqing": ["Netherworld Claw", "A flash of claws finishes the weakest foe.", "execute", "b0a0ff", Enums.Path.MARTIAL, ["zhu_zhuqing"]],
}


# ---------------------------------------------------------
# LOOKUPS
# ---------------------------------------------------------

static var _member_index := {}


static func family_of(partner_id: String) -> String:
	if _member_index.is_empty():
		for fam in FAMILIES:
			var members: Array = FAMILIES[fam][5]
			for id in members:
				_member_index[str(id)] = str(fam)
	return str(_member_index.get(partner_id, ""))


static func rule(rarity: int) -> Dictionary:
	return TIER_RULES.get(rarity, TIER_RULES[Enums.Rarity.PURPLE])


## "none", "proc" or "active" for a partner of this tier.
static func mode_for(rarity: int) -> String:
	return str(rule(rarity).get("mode", "active"))


static func proc_chance(rarity: int) -> float:
	return float(rule(rarity).get("proc", 0.0))


## The Dao chosen for a partner, or -1 if it isn't listed.
static func dao_for(partner_id: String) -> int:
	var fam := family_of(partner_id)
	return int(FAMILIES[fam][4]) if fam != "" else -1


## A partner's signature skill scaled for its tier, or {} if it has
## none (White tier, or not listed: then its Dao default is used).
static func skill_for(partner_id: String, rarity: int) -> Dictionary:
	if mode_for(rarity) == "none":
		return {}
	var fam := family_of(partner_id)
	if fam == "":
		return {}
	var entry: Array = FAMILIES[fam]
	var base: Dictionary = TEMPLATES.get(str(entry[2]), TEMPLATES["burst"])
	var s := base.duplicate()
	s["name"] = str(entry[0])
	s["desc"] = str(entry[1])
	s["color"] = Color(str(entry[3]))
	return apply_tier(s, rarity)


## Applies a tier's strength to a skill.
static func apply_tier(skill: Dictionary, rarity: int) -> Dictionary:
	var r := rule(rarity)
	var s := skill.duplicate()
	var mult := float(r.get("power", 1.0))
	s["power"] = float(s.get("power", 0.0)) * mult
	for key in ["heal_ally", "shield_team"]:
		if s.has(key):
			s[key] = float(s[key]) * mult
	if s.has("energy_team"):
		s["energy_team"] = int(round(float(s["energy_team"]) * mult))
	if s.has("status"):
		var chance := float(s.get("status_chance", 0.0)) * float(r.get("chance_mult", 1.0)) + float(r.get("chance_add", 0.0))
		if chance <= 0.0:
			s.erase("status")
		else:
			s["status_chance"] = minf(chance, 100.0)
			s["status_turns"] = int(s.get("status_turns", 1)) + int(r.get("turns_add", 0))
	return s
