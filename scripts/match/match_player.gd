class_name MatchPlayer
extends CharacterBody2D

signal aim_mode_changed(is_aiming: bool)
signal shot_metrics_changed(power_ratio: float, spin_ratio: float, is_charging: bool, is_lob: bool)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal action_executed(kind: StringName, direction: Vector2, power_ratio: float, spin_ratio: float, target_mate: Node2D)
signal feint_executed(beat_defender: bool, is_perfect_timing: bool, defender: AIFootballer)
signal pass_called()

@export var stats: FootballerStats = FootballerStats.new()
@export var acceleration: float = 980.0
@export var friction: float = 1150.0
@export var pickup_radius: float = 15.0
@export var charge_rate: float = 1.25
@export var curve_adjust_rate: float = 1.7

@onready var aim_line: Line2D = $AimLine
@onready var pass_preview_line: Line2D = $PassPreviewLine
@onready var facing_indicator: Polygon2D = $FacingIndicator
@onready var turn_ring: Line2D = $TurnRing
@onready var number_label: Label = $NumberLabel
@onready var char_visual: ProceduralCharacter = $ProceduralCharacter

var appearance: CharacterAppearance = null

var home_position: Vector2 = Vector2(-20.0, 0.0)
var ball: SoccerBall = null
var teammates: Array[AIFootballer] = []
var opponents: Array[AIFootballer] = []

var is_manual_control: bool = false
var facing_dir: Vector2 = Vector2.RIGHT
var is_aim_mode: bool = false
var is_charging_shot: bool = false
var is_lob_mode: bool = false
var shot_power_ratio: float = 0.0
var shot_spin_ratio: float = 0.0

# GDD 1.2 Stamina Ekonomisi (Görsel bulanıklık yok, saf hız/şut gücü/isabet cezası!)
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var _stamina_emit_accum: float = 0.0

var _selected_teammate: AIFootballer = null

var _feint_fake_timer: float = 0.0
var _feint_burst_timer: float = 0.0
var _feint_cooldown: float = 0.0
const FEINT_COOLDOWN_MAX: float = 1.15
var _feint_fake_dir: Vector2 = Vector2.RIGHT
var _feint_cut_dir: Vector2 = Vector2.RIGHT
var _feint_trail: Line2D = null
var _feint_ring_fx: Line2D = null
var _feint_cd_bar: Line2D = null

var _through_marker: Line2D = null
var _scale_tween: Tween = null

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 3
	add_to_group("player")
	add_to_group("footballers")
	add_to_group("team_0")
	aim_line.top_level = true
	aim_line.visible = false
	pass_preview_line.top_level = true
	pass_preview_line.visible = false
	turn_ring.visible = false

	if number_label != null:
		number_label.pivot_offset = number_label.size * 0.5
		number_label.rotation = MatchCamera.BEHIND_GOAL_ROTATION

	if appearance == null:
		appearance = CharacterAppearance.create_random(Color(0.14, 0.84, 0.98, 1.0), Color(0.95, 0.97, 1.0, 1.0), 1010)
	if char_visual != null:
		char_visual.apply_appearance(appearance)

	_feint_trail = Line2D.new()
	_feint_trail.top_level = true
	_feint_trail.width = 4.2
	_feint_trail.default_color = Color(0.55, 0.98, 1.0, 0.72)
	_feint_trail.visible = false
	add_child(_feint_trail)

	_feint_ring_fx = Line2D.new()
	_feint_ring_fx.top_level = true
	_feint_ring_fx.width = 1.8
	_feint_ring_fx.default_color = Color(0.4, 1.0, 0.85, 0.85)
	_feint_ring_fx.visible = false
	add_child(_feint_ring_fx)

	_feint_cd_bar = Line2D.new()
	_feint_cd_bar.width = 2.0
	_feint_cd_bar.default_color = Color(0.35, 0.95, 1.0, 0.85)
	add_child(_feint_cd_bar)

	_through_marker = Line2D.new()
	_through_marker.top_level = true
	_through_marker.width = 1.6
	_through_marker.default_color = Color(0.35, 1.0, 0.65, 0.82)
	_through_marker.visible = false
	add_child(_through_marker)

func setup_match_context(
	target_ball: SoccerBall,
	home_pos: Vector2,
	p_stats: FootballerStats,
	p_teammates: Array[AIFootballer],
	p_opponents: Array[AIFootballer]
) -> void:
	ball = target_ball
	home_position = home_pos
	stats = p_stats
	teammates = p_teammates
	opponents = p_opponents
	global_position = home_position
	_update_shirt_number_for_position()
	reset_physics_interpolation()
	if not ball.owner_changed.is_connected(_on_ball_owner_changed):
		ball.owner_changed.connect(_on_ball_owner_changed)

func randomize_appearance() -> void:
	appearance = CharacterAppearance.create_random(Color(0.14, 0.84, 0.98, 1.0), Color(0.95, 0.97, 1.0, 1.0))
	if char_visual != null:
		char_visual.apply_appearance(appearance)

func _update_shirt_number_for_position() -> void:
	if number_label == null or stats == null:
		return
	match stats.position:
		FootballerStats.Position.ST:
			number_label.text = "9"
		FootballerStats.Position.WING:
			number_label.text = "11"
		_:
			number_label.text = "10"

func set_match_stamina(start_val: float, max_val: float = 100.0) -> void:
	max_stamina = clampf(max_val, 30.0, 100.0)
	current_stamina = clampf(start_val, 5.0, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

func drain_sim_stamina(amount: float) -> void:
	var actual: float = amount * stats.get_stamina_drain_multiplier()
	current_stamina = maxf(current_stamina - actual, 8.0)
	stamina_changed.emit(current_stamina, max_stamina)

func get_fatigue_multiplier() -> float:
	# Stamina >= %40 iken tam performans; %40 altında hız, şut gücü ve isabet kademeli düşer!
	var ratio: float = current_stamina / 100.0
	if ratio >= 0.40:
		return 1.0
	return lerpf(0.68, 1.0, clampf(ratio / 0.40, 0.0, 1.0))

func get_fatigue_aim_jitter_rad() -> float:
	var ratio: float = current_stamina / 100.0
	if ratio >= 0.40:
		return 0.0
	return lerpf(0.14, 0.0, clampf(ratio / 0.40, 0.0, 1.0))

func set_manual_control(enabled: bool) -> void:
	is_manual_control = enabled
	turn_ring.visible = enabled
	_feint_cd_bar.visible = enabled
	if not enabled:
		_clear_teammate_highlight()
		_cancel_shot_and_aim()

func has_ball() -> bool:
	return ball != null and ball.holder == self

func is_in_opponent_penalty_box() -> bool:
	return global_position.x >= 355.0 and absf(global_position.y) <= 112.0

func reset_to_home() -> void:
	global_position = home_position
	velocity = Vector2.ZERO
	_feint_fake_timer = 0.0
	_feint_burst_timer = 0.0
	_feint_cooldown = 0.0
	is_lob_mode = false
	if _feint_trail != null:
		_feint_trail.visible = false
	if _feint_ring_fx != null:
		_feint_ring_fx.visible = false
	_cancel_shot_and_aim()
	_clear_teammate_highlight()
	reset_physics_interpolation()

func _get_world_move_input() -> Vector2:
	var screen_in: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if screen_in == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(-screen_in.y, screen_in.x)

func _unhandled_input(event: InputEvent) -> void:
	if not is_manual_control or not has_ball():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				shot_spin_ratio = clampf(shot_spin_ratio - 0.14, -1.0, 1.0)
				shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				shot_spin_ratio = clampf(shot_spin_ratio + 0.14, -1.0, 1.0)
				shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

func _process(delta: float) -> void:
	var real_dt: float = delta / maxf(Engine.time_scale, 0.0001)
	if _feint_fake_timer > 0.0:
		_feint_fake_timer = maxf(_feint_fake_timer - real_dt, 0.0)
		if _feint_fake_timer <= 0.0:
			_trigger_feint_phase_2_cut()

	if _feint_burst_timer > 0.0:
		_feint_burst_timer = maxf(_feint_burst_timer - real_dt, 0.0)
		var alpha: float = clampf(_feint_burst_timer / 0.26, 0.0, 1.0)
		if _feint_trail != null:
			_feint_trail.default_color.a = alpha * 0.72
			if _feint_burst_timer <= 0.0:
				_feint_trail.visible = false
		if _feint_ring_fx != null:
			_feint_ring_fx.default_color.a = alpha * 0.85
			if _feint_burst_timer <= 0.0:
				_feint_ring_fx.visible = false

	if _feint_cooldown > 0.0:
		_feint_cooldown = maxf(_feint_cooldown - real_dt, 0.0)

	_update_feint_cd_bar()

	if is_manual_control:
		var world_dir: Vector2 = _get_world_move_input()
		var is_feinting: bool = (_feint_fake_timer > 0.0 or _feint_burst_timer > 0.0)
		if has_ball():
			var wants_aim_slowmo: bool = (world_dir == Vector2.ZERO and not is_feinting) or is_charging_shot
			_set_aim_mode(wants_aim_slowmo)
			_handle_ball_carrier_controls(real_dt)
		else:
			if is_aim_mode or is_charging_shot:
				_cancel_shot_and_aim()
			_clear_teammate_highlight()
			pass_preview_line.visible = false
			if Input.is_action_just_pressed("call_for_pass"):
				_request_pass_from_teammates()
	else:
		if is_aim_mode or is_charging_shot:
			_cancel_shot_and_aim()

	_update_visual_facing()
	if char_visual != null:
		char_visual.update_locomotion(velocity, facing_dir, delta, MatchCamera.BEHIND_GOAL_ROTATION)

func _physics_process(delta: float) -> void:
	if ball == null:
		return

	if is_manual_control:
		_run_manual_movement(delta)

	_check_ball_pickup()

func _run_manual_movement(delta: float) -> void:
	var input_dir: Vector2 = _get_world_move_input()
	if is_charging_shot:
		input_dir = Vector2.ZERO

	if has_ball() and not is_charging_shot and Input.is_action_just_pressed("sprint_dribble") and _feint_cooldown <= 0.0 and current_stamina >= 8.0:
		_start_two_stage_feint(input_dir)

	var fatigue_mult: float = get_fatigue_multiplier()
	var jockey_factor: float = 1.0
	if has_ball() and _feint_burst_timer <= 0.0:
		var nearest_opp_dist: float = _distance_to_nearest_opponent()
		if nearest_opp_dist < 24.0:
			jockey_factor = lerpf(0.70, 1.0, clampf((nearest_opp_dist - 12.0) / 12.0, 0.0, 1.0))

	if _feint_fake_timer > 0.0:
		velocity = velocity.move_toward(_feint_fake_dir * 42.0, 1400.0 * delta)
		facing_dir = _feint_fake_dir
	elif _feint_burst_timer > 0.0:
		var burst_spd: float = stats.get_dribble_speed() * 1.65 * fatigue_mult
		velocity = velocity.move_toward(_feint_cut_dir * burst_spd, 2600.0 * delta)
		facing_dir = _feint_cut_dir
		if has_ball():
			ball.update_dribble_facing(_feint_cut_dir)
	elif input_dir != Vector2.ZERO:
		facing_dir = facing_dir.slerp(input_dir.normalized(), clampf(14.0 * delta, 0.0, 1.0)).normalized()
		if has_ball():
			ball.update_dribble_facing(facing_dir)
		var base_spd: float = (stats.get_dribble_speed() if has_ball() else stats.get_move_speed()) * jockey_factor * fatigue_mult
		var current_accel: float = acceleration * jockey_factor
		if velocity != Vector2.ZERO and input_dir.dot(velocity) < 0.0:
			current_accel = (acceleration + friction * 0.6) * jockey_factor
		velocity = velocity.move_toward(input_dir * base_spd, current_accel * delta)
		# Hareket halinde stamina tüketimi
		current_stamina = maxf(current_stamina - 4.8 * stats.get_stamina_drain_multiplier() * delta, 4.0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_stamina_emit_accum += delta
	if _stamina_emit_accum >= 0.08:
		_stamina_emit_accum = 0.0
		stamina_changed.emit(current_stamina, max_stamina)

	move_and_slide()

func _start_two_stage_feint(input_dir: Vector2) -> void:
	current_stamina = maxf(current_stamina - 6.5 * stats.get_stamina_drain_multiplier(), 4.0)
	stamina_changed.emit(current_stamina, max_stamina)

	var chosen_dir: Vector2 = input_dir.normalized() if input_dir.length_squared() > 0.05 else (get_global_mouse_position() - global_position).normalized()
	if chosen_dir.length_squared() < 0.01:
		chosen_dir = facing_dir

	var nearest_opp: AIFootballer = _find_nearest_opponent_within(56.0)
	if nearest_opp != null and velocity.length() > 16.0 and chosen_dir.dot(velocity.normalized()) > 0.82:
		var to_opp: Vector2 = (nearest_opp.global_position - global_position).normalized()
		var cross_z: float = velocity.normalized().cross(to_opp)
		var cut_angle: float = -0.90 if cross_z > 0.0 else 0.90
		chosen_dir = velocity.normalized().rotated(cut_angle)

	_feint_cut_dir = chosen_dir
	var fake_sign: float = -1.0 if facing_dir.cross(_feint_cut_dir) >= 0.0 else 1.0
	_feint_fake_dir = facing_dir.rotated(fake_sign * 1.1).normalized()
	_feint_fake_timer = 0.065
	_feint_cooldown = FEINT_COOLDOWN_MAX
	_play_squash_pop(Vector2(0.84, 1.20))

func _trigger_feint_phase_2_cut() -> void:
	if not has_ball():
		return
	_feint_burst_timer = 0.26
	var start_pos: Vector2 = global_position

	ball.trigger_feint_touch(_feint_cut_dir)
	velocity = _feint_cut_dir * (stats.get_dribble_speed() * 1.62 * get_fatigue_multiplier())
	_play_squash_pop(Vector2(1.34, 0.72))

	if _feint_trail != null:
		_feint_trail.points = PackedVector2Array([start_pos, start_pos + _feint_cut_dir * 28.0])
		_feint_trail.default_color.a = 0.72
		_feint_trail.visible = true

	if _feint_ring_fx != null:
		var ring_pts := PackedVector2Array()
		for i in 17:
			var ang: float = (float(i) / 16.0) * TAU
			ring_pts.append(start_pos + Vector2(cos(ang), sin(ang)) * 13.0)
		_feint_ring_fx.points = ring_pts
		_feint_ring_fx.default_color.a = 0.85
		_feint_ring_fx.visible = true

	var nearest_opp: AIFootballer = _find_nearest_opponent_within(54.0)
	var beat_opp: AIFootballer = null
	var is_perfect: bool = false

	if nearest_opp != null and nearest_opp.role != TacticsHelper.Role.GK:
		var to_opp: Vector2 = (nearest_opp.global_position - global_position).normalized()
		var cutting_away: bool = _feint_cut_dir.dot(to_opp) < 0.48
		var in_windup: bool = (nearest_opp.current_state == AIFootballer.AIState.TACKLE_WINDUP)
		var opp_committing: bool = in_windup or nearest_opp.velocity.length() > 28.0
		if cutting_away and opp_committing:
			var timing_bonus: float = 18.0 if in_windup else 6.0
			var skill_check: float = float(stats.dribbling) * get_fatigue_multiplier() + timing_bonus + randf_range(-6.0, 14.0)
			if skill_check >= float(nearest_opp.stats.tackling) * 0.78:
				nearest_opp.trigger_ankle_break(nearest_opp.velocity if nearest_opp.velocity.length() > 10.0 else -to_opp)
				beat_opp = nearest_opp
				is_perfect = in_windup or global_position.distance_to(nearest_opp.global_position) <= 34.0

	feint_executed.emit(beat_opp != null, is_perfect, beat_opp)

func _update_feint_cd_bar() -> void:
	if _feint_cd_bar == null or not is_manual_control:
		return
	var ready_ratio: float = 1.0 - clampf(_feint_cooldown / FEINT_COOLDOWN_MAX, 0.0, 1.0)
	var half_len: float = 7.0 * ready_ratio
	_feint_cd_bar.points = PackedVector2Array([Vector2(-11.0, -half_len), Vector2(-11.0, half_len)])
	_feint_cd_bar.default_color = Color(0.35, 1.0, 0.75, 0.9) if ready_ratio >= 0.99 else Color(0.75, 0.8, 0.85, 0.45)

func _check_ball_pickup() -> void:
	if ball == null or has_ball():
		return
	if ball.can_be_claimed_by(self, false):
		if global_position.distance_to(ball.global_position) <= pickup_radius:
			ball.claim(self, 0, facing_dir, false)
			shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

func _handle_ball_carrier_controls(real_dt: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var aim_dir: Vector2 = (mouse_pos - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = facing_dir

	if is_aim_mode or is_charging_shot:
		facing_dir = aim_dir
		ball.update_dribble_facing(aim_dir)

	_update_selected_teammate(aim_dir, mouse_pos)

	# Aşırtma / Havadan Vuruş Modu (F tuşu ile aç/kapa!)
	if Input.is_action_just_pressed("toggle_lob"):
		is_lob_mode = not is_lob_mode
		shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

	var curve_input: float = Input.get_axis("curve_left", "curve_right")
	if absf(curve_input) > 0.01:
		shot_spin_ratio = clampf(shot_spin_ratio + curve_input * curve_adjust_rate * real_dt, -1.0, 1.0)
		shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

	if Input.is_action_just_pressed("curve_reset"):
		shot_spin_ratio = 0.0
		shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

	if not is_charging_shot and Input.is_action_just_pressed("pass_direct") and _selected_teammate != null:
		_execute_smart_pass(_selected_teammate, false)
		return

	if not is_charging_shot and Input.is_action_just_pressed("pass_through") and _selected_teammate != null:
		_execute_smart_pass(_selected_teammate, true)
		return

	if Input.is_action_just_pressed("shoot"):
		is_charging_shot = true
		shot_power_ratio = 0.18
		shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

	if is_charging_shot and Input.is_action_pressed("shoot"):
		shot_power_ratio = clampf(shot_power_ratio + charge_rate * real_dt, 0.18, 1.0)
		shot_metrics_changed.emit(shot_power_ratio, shot_spin_ratio, is_charging_shot, is_lob_mode)

	if is_charging_shot and Input.is_action_just_released("shoot"):
		_execute_manual_shot(aim_dir)
		return

	_update_trajectory_visuals(aim_dir)

func _execute_smart_pass(target_mate: AIFootballer, is_through_ball: bool) -> void:
	var target_pos: Vector2 = target_mate.global_position
	var kind: StringName = &"pass_direct"
	var spin_val: float = shot_spin_ratio * stats.get_max_spin() * 0.55
	var loft_z: float = 0.0

	if is_through_ball:
		kind = &"pass_through"
		target_pos = _compute_through_pass_spot(target_mate)
	else:
		target_pos = target_mate.global_position + target_mate.velocity * 0.18

	if is_lob_mode:
		# Havadan orta / savunma üstünden aşırtma pas!
		kind = &"pass_lob"
		loft_z = 92.0

	if absf(shot_spin_ratio) < 0.05:
		spin_val = _compute_smart_pass_curl(ball.global_position, target_pos)

	# Yorgunluk sapması
	var jitter: float = get_fatigue_aim_jitter_rad() * 0.6
	if jitter > 0.001:
		var offset_v: Vector2 = (target_pos - ball.global_position).rotated(randf_range(-jitter, jitter))
		target_pos = ball.global_position + offset_v

	var dir: Vector2 = (target_pos - ball.global_position).normalized()
	var saved_spin_ratio: float = shot_spin_ratio
	var dist_ratio: float = clampf(global_position.distance_to(target_pos) / 360.0, 0.25, 0.85)

	target_mate.assign_incoming_pass(target_pos)

	_cleanup_after_kick()
	if is_through_ball or loft_z > 0.0:
		ball.pass_to(self, 0, target_pos, spin_val, kind, 145.0, 255.0, loft_z)
	else:
		ball.pass_to(self, 0, target_pos, spin_val, kind, 185.0, 320.0, 0.0)

	_play_squash_pop(Vector2(1.18, 0.86))
	action_executed.emit(kind, dir, dist_ratio, saved_spin_ratio, target_mate)

func _compute_through_pass_spot(target_mate: AIFootballer) -> Vector2:
	var run_dir: Vector2 = target_mate.velocity.normalized() if target_mate.velocity.length() > 14.0 else (target_mate.scenario_run_target - target_mate.global_position).normalized()
	if run_dir.length_squared() < 0.01:
		run_dir = Vector2.RIGHT
	var dist_to_mate: float = global_position.distance_to(target_mate.global_position)
	var lead_dist: float = clampf(dist_to_mate * 0.28 + 22.0, 36.0, 62.0)
	var pt: Vector2 = target_mate.global_position + run_dir * lead_dist
	pt.x = clampf(pt.x, -TacticsHelper.PITCH_HALF_W + 26.0, TacticsHelper.PITCH_HALF_W - 36.0)
	pt.y = clampf(pt.y, -TacticsHelper.PITCH_HALF_H + 26.0, TacticsHelper.PITCH_HALF_H - 26.0)
	return pt

func _compute_smart_pass_curl(from_pos: Vector2, to_pos: Vector2) -> float:
	var seg: Vector2 = to_pos - from_pos
	var seg_len_sq: float = seg.length_squared()
	if seg_len_sq < 400.0:
		return 0.0
	var seg_dir: Vector2 = seg.normalized()
	for opp in opponents:
		if not is_instance_valid(opp) or opp.role == TacticsHelper.Role.GK:
			continue
		var t: float = clampf((opp.global_position - from_pos).dot(seg) / seg_len_sq, 0.0, 1.0)
		if t <= 0.12 or t >= 0.88:
			continue
		var closest: Vector2 = from_pos + seg * t
		var d: float = opp.global_position.distance_to(closest)
		if d < 24.0:
			var side: float = seg_dir.cross(opp.global_position - from_pos)
			return 0.36 if side > 0.0 else -0.36
	return 0.0

func _execute_manual_shot(aim_dir: Vector2) -> void:
	var final_power: float = clampf(shot_power_ratio, 0.18, 1.0)
	var final_spin_ratio: float = shot_spin_ratio
	var fatigue_mult: float = get_fatigue_multiplier()
	var max_kick: float = stats.get_max_kick_speed() * fatigue_mult

	var was_lob: bool = is_lob_mode
	var loft_z: float = lerpf(85.0, 138.0, final_power) if was_lob else 0.0
	# Aşırtmada yatay hız daha tatlı/süzülen aralıktadır ki kalecinin üstünden ağlara düşsün!
	var launch_spd: float = lerpf(135.0, 265.0, final_power) if was_lob else lerpf(185.0, max_kick, final_power)
	var actual_spin: float = final_spin_ratio * stats.get_max_spin()

	# Düşük staminada şut isabeti sapar
	var jitter: float = get_fatigue_aim_jitter_rad()
	var final_dir: Vector2 = aim_dir.rotated(randf_range(-jitter, jitter)) if jitter > 0.001 else aim_dir

	_cleanup_after_kick()
	ball.kick(self, 0, final_dir, launch_spd, actual_spin, &"shot_lob" if was_lob else &"shot", loft_z)
	_play_squash_pop(Vector2(1.28, 0.76))
	action_executed.emit(&"shot_lob" if was_lob else &"shot", final_dir, final_power, final_spin_ratio, null)

func _cleanup_after_kick() -> void:
	is_charging_shot = false
	is_lob_mode = false
	shot_power_ratio = 0.0
	shot_spin_ratio = 0.0
	_set_aim_mode(false)
	aim_line.visible = false
	pass_preview_line.visible = false
	_clear_teammate_highlight()
	shot_metrics_changed.emit(0.0, 0.0, false, false)

func _update_selected_teammate(aim_dir: Vector2, mouse_pos: Vector2) -> void:
	var best_mate: AIFootballer = null
	var best_score: float = -99999.0

	for mate in teammates:
		if not is_instance_valid(mate) or mate.role == TacticsHelper.Role.GK:
			continue
		var to_mate: Vector2 = mate.global_position - global_position
		var dist: float = to_mate.length()
		if dist < 18.0 or dist > 560.0:
			continue
		var alignment: float = aim_dir.dot(to_mate.normalized())
		var mouse_dist: float = mouse_pos.distance_to(mate.global_position)
		var score: float = alignment * 145.0 - mouse_dist * 0.42 - dist * 0.04
		if score > best_score:
			best_score = score
			best_mate = mate

	if best_mate != _selected_teammate:
		_clear_teammate_highlight()
		_selected_teammate = best_mate
		if _selected_teammate != null:
			_selected_teammate.set_pass_highlighted(true)

func _clear_teammate_highlight() -> void:
	if is_instance_valid(_selected_teammate):
		_selected_teammate.set_pass_highlighted(false)
	_selected_teammate = null
	if _through_marker != null:
		_through_marker.visible = false

func _update_trajectory_visuals(aim_dir: Vector2) -> void:
	if is_aim_mode or is_charging_shot:
		aim_line.visible = true
		var preview_power: float = shot_power_ratio if is_charging_shot else 0.60
		var preview_loft: float = lerpf(85.0, 138.0, preview_power) if is_lob_mode else 0.0
		var preview_speed: float = lerpf(135.0, 265.0, preview_power) if is_lob_mode else lerpf(185.0, stats.get_max_kick_speed() * get_fatigue_multiplier(), preview_power)
		var preview_spin: float = shot_spin_ratio * stats.get_max_spin()

		aim_line.points = SoccerBall.simulate_trajectory(
			ball.global_position,
			aim_dir,
			preview_speed,
			preview_spin,
			ball.ground_friction,
			ball.spin_decay,
			ball.magnus_strength,
			30,
			0.030,
			preview_loft,
			ball.gravity_z,
			ball.air_drag
		)
		if is_lob_mode:
			aim_line.default_color = Color(0.45, 0.96, 1.0, 0.92)
		else:
			aim_line.default_color = Color(1.0, 0.92, 0.3, 0.85).lerp(Color(1.0, 0.28, 0.2, 0.95), preview_power)
	else:
		aim_line.visible = false

	if _selected_teammate != null and not is_charging_shot:
		pass_preview_line.visible = true
		pass_preview_line.points = PackedVector2Array([ball.global_position, _selected_teammate.global_position])
		if _through_marker != null:
			var spot: Vector2 = _compute_through_pass_spot(_selected_teammate)
			_through_marker.visible = true
			_through_marker.points = PackedVector2Array([
				spot + Vector2(0, -5), spot + Vector2(5, 0),
				spot + Vector2(0, 5), spot + Vector2(-5, 0), spot + Vector2(0, -5)
			])
	else:
		pass_preview_line.visible = false
		if _through_marker != null:
			_through_marker.visible = false

func _request_pass_from_teammates() -> void:
	if ball.holder is AIFootballer:
		var carrier := ball.holder as AIFootballer
		if carrier.team_id == 0:
			carrier.receive_pass_call_boost()
			_play_squash_pop(Vector2(1.18, 1.18))
			pass_called.emit()

func has_open_teammate() -> bool:
	for mate in teammates:
		if not is_instance_valid(mate) or mate.role == TacticsHelper.Role.GK:
			continue
		if global_position.distance_to(mate.global_position) < 260.0 and mate.global_position.x > global_position.x - 20.0:
			return true
	return false

func _distance_to_nearest_opponent() -> float:
	var best: float = 9999.0
	for opp in opponents:
		if not is_instance_valid(opp):
			continue
		var d: float = global_position.distance_to(opp.global_position)
		if d < best:
			best = d
	return best

func _find_nearest_opponent_within(radius: float) -> AIFootballer:
	var best: AIFootballer = null
	var best_d: float = radius
	for opp in opponents:
		if not is_instance_valid(opp):
			continue
		var d: float = global_position.distance_to(opp.global_position)
		if d < best_d:
			best_d = d
			best = opp
	return best

func _set_aim_mode(enabled: bool) -> void:
	if is_aim_mode == enabled:
		return
	is_aim_mode = enabled
	if not is_aim_mode:
		aim_line.visible = false
	aim_mode_changed.emit(is_aim_mode)

func _cancel_shot_and_aim() -> void:
	is_charging_shot = false
	is_lob_mode = false
	shot_power_ratio = 0.0
	shot_spin_ratio = 0.0
	_set_aim_mode(false)
	aim_line.visible = false
	pass_preview_line.visible = false
	shot_metrics_changed.emit(0.0, 0.0, false, false)

func _on_ball_owner_changed(new_owner: Node2D, _prev_owner: Node2D) -> void:
	if new_owner != self and (is_aim_mode or is_charging_shot):
		_cancel_shot_and_aim()

func _play_squash_pop(target_scale: Vector2) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	scale = target_scale
	_scale_tween = create_tween()
	_scale_tween.set_ignore_time_scale(true)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_visual_facing() -> void:
	if facing_indicator != null and facing_dir.length_squared() > 0.001:
		facing_indicator.rotation = facing_dir.angle()
