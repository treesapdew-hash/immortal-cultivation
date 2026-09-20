@tool
extends EditorScript

const FOLDER := "res://data/partners/white/"

# file id: [Dao name in Enums.Path, series]
const CARDS := {
	"lin_qiye_blindfolded": ["DIVINE", "Slay the Gods"],
	"han_li_child": ["MYSTIC", "A Record of a Mortal's Journey to Immortality"],
	"xiao_yan_youth": ["MARTIAL", "Battle Through the Heavens"],
	"shi_hao_child": ["MARTIAL", "Perfect World"],
	"wang_lin_youth": ["MYSTIC", "Renegade Immortal"],
	"bai_xiaochun_outer_disciple": ["SPIRIT", "A Will Eternal"],
	"nie_li_reborn": ["SPIRIT", "Tales of Demons and Gods"],
	"tang_san_village": ["MYSTIC", "Soul Land"],
	"xiao_wu": ["MARTIAL", "Soul Land"],
	"luo_feng_student": ["SPIRIT", "Swallowed Star"],
	"lin_dong_youth": ["MARTIAL", "Martial Universe"],
	"mu_chen_academy": ["DIVINE", "The Great Ruler"],
	"qin_yu_prince": ["MARTIAL", "Stellar Transformations"],
	"zhang_xiaofan_young": ["SWORD", "Jade Dynasty"],
	"meng_chuan_youth": ["SWORD", "Cang Yuan Tu"],
	"long_haochen_squire": ["DIVINE", "Throne of Seal"],
	"ye_fan_earth": ["DIVINE", "Shrouding the Heavens"],
	"li_feiyu": ["SWORD", "A Record of a Mortal's Journey to Immortality"],
	"zhang_tie": ["MARTIAL", "A Record of a Mortal's Journey to Immortality"],
	"mo_caihuan": ["SPIRIT", "A Record of a Mortal's Journey to Immortality"],
	"xiao_mei": ["SPIRIT", "Battle Through the Heavens"],
	"du_ze": ["SWORD", "Tales of Demons and Gods"],
	"lu_piao": ["SPIRIT", "Tales of Demons and Gods"],
	"wang_zhuo": ["MYSTIC", "Renegade Immortal"],
	"hou_xiaomei": ["MYSTIC", "A Will Eternal"],
	"lei_wujie": ["DIVINE", "Great Journey of Teenagers"],
	"su_baiyi": ["SWORD", "Jun You Yun"],
	"qingtan": ["MYSTIC", "Martial Universe"],
	"baili_pangpang": ["DIVINE", "Slay the Gods"],
	"hong_ying": ["SWORD", "Slay the Gods"],
}


func _run() -> void:
	var done := 0

	for id in CARDS:
		var file: String = FOLDER + str(id) + ".tres"
		if not ResourceLoader.exists(file):
			push_warning("Missing: " + file)
			continue

		var res = load(file)
		var dao_name: String = CARDS[id][0]

		if not Enums.Path.has(dao_name):
			push_error("Enums.Path has no '%s'. Your names are: %s" % [dao_name, Enums.Path.keys()])
			return

		res.set("path", Enums.Path[dao_name])
		res.set("series", CARDS[id][1])
		ResourceSaver.save(res, file)
		done += 1

	EditorInterface.get_resource_filesystem().scan()
	print("Set Dao and series on %d white cards" % done)
