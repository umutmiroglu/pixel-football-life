class_name LockerRoom
extends Node2D

@onready var player: TownPlayer = $TownPlayer
@onready var npcs_root: Node2D = $NPCs
@onready var info_label: Label = %LockerInfoLabel
@onready var prompt_label: Label = %LockerPromptLabel
@onready var dialogue_box: StoryDialogueBox = $LockerHUD/Root/StoryDialogueBox

var _spawned_npcs: Array[TownNPC] = []
var _active_target_type: StringName = &""
var _active_npc: TownNPC = null

const TUNNEL_POS: Vector2 = Vector2(118.0, 0.0)
const EXIT_TOWN_POS: Vector2 = Vector2(-118.0, 0.0)
const MATCH_SCENE_PATH: String = "res://scenes/match/match_prototype.tscn"
const TOWN_SCENE_PATH: String = "res://scenes/world/starter_town.tscn"

func _ready() -> void:
	Engine.time_scale = 1.0
	_spawn_squad_npcs()
	dialogue_box.finished.connect(_on_dialogue_finished)

	info_label.text = "%s SOYUNMA ODASI  |  Rakip: %s  |  Takim Guveni: %d" % [
		GameState.current_club_name, GameState.next_opponent_name, UniverseDB.get_average_team_pitch_trust()
	]

	# Maç öncesi soyunma odası hikaye finali (örn. Aldatan Eş Act 7!) varsa otomatik aç!
	var pre_match_pkt: Dictionary = QuestDirector.check_location_trigger("locker_room_pre_match", false)
	if not pre_match_pkt.is_empty():
		player.controls_locked = true
		dialogue_box.open_quest_packet(pre_match_pkt)

func _spawn_squad_npcs() -> void:
	var seats: Dictionary = {
		&"coach_main": Vector2(0.0, -56.0),
		&"capt_main": Vector2(-62.0, -48.0),
		&"mate_nightlife": Vector2(60.0, -48.0),
		&"mate_striker": Vector2(-55.0, 48.0),
		&"mate_mid": Vector2(55.0, 48.0)
	}
	for npc_prof in UniverseDB.npcs:
		if not seats.has(npc_prof.id):
			continue
		var actor := TownNPC.new()
		npcs_root.add_child(actor)
		actor.setup(npc_prof, seats[npc_prof.id] as Vector2)
		_spawned_npcs.append(actor)

func _process(_delta: float) -> void:
	if player.controls_locked:
		prompt_label.visible = false
		return

	_active_target_type = &""
	_active_npc = null

	if player.global_position.distance_to(TUNNEL_POS) <= 30.0:
		_active_target_type = &"tunnel"
		prompt_label.visible = true
		prompt_label.text = "[E] TUNELDEN SAHAYA CIK (MACI BASLAT!)"
		return

	if player.global_position.distance_to(EXIT_TOWN_POS) <= 30.0:
		_active_target_type = &"exit_town"
		prompt_label.visible = true
		prompt_label.text = "[E] Kasabaya Geri Don"
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
		prompt_label.text = "[E] Mac Oncesi Konus: %s" % _active_npc.npc_profile.full_name
	else:
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player.controls_locked:
		return
	if event.is_action_pressed("interact"):
		if _active_target_type == &"tunnel":
			get_tree().change_scene_to_file(MATCH_SCENE_PATH)
		elif _active_target_type == &"exit_town":
			GameState.pending_town_spawn = &"bus_stop"
			get_tree().change_scene_to_file(TOWN_SCENE_PATH)
		elif _active_target_type == &"npc" and _active_npc != null:
			player.controls_locked = true
			dialogue_box.open_daily_chat(_active_npc.npc_profile)

func _on_dialogue_finished(transition_to_match: bool) -> void:
	player.controls_locked = false
	info_label.text = "%s SOYUNMA ODASI  |  Rakip: %s  |  Takim Guveni: %d" % [
		GameState.current_club_name, GameState.next_opponent_name, UniverseDB.get_average_team_pitch_trust()
	]
	if transition_to_match:
		get_tree().change_scene_to_file(MATCH_SCENE_PATH)
