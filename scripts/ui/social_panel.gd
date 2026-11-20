class_name SocialPanel
extends PanelContainer

signal closed()

@onready var npc_list_box: VBoxContainer = %NPCListBox
@onready var portrait_holder: Node2D = %PortraitHolder
@onready var npc_name_label: Label = %NPCNameLabel
@onready var npc_tags_label: Label = %NPCTagsLabel
@onready var affection_bar: ProgressBar = %AffectionBar
@onready var affection_val: Label = %AffectionVal
@onready var trust_row: HBoxContainer = %TrustRow
@onready var trust_bar: ProgressBar = %TrustBar
@onready var trust_val: Label = %TrustVal
@onready var header_meta_label: Label = %HeaderMetaLabel
@onready var dialogue_label: Label = %DialogueLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var chat_btn: Button = %ChatBtn
@onready var quest_btn: Button = %QuestBtn
@onready var close_btn: Button = %CloseBtn

const PROCEDURAL_CHAR_SCENE: PackedScene = preload("res://scenes/character/procedural_character.tscn")

var _portrait_char: ProceduralCharacter = null
var _selected_npc: NPCProfile = null
var _active_daily: Dictionary = {}

func _ready() -> void:
	_portrait_char = PROCEDURAL_CHAR_SCENE.instantiate() as ProceduralCharacter
	_portrait_char.scale = Vector2(1.75, 1.75)
	portrait_holder.add_child(_portrait_char)

	chat_btn.pressed.connect(_on_chat_pressed)
	quest_btn.visible = false
	close_btn.pressed.connect(_on_close_pressed)

	UniverseDB.relationships_changed.connect(_refresh_selected_profile)
	GameState.player_resources_changed.connect(_refresh_header_meta)

	_populate_npc_list()
	if not UniverseDB.npcs.is_empty():
		_select_npc(UniverseDB.npcs[0])
	_refresh_header_meta()

func open_panel() -> void:
	visible = true
	_populate_npc_list()
	_refresh_header_meta()
	_refresh_selected_profile()

func _populate_npc_list() -> void:
	for child in npc_list_box.get_children():
		child.queue_free()

	for npc in UniverseDB.npcs:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 6)
		btn.text = npc.full_name
		btn.pressed.connect(_select_npc.bind(npc))
		npc_list_box.add_child(btn)

func _select_npc(npc: NPCProfile) -> void:
	_selected_npc = npc
	_active_daily.clear()
	_clear_choices()
	dialogue_label.text = "Sohbet etmek icin asagidaki dugmeye bas. (Buyuk yan hikayeler kasaba mekanlarinda tetiklenir!)"
	_refresh_selected_profile()

func _refresh_header_meta() -> void:
	var avg_trust: int = UniverseDB.get_average_team_pitch_trust()
	var status_str: String = " | HANGOVER!" if (GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")) else ""
	header_meta_label.text = "Para: %d TL  |  Takim Guveni: %d%s" % [GameState.cash, avg_trust, status_str]

func _refresh_selected_profile() -> void:
	_refresh_header_meta()
	if _selected_npc == null:
		return

	npc_name_label.text = "%s (%d yas)" % [_selected_npc.full_name, _selected_npc.age]
	var t1: String = UniverseDB.get_tag_label("temperament", _selected_npc.temperament)
	var t2: String = UniverseDB.get_tag_label("interest", _selected_npc.interest)
	var t3: String = UniverseDB.get_tag_label("philosophy", _selected_npc.philosophy)
	var t4: String = UniverseDB.get_tag_label("role", _selected_npc.role)
	npc_tags_label.text = "[%s] [%s] [%s] [%s]" % [t4, t1, t2, t3]

	affection_bar.value = _selected_npc.affection
	affection_val.text = "%d" % roundi(_selected_npc.affection)

	trust_row.visible = _selected_npc.is_football_world
	if _selected_npc.is_football_world:
		trust_bar.value = _selected_npc.pitch_trust
		trust_val.text = "%d" % roundi(_selected_npc.pitch_trust)

	if _portrait_char != null and _selected_npc.appearance != null:
		_portrait_char.apply_appearance(_selected_npc.appearance)
		_portrait_char.update_locomotion(Vector2.ZERO, Vector2.DOWN, 0.0, 0.0)

func _on_chat_pressed() -> void:
	if _selected_npc == null:
		return
	_active_daily = DialogueRunner.build_daily_chat(
		_selected_npc,
		UniverseDB.dialogues_data,
		UniverseDB.personalities_data,
		GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")
	)
	dialogue_label.text = str(_active_daily.get("line", ""))
	_clear_choices()
	var choices: Array = _active_daily.get("choices", [])
	for c in choices:
		if c is Dictionary:
			var ch_dict: Dictionary = c as Dictionary
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 6)
			btn.text = "> " + str(ch_dict.get("text", "..."))
			btn.pressed.connect(_on_daily_choice_picked.bind(ch_dict))
			choices_box.add_child(btn)

func _on_daily_choice_picked(choice: Dictionary) -> void:
	if _selected_npc == null:
		return
	var res: Dictionary = DialogueRunner.resolve_daily_choice(_selected_npc, choice, UniverseDB.personalities_data)
	_clear_choices()
	var aff_d: int = roundi(float(res.get("affection_delta", 0.0)))
	var tr_d: int = roundi(float(res.get("pitch_trust_delta", 0.0)))
	var delta_txt: String = "Samimiyet %+d" % aff_d
	if _selected_npc.is_football_world:
		delta_txt += " | Saha Guveni %+d" % tr_d
	dialogue_label.text = "%s\n[%s]" % [str(res.get("feedback", "")), delta_txt]

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
