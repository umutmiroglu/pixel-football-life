class_name MainMenu
extends Control

const TOWN_SCENE_PATH: String = "res://scenes/world/starter_town.tscn"
const PROCEDURAL_CHAR_SCENE: PackedScene = preload("res://scenes/character/procedural_character.tscn")
const START_FREE_POINTS: int = 15

const STAT_META: Array[Dictionary] = [
	{ "key": "speed", "label": "Hiz" },
	{ "key": "dribbling", "label": "Calim" },
	{ "key": "passing", "label": "Pas" },
	{ "key": "shooting", "label": "Sut" },
	{ "key": "curve", "label": "Falso" },
	{ "key": "physical", "label": "Fizik" }
]

@onready var name_input: LineEdit = %NameInput
@onready var rand_btn: Button = %RandNameBtn
@onready var pos_cam_btn: Button = %PosCAMBtn
@onready var pos_st_btn: Button = %PosSTBtn
@onready var pos_wing_btn: Button = %PosWINGBtn
@onready var preview_holder: Node2D = %PreviewHolder
@onready var appearance_box: VBoxContainer = %AppearanceBox
@onready var points_label: Label = %PointsLeftLabel
@onready var stats_alloc_box: VBoxContainer = %StatsAllocBox
@onready var start_new_btn: Button = %StartNewBtn
@onready var continue_btn: Button = %ContinueBtn

var _selected_pos: FootballerStats.Position = FootballerStats.Position.CAM
var _custom_app: CharacterAppearance = null
var _preview_char: ProceduralCharacter = null
var _points_left: int = START_FREE_POINTS
var _bonus_stats: Dictionary = {}
var _base_stats: Dictionary = {}
var _stat_val_labels: Dictionary = {}
var _app_val_labels: Dictionary = {}

func _ready() -> void:
	Engine.time_scale = 1.0
	_custom_app = CharacterAppearance.create_random(Color(0.14, 0.84, 0.98, 1.0), Color(0.95, 0.97, 1.0, 1.0))
	_preview_char = PROCEDURAL_CHAR_SCENE.instantiate() as ProceduralCharacter
	_preview_char.scale = Vector2(1.9, 1.9)
	preview_holder.add_child(_preview_char)

	name_input.text = NameGenerator.generate_male_name("TR", false)
	rand_btn.pressed.connect(_on_randomize_all)
	pos_cam_btn.pressed.connect(func() -> void: _select_pos(FootballerStats.Position.CAM))
	pos_st_btn.pressed.connect(func() -> void: _select_pos(FootballerStats.Position.ST))
	pos_wing_btn.pressed.connect(func() -> void: _select_pos(FootballerStats.Position.WING))
	start_new_btn.pressed.connect(_on_start_new)
	continue_btn.pressed.connect(_on_continue)

	_build_appearance_controls()
	_build_stat_controls()
	_select_pos(FootballerStats.Position.CAM)
	_refresh_appearance_ui()
	_refresh_save_button()

func _build_appearance_controls() -> void:
	var rows: Array[Dictionary] = [
		{ "key": "face_idx", "label": "Yuz" },
		{ "key": "hair_idx", "label": "Sac" },
		{ "key": "beard_idx", "label": "Sakal" },
		{ "key": "skin_color_idx", "label": "Ten" },
		{ "key": "hair_color_idx", "label": "Sac R." }
	]
	for r in rows:
		var k: String = str(r["key"])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)

		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(30.0, 0.0)
		lbl.add_theme_font_size_override("font_size", 5)
		lbl.text = str(r["label"])
		h.add_child(lbl)

		var b_prev := Button.new()
		b_prev.text = "<"
		b_prev.add_theme_font_size_override("font_size", 5)
		b_prev.pressed.connect(_step_appearance.bind(k, -1))
		h.add_child(b_prev)

		var v_lbl := Label.new()
		v_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v_lbl.add_theme_font_size_override("font_size", 5)
		v_lbl.text = "1/7"
		h.add_child(v_lbl)
		_app_val_labels[k] = v_lbl

		var b_next := Button.new()
		b_next.text = ">"
		b_next.add_theme_font_size_override("font_size", 5)
		b_next.pressed.connect(_step_appearance.bind(k, 1))
		h.add_child(b_next)

		appearance_box.add_child(h)

func _build_stat_controls() -> void:
	for sm in STAT_META:
		var k: String = str(sm["key"])
		_bonus_stats[k] = 0
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 5)
		lbl.text = str(sm["label"])
		h.add_child(lbl)

		var b_min := Button.new()
		b_min.text = "-"
		b_min.add_theme_font_size_override("font_size", 5)
		b_min.pressed.connect(_adjust_stat.bind(k, -1))
		h.add_child(b_min)

		var v_lbl := Label.new()
		v_lbl.custom_minimum_size = Vector2(28.0, 0.0)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v_lbl.add_theme_font_size_override("font_size", 5)
		v_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
		h.add_child(v_lbl)
		_stat_val_labels[k] = v_lbl

		var b_plus := Button.new()
		b_plus.text = "+"
		b_plus.add_theme_font_size_override("font_size", 5)
		b_plus.pressed.connect(_adjust_stat.bind(k, 1))
		h.add_child(b_plus)

		stats_alloc_box.add_child(h)

func _step_appearance(field: String, delta: int) -> void:
	SoundFX.play_click()
	var cur: int = int(_custom_app.get(field))
	var nxt: int = (cur + delta + CharacterAppearance.VARIANT_COUNT) % CharacterAppearance.VARIANT_COUNT
	_custom_app.set(field, nxt)
	_refresh_appearance_ui()

func _refresh_appearance_ui() -> void:
	if _preview_char != null and _custom_app != null:
		_preview_char.apply_appearance(_custom_app)
		_preview_char.update_locomotion(Vector2.ZERO, Vector2.DOWN, 0.0, 0.0)
	for k in _app_val_labels.keys():
		var lbl: Label = _app_val_labels[k] as Label
		lbl.text = "%d/7" % (int(_custom_app.get(str(k))) + 1)

func _select_pos(pos: FootballerStats.Position) -> void:
	SoundFX.play_click()
	_selected_pos = pos
	pos_cam_btn.modulate = Color(1.0, 0.92, 0.35, 1.0) if pos == FootballerStats.Position.CAM else Color(0.72, 0.78, 0.86, 1.0)
	pos_st_btn.modulate = Color(1.0, 0.92, 0.35, 1.0) if pos == FootballerStats.Position.ST else Color(0.72, 0.78, 0.86, 1.0)
	pos_wing_btn.modulate = Color(1.0, 0.92, 0.35, 1.0) if pos == FootballerStats.Position.WING else Color(0.72, 0.78, 0.86, 1.0)

	match pos:
		FootballerStats.Position.ST:
			_base_stats = { "speed": 76, "dribbling": 72, "passing": 68, "shooting": 82, "curve": 74, "physical": 64 }
		FootballerStats.Position.WING:
			_base_stats = { "speed": 84, "dribbling": 82, "passing": 72, "shooting": 74, "curve": 78, "physical": 60 }
		_:
			_base_stats = { "speed": 74, "dribbling": 78, "passing": 80, "shooting": 76, "curve": 80, "physical": 62 }

	_refresh_stat_ui()

func _adjust_stat(key: String, delta: int) -> void:
	var cur_b: int = int(_bonus_stats.get(key, 0))
	if delta > 0 and _points_left <= 0:
		return
	if delta < 0 and cur_b <= 0:
		return
	if int(_base_stats.get(key, 70)) + cur_b + delta > 95:
		return
	SoundFX.play_click()
	_bonus_stats[key] = cur_b + delta
	_points_left -= delta
	_refresh_stat_ui()

func _refresh_stat_ui() -> void:
	points_label.text = "RPG Puan Dagilimi (Kalan: %d)" % _points_left
	points_label.modulate = Color(0.45, 1.0, 0.58, 1.0) if _points_left > 0 else Color(0.78, 0.88, 1.0, 1.0)
	for sm in STAT_META:
		var k: String = str(sm["key"])
		var base_v: int = int(_base_stats.get(k, 70))
		var b_v: int = int(_bonus_stats.get(k, 0))
		var lbl: Label = _stat_val_labels[k] as Label
		lbl.text = "%d%s" % [base_v + b_v, ("(+%d)" % b_v) if b_v > 0 else ""]

func _on_randomize_all() -> void:
	SoundFX.play_click()
	NameGenerator.reset_used_names()
	name_input.text = NameGenerator.generate_male_name("TR", false)
	_custom_app = CharacterAppearance.create_random(Color(0.14, 0.84, 0.98, 1.0), Color(0.95, 0.97, 1.0, 1.0))
	_refresh_appearance_ui()

func _refresh_save_button() -> void:
	if SaveManager.has_save():
		var data: Dictionary = SaveManager.load_career()
		if not data.is_empty():
			continue_btn.visible = true
			continue_btn.text = "DEVAM ET: %s (%s S%d)" % [
				str(data.get("player_name", "Oyuncu")),
				str(data.get("current_club_name", "Kulup")),
				int(data.get("season", 1))
			]
			return
	continue_btn.visible = false

func _on_start_new() -> void:
	SoundFX.play_whistle()
	var chosen: String = name_input.text.strip_edges()
	GameState.start_new_career(chosen, _selected_pos, _custom_app, _bonus_stats)
	get_tree().change_scene_to_file(TOWN_SCENE_PATH)

func _on_continue() -> void:
	SoundFX.play_click()
	if GameState.load_from_disk():
		get_tree().change_scene_to_file(TOWN_SCENE_PATH)
