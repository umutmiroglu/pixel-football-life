class_name CharacterAppearance
extends Resource

# GDD 3.1: 7^5 şekil (body, legs, face, hair, beard) x 7 ten x 7 saç = 823.543 benzersiz karakter!
const VARIANT_COUNT: int = 7

const SKIN_PALETTE: Array[Color] = [
	Color(0.98, 0.86, 0.76, 1.0), # Çok açık
	Color(0.94, 0.77, 0.63, 1.0), # Açık buğday
	Color(0.87, 0.67, 0.50, 1.0), # Buğday / Akdeniz
	Color(0.76, 0.54, 0.38, 1.0), # Esmer
	Color(0.62, 0.41, 0.27, 1.0), # Koyu esmer
	Color(0.47, 0.30, 0.20, 1.0), # Kahverengi
	Color(0.33, 0.20, 0.14, 1.0), # Koyu kahve
]

const HAIR_PALETTE: Array[Color] = [
	Color(0.11, 0.10, 0.12, 1.0), # Siyah
	Color(0.24, 0.16, 0.11, 1.0), # Koyu kahve
	Color(0.44, 0.28, 0.16, 1.0), # Kestane
	Color(0.78, 0.62, 0.28, 1.0), # Sarışın
	Color(0.68, 0.28, 0.14, 1.0), # Kızıl
	Color(0.66, 0.68, 0.72, 1.0), # Kır / Gümüş
	Color(0.92, 0.88, 0.58, 1.0), # Platin / Boyalı yıldız
]

@export_range(0, 6) var body_idx: int = 0
@export_range(0, 6) var legs_idx: int = 0
@export_range(0, 6) var face_idx: int = 0
@export_range(0, 6) var hair_idx: int = 1
@export_range(0, 6) var beard_idx: int = 0

@export_range(0, 6) var skin_color_idx: int = 2
@export_range(0, 6) var hair_color_idx: int = 1

@export var primary_color: Color = Color(0.16, 0.55, 0.96, 1.0)
@export var secondary_color: Color = Color(0.92, 0.94, 0.98, 1.0)

func get_skin_color() -> Color:
	return SKIN_PALETTE[clampi(skin_color_idx, 0, SKIN_PALETTE.size() - 1)]

func get_hair_color() -> Color:
	return HAIR_PALETTE[clampi(hair_color_idx, 0, HAIR_PALETTE.size() - 1)]

func with_kit_colors(kit_primary: Color, kit_secondary: Color) -> CharacterAppearance:
	var copy := duplicate() as CharacterAppearance
	copy.primary_color = kit_primary
	copy.secondary_color = kit_secondary
	return copy

func to_dict() -> Dictionary:
	return {
		"body_idx": body_idx,
		"legs_idx": legs_idx,
		"face_idx": face_idx,
		"hair_idx": hair_idx,
		"beard_idx": beard_idx,
		"skin_color_idx": skin_color_idx,
		"hair_color_idx": hair_color_idx,
		"primary_color": primary_color.to_html(false),
		"secondary_color": secondary_color.to_html(false),
	}

static func from_dict(d: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	a.body_idx = clampi(int(d.get("body_idx", 0)), 0, 6)
	a.legs_idx = clampi(int(d.get("legs_idx", 0)), 0, 6)
	a.face_idx = clampi(int(d.get("face_idx", 0)), 0, 6)
	a.hair_idx = clampi(int(d.get("hair_idx", 1)), 0, 6)
	a.beard_idx = clampi(int(d.get("beard_idx", 0)), 0, 6)
	a.skin_color_idx = clampi(int(d.get("skin_color_idx", 2)), 0, 6)
	a.hair_color_idx = clampi(int(d.get("hair_color_idx", 1)), 0, 6)
	a.primary_color = Color.html(str(d.get("primary_color", "298cf5")))
	a.secondary_color = Color.html(str(d.get("secondary_color", "ebeffa")))
	return a

static func create_random(
	kit_primary: Color = Color(0.16, 0.55, 0.96, 1.0),
	kit_secondary: Color = Color(0.92, 0.94, 0.98, 1.0),
	seed_val: int = -1
) -> CharacterAppearance:
	var rng := RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var a := CharacterAppearance.new()
	a.body_idx = rng.randi_range(0, VARIANT_COUNT - 1)
	a.legs_idx = rng.randi_range(0, VARIANT_COUNT - 1)
	a.face_idx = rng.randi_range(0, VARIANT_COUNT - 1)
	a.hair_idx = rng.randi_range(0, VARIANT_COUNT - 1)
	a.beard_idx = rng.randi_range(0, VARIANT_COUNT - 1)
	a.skin_color_idx = rng.randi_range(0, SKIN_PALETTE.size() - 1)
	a.hair_color_idx = rng.randi_range(0, HAIR_PALETTE.size() - 1)
	a.primary_color = kit_primary
	a.secondary_color = kit_secondary
	return a
