@tool
extends EditorScript

# =========================================================
# Apply partner names (editor tool). Save as
#   res://tools/apply_partner_names.gd
#
# Run it: open in the Script editor, then File > Run (Ctrl+Shift+X).
#
# Sets display_name and form_name in every partner .tres under
# res://data/partners/ from the NAMES list below, e.g.
#   xiao_yan_fallen_heart_flame -> "Xiao Yan" + "Fallen Heart Flame"
# Only the two name fields change. Partners not listed are left alone.
# Edit NAMES and run it again any time; set DRY_RUN to preview.
# =========================================================

const DATA_FOLDER := "res://data/partners/"
const DRY_RUN := false

## partner id: [display name, form name ("" = no form)]
const NAMES := {
	"bai_xiaochun_outer_disciple": ["Bai Xiaochun", "Outer Disciple"],
	"baili_pangpang": ["Baili Pangpang", ""],
	"du_ze": ["Du Ze", ""],
	"han_li_child": ["Han Li", "Village Boy"],
	"hong_ying": ["Hong Ying", ""],
	"hou_xiaomei": ["Hou Xiaomei", ""],
	"lei_wujie": ["Lei Wujie", ""],
	"li_feiyu": ["Li Feiyu", ""],
	"lin_dong_youth": ["Lin Dong", "Youth"],
	"lin_qiye_blindfolded": ["Lin Qiye", "Blindfolded"],
	"long_haochen_squire": ["Long Haochen", "Squire"],
	"lu_piao": ["Lu Piao", ""],
	"luo_feng_student": ["Luo Feng", "Student"],
	"meng_chuan_youth": ["Meng Chuan", "Youth"],
	"mo_caihuan": ["Mo Caihuan", ""],
	"mu_chen_academy": ["Mu Chen", "Spirit Academy"],
	"nie_li_reborn": ["Nie Li", "Reborn"],
	"qin_yu_prince": ["Qin Yu", "Third Prince"],
	"qingtan": ["Qingtan", ""],
	"shi_hao_child": ["Shi Hao", "Stone Village Child"],
	"su_baiyi": ["Su Baiyi", ""],
	"tang_san_village": ["Tang San", "Holy Soul Village"],
	"wang_lin_youth": ["Wang Lin", "Youth"],
	"wang_zhuo": ["Wang Zhuo", ""],
	"xiao_mei": ["Xiao Mei", ""],
	"xiao_wu": ["Xiao Wu", ""],
	"xiao_yan_youth": ["Xiao Yan", "Youth"],
	"ye_fan_earth": ["Ye Fan", "From Earth"],
	"zhang_tie": ["Zhang Tie", ""],
	"zhang_xiaofan_young": ["Zhang Xiaofan", "Young"],
	"biyao": ["Biyao", ""],
	"chen_qiaoqian": ["Chen Qiaoqian", ""],
	"du_lingfei": ["Du Lingfei", ""],
	"huo_linger": ["Huo Ling'er", ""],
	"ji_ziyue": ["Ji Ziyue", ""],
	"li_muwan": ["Li Muwan", ""],
	"ling_qingzhu": ["Ling Qingzhu", ""],
	"liu_mei": ["Liu Mei", ""],
	"lu_xueqi": ["Lu Xueqi", ""],
	"luo_li": ["Luo Li", ""],
	"nalan_yanran": ["Nalan Yanran", ""],
	"nangong_wan": ["Nangong Wan", ""],
	"ning_rongrong": ["Ning Rongrong", ""],
	"qing_lin": ["Qing Lin", ""],
	"su_yan": ["Su Yan", ""],
	"su_youwei": ["Su Youwei", ""],
	"xia_ning_chang": ["Xia Ningchang", ""],
	"xia_qingyue": ["Xia Qingyue", ""],
	"xiao_ninger": ["Xiao Ning'er", ""],
	"xiao_yi_xian": ["Xiao Yixian", ""],
	"xin_ruyin": ["Xin Ruyin", ""],
	"xu_xin": ["Xu Xin", ""],
	"ya_fei": ["Ya Fei", ""],
	"ye_ziyun": ["Ye Ziyun", ""],
	"ying_huanhuan": ["Ying Huanhuan", ""],
	"yun_xi": ["Yun Xi", ""],
	"zhu_zhuqing": ["Zhu Zhuqing", ""],
	"bai_xiaochun_heavendao": ["Bai Xiaochun", "Heaven Dao Sect"],
	"cao_yusheng": ["Cao Yusheng", ""],
	"hai_bodong": ["Hai Bodong", ""],
	"han_li_foundation": ["Han Li", "Foundation Establishment"],
	"hong": ["Hong", ""],
	"huo_yuhao_spirit_eyes": ["Huo Yuhao", "Spirit Eyes"],
	"lin_dong_stone_talisman": ["Lin Dong", "Stone Talisman"],
	"luo_feng_warrior": ["Luo Feng", "Warrior"],
	"meng_chuan_base": ["Meng Chuan", "Blade Disciple"],
	"mu_chen_spiritual_road": ["Mu Chen", "Spiritual Road"],
	"nie_li_fanged_panda": ["Nie Li", "Demon Spirit Awakened"],
	"pang_bo": ["Pang Bo", ""],
	"qin_yu_meteor_tear": ["Qin Yu", "Meteor Tear"],
	"shan_qing_luo": ["Shan Qingluo", ""],
	"sheng_cai_er_assasin": ["Sheng Cai'er", "Assassin"],
	"shi_hao_supreme_bone": ["Shi Hao", "Supreme Bone"],
	"situ_nan_soul": ["Situ Nan", "Sealed Soul"],
	"song_junwan": ["Song Junwan", ""],
	"tang_san_shrek": ["Tang San", "Shrek Academy"],
	"wang_lin_disciple": ["Wang Lin", "Heng Yue Disciple"],
	"xiao_chen_early": ["Xiao Chen", ""],
	"xiao_diao": ["Xiao Diao", ""],
	"xiao_yan_heavy_ruler": ["Xiao Yan", "Heavy Xuan Ruler"],
	"yang_kai_golden_skeleton": ["Yang Kai", "Golden Skeleton"],
	"yun_yun": ["Yun Yun", "Cloud Lan Sect"],
	"abao_demon_prince": ["Abao", "Demon Prince"],
	"an_qingyu": ["An Qingyu", ""],
	"bai_xiaochun_blood_stream": ["Bai Xiaochun", "Blood Stream Sect"],
	"baili_dongjun_young_brewmaster": ["Baili Dongjun", "Young Brewmaster"],
	"bibi_dong": ["Bibi Dong", "Spirit Hall Pope"],
	"black_emperor": ["Black Emperor", ""],
	"bo_saixi": ["Bo Saixi", ""],
	"cao_yuan": ["Cao Yuan", ""],
	"chen_muye": ["Chen Muye", ""],
	"gongsun_wan_er": ["Gongsun Wan'er", ""],
	"han_li_core_formation": ["Han Li", "Core Formation"],
	"huo_ling_er_mature": ["Huo Ling'er", "Mature"],
	"ling_qingzhu_mature": ["Ling Qingzhu", "Mature"],
	"luo_feng_golden_horned": ["Luo Feng", "Golden Horned Beast"],
	"medusa_snake_queen": ["Medusa", "Snake Queen"],
	"nie_li_legend": ["Nie Li", "Legend"],
	"nine_nether": ["Nine Nether", ""],
	"qian_renxue": ["Qian Renxue", "Angel Heir"],
	"qing_yi": ["Qing Yi", ""],
	"shi_yi_dual_pupils": ["Shi Yi", "Double Pupils"],
	"thunder_god": ["Thunder God", ""],
	"wang_lin_nascent": ["Wang Lin", "Nascent Soul"],
	"xiao_yan_fallen_heart_flame": ["Xiao Yan", "Fallen Heart Flame"],
	"xie_yan_mature": ["Xie Yan", "Mature"],
	"yang_kai_dragon_transformation": ["Yang Kai", "Dragon Transformation"],
	"yao_lao_soul": ["Yao Lao", "Soul Form"],
	"ying_huanhuan_mature": ["Ying Huanhuan", "Mature"],
	"yuan_yao": ["Yuan Yao", ""],
	"zhao_layue": ["Zhao Layue", ""],
	"zhou_ru": ["Zhou Ru", ""],
	"zi_ling": ["Zi Ling", ""],
	"zi_yan": ["Zi Yan", "Little Dragon"],
	"wang_lin_ascendant": ["Wang Lin", "Ascendant Era"],
	"xiao_yan_douzun": ["Xiao Yan", "Dou Zun"],
	"shi_hao_imperial_pass": ["Shi Hao", "Imperial Pass"],
	"han_li_nascent": ["Han Li", "Nascent Soul"],
	"bai_xiaochun_young_ancestor": ["Bai Xiaochun", "Young Ancestor"],
	"nie_li_shadow_devil": ["Nie Li", "Shadow Devil"],
	"yang_kai_late_dragon": ["Yang Kai", "True Dragon"],
	"tang_san_sea_god": ["Tang San", "Sea God"],
	"huo_yuhao_ice_jade_emperor": ["Huo Yuhao", "Ice Jade Emperor"],
	"luo_feng_peak": ["Luo Feng", "Armored Peak"],
	"lin_dong_yuan_gate": ["Lin Dong", "Yuan Gate"],
	"mu_chen_nine_nether_flame_form": ["Mu Chen", "Nine Nether Flame"],
	"qin_yu_god_realm": ["Qin Yu", "Artisan God"],
	"zhang_xiaofan_ghost_li": ["Zhang Xiaofan", "Ghost Li"],
	"meng_chuan_lightning_form": ["Meng Chuan", "Lightning Form"],
	"lin_qiye_night_watcher": ["Lin Qiye", "Night Watcher"],
	"medusa_dou_sheng": ["Medusa", "Queen of Serpents"],
	"gu_xuner_gu_clan": ["Gu Xun'er", "Gu Clan"],
	"yun_yun_hua_sect": ["Yun Yun", "Hua Sect Leader"],
	"zi_yan_mature_dragon": ["Zi Yan", "Mature Dragon"],
	"yao_lao_restored_body": ["Yao Lao", "Restored Body"],
	"bibi_dong_limit_douluo": ["Bibi Dong", "Limit Douluo"],
	"qian_renxue_limit_douluo": ["Qian Renxue", "Limit Douluo"],
	"long_haochen_divine_knight": ["Long Haochen", "Divine Knight"],
	"sheng_caier_reincarnation": ["Sheng Cai'er", "Reincarnated Saintess"],
	"abao_demonized_form": ["Abao", "Demonized"],
	"fang_han_mature": ["Fang Han", ""],
	"luo_zheng_late_form": ["Luo Zheng", ""],
	"mo_fan_demon_element": ["Mo Fan", "Demon Element"],
	"chen_ping_an_swordbearer": ["Chen Ping'an", "Sword Bearer"],
	"qin_mu_devil_cult": ["Qin Mu", "Heavenly Devil Cult Master"],
	"jing_jiu_peak": ["Jing Jiu", ""],
	"wu_geng_late_king": ["Wu Geng", "Human King"],
	"zi_yu": ["Zi Yu", ""],
	"ni_tian_er_xing": ["Ni Tian Er Xing", ""],
	"baili_dongjun_mature": ["Baili Dongjun", "Mature"],
	"wuxin_late": ["Wuxin", ""],
	"xiao_se_late": ["Xiao Se", ""],
	"ye_dingzhi": ["Ye Dingzhi", ""],
	"ye_fan_sacred_body": ["Ye Fan", "Holy Body"],
	"jiang_taixu_divine_king": ["Jiang Taixu", "Divine King"],
	"xu_yang": ["Xu Yang", ""],
	"chu_feng": ["Chu Feng", ""],
	"zhuo_fan_demon_emperor": ["Zhuo Fan", "Demon Emperor"],
	"asura_god": ["Asura God", ""],
	"bibi_dong_rakshasa": ["Bibi Dong", "Rakshasa God"],
	"black_dragon_tian": ["Black Dragon Tian", ""],
	"bo_saixi_high_priest": ["Bo Saixi", "Peak High Priest"],
	"che_hou_yuan": ["Che Houyuan", "Heavenly Venerable"],
	"electrolux": ["Electrolux", ""],
	"fengxiu": ["Fengxiu", "Demon God Emperor"],
	"gu_xuner_divine_bloodline": ["Gu Xun'er", "Divine Bloodline"],
	"gu_yuan": ["Gu Yuan", ""],
	"hen_ren_da_di": ["Ruthless Empress", ""],
	"hun_tian_di": ["Hun Tiandi", "Soul Emperor"],
	"lin_qiye_merlin": ["Lin Qiye", "Merlin Form"],
	"lin_qiye_nyx": ["Lin Qiye", "Nyx Form"],
	"liu_shen": ["Liu Shen", "Willow Deity"],
	"long_hao_chen_throne": ["Long Haochen", "Throne of Eternity and Creation"],
	"medusa_nine_colored_python": ["Medusa", "Nine-Colored Heaven Swallowing Python"],
	"meng_chuan_saint": ["Meng Chuan", "Saint"],
	"meng_tianzheng": ["Meng Tianzheng", ""],
	"merlin": ["Merlin", "The Progenitor of Prophecy and Magic"],
	"nyx": ["Nyx", "Goddess of Night"],
	"qian_qu_demon_saint": ["Demon Saint", ""],
	"qian_renxue_angel": ["Qian Renxue", "Angel God"],
	"qin_yu_god_king": ["Qin Yu", "God King"],
	"sea_god": ["Poseidon", "Sea God"],
	"shi_hao_blood_drop": ["Shi Hao", "Blood-Drop Era"],
	"tang_hao_clear_sky": ["Tang Hao", "Peak Clear Sky Douluo"],
	"tang_san_asura_god": ["Tang San", "Asura God"],
	"tu_si": ["Tu Si", "Ancient God"],
	"wang_lin_life_death": ["Wang Lin", "Life and Death Intent"],
	"wu_shi_da_di": ["Wu Shi", "Beginningless Emperor"],
	"xiao_xuan": ["Xiao Xuan", ""],
	"xiao_yan_dou_sheng": ["Xiao Yan", "Dou Sheng"],
	"yang_kai_open_heaven": ["Yang Kai", "Open Heaven"],
	"yao_lao_medicine_saint": ["Yao Lao", "Medicine Saint"],
	"ziyan_ancient_void_dragon": ["Zi Yan", "Dragon Empress"],
	"meng_chuan_body_refining_saint": ["Meng Chuan", "Body Refining Saint"],
	"qin_yu_hongmeng_controller": ["Qin Yu", "Hongmeng Controller"],
	"shi_hao_immortal_king": ["Shi Hao", "Immortal King"],
	"tang_san_dual_god": ["Tang San", "Dual God"],
	"wang_ling_ancient_god": ["Wang Lin", "Ancient God"],
	"xiao_yan_flame_emperor": ["Xiao Yan", "Flame Emperor"],
	"yang_kai_world_creation_realm": ["Yang Kai", "World Creation Realm"],
}


func _run() -> void:
	var files: Array = []
	_collect(DATA_FOLDER, files)
	var changed := PackedStringArray()
	var unlisted := PackedStringArray()
	for path in files:
		var data := load(str(path)) as PartnerData
		if data == null:
			continue
		var id := data.partner_id if data.partner_id != "" else str(path).get_file().get_basename()
		if not NAMES.has(id):
			unlisted.append(id)
			continue
		var entry: Array = NAMES[id]
		var new_name := str(entry[0])
		var new_form := str(entry[1])
		if data.display_name == new_name and data.form_name == new_form:
			continue
		changed.append("%s: %s" % [id, new_name + ("" if new_form == "" else " - " + new_form)])
		if not DRY_RUN:
			data.display_name = new_name
			data.form_name = new_form
			var err := ResourceSaver.save(data, str(path))
			if err != OK:
				push_error("Could not save %s (error %d)" % [path, err])

	print("")
	print("=== Apply partner names ===")
	print("%s %d partner%s." % ["Would rename" if DRY_RUN else "Renamed", changed.size(), "" if changed.size() == 1 else "s"])
	for line in changed:
		print("  " + line)
	if not unlisted.is_empty():
		print("Not in NAMES (left as they are): " + ", ".join(unlisted))


func _collect(folder: String, out: Array) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not str(sub).begins_with("."):
			_collect(folder + str(sub) + "/", out)
	for f in dir.get_files():
		var file := str(f)
		if file.ends_with(".tres"):
			out.append(folder + file)
