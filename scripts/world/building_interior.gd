class_name BuildingInterior
extends Node2D

const TOWN_SCENE_PATH: String = "res://scenes/world/starter_town.tscn"
const CARDS_SCENE_PATH: String = "res://scenes/minigames/cafe_cards_scene.tscn"
const MATCH_SCENE_PATH: String = "res://scenes/match/match_prototype.tscn"

const EXIT_POS: Vector2 = Vector2(0.0, 56.0)

@onready var floor_rect: ColorRect = $FloorRect
@onready var wall_rect: ColorRect = $BackWallRect
@onready var custom_bg_sprite: Sprite2D = $CustomInteriorBg
@onready var props_root: Node2D = $Props
@onready var npcs_root: Node2D = $NPCs
@onready var player: TownPlayer = $TownPlayer

@onready var header_label: Label = %InteriorHeaderLabel
@onready var prompt_label: Label = %InteriorPromptLabel
@onready var toast_label: Label = %InteriorToastLabel
@onready var dialogue_box: StoryDialogueBox = $HUD/Root/StoryDialogueBox
@onready var pc_modal: PCHubModal = $HUD/Root/PCHubModal
@onready var negotiation_modal: NegotiationModal = $HUD/Root/NegotiationModal
@onready var sleep_overlay: SleepTransitionOverlay = $HUD/Root/SleepTransitionOverlay

var _interior_id: StringName = &"home"
var _stations: Array[Dictionary] = []
var _spawned_npcs: Array[TownNPC] = []
var _active_type: StringName = &""
var _active_station: Dictionary = {}
var _active_npc: TownNPC = null
var _toast_tween: Tween = null

func _ready() -> void:
	Engine.time_scale = 1.0
	_interior_id = GameState.current_interior_id

	dialogue_box.finished.connect(_on_dialogue_finished)
	pc_modal.closed.connect(_on_modal_closed)
	pc_modal.quest_packet_triggered.connect(_on_pc_quest_triggered)
	negotiation_modal.closed.connect(_on_negotiation_closed)
	sleep_overlay.sleep_finished.connect(_on_sleep_finished)
	GameState.time_changed.connect(_on_time_changed)
	GameState.passed_out_at_night.connect(_on_passed_out_at_night)

	_build_interior(_interior_id)
	_refresh_header()

	# İçeri girer girmez bu mekanda tetiklenecek bir yan hikaye (örn. cafe_interior / nightclub_interior) varsa başlat!
	var trigger_key: String = _get_quest_trigger_key(_interior_id)
	if not trigger_key.is_empty():
		var pkt: Dictionary = QuestDirector.check_location_trigger(trigger_key, false)
		if not pkt.is_empty():
			player.controls_locked = true
			dialogue_box.open_quest_packet(pkt)

func _get_quest_trigger_key(bid: StringName) -> String:
	match bid:
		&"gol_cafe": return "cafe_interior"
		&"nightclub": return "nightclub_interior"
		_: return String(bid)

func _build_interior(bid: StringName) -> void:
	_stations.clear()
	_spawned_npcs.clear()

	# Kullanıcı kendi Aseprite iç mekan çizimini assets/sprites/interiors/<id>_bg.png olarak koyduysa otomatik yükle!
	var custom_bg_path: String = "res://assets/sprites/interiors/%s_bg.png" % String(bid)
	if ResourceLoader.exists(custom_bg_path):
		custom_bg_sprite.texture = load(custom_bg_path) as Texture2D
		custom_bg_sprite.visible = true
	else:
		custom_bg_sprite.visible = false

	match bid:
		&"home":
			floor_rect.color = Color(0.48, 0.34, 0.22, 1.0)
			wall_rect.color = Color(0.76, 0.68, 0.56, 1.0)
			_add_prop("res://assets/sprites/props/bed.png", Vector2(-68.0, -28.0), &"home_bed", "[E] Yatakta Uyu (Gunu Bitir & Oto-Kaydet)", Vector2(28.0, 20.0))
			_add_prop("res://assets/sprites/props/pc_desk.png", Vector2(68.0, -28.0), &"home_pc", "[E] Evdeki Bilgisayari Ac (PC Hub)", Vector2(28.0, 20.0))
			# Faz 6: Satin alinan ev dekorasyon mobilyalari fiziksel olarak evin icine yerlesir!
			if GameState.has_item(&"home_arcade_tv"):
				_add_prop("res://assets/sprites/props/arcade_tv.png", Vector2(0.0, -30.0), &"play_console", "[E] Retro Konsol Oyna (Stres At)", Vector2(28.0, 20.0))
			if GameState.has_item(&"home_gym_corner"):
				_add_prop("res://assets/sprites/props/home_gym.png", Vector2(-72.0, 18.0), &"home_workout", "[E] Ev Spor Kosesinde Calis", Vector2(28.0, 20.0))
			if GameState.has_item(&"home_trophy_shelf"):
				_add_prop("res://assets/sprites/props/trophy_shelf.png", Vector2(74.0, 18.0), &"view_trophies", "[E] Kupa & Madalya Dolabi", Vector2(24.0, 22.0))
			if GameState.romance_status == &"moved_together":
				_spawn_npc(&"barista_main", Vector2(24.0, 12.0))

		&"clubhouse":
			floor_rect.color = Color(0.18, 0.28, 0.44, 1.0)
			wall_rect.color = Color(0.32, 0.42, 0.58, 1.0)
			_add_prop("res://assets/sprites/props/negotiation_desk.png", Vector2(0.0, -26.0), &"negotiation", "[E] Sozlesme & Transfer Pazarlik Masasi", Vector2(52.0, 24.0))
			_spawn_npc(&"chairman_main", Vector2(-42.0, -24.0))
			_spawn_npc(&"agent_main", Vector2(52.0, -18.0))

		&"press_center":
			floor_rect.color = Color(0.34, 0.36, 0.42, 1.0)
			wall_rect.color = Color(0.64, 0.64, 0.68, 1.0)
			_add_prop("res://assets/sprites/props/press_desk.png", Vector2(0.0, -26.0), &"interview", "[E] Basin Roportaji Ver (Medya Itibari)", Vector2(44.0, 20.0))
			_spawn_npc(&"press_main", Vector2(42.0, -18.0))

		&"gol_cafe":
			floor_rect.color = Color(0.56, 0.4, 0.26, 1.0)
			wall_rect.color = Color(0.84, 0.72, 0.54, 1.0)
			_add_prop("res://assets/sprites/props/cafe_counter.png", Vector2(0.0, -30.0), &"buy_coffee", "[E] Sicak Kahve Ic (50 TL)", Vector2(60.0, 20.0))
			_spawn_npc(&"barista_main", Vector2(-46.0, -16.0))
			if GameState.romance_status == &"none":
				_add_prop("res://assets/sprites/props/card_table.png", Vector2(54.0, 12.0), &"romance_date", "[E] Baristayla Kahve Randevusu (Iliski)", Vector2(36.0, 22.0))

		&"nightclub":
			floor_rect.color = Color(0.14, 0.1, 0.22, 1.0)
			wall_rect.color = Color(0.28, 0.12, 0.42, 1.0)
			_add_prop("res://assets/sprites/props/bar_counter.png", Vector2(0.0, -30.0), &"party_night", "[E] Gece Boyu Eglen (150 TL)", Vector2(68.0, 20.0))
			_spawn_npc(&"mate_nightlife", Vector2(52.0, -8.0))

		&"sport_shop":
			floor_rect.color = Color(0.24, 0.42, 0.32, 1.0)
			wall_rect.color = Color(0.72, 0.82, 0.74, 1.0)
			_add_prop("res://assets/sprites/props/shop_rack.png", Vector2(0.0, -28.0), &"open_shop", "[E] Krampon & Ekipman Vitrini", Vector2(44.0, 20.0))
			_spawn_npc(&"shop_owner", Vector2(46.0, -14.0))

		&"corner_cafe":
			floor_rect.color = Color(0.46, 0.34, 0.24, 1.0)
			wall_rect.color = Color(0.76, 0.66, 0.54, 1.0)
			_add_prop("res://assets/sprites/props/cafe_counter.png", Vector2(-42.0, -30.0), &"buy_tea", "[E] Sicak Cay Ic (35 TL)", Vector2(58.0, 20.0))
			_add_prop("res://assets/sprites/props/card_table.png", Vector2(48.0, -12.0), &"play_cards", "[E] 21 Iskambil Masasina Otur!", Vector2(36.0, 24.0))
			_spawn_npc(&"cafe2_host", Vector2(-56.0, 2.0))

func _add_prop(tex_path: String, pos: Vector2, action_id: StringName, prompt_txt: String, col_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var spr := Sprite2D.new()
	spr.texture = load(tex_path) as Texture2D
	body.add_child(spr)

	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = col_size
	col.shape = rect_shape
	body.add_child(col)
	props_root.add_child(body)

	var lbl := Label.new()
	lbl.text = prompt_txt.replace("[E] ", "")
	lbl.position = Vector2(-56.0, -col_size.y * 0.5 - 12.0)
	lbl.size = Vector2(112.0, 12.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 5)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62, 1.0))
	body.add_child(lbl)

	_stations.append({
		"pos": pos,
		"radius": maxf(col_size.x, col_size.y) * 0.5 + 16.0,
		"action": action_id,
		"prompt": prompt_txt
	})

func _spawn_npc(npc_id: StringName, pos: Vector2) -> void:
	var prof: NPCProfile = UniverseDB.find_npc_by_id(npc_id)
	if prof == null:
		return
	var actor := TownNPC.new()
	npcs_root.add_child(actor)
	actor.setup(prof, pos)
	_spawned_npcs.append(actor)

func _refresh_header() -> void:
	var title: String = _get_building_title(_interior_id)
	header_label.text = "%s  |  [%s] %s  |  %d TL  |  STAM: %%%d" % [
		title, GameState.get_time_string(), GameState.get_day_label(), GameState.cash, roundi(GameState.current_stamina)
	]

func _get_building_title(bid: StringName) -> String:
	match bid:
		&"home": return "SENIN EVIN"
		&"clubhouse": return "KULUP EVI (MAVI LOKAL)"
		&"press_center": return "KASABA SPOR GAZETESI"
		&"gol_cafe": return "GOL KAFE"
		&"nightclub": return "NEON GECE KULUBU"
		&"sport_shop": return "KRAMPON & SPOR MAGAZASI"
		&"corner_cafe": return "KOSE KAHVE"
		_: return "IC MEKAN"

func _process(delta: float) -> void:
	GameState.tick_clock(delta, player.controls_locked)
	if player.controls_locked:
		prompt_label.visible = false
		return

	_active_type = &""
	_active_station = {}
	_active_npc = null

	if player.global_position.distance_to(EXIT_POS) <= 24.0:
		_active_type = &"exit"
		prompt_label.visible = true
		prompt_label.text = "[E] Kapidan Kasabaya Cik"
		return

	var best_d: float = 9999.0
	for n in _spawned_npcs:
		var d: float = player.global_position.distance_to(n.global_position)
		if d <= 26.0 and d < best_d:
			best_d = d
			_active_type = &"npc"
			_active_npc = n

	for st in _stations:
		var d: float = player.global_position.distance_to(st["pos"] as Vector2)
		if d <= float(st["radius"]) and d < best_d:
			best_d = d
			_active_type = &"station"
			_active_station = st
			_active_npc = null

	if _active_type == &"npc" and _active_npc != null:
		prompt_label.visible = true
		prompt_label.text = "[E] Konus: %s" % _active_npc.npc_profile.full_name
	elif _active_type == &"station" and not _active_station.is_empty():
		prompt_label.visible = true
		prompt_label.text = str(_active_station["prompt"])
	else:
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player.controls_locked:
		return
	if event.is_action_pressed("interact"):
		if _active_type == &"exit":
			SoundFX.play_door()
			GameState.pending_town_spawn = _interior_id
			get_tree().change_scene_to_file(TOWN_SCENE_PATH)
		elif _active_type == &"npc" and _active_npc != null:
			player.controls_locked = true
			dialogue_box.open_daily_chat(_active_npc.npc_profile)
		elif _active_type == &"station" and not _active_station.is_empty():
			_execute_station(StringName(str(_active_station["action"])))

func _execute_station(action_id: StringName) -> void:
	match action_id:
		&"home_bed":
			player.controls_locked = true
			sleep_overlay.trigger_sleep(false)

		&"play_console":
			if GameState.played_console_today:
				_show_toast("Bugun yeterince oyun oynadin, biraz dinlen veya sahaya cik!", Color(0.95, 0.85, 0.45, 1.0))
				return
			GameState.played_console_today = true
			GameState.modify_stamina(8.0)
			_refresh_header()
			_show_toast("Retro konsolda 2 mac atip stres attin! (+8 Stamina)", Color(0.55, 1.0, 0.72, 1.0))

		&"home_workout":
			if GameState.current_stamina < 14.0:
				_show_toast("Evde idman icin en az %14 Stamina gerekli.", Color(1.0, 0.45, 0.38, 1.0))
				return
			GameState.modify_stamina(-10.0)
			var note: String = GameState.add_stat_delta("physical", 1)
			_refresh_header()
			_show_toast("Ev spor kosesinde ter attin! (%s)" % note, Color(0.52, 1.0, 0.65, 1.0))

		&"view_trophies":
			_show_toast("Sezon %d | Gol: %d | Asist: %d | Pasif Gelir: +%d TL/hf" % [
				GameState.season, GameState.season_goals, GameState.season_assists, GameState.passive_weekly_income
			], Color(1.0, 0.92, 0.42, 1.0))

		&"romance_date":
			var b_npc: NPCProfile = UniverseDB.find_npc_by_id(&"barista_main")
			if b_npc == null:
				return
			if b_npc.affection < 60.0:
				_show_toast("%s ile once biraz daha sohbet edip samimiyet kurmalisin!" % b_npc.full_name, Color(1.0, 0.78, 0.52, 1.0))
				return
			if GameState.cash < 80:
				_show_toast("Romantik kahve randevusu icin 80 TL gerekli.", Color(1.0, 0.45, 0.38, 1.0))
				return
			GameState.modify_cash(-80)
			GameState.romance_partner_name = b_npc.full_name
			GameState.romance_status = &"dating"
			b_npc.affection = clampf(b_npc.affection + 12.0, 0.0, 100.0)
			UniverseDB.relationships_changed.emit()
			GameState.save_to_disk()
			_refresh_header()
			_show_toast("Harika bir aksamdi! Artik %s ile iliskidesin!" % b_npc.full_name, Color(1.0, 0.58, 0.82, 1.0))

		&"home_pc":
			player.controls_locked = true
			pc_modal.open_pc()

		&"negotiation":
			player.controls_locked = true
			negotiation_modal.open_negotiation()

		&"open_shop":
			player.controls_locked = true
			pc_modal.open_physical_sport_shop()

		&"play_cards":
			get_tree().change_scene_to_file(CARDS_SCENE_PATH)

		&"buy_coffee":
			if GameState.cash < 50:
				_show_toast("Kahve icin yeterli nakit yok (50 TL).", Color(1.0, 0.45, 0.38, 1.0))
				return
			GameState.modify_cash(-50)
			GameState.modify_stamina(20.0)
			_refresh_header()
			_show_toast("Gol Kafe'de sicak kahve ictin, biraz toparlandin.", Color(0.95, 0.85, 0.45, 1.0))

		&"buy_tea":
			if GameState.cash < 35:
				_show_toast("Cay icin yeterli nakit yok (35 TL).", Color(1.0, 0.45, 0.38, 1.0))
				return
			GameState.modify_cash(-35)
			GameState.modify_stamina(16.0)
			_refresh_header()
			_show_toast("Kose Kahve'de tavsan kani cay ictin!", Color(0.72, 0.96, 0.72, 1.0))

		&"party_night":
			if GameState.cash < 150:
				_show_toast("Gece kulubu eglencesi 150 TL.", Color(1.0, 0.45, 0.38, 1.0))
				return
			GameState.modify_cash(-150)
			GameState.modify_stamina(-25.0)
			GameState.add_status(&"Hangover")
			GameState.fan_reputation = clampf(GameState.fan_reputation + 2.0, 0.0, 100.0)
			_refresh_header()
			_show_toast("Neon Club'da gece gec saatlere kadar eglendin...", Color(1.0, 0.6, 0.85, 1.0))

		&"interview":
			if GameState.interviewed_today:
				_show_toast("Bugun basin roportajini zaten verdin!", Color(0.95, 0.85, 0.45, 1.0))
				return
			GameState.interviewed_today = true
			GameState.media_reputation = clampf(GameState.media_reputation + 5.0, 0.0, 100.0)
			GameState.fan_reputation = clampf(GameState.fan_reputation + 2.0, 0.0, 100.0)
			GameState.add_pc_news(
				"OZEL ROPORTAJ: %s Hedeflerini Anlatti!" % GameState.player_name,
				"%s formasiyla iddiali aciklamalar yapan %s, taraftarlardan tam destek aldi." % [GameState.current_club_name, GameState.player_name]
			)
			_refresh_header()
			_show_toast("Basin roportaji yayinlandi! Medya itibarin artti.", Color(0.62, 0.92, 1.0, 1.0))

func _on_pc_quest_triggered(pkt: Dictionary) -> void:
	dialogue_box.open_quest_packet(pkt)

func _on_dialogue_finished(to_match: bool) -> void:
	player.controls_locked = false
	_refresh_header()
	if to_match:
		get_tree().change_scene_to_file(MATCH_SCENE_PATH)

func _on_modal_closed() -> void:
	player.controls_locked = false
	_refresh_header()

func _on_time_changed(_m: int) -> void:
	_refresh_header()

func _on_passed_out_at_night() -> void:
	if not is_inside_tree():
		return
	player.controls_locked = true
	sleep_overlay.trigger_sleep(true)

func _on_sleep_finished(summary_msg: String) -> void:
	player.controls_locked = false
	if _interior_id != &"home":
		GameState.current_interior_id = &"home"
		get_tree().reload_current_scene()
		return
	_refresh_header()
	_show_toast(summary_msg, Color(0.55, 0.95, 1.0, 1.0))

func _on_negotiation_closed(did_transfer: bool) -> void:
	player.controls_locked = false
	if did_transfer:
		GameState.last_match_summary = "FLAS TRANSFER! Yeni Kulup: %s (%s) — Tum kadro & lig yenilendi!" % [GameState.current_club_name, GameState.current_country_code]
		GameState.pending_town_spawn = &"home"
		get_tree().change_scene_to_file(TOWN_SCENE_PATH)
		return
	_refresh_header()

func _show_toast(msg: String, col: Color) -> void:
	toast_label.text = msg
	toast_label.modulate = col
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.45)
