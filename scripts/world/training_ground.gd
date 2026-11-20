class_name TrainingGround
extends Node2D

@onready var player: TownPlayer = $TownPlayer
@onready var npcs_root: Node2D = $NPCs
@onready var info_label: Label = %TrainingInfoLabel
@onready var prompt_label: Label = %TrainingPromptLabel
@onready var toast_label: Label = %TrainingToastLabel
@onready var dialogue_box: StoryDialogueBox = $TrainingHUD/Root/StoryDialogueBox
@onready var sleep_overlay: SleepTransitionOverlay = $TrainingHUD/Root/SleepTransitionOverlay

var _spawned_npcs: Array[TownNPC] = []
var _active_target_type: StringName = &""
var _active_npc: TownNPC = null
var _toast_tween: Tween = null
var _daylight_mod: CanvasModulate = null

const BUS_RETURN_POS: Vector2 = Vector2(-175.0, 10.0)
const PITCH_DRILL_POS: Vector2 = Vector2(72.0, -8.0)
const MINI_GOAL_POS: Vector2 = Vector2(182.0, 0.0)
const TOWN_SCENE_PATH: String = "res://scenes/world/starter_town.tscn"
const TRAINING_DECK_PATH: String = "res://scenes/minigames/training_deck_scene.tscn"

func _ready() -> void:
	Engine.time_scale = 1.0
	_daylight_mod = CanvasModulate.new()
	add_child(_daylight_mod)
	_daylight_mod.color = GameState.get_daylight_tint()
	_spawn_training_squad()
	dialogue_box.finished.connect(_on_dialogue_finished)
	sleep_overlay.sleep_finished.connect(_on_sleep_finished)
	GameState.time_changed.connect(_on_time_changed)
	GameState.passed_out_at_night.connect(_on_passed_out_at_night)
	_refresh_header()

	# Eğer Antrenman Tesisleri çıkışında tetiklenecek bir hikaye (örn. Aldatan Eş Perde 2!) varsa aç!
	var pkt: Dictionary = QuestDirector.check_location_trigger("training_ground_exit", false)
	if not pkt.is_empty():
		player.controls_locked = true
		dialogue_box.open_quest_packet(pkt)

func _spawn_training_squad() -> void:
	var spots: Dictionary = {
		&"coach_main": Vector2(18.0, -56.0),
		&"capt_main": Vector2(118.0, -58.0),
		&"mate_nightlife": Vector2(-58.0, -48.0),
		&"mate_striker": Vector2(138.0, 42.0),
		&"mate_mid": Vector2(20.0, 52.0)
	}
	for npc_prof in UniverseDB.npcs:
		if not spots.has(npc_prof.id):
			continue
		var actor := TownNPC.new()
		npcs_root.add_child(actor)
		actor.setup(npc_prof, spots[npc_prof.id] as Vector2)
		_spawned_npcs.append(actor)

func _refresh_header() -> void:
	info_label.text = "[%s] %s ANTRENMAN  |  %s  |  STAM: %%%d" % [
		GameState.get_time_string(), GameState.current_club_name, GameState.get_day_label(), roundi(GameState.current_stamina)
	]

func _on_time_changed(_m: int) -> void:
	_refresh_header()
	if _daylight_mod != null:
		_daylight_mod.color = GameState.get_daylight_tint()

func _on_passed_out_at_night() -> void:
	if not is_inside_tree():
		return
	player.controls_locked = true
	sleep_overlay.trigger_sleep(true)

func _on_sleep_finished(summary_msg: String) -> void:
	player.controls_locked = false
	GameState.current_interior_id = &"home"
	GameState.last_match_summary = summary_msg
	get_tree().change_scene_to_file("res://scenes/world/building_interior.tscn")

func _process(delta: float) -> void:
	GameState.tick_clock(delta, player.controls_locked)
	if player.controls_locked:
		prompt_label.visible = false
		return

	_active_target_type = &""
	_active_npc = null

	if player.global_position.distance_to(BUS_RETURN_POS) <= 32.0:
		_active_target_type = &"bus_return"
		prompt_label.visible = true
		prompt_label.text = "[E] Kasaba Otobusune Bin (Merkeze Don)"
		return

	if player.global_position.distance_to(MINI_GOAL_POS) <= 34.0:
		_active_target_type = &"shoot_deck"
		prompt_label.visible = true
		prompt_label.text = "[E] Bugunun Ozel Sut Destesi Yapildi" if GameState.extra_shoot_done_today else "[E] Ozel Serbest Vurus & Bitiricilik Destesi (2 Kart)"
		return

	if player.global_position.distance_to(PITCH_DRILL_POS) <= 34.0:
		_active_target_type = &"team_deck"
		prompt_label.visible = true
		if not GameState.is_training_day():
			prompt_label.text = "[E] Takim Idman Destesi (Yalnizca Pzt / Sal / Per)"
		else:
			prompt_label.text = "[E] Bugunun Takim Idmanini Tamamladin" if GameState.trained_today else "[E] Takim Antrenman Destesini Baslat (3 Kart)"
		return

	var best_d: float = 30.0
	for n in _spawned_npcs:
		var d: float = player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			_active_target_type = &"npc"
			_active_npc = n

	if _active_target_type == &"npc" and _active_npc != null:
		prompt_label.visible = true
		prompt_label.text = "[E] Konus: %s" % _active_npc.npc_profile.full_name
	else:
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player.controls_locked:
		return
	if event.is_action_pressed("interact"):
		if _active_target_type == &"bus_return":
			GameState.pending_town_spawn = &"bus_stop"
			get_tree().change_scene_to_file(TOWN_SCENE_PATH)
		elif _active_target_type == &"team_deck":
			_start_team_training_deck()
		elif _active_target_type == &"shoot_deck":
			_start_shooting_deck()
		elif _active_target_type == &"npc" and _active_npc != null:
			player.controls_locked = true
			dialogue_box.open_daily_chat(_active_npc.npc_profile)

func _start_team_training_deck() -> void:
	if not GameState.is_training_day():
		_show_toast("Bugun serbest gun! Resmi takim idmani Pzt/Sal/Per gunleri. Sagdaki kalede ozel sut destesi cekebilirsin!", Color(0.95, 0.85, 0.45, 1.0))
		return
	if GameState.trained_today:
		_show_toast("Bugun takim idmanini yaptin! Istersen sagdaki kalede ozel serbest vurus destesi cek.", Color(0.95, 0.85, 0.45, 1.0))
		return
	if GameState.current_stamina < 15.0:
		_show_toast("Cok yorgunsun! Kasabaya donup dinlenmen gerekiyor.", Color(1.0, 0.45, 0.38, 1.0))
		return
	GameState.training_deck_mode = &"team"
	get_tree().change_scene_to_file(TRAINING_DECK_PATH)

func _start_shooting_deck() -> void:
	if GameState.extra_shoot_done_today:
		_show_toast("Bugun ozel serbest vurus & bitiricilik destesini tamamladin!", Color(0.95, 0.85, 0.45, 1.0))
		return
	if GameState.current_stamina < 12.0:
		_show_toast("Ozel sut destesi icin en az %12 Stamina gerekli.", Color(1.0, 0.45, 0.38, 1.0))
		return
	GameState.training_deck_mode = &"shooting"
	get_tree().change_scene_to_file(TRAINING_DECK_PATH)

func _on_dialogue_finished(_to_match: bool) -> void:
	player.controls_locked = false
	_refresh_header()

func _show_toast(msg: String, col: Color) -> void:
	toast_label.text = msg
	toast_label.modulate = col
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.45)
