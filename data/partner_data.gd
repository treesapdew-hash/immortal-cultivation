class_name PartnerData
extends Resource

# =========================================================
# STATIC partner definition. One .tres file per partner.
#
# This never changes while the game runs. It is the designer's
# description of what a partner IS.
#
# The player's copy of a partner (their level, stars, gear)
# lives in OwnedPartner instead. Keep these two separate --
# it is the single most important structural decision here.
#
# Spec section 17: partner data must be data-driven, and
# artwork must not be hardcoded through the game scripts.
# =========================================================


@export_group("Identity")

## Unique key, lowercase with underscores. Also used to build
## asset paths, so it must match your filenames.
## Example: "han_li_young" -> han_li_young_card.png
@export var partner_id: String = ""

## Shown in the UI. Example: "Han Li"
@export var display_name: String = ""

## Which version of the character this is (spec section 16).
## Han Li - Child and Han Li - Core Formation are SEPARATE partners.
@export var form_name: String = ""

## Where the character comes from. Example: "A Record of a Mortal's Journey"
@export var series: String = ""


@export_group("Classification")

@export var rarity: Enums.Rarity = Enums.Rarity.WHITE

@export var path: Enums.Path = Enums.Path.MARTIAL

## Realm this partner starts at. Index into Enums.REALMS.
@export_range(0, 29) var starting_realm_index: int = 0


@export_group("Base Stats")

# These are the values at cultivation step 0, 1 star, 0 awakening.
# Everything else is derived from them, so keep them small and
# readable. Tuning the whole game means tuning these numbers.

@export var base_hp: int = 1000
@export var base_atk: int = 100
@export var base_def: int = 60
@export var base_mdef: int = 60
@export var base_spd: int = 100

@export_range(0.0, 100.0) var base_crit: float = 10.0
@export_range(0.0, 100.0) var base_crit_damage: float = 150.0
@export_range(0.0, 100.0) var base_eva: float = 5.0
@export_range(0.0, 100.0) var base_accuracy: float = 90.0

## Energy gained per action. At 100 energy the signature skill fires.
@export var base_energy_regen: int = 20


@export_group("Skill")

@export var skill_name: String = ""

@export_multiline var skill_description: String = ""

@export var skill_icon: Texture2D


@export_group("Artwork")

## Full card art for the partner detail panel.
@export var card_texture: Texture2D

## Battle sprite. Must have a transparent background.
@export var sprite_texture: Texture2D

## Small portrait for lists and the formation row.
## Optional -- falls back to card_texture if left empty.
@export var portrait_texture: Texture2D


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

## "Han Li - Foundation Establishment"
func get_full_name() -> String:
	if form_name.is_empty():
		return display_name

	return "%s - %s" % [display_name, form_name]


func get_rarity_color() -> Color:
	return Enums.RARITY_COLORS[rarity]


func get_rarity_multiplier() -> float:
	return Enums.RARITY_STAT_MULTIPLIER[rarity]


func get_portrait() -> Texture2D:
	if portrait_texture != null:
		return portrait_texture

	return card_texture
