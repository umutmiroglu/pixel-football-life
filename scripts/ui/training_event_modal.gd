class_name TrainingEventModal
extends PanelContainer

signal completed(summary_text: String)

const EVENTS_PATH: String = "res://data/json/training_events.json"

@onready var title_label: Label = %EventTitleLabel
@onready var desc_label: Label = %EventDescLabel
@onready var choices_box: VBoxContainer = %EventChoicesBox
@onready var continue_btn: Button = %EventContinueBtn

var _events: Array[Dictionary] = []
var _last_summary: String = ""

func _ready() -> void:
	visible = false
	_load_events()
	continue_btn.pressed.connect(_on_continue_pressed)

func _load_events() -> void:
	_events.clear()
	if not FileAccess.file_exists(EVENTS_PATH):
		push_error("TrainingEventModal missing JSON: " + EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if parsed is Dictionary:
		for ev in (parsed as Dictionary).get("events", []):
			if ev is Dictionary:
				_events.append(ev as Dictionary)

func open_training_card() -> void:
	if _events.is_empty():
		_load_events()
	var is_hangover: bool = GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")
	var pool: Array[Dictionary] = []
	for ev in _events:
		var req_h: bool = bool(ev.get("requires_hangover", false))
		if is_hangover and req_h:
			pool.append(ev)
		elif (not is_hangover) and (not req_h):
			pool.append(ev)
	if pool.is_empty() and not _events.is_empty():
		pool = _events

	if pool.is_empty():
		completed.emit("Antrenman verisi bulunamadi.")
		return

	var picked: Dictionary = pool[randi() % pool.size()]
	_present_event(picked)

func _present_event(ev: Dictionary) -> void:
	visible = true
	continue_btn.visible = false
	_last_summary = ""
	title_label.text = str(ev.get("title", "ANTRENMAN KARTI")).to_upper()
	desc_label.text = str(ev.get("description", ""))
	_clear_choices()

	var choices: Array = ev.get("choices", [])
	for c in choices:
		if c is Dictionary:
			var ch: Dictionary = c as Dictionary
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", 6)
			# KATI KURAL: Seceneklerde asla parantez ici stat/odul spoileri gosterilmez!
			btn.text = "> " + str(ch.get("label", "..."))
			btn.pressed.connect(_on_choice_picked.bind(ch))
			choices_box.add_child(btn)

func _on_choice_picked(choice: Dictionary) -> void:
	_clear_choices()
	var eff: Dictionary = choice.get("effects", {})
	var feedback_notes := PackedStringArray()

	if eff.has("stat"):
		var n1: String = GameState.add_stat_delta(str(eff["stat"]), int(eff.get("stat_delta", 0)))
		if not n1.is_empty():
			feedback_notes.append(n1)
	if eff.has("stat2"):
		var n2: String = GameState.add_stat_delta(str(eff["stat2"]), int(eff.get("stat2_delta", 0)))
		if not n2.is_empty():
			feedback_notes.append(n2)
	if eff.has("stamina_delta"):
		GameState.modify_stamina(float(eff["stamina_delta"]))
	if eff.has("coach_trust_delta"):
		var cd: float = float(eff["coach_trust_delta"])
		GameState.manager_trust = clampf(GameState.manager_trust + cd, 0.0, 100.0)
		var coach_npc: NPCProfile = UniverseDB.find_npc_by_id(&"coach_main")
		if coach_npc != null:
			coach_npc.pitch_trust = clampf(coach_npc.pitch_trust + cd, 0.0, 100.0)
			UniverseDB.relationships_changed.emit()
		if absf(cd) >= 1.0:
			feedback_notes.append("Hoca Guveni %+d" % roundi(cd))
	if eff.has("team_trust_delta"):
		var td: float = float(eff["team_trust_delta"])
		for npc in UniverseDB.npcs:
			if npc.role == &"teammate" or npc.role == &"captain":
				npc.pitch_trust = clampf(npc.pitch_trust + td, 0.0, 100.0)
		UniverseDB.relationships_changed.emit()
		if absf(td) >= 1.0:
			feedback_notes.append("Takim Guveni %+d" % roundi(td))

	GameState.trained_today = true
	GameState.player_resources_changed.emit()

	var result_text: String = str(choice.get("result_text", "Antrenman tamamlandi."))
	var suffix: String = ("\n\n[" + " | ".join(feedback_notes) + "]") if not feedback_notes.is_empty() else ""
	desc_label.text = result_text + suffix
	_last_summary = "Idman tamamlandi! " + (", ".join(feedback_notes) if not feedback_notes.is_empty() else "")
	continue_btn.visible = true
	continue_btn.grab_focus()

func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()

func _on_continue_pressed() -> void:
	visible = false
	completed.emit(_last_summary)
