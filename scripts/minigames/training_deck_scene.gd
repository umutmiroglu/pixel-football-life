class_name TrainingDeckScene
extends Control

const DECK_PATH: String = "res://data/json/training_deck.json"
const CARDS_ART_DIR: String = "res://assets/sprites/cards/"
const TRAINING_GROUND_PATH: String = "res://scenes/world/training_ground.tscn"

@onready var top_info_label: Label = %DeckTopInfoLabel
@onready var stam_info_label: Label = %DeckStamLabel
@onready var card_panel: PanelContainer = %CardPanel
@onready var cat_label: Label = %CardCategoryLabel
@onready var title_label: Label = %CardTitleLabel
@onready var art_rect: TextureRect = %CardArtRect
@onready var desc_label: Label = %CardDescLabel
@onready var choices_box: VBoxContainer = %CardChoicesBox
@onready var next_btn: Button = %CardNextBtn

var _session_cards: Array[Dictionary] = []
var _current_idx: int = 0
var _session_xp_total: int = 0
var _session_notes: PackedStringArray = PackedStringArray()
var _is_shooting_mode: bool = false
var _session_finished: bool = false

func _ready() -> void:
	Engine.time_scale = 1.0
	_is_shooting_mode = (GameState.training_deck_mode == &"shooting")
	next_btn.pressed.connect(_on_next_pressed)
	_build_session_deck()
	_show_current_card()

func _build_session_deck() -> void:
	_session_cards.clear()
	_session_notes.clear()
	_session_xp_total = 0
	if not FileAccess.file_exists(DECK_PATH):
		push_error("TrainingDeckScene missing JSON: " + DECK_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not (parsed is Dictionary):
		return

	var all_cards: Array[Dictionary] = []
	for item in (parsed as Dictionary).get("cards", []):
		if item is Dictionary:
			all_cards.append(item as Dictionary)

	var is_hangover: bool = GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")
	var target_count: int = 2 if _is_shooting_mode else 3
	var pool: Array[Dictionary] = []

	for c in all_cards:
		var req_h: bool = bool(c.get("requires_hangover", false))
		var d_tag: String = str(c.get("deck", "team"))
		if req_h:
			if (not _is_shooting_mode) and is_hangover:
				_session_cards.append(c)
			continue
		if _is_shooting_mode and (d_tag == "shooting" or d_tag == "both"):
			pool.append(c)
		elif (not _is_shooting_mode) and (d_tag == "team" or d_tag == "both"):
			pool.append(c)

	pool.shuffle()
	for c in pool:
		if _session_cards.size() >= target_count:
			break
		_session_cards.append(c)

func _show_current_card() -> void:
	_refresh_top_bar()
	if _current_idx >= _session_cards.size():
		_show_session_summary()
		return

	var card: Dictionary = _session_cards[_current_idx]
	next_btn.visible = false
	cat_label.text = "[ %s ]" % str(card.get("category", "ANTRENMAN"))
	cat_label.modulate = Color(1.0, 0.45, 0.4, 1.0) if bool(card.get("requires_hangover", false)) else Color(0.55, 0.94, 1.0, 1.0)
	title_label.text = str(card.get("title", "Idman Karti"))
	desc_label.text = str(card.get("description", ""))
	desc_label.modulate = Color(0.92, 0.96, 1.0, 1.0)

	var art_name: String = str(card.get("art", "card_default.png"))
	var art_path: String = CARDS_ART_DIR + art_name
	if not ResourceLoader.exists(art_path):
		art_path = CARDS_ART_DIR + "card_default.png"
	if ResourceLoader.exists(art_path):
		art_rect.texture = load(art_path) as Texture2D

	_clear_choices()
	var choices: Array = card.get("choices", [])
	for ch_v in choices:
		if ch_v is Dictionary:
			var ch: Dictionary = ch_v as Dictionary
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", 6)
			# KATI KURAL: Seceneklerde asla parantez ici stat/odul spoileri yok!
			btn.text = "> " + str(ch.get("label", "..."))
			btn.pressed.connect(_on_choice_picked.bind(ch))
			choices_box.add_child(btn)

	_animate_card_entrance()

func _animate_card_entrance() -> void:
	SoundFX.play_card()
	card_panel.pivot_offset = card_panel.size * 0.5
	card_panel.scale = Vector2(0.88, 0.88)
	card_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_panel, "modulate:a", 1.0, 0.18)

func _on_choice_picked(choice: Dictionary) -> void:
	_clear_choices()
	var is_crit: bool = false
	var has_check: bool = choice.has("check_stat") and choice.has("crit_effects")
	if has_check:
		var stat_val: int = _get_player_stat(str(choice["check_stat"]))
		var thresh: int = int(choice.get("check_threshold", 75))
		var chance: float = clampf(0.40 + float(stat_val - thresh) * 0.035, 0.22, 0.88)
		is_crit = (randf() < chance)

	var eff: Dictionary = choice.get("crit_effects", {}) if is_crit else choice.get("normal_effects", {})
	var result_text: String = str(choice.get("crit_text", "")) if is_crit else str(choice.get("normal_text", ""))
	if result_text.is_empty():
		result_text = str(choice.get("normal_text", "Antrenman tamamlandi."))

	var step_notes: PackedStringArray = _apply_effects(eff)
	for sn in step_notes:
		_session_notes.append(sn)

	if is_crit:
		SoundFX.play_level_up()
	else:
		SoundFX.play_click()

	var badge: String = "★ KRITIK BASARI! ★\n" if is_crit else ""
	desc_label.modulate = Color(1.0, 0.92, 0.35, 1.0) if is_crit else Color(0.65, 0.98, 0.72, 1.0)
	var note_suffix: String = ("\n\n[" + " | ".join(step_notes) + "]") if not step_notes.is_empty() else ""
	desc_label.text = badge + result_text + note_suffix

	_refresh_top_bar()
	next_btn.visible = true
	next_btn.text = "Sonraki Kart ->" if (_current_idx + 1 < _session_cards.size()) else "Seans Ozetini Gor"
	next_btn.grab_focus()

func _apply_effects(eff: Dictionary) -> PackedStringArray:
	var notes := PackedStringArray()
	if eff.has("xp"):
		var xp_gain: int = int(eff["xp"])
		if xp_gain > 0:
			_session_xp_total += xp_gain
			GameState.add_career_xp(xp_gain)
			notes.append("+%d XP" % xp_gain)
	if eff.has("stat"):
		var n1: String = GameState.add_stat_delta(str(eff["stat"]), int(eff.get("stat_delta", 0)))
		if not n1.is_empty():
			notes.append(n1)
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
			notes.append("Hoca Guveni %+d" % roundi(cd))
	if eff.has("team_trust_delta"):
		var td: float = float(eff["team_trust_delta"])
		for npc in UniverseDB.npcs:
			if npc.role == &"teammate" or npc.role == &"captain":
				npc.pitch_trust = clampf(npc.pitch_trust + td, 0.0, 100.0)
		UniverseDB.relationships_changed.emit()
		if absf(td) >= 1.0:
			notes.append("Takim Guveni %+d" % roundi(td))
	GameState.player_resources_changed.emit()
	return notes

func _get_player_stat(stat_name: String) -> int:
	if GameState.player_stats == null:
		return 70
	match stat_name:
		"speed": return GameState.player_stats.speed
		"dribbling": return GameState.player_stats.dribbling
		"passing": return GameState.player_stats.passing
		"vision": return GameState.player_stats.vision
		"positioning": return GameState.player_stats.positioning
		"shooting": return GameState.player_stats.shooting
		"curve": return GameState.player_stats.curve
		"physical": return GameState.player_stats.physical
		"stamina": return GameState.player_stats.stamina
		_: return 70

func _show_session_summary() -> void:
	_session_finished = true
	var hours_spent: int = 2 if _is_shooting_mode else 8
	if _is_shooting_mode:
		GameState.extra_shoot_done_today = true
	else:
		GameState.trained_today = true
	# Takım antrenmanı +8 saat, özel serbest vuruş +2 saat sürer!
	GameState.advance_time_minutes(hours_spent * 60)
	GameState.player_resources_changed.emit()

	_clear_choices()
	cat_label.text = "[ SEANS TAMAMLANDI (+%d SAAT) ]" % hours_spent
	cat_label.modulate = Color(0.45, 1.0, 0.58, 1.0)
	title_label.text = "OZEL SERBEST VURUS OZETI" if _is_shooting_mode else "GUNUN IDMAN OZETI"
	var level_hint: String = "\n\n★ Yeterli XP doldu! Gece uyudugunda +%d RPG puani dagitacaksin! ★" % GameState.free_stat_points if GameState.free_stat_points > 0 else ""
	desc_label.modulate = Color(0.92, 0.96, 1.0, 1.0)
	desc_label.text = (
		"Harika calistin %s! (+%d saat gecti, Saat: %s)\n\n"
		+ "Kazanilan Toplam XP: +%d XP\n"
		+ "Kalan Stamina: %%%d  |  Hoca Guveni: %%%d%s"
	) % [
		GameState.player_name, hours_spent, GameState.get_time_string(),
		_session_xp_total, roundi(GameState.current_stamina), roundi(GameState.manager_trust), level_hint
	]

	next_btn.visible = true
	next_btn.text = "Antrenman Tesisleri'ne Don"
	next_btn.grab_focus()
	_animate_card_entrance()

func _on_next_pressed() -> void:
	if _session_finished:
		get_tree().change_scene_to_file(TRAINING_GROUND_PATH)
		return
	_current_idx += 1
	_show_current_card()

func _refresh_top_bar() -> void:
	var mode_txt: String = "SERBEST VURUS DESTESI" if _is_shooting_mode else "TAKIM ANTRENMANI"
	var card_num: int = mini(_current_idx + 1, maxi(_session_cards.size(), 1))
	top_info_label.text = "%s  |  KART %d / %d" % [mode_txt, card_num, maxi(_session_cards.size(), 1)]
	stam_info_label.text = "Saat %s | STAM: %%%d" % [GameState.get_time_string(), roundi(GameState.current_stamina)]

func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()
