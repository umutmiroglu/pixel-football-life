class_name StoryDialogueBox
extends PanelContainer

signal finished(transition_to_match: bool)

@onready var title_label: Label = %TitleLabel
@onready var speaker_label: Label = %SpeakerLabel
@onready var mood_label: Label = %MoodLabel
@onready var text_label: Label = %TextLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var next_btn: Button = %NextBtn

var _mode: StringName = &"quest" # &"quest" veya &"daily"
var _packet: Dictionary = {}
var _line_index: int = 0
var _daily_npc: NPCProfile = null
var _pending_match_transition: bool = false
var _daily_done: bool = false

func _ready() -> void:
	visible = false
	next_btn.pressed.connect(_on_next_pressed)

func open_quest_packet(packet: Dictionary) -> void:
	if packet.is_empty():
		return
	_mode = &"quest"
	_packet = packet
	_line_index = 0
	_pending_match_transition = false
	visible = true
	title_label.text = "HIKAYE: %s" % str(_packet.get("quest_title", "Olay")).to_upper()
	_show_current_quest_line()

func open_daily_chat(npc: NPCProfile) -> void:
	_mode = &"daily"
	_daily_npc = npc
	_daily_done = false
	_pending_match_transition = false
	visible = true
	var t_role: String = UniverseDB.get_tag_label("role", npc.role)
	var t_temp: String = UniverseDB.get_tag_label("temperament", npc.temperament)
	var t_int: String = UniverseDB.get_tag_label("interest", npc.interest)
	title_label.text = "%s  [%s | %s | %s]" % [npc.full_name, t_role, t_temp, t_int]

	var chat: Dictionary = DialogueRunner.build_daily_chat(
		npc,
		UniverseDB.dialogues_data,
		UniverseDB.personalities_data,
		GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")
	)
	speaker_label.text = npc.full_name
	var rel_info: String = "Samimiyet: %d" % roundi(npc.affection)
	if npc.is_football_world:
		rel_info += " | Saha Guveni: %d" % roundi(npc.pitch_trust)
	mood_label.text = rel_info
	text_label.text = str(chat.get("line", ""))

	_clear_choices()
	next_btn.visible = false
	var choices: Array = chat.get("choices", [])
	for c in choices:
		if c is Dictionary:
			var cd: Dictionary = c as Dictionary
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 6)
			btn.text = "> " + str(cd.get("text", "..."))
			btn.pressed.connect(_on_daily_choice_selected.bind(cd))
			choices_box.add_child(btn)

func _on_daily_choice_selected(choice: Dictionary) -> void:
	if _daily_npc == null:
		return
	var res: Dictionary = DialogueRunner.resolve_daily_choice(_daily_npc, choice, UniverseDB.personalities_data)
	_clear_choices()
	text_label.text = str(res.get("feedback", ""))
	_daily_done = true
	next_btn.visible = true
	next_btn.text = "Kapat [E / Tikla]"

func _show_current_quest_line() -> void:
	_clear_choices()
	var lines: Array = _packet.get("dialogue", [])
	if _line_index < lines.size():
		var item: Dictionary = lines[_line_index] as Dictionary
		var spk_key: String = str(item.get("speaker_key", "narrator"))
		speaker_label.text = str(item.get("speaker_name", "ANLATICI"))
		var mood_str: String = str(item.get("mood", ""))
		mood_label.text = ("[%s]" % mood_str) if not mood_str.is_empty() else ""
		text_label.text = str(item.get("text", ""))
		if spk_key == "narrator":
			speaker_label.modulate = Color(0.7, 0.85, 1.0, 1.0)
			text_label.modulate = Color(0.86, 0.9, 0.96, 1.0)
		elif spk_key == "player":
			speaker_label.modulate = Color(0.35, 0.96, 1.0, 1.0)
			text_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			speaker_label.modulate = Color(1.0, 0.9, 0.35, 1.0)
			text_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

		var is_last_line: bool = (_line_index == lines.size() - 1)
		var choices: Array = _packet.get("choices", [])
		if is_last_line and not choices.is_empty():
			next_btn.visible = false
			_populate_quest_choices(choices)
		else:
			next_btn.visible = true
			next_btn.text = "Devam [Tikla / Space]" if not is_last_line else "Tamamla [Tikla / Space]"
	else:
		_complete_current_quest_node()

func _populate_quest_choices(choices: Array) -> void:
	for c in choices:
		if not (c is Dictionary):
			continue
		var cd: Dictionary = c as Dictionary
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 6)
		# GDD Kuralı: Diyalog seçeneklerinde asla parantez içi kazanç/maliyet spoiler'ı gösterilmez!
		btn.text = "> %s" % str(cd.get("label", "Sec"))
		btn.pressed.connect(_on_quest_choice_picked.bind(cd))
		choices_box.add_child(btn)

func _on_quest_choice_picked(choice: Dictionary) -> void:
	var qid: String = str(_packet.get("quest_id", ""))
	if choice.has("effects") and choice["effects"] is Dictionary:
		var eff_res: Dictionary = QuestDirector.apply_node_or_choice_effects(qid, choice["effects"] as Dictionary)
		if bool(eff_res.get("transition_to_match", false)):
			_pending_match_transition = true

	var next_id: Variant = choice.get("next", null)
	if next_id != null and not str(next_id).is_empty():
		var next_pkt: Dictionary = QuestDirector.get_next_node_packet(qid, str(next_id))
		if not next_pkt.is_empty():
			_packet = next_pkt
			_line_index = 0
			_show_current_quest_line()
			return
	_close_box()

func _complete_current_quest_node() -> void:
	var qid: String = str(_packet.get("quest_id", ""))
	var node_eff: Variant = _packet.get("effects", {})
	if node_eff is Dictionary and not (node_eff as Dictionary).is_empty():
		var eff_res: Dictionary = QuestDirector.apply_node_or_choice_effects(qid, node_eff as Dictionary)
		if bool(eff_res.get("transition_to_match", false)):
			_pending_match_transition = true

	if bool(_packet.get("is_ending", false)):
		QuestDirector.mark_quest_finished(qid)

	var next_id: Variant = _packet.get("next", null)
	if next_id != null and not str(next_id).is_empty():
		var next_pkt: Dictionary = QuestDirector.get_next_node_packet(qid, str(next_id))
		if not next_pkt.is_empty():
			_packet = next_pkt
			_line_index = 0
			_show_current_quest_line()
			return

	_close_box()

func _on_next_pressed() -> void:
	if _mode == &"daily":
		if _daily_done:
			_close_box()
		return
	_line_index += 1
	_show_current_quest_line()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if next_btn.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_on_next_pressed()

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _close_box() -> void:
	visible = false
	_clear_choices()
	finished.emit(_pending_match_transition)
