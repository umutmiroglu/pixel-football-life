class_name MatchDirector
extends Node2D

signal match_state_changed(new_state: MatchState)
signal commentary_logged(minute_str: String, text: String, highlight_color: Color)
signal score_changed(home_goals: int, away_goals: int)

enum MatchState {
	SIMULATION,   # Katman 1: FM 2D Maç Merkezi (Veri + Taktik Radar + Canlı Spiker)
	PLAYER_TURN,  # Katman 2: Özenle Kurgulanmış Taktik Senaryo (Dur-Seç-Vur + Vücutla Saklama + Çalım)
	RESOLVE,      # Senaryo Sonucu İzleme (1.4s -> FM Simülasyonuna Dönüş)
	FULL_TIME     # 90. Dakika Maç Sonu Raporu
}

@export var aim_time_scale: float = 0.14
@export var active_play_time_scale: float = 0.85
@export var time_transition_rate: float = 14.0

@onready var pitch_world: Node2D = $PitchWorld
@onready var footballers_root: Node2D = $PitchWorld/Footballers
@onready var player: MatchPlayer = $PitchWorld/Footballers/Player
@onready var ball: SoccerBall = $PitchWorld/Ball
@onready var camera: MatchCamera = $MatchCamera
@onready var hud: MatchHUD = $MatchHUD
@onready var fm_overlay: FMSimOverlay = $MatchHUD/RootControl/FMSimOverlay
@onready var social_panel: SocialPanel = $MatchHUD/RootControl/SocialPanel
@onready var evaluator: MatchEvaluator = $MatchEvaluator
@onready var home_goal_area: Area2D = $PitchWorld/HomeGoalArea
@onready var away_goal_area: Area2D = $PitchWorld/AwayGoalArea

var current_state: MatchState = MatchState.SIMULATION
var sim_speed_multiplier: float = 1.0
var match_minute: int = 0
var _sim_minute_accum: float = 0.0
var _sim_cooldown_minutes: int = 0

var home_goals: int = 0
var away_goals: int = 0
var home_shots: int = 0
var away_shots: int = 0
var home_possession: int = 52
var _opp_marking_level: int = 64
var _start_stamina_level: int = 100

var user_stats: FootballerStats = null
var active_mates: Array[AIFootballer] = []
var active_opponents: Array[AIFootballer] = []
var active_roster: Array[CharacterBody2D] = []

var _target_time_scale: float = 1.0
var _in_hit_stop: bool = false
var _hit_stop_id: int = 0
var _resolve_timer: float = 0.0
var _loose_ball_far_timer: float = 0.0
var _entry_read_timer: float = 0.0
var _home_club_name: String = "Kasaba Spor"
var _away_club_name: String = "Anadolu FK"

var _scenario_goal_scored: bool = false
var _is_clutch_scenario: bool = false
var _last_scenario_title: String = ""
var _social_paused: bool = false

const SIM_EVENTS_NEUTRAL: PackedStringArray = [
	"Orta sahada dengeli mucadele suruyor.",
	"{home} geriden sabirli paslarla cikiyor.",
	"{away} orta blokta pas kanallarini kapatiyor.",
	"Kanattan yapilan orta savunmadan sekip uzaklasti.",
	"Iki takim da oyunu kanatlara acmaya calisiyor.",
	"On libero sert bir mudahaleyle atagi kesti."
]

func _ready() -> void:
	_home_club_name = GameState.current_club_name
	_away_club_name = GameState.next_opponent_name
	user_stats = GameState.player_stats if GameState.player_stats != null else FootballerStats.create_preset(76, 80, 78, 80, 74, 78, 82, 52, 50, 68)
	_start_stamina_level = roundi(GameState.current_stamina)
	evaluator.manager_trust = GameState.manager_trust
	_wire_signals()
	_start_new_match()

func _wire_signals() -> void:
	ball.owner_changed.connect(_on_ball_owner_changed)
	ball.post_hit.connect(_on_ball_post_hit)
	ball.out_of_bounds.connect(_on_ball_out_of_bounds)
	ball.pass_completed.connect(_on_ball_pass_completed)
	ball.pass_intercepted.connect(_on_ball_pass_intercepted)

	player.aim_mode_changed.connect(_on_player_aim_mode_changed)
	player.shot_metrics_changed.connect(hud.on_shot_metrics_changed)
	player.stamina_changed.connect(_on_player_stamina_changed)
	player.action_executed.connect(_on_player_action_executed)
	player.feint_executed.connect(_on_player_feint_executed)
	player.pass_called.connect(_on_player_pass_called)

	home_goal_area.body_entered.connect(_on_goal_entered.bind(1))
	away_goal_area.body_entered.connect(_on_goal_entered.bind(0))

	evaluator.ratings_updated.connect(_on_ratings_updated)
	evaluator.coach_feedback_emitted.connect(_on_coach_feedback)

	commentary_logged.connect(hud.on_commentary_logged)
	score_changed.connect(hud.on_score_changed)

	hud.debug_stat_changed.connect(_on_debug_stat_changed)
	hud.debug_style_cycle_requested.connect(_on_debug_style_cycle)
	hud.debug_position_cycle_requested.connect(_on_debug_position_cycle)
	hud.debug_appearance_randomize_requested.connect(_on_debug_appearance_randomize)

	fm_overlay.speed_selected.connect(_set_sim_speed)
	fm_overlay.restart_match_requested.connect(_return_to_starter_town)
	fm_overlay.trigger_now_requested.connect(_force_trigger_scenario)
	fm_overlay.social_panel_requested.connect(_on_open_social_panel)
	social_panel.closed.connect(_on_close_social_panel)

	UniverseDB.relationships_changed.connect(_sync_universe_to_match)

func _start_new_match() -> void:
	match_minute = 1
	_sim_minute_accum = 0.0
	_sim_cooldown_minutes = 3
	home_goals = 0
	away_goals = 0
	home_shots = 0
	away_shots = 0
	home_possession = 52
	_scenario_goal_scored = false

	_clear_scenario_actors()
	evaluator.reset_match()
	evaluator.manager_trust = GameState.manager_trust
	user_stats.team_trust = UniverseDB.get_average_team_pitch_trust()
	# Eğer yan görev (Aldatan Eş ihanet sonu gibi) pas modifiyeri bıraktıysa team_trust'a yansıt!
	if GameState.pending_match_modifiers.has("teammate_pass_bias_override"):
		user_stats.team_trust = mini(user_stats.team_trust, 20)
	var effective_start_stam: int = mini(_start_stamina_level, 62) if (GameState.has_status(&"HangoverActive") or GameState.has_status(&"Hangover")) else _start_stamina_level
	player.set_match_stamina(float(effective_start_stam), 100.0)
	fm_overlay.clear_feed()
	score_changed.emit(home_goals, away_goals)
	hud.sync_debug_values(user_stats.positioning, user_stats.team_trust, _opp_marking_level, effective_start_stam, evaluator.get_style_name(), user_stats.get_position_code())
	_enter_state(MatchState.SIMULATION)
	_push_feed("Baslama dudugu caldi! 11v11 mac basladi.", "#9be0ff")
	_sync_fm_header()

func _process(delta: float) -> void:
	# 1. Zaman Ölçeği Yumuşak Geçişi
	if not _in_hit_stop:
		var real_dt: float = delta / maxf(Engine.time_scale, 0.0001)
		var t: float = 1.0 - exp(-time_transition_rate * real_dt)
		Engine.time_scale = lerpf(Engine.time_scale, _target_time_scale, t)

	# 2. Durum Makinesi Akışı
	match current_state:
		MatchState.SIMULATION:
			_tick_fm_simulation(delta)
		MatchState.PLAYER_TURN:
			_tick_scenario_turn(delta)
		MatchState.RESOLVE:
			_resolve_timer -= delta
			if _resolve_timer <= 0.0:
				_return_to_fm_simulation()

func _tick_fm_simulation(delta: float) -> void:
	if _social_paused:
		return
	# Simülasyon ekranı daima gerçek zamanlı (Engine.time_scale = 1.0), hızı sim_speed_multiplier ile artar
	var seconds_per_match_min: float = 0.72 / sim_speed_multiplier
	_sim_minute_accum += delta
	if _sim_minute_accum < seconds_per_match_min:
		return
	_sim_minute_accum -= seconds_per_match_min

	match_minute += 1
	player.drain_sim_stamina(0.65)
	if match_minute >= 90:
		match_minute = 90
		_finish_match()
		return

	# Topla oynama yüzdesini hafifçe dalgalandır
	home_possession = clampi(home_possession + randi_range(-2, 2), 38, 66)
	_sync_fm_header()

	if _sim_cooldown_minutes > 0:
		_sim_cooldown_minutes -= 1

	# 1. Bizim Karakterimize Kritik Pozisyon Gelme İhtimali (İstatistiklere Bağlı!)
	if _sim_cooldown_minutes <= 0:
		var pos_factor: float = float(user_stats.positioning) / 100.0
		var trust_factor: float = float(user_stats.team_trust) / 100.0
		var mark_penalty: float = float(_opp_marking_level) / 100.0
		# Özellik yüksekse dakika başına ~%18, düşükse ~%5 kritik pozisyon şansı
		var chance: float = clampf(0.05 + pos_factor * 0.08 + trust_factor * 0.07 - mark_penalty * 0.04, 0.04, 0.22)
		if randf() < chance:
			_launch_interactive_scenario()
			return

	# 2. Arka Plan 11v11 Maç Olayları (Rakip/Takım Şutları, Goller, Spiker)
	var event_roll: float = randf()
	if event_roll < 0.032:
		away_shots += 1
		if randf() < 0.26:
			away_goals += 1
			score_changed.emit(home_goals, away_goals)
			_push_feed("GOL! %s kontra atakta aglari sarsti! (%d - %d)" % [_away_club_name, home_goals, away_goals], "#ff6659")
		else:
			_push_feed("%s kaleyi yokladi, kalecimiz gole izin vermedi!" % _away_club_name, "#ffb86c")
		_sync_fm_header()
	elif event_roll < 0.062:
		home_shots += 1
		if randf() < 0.22:
			home_goals += 1
			score_changed.emit(home_goals, away_goals)
			_push_feed("GOOOL! %s harika bir organizasyonla aglari sarsti! (%d - %d)" % [_home_club_name, home_goals, away_goals], "#5cff7a")
		else:
			_push_feed("%s tehlikeli bir sut cikardi, top az farkla aut!" % _home_club_name, "#8be9fd")
		_sync_fm_header()
	elif event_roll < 0.28:
		var msg: String = SIM_EVENTS_NEUTRAL[randi() % SIM_EVENTS_NEUTRAL.size()]
		msg = msg.replace("{home}", _home_club_name).replace("{away}", _away_club_name)
		_push_feed(msg, "#cbd6e2")

func _tick_scenario_turn(delta: float) -> void:
	if _scenario_goal_scored:
		return

	# Senaryo başlangıcında "Sahayı Oku" (Bullet-Time Entry): İlk 0.85 sn veya ilk tuşa basana kadar ağır çekim!
	if _entry_read_timer > 0.0:
		var real_dt: float = delta / maxf(Engine.time_scale, 0.0001)
		_entry_read_timer = maxf(_entry_read_timer - real_dt, 0.0)
		var move_in: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move_in != Vector2.ZERO:
			_entry_read_timer = 0.0
		if _entry_read_timer > 0.0:
			_target_time_scale = aim_time_scale
		else:
			_target_time_scale = aim_time_scale if player.is_aim_mode else active_play_time_scale

	# 1. Top rakibin net kontrolüne geçtiyse -> RESOLVE -> FM Simülasyonu
	if _get_ball_holder_team() == 1:
		_log_commentary("Rakip topu kontrol etti! Pozisyon sona erdi.", Color(1.0, 0.5, 0.42, 1.0))
		_enter_state(MatchState.RESOLVE, 1.15)
		return

	# 2. Top sahipsiz şekilde tüm oyuncularımızdan çok uzaklaştıysa (> 240 px ve yavaşsa) -> Simülasyona dön!
	if ball.holder == null:
		var min_team_dist: float = _min_home_distance_to_ball()
		if min_team_dist > 235.0 or (min_team_dist > 140.0 and ball.velocity.length() < 28.0):
			_loose_ball_far_timer += delta
			if _loose_ball_far_timer >= 0.9:
				_log_commentary("Top sahipsiz alana uzaklasti, mac akisina donuluyor.", Color(0.82, 0.88, 0.95, 1.0))
				_enter_state(MatchState.RESOLVE, 0.85)
		else:
			_loose_ball_far_timer = 0.0
	else:
		_loose_ball_far_timer = 0.0

func _min_home_distance_to_ball() -> float:
	var best: float = player.global_position.distance_to(ball.global_position)
	for mate in active_mates:
		if is_instance_valid(mate):
			best = minf(best, mate.global_position.distance_to(ball.global_position))
	return best

func _force_trigger_scenario() -> void:
	if current_state == MatchState.SIMULATION:
		_launch_interactive_scenario()

func _launch_interactive_scenario() -> void:
	var data: ScenarioGenerator.ScenarioData = ScenarioGenerator.generate_scenario(user_stats, _opp_marking_level)
	_last_scenario_title = data.title
	_scenario_goal_scored = false
	_sim_cooldown_minutes = randi_range(5, 9)

	_clear_scenario_actors()

	# Senaryodaki seçilmiş oyuncuları (sıfır kalabalık, saf taktik!) yerleştir
	for spawn in data.actors:
		var ai := AIFootballer.new()
		ai.name = "Scen_%d_%s_%d" % [spawn.team_id, spawn.label, spawn.number]
		footballers_root.add_child(ai)
		var ai_stats: FootballerStats = _make_scenario_stats(spawn.team_id, spawn.role)
		ai.configure_scenario_actor(spawn, ai_stats, ball, player)
		if spawn.team_id == 0:
			active_mates.append(ai)
			ai.pass_sent.connect(_on_ai_pass_sent)
			ai.shot_fired.connect(_on_ai_shot_fired)
		else:
			active_opponents.append(ai)
			ai.tackle_attempted.connect(_on_opponent_tackle_attempted)
		active_roster.append(ai)

	active_roster.append(player)
	player.setup_match_context(ball, data.player_pos, user_stats, active_mates, active_opponents)
	player.reset_to_home()
	player.facing_dir = Vector2.RIGHT

	for ai in active_mates:
		ai.set_roster_reference(active_roster)
	for ai in active_opponents:
		ai.set_roster_reference(active_roster)

	ball.reset_to(data.ball_start_pos)
	if data.passer_index >= 0 and data.passer_index < active_mates.size():
		# Pası takım arkadaşımızdan gerçek zamanlı olarak ayağımıza gönder!
		var passer: AIFootballer = active_mates[data.passer_index]
		ball.global_position = passer.global_position + Vector2(10.0, 0.0)
		ball.pass_to(passer, 0, player.global_position, 0.0, &"ai_pass", 215.0, 290.0)
	else:
		ball.claim(player, 0, Vector2.RIGHT, false)

	camera.setup_targets(player, ball)
	_is_clutch_scenario = (match_minute >= 70 and absi(home_goals - away_goals) <= 1)
	var banner_title: String = ("KIRILMA ANI (%d') — %s" % [match_minute, data.title]) if _is_clutch_scenario else data.title
	var banner_col: Color = Color(1.0, 0.72, 0.22, 1.0) if _is_clutch_scenario else Color(1.0, 0.9, 0.25, 1.0)
	_push_feed("KRITIK POZISYON: %s" % banner_title, "#ffbe3b" if _is_clutch_scenario else "#ffe65c")
	_enter_state(MatchState.PLAYER_TURN, 1.4, data.turn_time_limit)
	camera.add_trauma(0.26 if _is_clutch_scenario else 0.18)
	hud.show_banner(banner_title, banner_col, 0.95 if _is_clutch_scenario else 0.75)
	_log_commentary(data.intro_commentary, Color(1.0, 0.92, 0.38, 1.0))

func _return_to_fm_simulation() -> void:
	_clear_scenario_actors()
	_enter_state(MatchState.SIMULATION)
	_sync_fm_header()

func _finish_match() -> void:
	SoundFX.play_whistle()
	GameState.advance_time_minutes(180)
	_clear_scenario_actors()
	var played_opponent: String = GameState.next_opponent_name
	var growth_notes: PackedStringArray = GameState.record_match_result(
		home_goals,
		away_goals,
		evaluator.match_rating,
		evaluator.manager_trust,
		evaluator.goals_scored,
		evaluator.assists_made,
		evaluator.key_passes,
		evaluator.dribbles_won,
		player.current_stamina
	)
	_enter_state(MatchState.FULL_TIME)
	var growth_line: String = ("\nStat Gelisimi: " + ", ".join(growth_notes)) if not growth_notes.is_empty() else ""
	var summary: String = (
		"MAC SONUCU: %s %d - %d %s\n\n"
		+ "Mac Puanin (Mackolik): %.1f / 10.0\n"
		+ "Hoca Uyumu (%s): %%%d\n\n"
		+ "Gol: %d  |  Asist: %d  |  Isabetli Pas: %d\n"
		+ "Kilit/Ara Pasi: %d  |  Basarili Calim: %d  |  Top Kaybi: %d%s"
	) % [
		GameState.current_club_name, home_goals, away_goals, played_opponent,
		evaluator.match_rating,
		evaluator.get_style_name(), roundi(evaluator.manager_trust),
		evaluator.goals_scored, evaluator.assists_made, evaluator.passes_completed,
		evaluator.key_passes, evaluator.dribbles_won, evaluator.turnovers, growth_line
	]
	fm_overlay.show_full_time(summary)

func _return_to_starter_town() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/world/starter_town.tscn")

func _clear_scenario_actors() -> void:
	for ai in active_mates:
		if is_instance_valid(ai):
			ai.queue_free()
	for ai in active_opponents:
		if is_instance_valid(ai):
			ai.queue_free()
	active_mates.clear()
	active_opponents.clear()
	active_roster.clear()

func _make_scenario_stats(team_id: int, role: TacticsHelper.Role) -> FootballerStats:
	if role == TacticsHelper.Role.GK:
		return FootballerStats.create_preset(74, 45, 65, 65, 78, 45, 45, 72, 76, 30)
	if team_id == 0:
		return FootballerStats.create_preset(74, 70, 74, 76, 76, 76, 70, 58, 56, 65)
	# Rakip savunmacılar debug panelindeki _opp_marking_level değerini kullanır
	return FootballerStats.create_preset(66, 56, 64, 62, 62, 55, 50, _opp_marking_level, _opp_marking_level, 50)

func _enter_state(new_state: MatchState, custom_resolve_time: float = 1.4, custom_turn_time: float = 9.0) -> void:
	current_state = new_state
	match current_state:
		MatchState.SIMULATION:
			pitch_world.visible = false
			pitch_world.process_mode = Node.PROCESS_MODE_DISABLED
			fm_overlay.visible = true
			player.set_manual_control(false)
			_target_time_scale = 1.0
			Engine.time_scale = 1.0
			hud.set_action_hud_visible(false)

		MatchState.PLAYER_TURN:
			fm_overlay.visible = false
			pitch_world.visible = true
			pitch_world.process_mode = Node.PROCESS_MODE_INHERIT
			_loose_ball_far_timer = 0.0
			_entry_read_timer = 0.85
			player.set_manual_control(true)
			_target_time_scale = aim_time_scale
			Engine.time_scale = aim_time_scale
			camera.set_camera_mode(MatchCamera.CameraMode.PLAYER_FOLLOW)
			hud.set_action_hud_visible(true)
			hud.on_match_state_changed("SIRA SENDE", true, player.has_ball())

		MatchState.RESOLVE:
			player.set_manual_control(false)
			_target_time_scale = 1.0
			_resolve_timer = custom_resolve_time
			camera.set_camera_mode(MatchCamera.CameraMode.RESOLVE_BALL)
			hud.on_match_state_changed("POZISYON SONUCU", false, false)

		MatchState.FULL_TIME:
			pitch_world.visible = false
			pitch_world.process_mode = Node.PROCESS_MODE_DISABLED
			fm_overlay.visible = true
			player.set_manual_control(false)
			_target_time_scale = 1.0
			Engine.time_scale = 1.0
			hud.set_action_hud_visible(false)

	match_state_changed.emit(current_state)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		hud.toggle_debug_panel()
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.is_echo():
			if ke.physical_keycode == KEY_1:
				_set_sim_speed(1.0)
			elif ke.physical_keycode == KEY_2:
				_set_sim_speed(2.0)
			elif ke.physical_keycode == KEY_3:
				_set_sim_speed(4.0)
			elif ke.physical_keycode == KEY_R and current_state != MatchState.SIMULATION:
				_return_to_fm_simulation()

func _set_sim_speed(mult: float) -> void:
	sim_speed_multiplier = mult
	_sync_fm_header()

func _sync_fm_header() -> void:
	fm_overlay.update_header(match_minute, sim_speed_multiplier, home_goals, away_goals, home_possession, home_shots, away_shots, _home_club_name, _away_club_name)
	hud.on_clock_updated(match_minute, sim_speed_multiplier)

func _on_ball_owner_changed(new_owner: Node2D, _prev_owner: Node2D) -> void:
	if current_state != MatchState.PLAYER_TURN:
		return
	if new_owner == player:
		hud.on_match_state_changed("SIRA SENDE", true, true)
	else:
		hud.on_match_state_changed("VER-KAC SEKANSI", true, false)

func _on_player_aim_mode_changed(is_aiming: bool) -> void:
	if current_state != MatchState.PLAYER_TURN:
		return
	if is_aiming or _entry_read_timer > 0.0:
		_target_time_scale = aim_time_scale
		camera.set_camera_mode(MatchCamera.CameraMode.PLAYER_AIM)
	else:
		_target_time_scale = active_play_time_scale
		camera.set_camera_mode(MatchCamera.CameraMode.PLAYER_FOLLOW)

func _on_player_action_executed(
	kind: StringName,
	_direction: Vector2,
	power_ratio: float,
	spin_ratio: float,
	target_mate: Node2D
) -> void:
	if kind == &"shot" or kind == &"shot_lob":
		_entry_read_timer = 0.0
		home_shots += 1
		var dist_to_goal: float = player.global_position.distance_to(Vector2(TacticsHelper.PITCH_HALF_W, 0.0))
		evaluator.record_shot(dist_to_goal, absf(spin_ratio), player.has_open_teammate())
		var trauma_amt: float = lerpf(0.45, 0.85, power_ratio)
		var freeze_dur: float = lerpf(0.055, 0.11, power_ratio)
		SoundFX.play_kick()
		camera.add_trauma(trauma_amt)
		_trigger_hit_stop(freeze_dur, 0.025)
		var shot_msg: String = "Klas bir asirtma denemesi! Kalecinin ustunden suzuluyor!" if kind == &"shot_lob" else "Sert bir vurus cikti! Top kaleye gidiyor!"
		_log_commentary(shot_msg, Color(1.0, 0.72, 0.3, 1.0))
		_enter_state(MatchState.RESOLVE, 1.65)
	else:
		SoundFX.play_kick()
		_entry_read_timer = 0.0
		camera.add_trauma(0.20)
		_trigger_hit_stop(0.03, 0.08)
		camera.set_camera_mode(MatchCamera.CameraMode.PLAYER_FOLLOW)
		_target_time_scale = active_play_time_scale
		var mate_num: String = str((target_mate as AIFootballer).shirt_number) if target_mate is AIFootballer else "arkadasina"
		var p_label: String = "Havadan orta" if kind == &"pass_lob" else ("Kavisli ara pasi" if kind == &"pass_through" else "Temiz pas")
		_log_commentary("%s #%s yonune gonderildi — ceza sahasina kos!" % [p_label, mate_num], Color(0.55, 0.9, 1.0, 1.0))

func _on_player_feint_executed(beat_defender: bool, is_perfect_timing: bool, _defender: AIFootballer) -> void:
	if beat_defender:
		evaluator.record_dribble_burst_success()
		if is_perfect_timing:
			camera.add_trauma(0.36)
			camera.punch_zoom(0.10)
			_trigger_hit_stop(0.052, 0.05)
			hud.show_banner("MUKEMMEL CALIM!", Color(0.28, 1.0, 0.95, 1.0), 0.65)
			_log_commentary("Zamanlama kusursuz! Savunmacinin bileklerini kirdi!", Color(0.32, 1.0, 0.82, 1.0))
			_push_feed("Mukemmel calimla rakibini oyundan dusurdun!", "#56f0ff")
		else:
			camera.add_trauma(0.24)
			_trigger_hit_stop(0.032, 0.07)
			hud.show_banner("CALIM!", Color(0.45, 0.95, 1.0, 1.0), 0.5)
			_log_commentary("Bilek hareketiyle rakibinden siyrildi!", Color(0.45, 0.98, 0.85, 1.0))
	else:
		camera.add_trauma(0.10)

func _on_player_pass_called() -> void:
	_log_commentary("Elini kaldirdi, pas istiyor!", Color(0.8, 0.92, 1.0, 1.0))

func _on_ball_pass_completed(passer: Node2D, receiver: Node2D, kick_kind: StringName, dist: float, is_forward: bool) -> void:
	if passer == player and receiver != player:
		evaluator.record_pass_completed(kick_kind == &"pass_through", dist, is_forward)
		var msg: String = "Inanilmaz ara pasi adrese teslim!" if kick_kind == &"pass_through" else "Isabetli pas!"
		_log_commentary(msg, Color(0.45, 1.0, 0.55, 1.0))

func _on_ball_pass_intercepted(passer: Node2D, _interceptor: Node2D) -> void:
	if passer == player:
		evaluator.record_turnover(true)
		camera.add_trauma(0.32)
		_log_commentary("Rakip savunma pas arasina girdi!", Color(1.0, 0.42, 0.35, 1.0))
		_push_feed("Pasin savunma tarafindan kesildi.", "#ff6b6b")
		if current_state == MatchState.PLAYER_TURN:
			_enter_state(MatchState.RESOLVE, 1.1)

func _on_opponent_tackle_attempted(_defender: AIFootballer, target: Node2D, succeeded: bool) -> void:
	if target == player and succeeded:
		evaluator.record_turnover(false)
		camera.add_trauma(0.45)
		_trigger_hit_stop(0.05, 0.04)
		hud.show_banner("TOP KAYBI", Color(1.0, 0.35, 0.3, 1.0), 0.65)
		_log_commentary("Sert mudahale! Savunma topu ayagindan soktu.", Color(1.0, 0.4, 0.35, 1.0))
		_push_feed("Ikili mucadelede topu kaybettin.", "#ff6b6b")
		if current_state == MatchState.PLAYER_TURN:
			_enter_state(MatchState.RESOLVE, 1.15)

func _on_ai_pass_sent(_passer: AIFootballer, _target: Node2D, _team_id: int) -> void:
	pass

func _on_ai_shot_fired(shooter: AIFootballer, team_id: int) -> void:
	if team_id == 0:
		home_shots += 1
		_log_commentary("Takim arkadasin #%d kaleye sert vurdu!" % shooter.shirt_number, Color(1.0, 0.82, 0.38, 1.0))
		# Şut çekilince sadece kamera topu izler, gol/aut/rakip kontrolüne göre sonuçlanır!
		camera.set_camera_mode(MatchCamera.CameraMode.RESOLVE_BALL)

func _on_ball_post_hit(impact_speed: float) -> void:
	if impact_speed > 120.0:
		SoundFX.play_post()
		camera.add_trauma(clampf(impact_speed / 450.0, 0.25, 0.6))
		_log_commentary("DIREKTEN DONDU!", Color(1.0, 0.82, 0.25, 1.0))
		_push_feed("Inanilmaz an! Sutun direkten dondu!", "#ffda57")

func _on_ball_out_of_bounds(kind: StringName, _exit_pos: Vector2, _last_team: int) -> void:
	if current_state == MatchState.SIMULATION or current_state == MatchState.FULL_TIME or _scenario_goal_scored:
		return
	var msg: String = "Top disari cikti! (%s)" % String(kind).to_upper()
	_log_commentary(msg, Color(0.85, 0.9, 0.96, 1.0))
	_push_feed("Pozisyon aut/tac ile sonuclandi.", "#cbd6e2")
	_enter_state(MatchState.RESOLVE, 0.95)

func _on_goal_entered(body: Node2D, scoring_team: int) -> void:
	if body != ball or _scenario_goal_scored or current_state == MatchState.SIMULATION:
		return
	_scenario_goal_scored = true

	if scoring_team == 0:
		SoundFX.play_goal()
		home_goals += 1
		var by_user: bool = (ball.last_touch_node == player)
		var assisted_by_user: bool = (not by_user and ball.last_passer_node == player)
		if by_user:
			evaluator.record_goal(true)
			_log_commentary("GOOOOL! 10 Numaradan muhtesem bir bitiris!", Color(0.3, 1.0, 0.45, 1.0))
			_push_feed("GOOOOL! Harika bir vurusla aglari sarstin! (%d - %d)" % [home_goals, away_goals], "#4dff79")
		elif assisted_by_user:
			evaluator.record_assist()
			_log_commentary("GOOOOL! Harika asistinle takim arkadasin bitirdi!", Color(0.3, 1.0, 0.65, 1.0))
			_push_feed("GOOOOL! Altin degerinde asistinle gol geldi! (%d - %d)" % [home_goals, away_goals], "#4dffb8")
		else:
			evaluator.record_goal(false)
			_log_commentary("GOOOOL! Mavi takim gol buldu!", Color(0.35, 0.95, 0.55, 1.0))
		if _is_clutch_scenario and (by_user or assisted_by_user):
			GameState.add_career_xp(35)
			hud.show_banner("KIRILMA ANI GOLU! (+35 XP)", Color(1.0, 0.9, 0.25, 1.0), 1.45)
		else:
			hud.show_banner("GOOOOL!", Color(0.3, 1.0, 0.45, 1.0), 1.35)
	else:
		away_goals += 1
		hud.show_banner("RAKIP GOLU", Color(1.0, 0.32, 0.3, 1.0), 1.25)

	score_changed.emit(home_goals, away_goals)
	camera.add_trauma(0.92)
	_trigger_hit_stop(0.135, 0.03)
	_enter_state(MatchState.RESOLVE, 1.75)

func _on_player_stamina_changed(cur: float, max_val: float) -> void:
	hud.on_stamina_changed(cur, max_val)
	fm_overlay.update_stamina(cur, max_val)

func _on_ratings_updated(match_rating: float, manager_trust: float, style_name: String) -> void:
	hud.on_ratings_updated(match_rating, manager_trust, style_name)
	fm_overlay.update_ratings(match_rating, manager_trust, style_name)

func _on_coach_feedback(message: String, is_positive: bool) -> void:
	var col: Color = Color(0.45, 1.0, 0.65, 1.0) if is_positive else Color(1.0, 0.42, 0.35, 1.0)
	_log_commentary(message, col)
	_push_feed(message, "#66ff99" if is_positive else "#ff7666")

func _on_debug_stat_changed(stat_key: StringName, new_value: int) -> void:
	match stat_key:
		&"positioning":
			user_stats.positioning = new_value
		&"team_trust":
			user_stats.team_trust = new_value
		&"opp_marking":
			_opp_marking_level = new_value
			for opp in active_opponents:
				if is_instance_valid(opp):
					opp.stats.marking = new_value
					opp.stats.tackling = new_value
		&"start_stamina":
			_start_stamina_level = new_value
			player.set_match_stamina(float(new_value), 100.0)

func _on_debug_style_cycle() -> void:
	var next_idx: int = (int(evaluator.current_style) + 1) % 3
	evaluator.set_manager_style(next_idx as MatchEvaluator.ManagerStyle)

func _on_debug_position_cycle() -> void:
	var next_p: int = (int(user_stats.position) + 1) % 3
	user_stats.position = next_p as FootballerStats.Position
	hud.sync_debug_values(user_stats.positioning, user_stats.team_trust, _opp_marking_level, _start_stamina_level, evaluator.get_style_name(), user_stats.get_position_code())
	_push_feed("Mevki degisti: %s (Senaryolar buna gore secilecek!)" % user_stats.get_position_code(), "#ffe65c")

func _on_debug_appearance_randomize() -> void:
	player.randomize_appearance()
	_log_commentary("Yeni 5 katmanli karakter gorunumu uygulandi!", Color(0.55, 0.95, 1.0, 1.0))

func _on_open_social_panel() -> void:
	_social_paused = true
	social_panel.open_panel()

func _on_close_social_panel() -> void:
	_social_paused = false
	_sync_universe_to_match()

func _sync_universe_to_match() -> void:
	if user_stats == null:
		return
	var avg_trust: int = UniverseDB.get_average_team_pitch_trust()
	user_stats.team_trust = avg_trust
	hud.sync_debug_values(user_stats.positioning, user_stats.team_trust, _opp_marking_level, roundi(player.current_stamina), evaluator.get_style_name(), user_stats.get_position_code())

func _trigger_hit_stop(duration: float, slow_scale: float) -> void:
	_hit_stop_id += 1
	var my_id: int = _hit_stop_id
	_in_hit_stop = true
	Engine.time_scale = slow_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if not is_inside_tree():
		return
	if my_id == _hit_stop_id:
		_in_hit_stop = false
		Engine.time_scale = _target_time_scale

func _get_ball_holder_team() -> int:
	if ball.holder == null:
		return -1
	if ball.holder == player:
		return 0
	if ball.holder is AIFootballer:
		return (ball.holder as AIFootballer).team_id
	return -1

func _log_commentary(text: String, color: Color) -> void:
	commentary_logged.emit("%02d'" % match_minute, text, color)

func _push_feed(text: String, hex_color: String) -> void:
	fm_overlay.append_feed("%02d'" % match_minute, text, hex_color)
