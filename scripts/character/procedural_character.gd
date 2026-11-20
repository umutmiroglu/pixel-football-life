class_name ProceduralCharacter
extends Node2D

# 4x4 Sprite Sheet satırları: 0=Aşağı(Güney), 1=Yukarı(Kuzey), 2=Sağ, 3=Sol
const ROW_DOWN: int = 0
const ROW_UP: int = 1
const ROW_RIGHT: int = 2
const ROW_LEFT: int = 3
const FRAMES_PER_ROW: int = 4

@onready var shadow_sprite: Sprite2D = $Shadow
@onready var legs_sprite: Sprite2D = $LegsSprite
@onready var body_sprite: Sprite2D = $BodySprite
@onready var face_sprite: Sprite2D = $FaceSprite
@onready var hair_sprite: Sprite2D = $HairSprite
@onready var beard_sprite: Sprite2D = $BeardSprite

var appearance: CharacterAppearance = null
var _anim_time: float = 0.0
var _current_row: int = ROW_DOWN
var _current_col: int = 0

static var _texture_cache: Dictionary[String, Texture2D] = {}

func _ready() -> void:
	if appearance == null:
		apply_appearance(CharacterAppearance.new())
	else:
		apply_appearance(appearance)

func apply_appearance(data: CharacterAppearance) -> void:
	appearance = data
	if legs_sprite == null:
		return

	legs_sprite.texture = _load_layer_tex("legs", data.legs_idx)
	body_sprite.texture = _load_layer_tex("body", data.body_idx)
	face_sprite.texture = _load_layer_tex("face", data.face_idx)
	hair_sprite.texture = _load_layer_tex("hair", data.hair_idx)
	beard_sprite.texture = _load_layer_tex("beard", data.beard_idx)

	legs_sprite.self_modulate = data.secondary_color
	body_sprite.self_modulate = data.primary_color
	face_sprite.self_modulate = data.get_skin_color()
	hair_sprite.self_modulate = data.get_hair_color()
	beard_sprite.self_modulate = data.get_hair_color()

	_apply_frame(_current_row, _current_col)

func update_locomotion(world_velocity: Vector2, world_facing: Vector2, delta: float, camera_rot: float = 0.0) -> void:
	# Karakter ekranda daima Stardew Valley gibi dik dursun (kale arkası +90° kamerada rotation=+90°)
	rotation = camera_rot

	# Dünya yönünü ekran yönüne çevir (kamera +90° dönükse +X yukarı/-Y olur!)
	var speed: float = world_velocity.length()
	var ref_dir: Vector2 = world_velocity.normalized() if speed > 10.0 else world_facing
	var screen_dir: Vector2 = ref_dir.rotated(-camera_rot)

	if screen_dir.length_squared() > 0.01:
		if absf(screen_dir.x) > absf(screen_dir.y):
			_current_row = ROW_RIGHT if screen_dir.x > 0.0 else ROW_LEFT
		else:
			_current_row = ROW_DOWN if screen_dir.y > 0.0 else ROW_UP

	if speed > 10.0:
		# Hıza orantılı akıcı 4 kare yürüme/koşu animasyonu
		var fps: float = clampf(speed * 0.11, 5.0, 12.0)
		_anim_time += delta * fps
		_current_col = int(floor(_anim_time)) % FRAMES_PER_ROW
	else:
		_anim_time = 0.0
		_current_col = 0

	_apply_frame(_current_row, _current_col)

func _apply_frame(row: int, col: int) -> void:
	var frame_idx: int = row * FRAMES_PER_ROW + col
	legs_sprite.frame = frame_idx
	body_sprite.frame = frame_idx
	face_sprite.frame = frame_idx
	hair_sprite.frame = frame_idx
	beard_sprite.frame = frame_idx

static func _load_layer_tex(folder: String, idx: int) -> Texture2D:
	var safe_idx: int = clampi(idx, 0, CharacterAppearance.VARIANT_COUNT - 1)
	var path: String = "res://assets/sprites/character/%s/%s_%d.png" % [folder, folder, safe_idx]
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex := load(path) as Texture2D
	if tex != null:
		_texture_cache[path] = tex
	return tex
