class_name StarterTown
extends Node2D

@onready var player: TownPlayer = $TownPlayer
@onready var buildings_root: Node2D = $Buildings
@onready var npcs_root: Node2D = $NPCs
@onready var hud_day_label: Label = %DayLabel
@onready var hud_money_label: Label = %MoneyLabel
@onready var hud_stam_label: Label = %StamLabel
@onready var hud_quest_hint: Label = %QuestHintLabel
@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel
@onready var dialogue_box: StoryDialogueBox = $TownHUD/Root/StoryDialogueBox
@onready var pc_modal: PCHubModal = $TownHUD/Root/PCHubModal
@onready var negotiation_modal: NegotiationModal = $TownHUD/Root/NegotiationModal
@onready var season_end_modal: SeasonEndModal = $TownHUD/Root/SeasonEndModal
@onready var crisis_modal: CrisisEventModal = $TownHUD/Root/CrisisEventModal
@onready var sleep_overlay: SleepTransitionOverlay = $TownHUD/Root/SleepTransitionOverlay
@onready var square_label: Label = $SquareLabel

@onready var bus_modal: PanelContainer = %BusModal
@onready var bus_training_btn: Button = %BusTrainingBtn
@onready var bus_stadium_btn: Button = %BusStadiumBtn
@onready var bus_cancel_btn: Button = %BusCancelBtn

var _spawned_npcs: Array[TownNPC] = []
var _zone_markers: Dictionary = {}
var _door_spawn_points: Dictionary = {}
var _active_target_type: StringName = &""
var _active_zone_id: StringName = &""
var _active_npc: TownNPC = null
var _toast_tween: Tween = null
var _pending_season_advance_after_neg: bool = false
var _world_modulate: CanvasModulate = null
var _base_archetype_tint: Color = Color.WHITE

const MATCH_SCENE_PATH: String = "res://scenes/match/match_prototype.tscn"
const LOCKER_ROOM_PATH: String = "res://scenes/world/locker_room.tscn"
const TRAINING_GROUND_PATH: String = "res://scenes/world/training_ground.tscn"
const INTERIOR_SCENE_PATH: String = "res://scenes/world/building_interior.tscn"

func _ready() -> void:
	Engine.time_scale = 1.0
	_apply_world_archetype_atmosphere()
	_build_town_buildings_and_doors()
	_spawn_street_npcs()
	_place_player_at_spawn()

	dialogue_box.finished.connect(_on_dialogue_finished)
	pc_modal.closed.connect(_on_modal_closed)
	pc_modal.quest_packet_triggered.connect(_on_pc_quest_triggered)
	negotiation_modal.closed.connect(_on_negotiation_closed)
	season_end_modal.negotiate_requested.connect(_on_season_end_negotiate)
	season_end_modal.next_season_requested.connect(_on_season_end_continue)
	crisis_modal.finished.connect(_on_crisis_finished)
	sleep_overlay.sleep_finished.connect(_on_sleep_finished)

	bus_modal.visible = false
	bus_training_btn.pressed.connect(_on_bus_to_training)
	bus_stadium_btn.pressed.connect(_on_bus_to_stadium)
	bus_cancel_btn.pressed.connect(_on_bus_cancel)

	GameState.day_advanced.connect(_on_day_advanced)
	GameState.time_changed.connect(_on_time_changed)
	GameState.passed_out_at_night.connect(_on_passed_out_at_night)
	GameState.player_resources_changed.connect(_refresh_hud)
	GameState.status_effects_changed.connect(_refresh_hud)
	QuestDirector.active_triggers_changed.connect(_refresh_zone_badges)
	QuestDirector.scheduled_event_delivered.connect(_on_scheduled_event_delivered)

	_refresh_hud()
	_refresh_zone_badges()

	if GameState.pending_romance_transfer_drama:
		player.controls_locked = true
		crisis_modal.open_romance_transfer_drama()
	elif GameState.season_completed_pending:
		player.controls_locked = true
		season_end_modal.open_season_end()
	elif not GameState.pending_crisis_tag.is_empty():
		var c_tag: String = GameState.pending_crisis_tag
		GameState.pending_crisis_tag = ""
		player.controls_locked = true
		crisis_modal.open_crisis(c_tag)
	elif not GameState.last_match_summary.is_empty():
		_show_toast(GameState.last_match_summary, Color(0.45, 1.0, 0.65, 1.0))
		GameState.last_match_summary = ""

func _apply_world_archetype_atmosphere() -> void:
	var arch: Dictionary = GameState.get_current_world_archetype()
	square_label.text = str(arch.get("square_label", "KASABA MEYDANI"))
	var tint_arr: Variant = arch.get("tint", [1.0, 1.0, 1.0, 1.0])
	_base_archetype_tint = Color.WHITE
	if tint_arr is Array and (tint_arr as Array).size() >= 4:
		var a: Array = tint_arr as Array
		_base_archetype_tint = Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	_world_modulate = CanvasModulate.new()
	add_child(_world_modulate)
	_sync_daylight_color()

	var weather: String = str(arch.get("weather", "clear"))
	if weather == "rain" or weather == "sun_dust" or weather == "confetti":
		var particles := CPUParticles2D.new()
		particles.position = Vector2(0.0, -320.0)
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(520.0, 20.0)
		particles.z_index = 25
		if weather == "rain":
			particles.amount = 140
			particles.lifetime = 2.6
			particles.direction = Vector2(-0.25, 1.0)
			particles.spread = 4.0
			particles.initial_velocity_min = 190.0
			particles.initial_velocity_max = 260.0
			particles.gravity = Vector2(0.0, 0.0)
			particles.scale_amount_min = 1.2
			particles.scale_amount_max = 1.8
			particles.color = Color(0.68, 0.84, 1.0, 0.45)
		elif weather == "confetti":
			particles.amount = 65
			particles.lifetime = 5.0
			particles.direction = Vector2(0.1, 1.0)
			particles.spread = 35.0
			particles.initial_velocity_min = 35.0
			particles.initial_velocity_max = 75.0
			particles.gravity = Vector2(0.0, 18.0)
			particles.scale_amount_min = 1.8
			particles.scale_amount_max = 2.6
			particles.color = Color(1.0, 0.88, 0.25, 0.72)
		else:
			particles.amount = 55
			particles.lifetime = 5.5
			particles.direction = Vector2(0.2, 1.0)
			particles.spread = 25.0
			particles.initial_velocity_min = 18.0
			particles.initial_velocity_max = 38.0
			particles.gravity = Vector2(0.0, 4.0)
			particles.scale_amount_min = 1.2
			particles.scale_amount_max = 2.0
			particles.color = Color(1.0, 0.94, 0.65, 0.35)
		add_child(particles)

func _sync_daylight_color() -> void:
	if _world_modulate != null:
		_world_modulate.color = _base_archetype_tint * GameState.get_daylight_tint()

func _on_day_advanced(_td: int, _w: int, _d: int) -> void:
	_refresh_hud()
	_sync_daylight_color()

func _on_time_changed(_m: int) -> void:
	_refresh_hud()
	_sync_daylight_color()

func _on_passed_out_at_night() -> void:
	if not is_inside_tree():
		return
	player.controls_locked = true
	sleep_overlay.trigger_sleep(true)

func _on_sleep_finished(summary_msg: String) -> void:
	player.controls_locked = false
	GameState.current_interior_id = &"home"
	GameState.last_match_summary = summary_msg
	get_tree().change_scene_to_file(INTERIOR_SCENE_PATH)

func _on_crisis_finished(summary_text: String) -> void:
	player.controls_locked = false
	_refresh_hud()
	if not summary_text.is_empty():
		_show_toast(summary_text, Color(1.0, 0.85, 0.45, 1.0))

func _build_town_buildings_and_doors() -> void:
	# Her bina: Aseprite-hazır dış cephe PNG + gerçek StaticBody2D duvar çarpışması + YALNIZCA yola bakan ön kapı!
	# Üst Sıra (Kapılar güneyde, yola bakar: door_offset = Vector2(0, +46))
	_place_building(&"home", "SENIN EVIN", "res://assets/sprites/buildings/home_ext.png", Vector2(-368.0, -196.0), Vector2(106.0, 74.0), Vector2(0.0, 46.0), "[E] Eve Gir (Yatak & PC)")
	_place_building(&"clubhouse", "KULUP EVI\n(MAVI LOKAL)", "res://assets/sprites/buildings/clubhouse_ext.png", Vector2(-80.0, -196.0), Vector2(122.0, 74.0), Vector2(0.0, 46.0), "[E] Kulup Evi'ne Gir")
	_place_building(&"press_center", "GAZETECILIK\nMERKEZI", "res://assets/sprites/buildings/press_ext.png", Vector2(160.0, -196.0), Vector2(106.0, 74.0), Vector2(0.0, 46.0), "[E] Basin Merkezi'ne Gir")

	# Alt Sıra (Kapılar kuzeyde, yola bakar: door_offset = Vector2(0, -46))
	_place_building(&"gol_cafe", "GOL KAFE", "res://assets/sprites/buildings/gol_cafe_ext.png", Vector2(-368.0, 190.0), Vector2(106.0, 74.0), Vector2(0.0, -46.0), "[E] Gol Kafe'ye Gir")
	_place_building(&"nightclub", "NEON GECE\nKULUBU", "res://assets/sprites/buildings/nightclub_ext.png", Vector2(-80.0, 190.0), Vector2(122.0, 74.0), Vector2(0.0, -46.0), "[E] Neon Gece Kulubu'ne Gir")
	_place_building(&"sport_shop", "KRAMPON &\nSPOR MAGAZASI", "res://assets/sprites/buildings/sport_shop_ext.png", Vector2(160.0, 190.0), Vector2(106.0, 74.0), Vector2(0.0, -46.0), "[E] Spor Magazasi'na Gir")
	_place_building(&"corner_cafe", "KOSE KAHVE\n(CAY & 21)", "res://assets/sprites/buildings/corner_cafe_ext.png", Vector2(352.0, 190.0), Vector2(106.0, 74.0), Vector2(0.0, -46.0), "[E] Kose Kahve'ye Gir")

	# Otobüs Durağı + Aseprite-hazır Otobüs Sprite'ı
	var bus_body := StaticBody2D.new()
	bus_body.position = Vector2(396.0, -78.0)
	var bus_spr := Sprite2D.new()
	bus_spr.texture = load("res://assets/sprites/props/bus_vehicle.png") as Texture2D
	bus_body.add_child(bus_spr)
	var bus_col := CollisionShape2D.new()
	var bus_sh := RectangleShape2D.new()
	bus_sh.size = Vector2(58.0, 24.0)
	bus_col.shape = bus_sh
	bus_body.add_child(bus_col)
	buildings_root.add_child(bus_body)

	var bus_lbl := Label.new()
	bus_lbl.text = "OTOBUS DURAGI\n(STADYUM & IDMAN)"
	bus_lbl.position = Vector2(342.0, -114.0)
	bus_lbl.size = Vector2(110.0, 24.0)
	bus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bus_lbl.add_theme_font_size_override("font_size", 5)
	bus_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
	buildings_root.add_child(bus_lbl)

	# Otobüs Durağı ve Kafe Arka Sokağı dış etkileşim noktaları
	_register_zone(&"bus_stop", Vector2(364.0, -48.0), 28.0, "[E] Otobus Duragi (Stadyum / Antrenman Tesisleri)")
	_door_spawn_points[&"bus_stop"] = Vector2(356.0, -34.0)
	_register_zone(&"cafe_back_alley", Vector2(-446.0, 196.0), 26.0, "[E] Kafe Arka Sokagi")

func _place_building(
	bid: StringName,
	title: String,
	tex_path: String,
	center_pos: Vector2,
	col_size: Vector2,
	door_offset: Vector2,
	prompt_text: String
) -> void:
	var body := StaticBody2D.new()
	body.name = "Bldg_" + String(bid)
	body.position = center_pos

	var spr := Sprite2D.new()
	spr.texture = load(tex_path) as Texture2D
	body.add_child(spr)

	var col := CollisionShape2D.new()
	var rect_sh := RectangleShape2D.new()
	rect_sh.size = col_size
	col.shape = rect_sh
	body.add_child(col)

	var sign_lbl := Label.new()
	sign_lbl.text = title
	sign_lbl.position = Vector2(-56.0, -30.0)
	sign_lbl.size = Vector2(112.0, 24.0)
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 5)
	sign_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85, 1.0))
	sign_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 1.0))
	sign_lbl.add_theme_constant_override("outline_size", 2)
	body.add_child(sign_lbl)

	buildings_root.add_child(body)

	# Yola bakan tek kapı giriş noktası (sadece buradan içeri girilebilir!)
	var door_pos: Vector2 = center_pos + door_offset
	var door_cue := ColorRect.new()
	door_cue.position = door_pos - Vector2(9.0, 4.0)
	door_cue.size = Vector2(18.0, 8.0)
	door_cue.color = Color(0.95, 0.84, 0.42, 0.45)
	door_cue.z_index = -3
	buildings_root.add_child(door_cue)

	_register_zone(bid, door_pos, 22.0, prompt_text)
	_door_spawn_points[bid] = door_pos + (Vector2(0.0, 12.0) if door_offset.y > 0.0 else Vector2(0.0, -12.0))

func _place_player_at_spawn() -> void:
	var sp: StringName = GameState.pending_town_spawn
	if _door_spawn_points.has(sp):
		player.global_position = _door_spawn_points[sp] as Vector2
	else:
		player.global_position = _door_spawn_points.get(&"home", Vector2(-368.0, -138.0)) as Vector2
	GameState.pending_town_spawn = &"home"
	player.reset_physics_interpolation()

func _register_zone(zone_id: StringName, pos: Vector2, radius: float, label_text: String) -> void:
	var badge := Label.new()
	badge.text = "[!]"
	badge.position = pos + Vector2(-14.0, -24.0)
	badge.size = Vector2(28.0, 14.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	badge.visible = false
	add_child(badge)

	_zone_markers[zone_id] = {
		"pos": pos,
		"radius": radius,
		"label": label_text,
		"badge": badge
	}

func _spawn_street_npcs() -> void:
	# Dışarıda kasaba sokaklarında dolaşan takım arkadaşları (diğer NPC'ler kendi binalarının içinde!)
	var placements: Dictionary = {
		&"mate_striker": Vector2(32.0, -12.0),  # Kasaba Meydanı
		&"mate_mid": Vector2(292.0, -28.0)      # Otobüs durağı civarı
	}
	for npc_prof in UniverseDB.npcs:
		if not placements.has(npc_prof.id):
			continue
		var actor := TownNPC.new()
		npcs_root.add_child(actor)
		actor.setup(npc_prof, placements[npc_prof.id] as Vector2)
		_spawned_npcs.append(actor)

func _process(delta: float) -> void:
	GameState.tick_clock(delta, player.controls_locked)
	if player.controls_locked:
		prompt_label.visible = false
		return
	_scan_nearest_interaction()

func _scan_nearest_interaction() -> void:
	_active_target_type = &""
	_active_zone_id = &""
	_active_npc = null
	var best_dist: float = 9999.0

	for npc_node in _spawned_npcs:
		var d: float = player.global_position.distance_to(npc_node.global_position)
		if d <= 26.0 and d < best_dist:
			best_dist = d
			_active_target_type = &"npc"
			_active_npc = npc_node

	for zid in _zone_markers.keys():
		var zd: Dictionary = _zone_markers[zid]
		var d: float = player.global_position.distance_to(zd["pos"] as Vector2)
		if d <= float(zd["radius"]) and d < best_dist:
			best_dist = d
			_active_target_type = &"zone"
			_active_zone_id = zid as StringName
			_active_npc = null

	if _active_target_type == &"npc" and _active_npc != null:
		prompt_label.visible = true
		prompt_label.text = "[E] Konus: %s" % _active_npc.npc_profile.full_name
	elif _active_target_type == &"zone":
		prompt_label.visible = true
		var zd: Dictionary = _zone_markers[_active_zone_id]
		var extra: String = ""
		if _zone_has_quest_trigger(_active_zone_id):
			extra = "  [!] HIKAYE!"
		elif _active_zone_id == &"bus_stop" and (QuestDirector.has_available_trigger_at("training_ground_exit") or QuestDirector.has_available_trigger_at("locker_room_pre_match")):
			extra = "  [!] DURAKTA OLAY VAR!"
		prompt_label.text = str(zd["label"]) + extra
	else:
		prompt_label.visible = false

func _zone_has_quest_trigger(zid: StringName) -> bool:
	match zid:
		&"home": return QuestDirector.has_available_trigger_at("home_pc_messages")
		&"gol_cafe": return QuestDirector.has_available_trigger_at("cafe_interior")
		&"nightclub": return QuestDirector.has_available_trigger_at("nightclub_interior")
		_: return QuestDirector.has_available_trigger_at(String(zid))

func _unhandled_input(event: InputEvent) -> void:
	if player.controls_locked:
		return
	if event.is_action_pressed("interact"):
		if _active_target_type == &"npc" and _active_npc != null:
			player.controls_locked = true
			dialogue_box.open_daily_chat(_active_npc.npc_profile)
		elif _active_target_type == &"zone":
			_interact_with_zone(_active_zone_id)

func _interact_with_zone(zone_id: StringName) -> void:
	# Dış mekan özel noktaları
	if zone_id == &"bus_stop":
		_open_bus_modal()
		return

	if zone_id == &"cafe_back_alley":
		var quest_pkt: Dictionary = QuestDirector.check_location_trigger("cafe_back_alley", false)
		if not quest_pkt.is_empty():
			player.controls_locked = true
			dialogue_box.open_quest_packet(quest_pkt)
			return
		_show_toast("Arka sokak sessiz ve los... Su an kimse yok.", Color(0.75, 0.82, 0.9, 1.0))
		return

	# Ev kapısı her zaman açık (yatak + PC)
	if zone_id == &"home":
		SoundFX.play_door()
		GameState.current_interior_id = &"home"
		get_tree().change_scene_to_file(INTERIOR_SCENE_PATH)
		return

	# Diğer binalar: Eğer içeride bekleyen bir hikaye varsa soft-lock olmaması için her zaman girilebilir!
	var has_story: bool = _zone_has_quest_trigger(zone_id)

	# KULLANICI KURALI: Antrenman gününde (Pzt/Sal/Per) antrenmanı YAPMADAN önce yalnızca Antrenman Tesisleri'ne gidilir!
	# Antrenmanı tamamlayıp döndüğünde (trained_today == true) akşam mekanlara girebilirsin!
	if not has_story:
		if GameState.is_training_day() and not GameState.trained_today:
			_show_toast("Bugun antrenman gunu! Once otobusle Antrenman Tesisleri'ne gidip idmani bitirmelisin.", Color(1.0, 0.78, 0.32, 1.0))
			return
		if GameState.is_match_day():
			_show_toast("Bugun MAC GUNU! Otobus Duragi'ndan Stadyuma gitmelisin!", Color(1.0, 0.82, 0.32, 1.0))
			return

	# Binanın kapısından gerçek yürünebilir iç mekan sahnesine geç!
	SoundFX.play_door()
	GameState.current_interior_id = zone_id
	get_tree().change_scene_to_file(INTERIOR_SCENE_PATH)

func _open_bus_modal() -> void:
	player.controls_locked = true
	var tr_badge: String = " [!]" if QuestDirector.has_available_trigger_at("training_ground_exit") else ""
	var st_badge: String = " [!]" if (QuestDirector.has_available_trigger_at("locker_room_pre_match") or GameState.is_match_day()) else ""

	if GameState.is_training_day():
		bus_training_btn.disabled = false
		bus_training_btn.text = ("Antrenman Tesisleri (Idman Tamamlandi — Poligon Acik)%s" if GameState.trained_today else "Kulup Antrenman Tesisleri (Bugun Idman Gunu!)%s") % tr_badge
		bus_stadium_btn.disabled = true
		bus_stadium_btn.text = "Kasaba Stadyumu (Yalnizca Pazar — Mac Gunu)"
	elif GameState.is_match_day():
		bus_training_btn.disabled = true
		bus_training_btn.text = "Antrenman Tesisleri (Bugun Mac Gunu!)"
		bus_stadium_btn.disabled = false
		bus_stadium_btn.text = "Kasaba Stadyumu (Rakip: %s)%s" % [GameState.next_opponent_name, st_badge]
	else:
		bus_training_btn.disabled = false
		bus_training_btn.text = "Antrenman Tesisleri (Bireysel Sut Poligonu)%s" % tr_badge
		var has_locker_quest: bool = QuestDirector.has_available_trigger_at("locker_room_pre_match")
		bus_stadium_btn.disabled = not has_locker_quest
		bus_stadium_btn.text = "Kasaba Stadyumu (Hikaye Olayi!) [!]" if has_locker_quest else "Kasaba Stadyumu (Yalnizca Pazar — Mac Gunu)"

	bus_modal.visible = true

func _on_bus_to_training() -> void:
	bus_modal.visible = false
	get_tree().change_scene_to_file(TRAINING_GROUND_PATH)

func _on_bus_to_stadium() -> void:
	bus_modal.visible = false
	get_tree().change_scene_to_file(LOCKER_ROOM_PATH)

func _on_bus_cancel() -> void:
	bus_modal.visible = false
	player.controls_locked = false

func _on_pc_quest_triggered(pkt: Dictionary) -> void:
	dialogue_box.open_quest_packet(pkt)

func _on_dialogue_finished(transition_to_match: bool) -> void:
	player.controls_locked = false
	_refresh_hud()
	_refresh_zone_badges()
	if transition_to_match:
		get_tree().change_scene_to_file(MATCH_SCENE_PATH)

func _on_modal_closed() -> void:
	player.controls_locked = false
	_refresh_hud()
	_refresh_zone_badges()

func _on_season_end_negotiate() -> void:
	_pending_season_advance_after_neg = true
	negotiation_modal.open_negotiation()

func _on_season_end_continue() -> void:
	GameState.advance_to_next_season()
	player.controls_locked = false
	_refresh_hud()
	_refresh_zone_badges()
	_show_toast("SEZON %d BASLADI! Ilk rakip: %s" % [GameState.season, GameState.next_opponent_name], Color(0.45, 1.0, 0.65, 1.0))

func _on_negotiation_closed(did_transfer: bool) -> void:
	player.controls_locked = false
	if _pending_season_advance_after_neg:
		_pending_season_advance_after_neg = false
		GameState.advance_to_next_season()
		if did_transfer:
			GameState.last_match_summary = "SEZON %d — FLAS TRANSFER: %s (%s)!" % [GameState.season, GameState.current_club_name, GameState.current_country_code]
			get_tree().reload_current_scene()
			return
		_refresh_hud()
		_refresh_zone_badges()
		_show_toast("SEZON %d BASLADI! (%s — Ilk rakip: %s)" % [GameState.season, GameState.current_club_name, GameState.next_opponent_name], Color(0.45, 1.0, 0.65, 1.0))
		return

	if did_transfer:
		GameState.last_match_summary = "FLAS TRANSFER! Yeni Kulup: %s (%s) — Tum kadro & lig yenilendi!" % [GameState.current_club_name, GameState.current_country_code]
		get_tree().reload_current_scene()
		return
	_refresh_hud()
	_refresh_zone_badges()

func _on_scheduled_event_delivered(_channel: String, title: String) -> void:
	_show_toast("[PC BILDIRIM] %s" % title, Color(1.0, 0.9, 0.35, 1.0))

func _refresh_hud() -> void:
	hud_day_label.text = "[%s] %s | %s (%s)" % [GameState.get_time_string(), GameState.get_day_label(), GameState.current_club_name, GameState.current_country_code]
	hud_money_label.text = "%d TL" % GameState.cash
	var hangover_tag: String = " [HANGOVER!]" if (GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")) else ""
	hud_stam_label.text = "STAM: %%%d%s" % [roundi(GameState.current_stamina), hangover_tag]
	hud_stam_label.modulate = Color(1.0, 0.38, 0.32, 1.0) if (not hangover_tag.is_empty() or GameState.current_stamina < 40.0) else Color(0.4, 0.98, 0.52, 1.0)

	var q_hint: String = QuestDirector.get_active_quest_hint()
	if q_hint.is_empty():
		if GameState.is_match_day():
			q_hint = "BUGUN MAC GUNU! Otobus Duragi'ndan Stadyuma git (Rakip: %s)!" % GameState.next_opponent_name
		elif GameState.is_training_day():
			q_hint = "ANTRENMAN GUNU! Once Otobus Duragi'ndan Antrenman Tesisleri'ne git!" if not GameState.trained_today else "Antrenman bitti! Aksam kasaba mekanlarina girebilir veya eve donup uyuyabilirsin."
		elif QuestDirector.has_available_trigger_at("cafe_interior"):
			q_hint = "[!] Serbest Gun — Gol Kafe'nin kapısından iceri gir, yeni olay seni bekliyor!"
		else:
			q_hint = "Serbest Gun! Binalarin on kapilarindan iceri gir, Kose Kahve'de 21 oyna!"
	hud_quest_hint.text = q_hint

func _refresh_zone_badges() -> void:
	for zid in _zone_markers.keys():
		var zd: Dictionary = _zone_markers[zid]
		var badge: Label = zd["badge"] as Label
		if zid == &"bus_stop":
			var bus_event: bool = (
				QuestDirector.has_available_trigger_at("training_ground_exit")
				or QuestDirector.has_available_trigger_at("locker_room_pre_match")
				or GameState.is_match_day()
				or (GameState.is_training_day() and not GameState.trained_today)
			)
			badge.text = "[BUS!]" if bus_event else ""
			badge.visible = bus_event
		else:
			var has_q: bool = _zone_has_quest_trigger(zid as StringName)
			badge.text = "[!]"
			badge.visible = has_q
	_refresh_hud()

func _show_toast(msg: String, col: Color) -> void:
	toast_label.text = msg
	toast_label.modulate = col
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
