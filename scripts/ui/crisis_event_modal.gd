class_name CrisisEventModal
extends PanelContainer

signal finished(summary_text: String)

const CRISIS_PATH: String = "res://data/json/crisis_events.json"

@onready var tag_label: Label = %CrisisTagLabel
@onready var title_label: Label = %CrisisTitleLabel
@onready var desc_label: Label = %CrisisDescLabel
@onready var choices_box: VBoxContainer = %CrisisChoicesBox
@onready var ok_btn: Button = %CrisisOkBtn

var _crises: Array[Dictionary] = []
var _last_summary: String = ""

func _ready() -> void:
	visible = false
	_load_crises()
	ok_btn.pressed.connect(_on_ok_pressed)

func _load_crises() -> void:
	_crises.clear()
	if not FileAccess.file_exists(CRISIS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CRISIS_PATH))
	if parsed is Dictionary:
		for c in (parsed as Dictionary).get("crises", []):
			if c is Dictionary:
				_crises.append(c as Dictionary)

func open_crisis(trigger_tag: String) -> void:
	if _crises.is_empty():
		_load_crises()
	var pool: Array[Dictionary] = []
	for c in _crises:
		if str(c.get("trigger_tag", "general")) == trigger_tag:
			pool.append(c)
	if pool.is_empty():
		pool = _crises
	if pool.is_empty():
		finished.emit("")
		return

	var ev: Dictionary = pool[randi() % pool.size()]
	visible = true
	ok_btn.visible = false
	_last_summary = ""
	tag_label.text = "[ BASIN & TARAFTAR KRIZI ]"
	tag_label.modulate = Color(1.0, 0.45, 0.38, 1.0)
	title_label.text = str(ev.get("title", "BASIN KRIZI"))
	desc_label.text = str(ev.get("description", ""))
	desc_label.modulate = Color(0.94, 0.96, 1.0, 1.0)
	_clear_choices()

	for ch_v in ev.get("choices", []):
		if ch_v is Dictionary:
			var ch: Dictionary = ch_v as Dictionary
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", 6)
			# KATI KURAL: Seceneklerde asla spoiler yok!
			btn.text = "> " + str(ch.get("label", "..."))
			btn.pressed.connect(_on_crisis_choice.bind(ch))
			choices_box.add_child(btn)

func open_romance_transfer_drama() -> void:
	visible = true
	ok_btn.visible = false
	_last_summary = ""
	var pname: String = GameState.romance_partner_name if not GameState.romance_partner_name.is_empty() else "Sevgilin"
	tag_label.text = "[ TRANSFER DRAMASI — ILISKI KARARI ]"
	tag_label.modulate = Color(1.0, 0.58, 0.78, 1.0)
	title_label.text = "%s Ile Yol Ayrimi" % pname
	desc_label.modulate = Color(0.96, 0.94, 1.0, 1.0)
	desc_label.text = "%s (%s) kulubune transfer oldugunu ogrenen %s gozleri dolarak bavulunun yanina oturdu: 'Baska bir ulkeye gidiyorsun %s... Bizim hikayemiz ne olacak?'" % [
		GameState.current_club_name, GameState.current_country_code, pname, GameState.player_name
	]
	_clear_choices()

	var opts: Array[Dictionary] = [
		{
			"label": "Benimle yeni ulkeye gel, hayatimizi orada birlikte kuralim.",
			"status": &"moved_together",
			"result": "%s gulumseyerek boynuna sarildi: 'Seninle dunyanin obur ucuna bile gelirim!' Artık yeni ulkedeki evinde seni karsilayacak." % pname
		},
		{
			"label": "Buradaki duzenini bozma, evdeki PC'den her hafta goruntulu konusalim.",
			"status": &"long_distance",
			"result": "%s derin bir nefes alip elini tuttu: 'Zor olacak ama her macini ekrandan izleyecegim.' (Haftalik romantik PC mesajlari basladi!)" % pname
		},
		{
			"label": "Kariyerim icin tek basima gitmem en dogrusu... Hoscakal.",
			"status": &"broken_up",
			"result": "Sessiz ve buruk bir veda oldu. Yeni sehrinde tamamen futbola odaklanacaksin."
		}
	]
	for opt in opts:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 6)
		btn.text = "> " + str(opt["label"])
		btn.pressed.connect(_on_romance_choice.bind(opt))
		choices_box.add_child(btn)

func _on_crisis_choice(ch: Dictionary) -> void:
	_clear_choices()
	var eff: Dictionary = ch.get("effects", {})
	var has_pr: bool = GameState.has_item(&"pr_agency")
	var notes := PackedStringArray()
	var pr_helped: bool = false

	if eff.has("cash"):
		var dc: int = int(eff["cash"])
		GameState.modify_cash(dc)
		notes.append("%+d TL" % dc)

	if eff.has("fan_rep"):
		var df: float = float(eff["fan_rep"])
		if df < 0.0 and has_pr:
			df *= 0.5
			pr_helped = true
		GameState.fan_reputation = clampf(GameState.fan_reputation + df, 0.0, 100.0)
		notes.append("Taraftar %+d" % roundi(df))

	if eff.has("media_rep"):
		var dm: float = float(eff["media_rep"])
		if dm < 0.0 and has_pr:
			dm *= 0.5
			pr_helped = true
		GameState.media_reputation = clampf(GameState.media_reputation + dm, 0.0, 100.0)
		notes.append("Medya %+d" % roundi(dm))

	if eff.has("coach_trust"):
		var ct: float = float(eff["coach_trust"])
		GameState.manager_trust = clampf(GameState.manager_trust + ct, 0.0, 100.0)
		notes.append("Hoca %+d" % roundi(ct))

	if eff.has("team_trust"):
		var tt: float = float(eff["team_trust"])
		for npc in UniverseDB.npcs:
			if npc.role == &"teammate" or npc.role == &"captain":
				npc.pitch_trust = clampf(npc.pitch_trust + tt, 0.0, 100.0)
		UniverseDB.relationships_changed.emit()
		notes.append("Takim %+d" % roundi(tt))

	if pr_helped:
		notes.append("PR Danismani hasari azaltti!")

	var r_txt: String = str(ch.get("result_text", "Kriz sonuclandi."))
	GameState.add_pc_news("GUNDEM: " + title_label.text, r_txt)
	GameState.player_resources_changed.emit()

	desc_label.modulate = Color(0.75, 0.96, 0.8, 1.0)
	desc_label.text = r_txt + ("\n\n[" + " | ".join(notes) + "]" if not notes.is_empty() else "")
	_last_summary = "Kriz cozuldu: " + ", ".join(notes)
	ok_btn.visible = true
	ok_btn.grab_focus()

func _on_romance_choice(opt: Dictionary) -> void:
	_clear_choices()
	var st: StringName = opt["status"] as StringName
	GameState.romance_status = st
	GameState.pending_romance_transfer_drama = false
	if st == &"moved_together":
		GameState.modify_stamina(15.0)
	elif st == &"broken_up":
		GameState.modify_stamina(-10.0)
	GameState.save_to_disk()

	desc_label.modulate = Color(1.0, 0.82, 0.9, 1.0)
	desc_label.text = str(opt["result"])
	_last_summary = "Iliski karari alindi."
	ok_btn.visible = true
	ok_btn.grab_focus()

func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()

func _on_ok_pressed() -> void:
	visible = false
	finished.emit(_last_summary)
