class_name PCHubModal
extends PanelContainer

signal closed()
signal quest_packet_triggered(packet: Dictionary)

const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"
const RPG_STATS: Array[Dictionary] = [
	{ "key": "speed", "label": "Hiz (Speed)" },
	{ "key": "dribbling", "label": "Calim (Dribbling)" },
	{ "key": "passing", "label": "Pas (Passing)" },
	{ "key": "vision", "label": "Oyun Gorusu (Vision)" },
	{ "key": "positioning", "label": "Pozisyon Alma" },
	{ "key": "shooting", "label": "Sut (Shooting)" },
	{ "key": "curve", "label": "Falso (Curve)" },
	{ "key": "physical", "label": "Fizik (Physical)" },
	{ "key": "stamina", "label": "Dayaniklilik (Stamina)" }
]

@onready var tab_msg_btn: Button = %TabMsgBtn
@onready var tab_social_btn: Button = %TabSocialBtn
@onready var tab_league_btn: Button = %TabLeagueBtn
@onready var tab_shop_btn: Button = %TabShopBtn
@onready var tab_rpg_btn: Button = %TabRpgBtn
@onready var close_btn: Button = %CloseBtn
@onready var pc_content_label: RichTextLabel = %PCContentLabel
@onready var pc_quest_btn: Button = %PCQuestBtn

@onready var shop_container: VBoxContainer = %ShopContainer
@onready var shop_header_label: Label = %ShopHeaderLabel
@onready var shop_feedback_label: Label = %ShopFeedbackLabel
@onready var shop_list_box: VBoxContainer = %ShopListBox

@onready var rpg_container: VBoxContainer = %RpgContainer
@onready var rpg_header_label: Label = %RpgHeaderLabel
@onready var rpg_list_box: VBoxContainer = %RpgListBox
@onready var legacy_summary_label: Label = %LegacySummaryLabel
@onready var retire_export_btn: Button = %RetireExportBtn
@onready var main_menu_btn: Button = %MainMenuBtn

var _current_tab: StringName = &"messages"
var _physical_sport_shop_mode: bool = false

func _ready() -> void:
	visible = false
	tab_msg_btn.pressed.connect(func() -> void: _show_tab(&"messages"))
	tab_social_btn.pressed.connect(func() -> void: _show_tab(&"social"))
	tab_league_btn.pressed.connect(func() -> void: _show_tab(&"league"))
	tab_shop_btn.pressed.connect(func() -> void: _show_tab(&"shop"))
	tab_rpg_btn.pressed.connect(func() -> void: _show_tab(&"rpg"))
	close_btn.pressed.connect(_on_close_pressed)
	pc_quest_btn.pressed.connect(_on_pc_quest_pressed)
	retire_export_btn.pressed.connect(_on_retire_export_pressed)
	main_menu_btn.pressed.connect(_on_return_main_menu)

func open_pc() -> void:
	_physical_sport_shop_mode = false
	tab_msg_btn.visible = true
	tab_social_btn.visible = true
	tab_league_btn.visible = true
	tab_shop_btn.visible = true
	tab_rpg_btn.visible = true
	tab_shop_btn.text = "Magaza"
	tab_rpg_btn.text = "RPG (+%d)" % GameState.free_stat_points if GameState.free_stat_points > 0 else "RPG & Kariyer"
	visible = true
	shop_feedback_label.visible = false
	main_menu_btn.visible = false
	retire_export_btn.disabled = false

	if QuestDirector.has_available_trigger_at("home_pc_messages"):
		pc_quest_btn.visible = true
		pc_quest_btn.text = "[!] YENI ACIL MESAJI OKU!"
	else:
		pc_quest_btn.visible = false
	_show_tab(&"messages")

func open_physical_sport_shop() -> void:
	_physical_sport_shop_mode = true
	tab_msg_btn.visible = false
	tab_social_btn.visible = false
	tab_league_btn.visible = false
	tab_rpg_btn.visible = false
	tab_shop_btn.visible = true
	tab_shop_btn.text = "KRAMPON & SPOR MAGAZASI"
	pc_quest_btn.visible = false
	visible = true
	shop_feedback_label.visible = false
	_show_tab(&"shop")

func _show_tab(tab: StringName) -> void:
	SoundFX.play_click()
	_current_tab = tab
	pc_content_label.visible = false
	shop_container.visible = false
	rpg_container.visible = false

	if tab == &"shop":
		shop_container.visible = true
		_rebuild_shop_list()
		return
	if tab == &"rpg":
		rpg_container.visible = true
		_rebuild_rpg_panel()
		return

	pc_content_label.visible = true
	var lines := PackedStringArray()
	match tab:
		&"messages":
			lines.append("[color=#70e1ff][b]=== GELEN MESAJLAR ===[/b][/color]")
			for m in GameState.pc_messages:
				lines.append("[color=#ffe66d][b]%s[/b] — %s[/color]\n%s\n" % [str(m.get("sender", "")), str(m.get("title", "")), str(m.get("text", ""))])
		&"social":
			lines.append("[color=#70e1ff][b]=== SOSYAL MEDYA AKISI (Taraftar: %%%d | Medya: %%%d) ===[/b][/color]" % [roundi(GameState.fan_reputation), roundi(GameState.media_reputation)])
			for p in GameState.pc_social_posts:
				lines.append("[color=#ff9e64][b]%s[/b] %s[/color]\n%s\n" % [str(p.get("author", "")), str(p.get("tag", "")), str(p.get("text", ""))])
		&"league":
			lines.append("[color=#70e1ff][b]=== LIG PUAN DURUMU (%s — S%d H%d/%d) ===[/b][/color]" % [GameState.current_country_code, GameState.season, mini(GameState.week, GameState.SEASON_WEEKS), GameState.SEASON_WEEKS])
			var rank: int = 1
			for row in GameState.league_table:
				var col: String = "#5cff7a" if bool(row.get("is_player_club", false)) else "#dce8f5"
				lines.append("[color=%s]%d. %s  —  O:%d  AV:%+d  P:%d[/color]" % [col, rank, str(row["name"]), int(row["played"]), int(row["gd"]), int(row["pts"])])
				rank += 1
			lines.append("\n[color=#ffe66d][b]=== SPOR HABERLERI ===[/b][/color]")
			for n in GameState.pc_news:
				lines.append("[b]%s[/b]\n%s\n" % [str(n.get("headline", "")), str(n.get("text", ""))])

	pc_content_label.text = "\n".join(lines)

func _rebuild_shop_list() -> void:
	for child in shop_list_box.get_children():
		child.queue_free()

	var st: FootballerStats = GameState.player_stats
	var anomaly_txt: String = " [FIZIKSEL ANOMALI!]" if (st != null and st.is_physical_anomaly) else ""
	var stat_line: String = ""
	if st != null:
		stat_line = "\nSUT:%d FAL:%d PAS:%d CAL:%d HIZ:%d (Eff:%d) FIZ:%d%s" % [
			st.shooting, st.curve, st.passing, st.dribbling, st.speed, roundi(st.get_effective_speed()), st.physical, anomaly_txt
		]
	var mode_hint: String = " | (Ev Dekoru & Yatirim icin Evdeki PC!)" if _physical_sport_shop_mode else ""
	shop_header_label.text = "Nakit: %d TL | Maas: %d TL/hf | Pasif: +%d TL/hf%s%s" % [
		GameState.cash, GameState.weekly_wage, GameState.passive_weekly_income, mode_hint, stat_line
	]

	for item in GameState.shop_catalog:
		var cat: String = str(item.get("category", "equipment"))
		if _physical_sport_shop_mode and cat != "equipment" and cat != "service":
			continue

		var item_id := StringName(str(item.get("id", "")))
		var is_consumable: bool = bool(item.get("consumable", false))
		var owned: bool = (not is_consumable) and (item_id in GameState.owned_items)
		var price: int = int(item.get("price", 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var info_lbl := Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.add_theme_font_size_override("font_size", 5)
		info_lbl.text = "[%s] %s — %s" % [_category_label(cat), str(item.get("name", "")), str(item.get("description", ""))]
		row.add_child(info_lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(56.0, 0.0)
		buy_btn.add_theme_font_size_override("font_size", 5)
		if owned:
			buy_btn.text = "ALINDI"
			buy_btn.disabled = true
		else:
			buy_btn.text = "%d TL" % price
			buy_btn.disabled = (GameState.cash < price)
			buy_btn.pressed.connect(_on_buy_item_pressed.bind(item_id))
		row.add_child(buy_btn)

		shop_list_box.add_child(row)

func _rebuild_rpg_panel() -> void:
	for c in rpg_list_box.get_children():
		c.queue_free()

	var st: FootballerStats = GameState.player_stats
	var anomaly_txt: String = " | [FIZIKSEL ANOMALI!]" if (st != null and st.is_physical_anomaly) else ""
	var sleep_note: String = " | Uyudugunda Dagitilacak Puan: %d!" % GameState.free_stat_points if GameState.free_stat_points > 0 else ""
	rpg_header_label.text = "%s (%d yas) — Seviye %d (XP: %d/%d)%s%s" % [
		GameState.player_name, GameState.player_age, GameState.career_level, GameState.career_xp, GameState.get_xp_for_next_level(), sleep_note, anomaly_txt
	]
	tab_rpg_btn.text = "RPG & Kariyer"

	if st != null:
		for meta in RPG_STATS:
			var k: String = str(meta["key"])
			var cur_val: int = int(st.get(k))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)

			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 5)
			lbl.text = str(meta["label"])
			row.add_child(lbl)

			var val_lbl := Label.new()
			val_lbl.custom_minimum_size = Vector2(28.0, 0.0)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.add_theme_font_size_override("font_size", 5)
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
			val_lbl.text = str(cur_val)
			row.add_child(val_lbl)

			rpg_list_box.add_child(row)

	var countries_str: String = ", ".join(GameState.countries_played)
	legacy_summary_label.text = "KARIYER MUZESI: %d Sezon | %d Mac | %d Gol | %d Asist | %d Kupa | Ulkeler: [%s]" % [
		GameState.season, GameState.career_total_matches, GameState.career_total_goals, GameState.career_total_assists, GameState.career_trophies, countries_str
	]

func _on_spend_rpg_point(stat_key: String) -> void:
	GameState.spend_stat_point(stat_key)
	_rebuild_rpg_panel()

func _on_retire_export_pressed() -> void:
	SoundFX.play_whistle()
	var exported_path: String = GameState.export_career_legacy()
	retire_export_btn.disabled = true
	main_menu_btn.visible = true
	legacy_summary_label.modulate = Color(1.0, 0.92, 0.38, 1.0)
	legacy_summary_label.text = "EMEKLI OLDUN! Efsane kariyerin devam oyunu icin disa aktarildi:\n%s" % exported_path

func _on_return_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _category_label(cat: String) -> String:
	match cat:
		"equipment": return "EKIPMAN"
		"service": return "SAGLIK/PR"
		"lifestyle": return "YASAM"
		"furniture": return "EV DEKOR"
		"investment": return "YATIRIM"
		_: return "DIGER"

func _on_buy_item_pressed(item_id: StringName) -> void:
	var res: Dictionary = GameState.purchase_shop_item(item_id)
	shop_feedback_label.visible = true
	shop_feedback_label.text = str(res.get("message", ""))
	shop_feedback_label.modulate = Color(0.45, 1.0, 0.58, 1.0) if bool(res.get("ok", false)) else Color(1.0, 0.45, 0.38, 1.0)
	_rebuild_shop_list()

func _on_pc_quest_pressed() -> void:
	var pkt: Dictionary = QuestDirector.check_location_trigger("home_pc_messages", false)
	if not pkt.is_empty():
		visible = false
		quest_packet_triggered.emit(pkt)

func _on_close_pressed() -> void:
	SoundFX.play_click()
	visible = false
	closed.emit()
