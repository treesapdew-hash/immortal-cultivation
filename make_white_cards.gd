@tool
extends EditorScript

const TIER := "white"
const RARITY_VALUE := 0   # position of WHITE in your Rarity enum
const DATA_DIR := "res://data/partners/"
const ART_DIR := "res://assets/partners/"

# id, display name, form, codex no, source
const CARDS := [
	["lin_qiye_blindfolded", "Lin Qiye", "Blindfolded", 1, "Slay the Gods"],
	["han_li_child", "Han Li", "Child", 2, "A Record of a Mortal's Journey to Immortality"],
	["xiao_yan_youth", "Xiao Yan", "Wu Tan City Youth", 3, "Battle Through the Heavens"],
	["shi_hao_child", "Shi Hao", "Stone Village Child", 4, "Perfect World"],
	["wang_lin_youth", "Wang Lin", "Village Youth", 5, "Renegade Immortal"],
	["bai_xiaochun_outer_disciple", "Bai Xiaochun", "Outer Sect Disciple", 6, "A Will Eternal"],
	["nie_li_reborn", "Nie Li", "Reborn Student", 7, "Tales of Demons and Gods"],
	["tang_san_village", "Tang San", "Holy Soul Village", 8, "Soul Land"],
	["xiao_wu", "Xiao Wu", "Notting Academy", 9, "Soul Land"],
	["luo_feng_student", "Luo Feng", "Student", 10, "Swallowed Star"],
	["lin_dong_youth", "Lin Dong", "Qingyang Town Youth", 11, "Martial Universe"],
	["mu_chen_academy", "Mu Chen", "Northern Spiritual Academy", 12, "The Great Ruler"],
	["qin_yu_prince", "Qin Yu", "Young Prince", 13, "Stellar Transformations"],
	["zhang_xiaofan_young", "Zhang Xiaofan", "Young", 14, "Jade Dynasty"],
	["meng_chuan_youth", "Meng Chuan", "Dongning Youth", 15, "Cang Yuan Tu"],
	["long_haochen_squire", "Long Haochen", "Squire Knight", 16, "Throne of Seal"],
	["ye_fan_earth", "Ye Fan", "Earth", 17, "Shrouding the Heavens"],
	["li_feiyu", "Li Feiyu", "", 18, "A Record of a Mortal's Journey to Immortality"],
	["zhang_tie", "Zhang Tie", "", 19, "A Record of a Mortal's Journey to Immortality"],
	["mo_caihuan", "Mo Caihuan", "", 20, "A Record of a Mortal's Journey to Immortality"],
	["xiao_mei", "Xiao Mei", "", 21, "Battle Through the Heavens"],
	["du_ze", "Du Ze", "", 22, "Tales of Demons and Gods"],
	["lu_piao", "Lu Piao", "", 23, "Tales of Demons and Gods"],
	["wang_zhuo", "Wang Zhuo", "", 24, "Renegade Immortal"],
	["hou_xiaomei", "Hou Xiaomei", "", 25, "A Will Eternal"],
	["lei_wujie", "Lei Wujie", "Early", 26, "Great Journey of Teenagers"],
	["su_baiyi", "Su Baiyi", "Early", 27, "Jun You Yun"],
	["qingtan", "Qingtan", "Young", 28, "Martial Universe"],
	["baili_pangpang", "Baili Pangpang", "Recruit", 29, "Slay the Gods"],
	["hong_ying", "Hong Ying", "", 30, "Slay the Gods"],
]


func _run() -> void:
	var data_folder := DATA_DIR + TIER + "/"
	DirAccess.make_dir_recursive_absolute(data_folder)

	var created := 0
	var updated := 0

	for c in CARDS:
		var id: String = c[0]
		var path := data_folder + id + ".tres"
		var art_folder := ART_DIR + TIER + "/" + id + "/"
		DirAccess.make_dir_recursive_absolute(art_folder)

		var res: Resource
		var is_new := not ResourceLoader.exists(path)

		if is_new:
			res = PartnerData.new()
			_put(res, "partner_id", id)
			_put(res, "character_id", c[1].to_lower().replace(" ", "_").replace("'", ""))
			_put(res, "display_name", c[1])
			_put(res, "form_name", c[2])
			_put(res, "codex_no", c[3])
			_put(res, "source", c[4])
			_put(res, "rarity", RARITY_VALUE)
		else:
			res = load(path)

		var hooked := false
		hooked = _hook_texture(res, "card_texture", art_folder + id + "_card.png") or hooked
		hooked = _hook_texture(res, "sprite_texture", art_folder + id + "_sprite.png") or hooked

		if is_new or hooked:
			var err := ResourceSaver.save(res, path)
			if err != OK:
				push_error("Could not save " + path)
				continue
			if is_new:
				created += 1
			else:
				updated += 1

	EditorInterface.get_resource_filesystem().scan()
	print("%s cards: %d created, %d updated with art" % [TIER, created, updated])


# Only sets a field if PartnerData actually has it
func _put(res: Resource, field: String, value) -> void:
	for p in res.get_property_list():
		if p.name == field:
			res.set(field, value)
			return
	push_warning("PartnerData has no field '%s' (skipped)" % field)


func _hook_texture(res: Resource, field: String, png: String) -> bool:
	if not ResourceLoader.exists(png):
		return false
	if not field in res or res.get(field) != null:
		return false
	res.set(field, load(png))
	return true
