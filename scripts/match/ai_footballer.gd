class_name AIFootballer
extends CharacterBody2D

signal tackle_attempted(defender: AIFootballer, target: Node2D, succeeded: bool)
signal shot_fired(shooter: AIFootballer, team_id: int)
signal pass_sent(passer: AIFootballer, target: Node2D, team_id: int)

enum AIState {
	POSITIONING,
	RECEIVE_PASS,   # Kendisine atılan pasın/ara pasının düşeceği noktaya %118 depar atar!
	CARRY_BALL,
	JOCKEY_CONTAIN,
	PRESS_CARRIER,
	CHASE_BALL,
	TACKLE_WINDUP,
	ANKLE_BROKEN,
	RECOVER
}

var team_id: int = 0
var shirt_number: int = 1
var slot_label: String = "MO"
var role: TacticsHelper.Role = TacticsHelper.Role.MID
var home_position: Vector2 = Vector2.ZERO
var scenario_run_target: Vector2 = Vector2.ZERO
var stats: FootballerStats = FootballerStats.new()

var ball_ref: SoccerBall = null
var all_footballers: Array[CharacterBody2D] = []
var user_player: MatchPlayer = null

var current_state: AIState = AIState.POSITIONING
var facing_dir: Vector2 = Vector2.RIGHT
var _decision_timer: float = 0.0
var _windup_timer: float = 0.0
var _recover_timer: float = 0.0
var _ankle_slide_dir: Vector2 = Vector2.ZERO
var _tackle_target: Node2D = null
var _is_highlighted: bool = false
var _pass_call_boost: float = 0.0
var _receive_target_pos: Vector2 = Vector2.ZERO
var _receive_timer: float = 0.0

const PROCEDURAL_CHAR_SCENE: PackedScene = preload("res://scenes/character/procedural_character.tscn")

var _char_visual: ProceduralCharacter = null
var _highlight_ring: Line2D = null
var _telegraph_ring: Line2D = null
var _stun_ring: Line2D = null
var _run_arrow: Line2D = null
var _number_label: Label = null

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 3
	add_to_group("footballers")
	_build_visuals()

func configure_scenario_actor(
	p_spawn: ScenarioGenerator.ActorSpawn,
	p_stats: FootballerStats,
	p_ball: SoccerBall,
	p_user: MatchPlayer
) -> void:
	team_id = p_spawn.team_id
	shirt_number = p_spawn.number
	slot_label = p_spawn.label
	role = p_spawn.role
	home_position = p_spawn.pos
	scenario_run_target = p_spawn.run_target
	stats = p_stats
	ball_ref = p_ball
	user_player = p_user
	global_position = p_spawn.pos
	facing_dir = Vector2.RIGHT if team_id == 0 else Vector2.LEFT
	add_to_group("team_%d" % team_id)
	_apply_team_colors()
	reset_physics_interpolation()

func set_roster_reference(roster: Array[CharacterBody2D]) -> void:
	all_footballers = roster

func set_pass_highlighted(enabled: bool) -> void:
	_is_highlighted = enabled
	if _highlight_ring != null:
		_highlight_ring.visible = enabled

func assign_incoming_pass(intercept_spot: Vector2) -> void:
	# Oyuncu bize X veya C ile pas attı! Anında topun buluşma noktasına depara kalk!
	_receive_target_pos = intercept_spot
	_receive_timer = 2.4
	current_state = AIState.RECEIVE_PASS

func receive_pass_call_boost() -> void:
	_pass_call_boost = 2.5

func trigger_ankle_break(old_momentum_dir: Vector2) -> void:
	if role == TacticsHelper.Role.GK:
		return
	current_state = AIState.ANKLE_BROKEN
	_recover_timer = 0.78
	_ankle_slide_dir = old_momentum_dir.normalized() if old_momentum_dir.length_squared() > 0.01 else facing_dir
	_tackle_target = null
	_set_telegraph_visible(false)
	_set_stun_visible(true)

func _physics_process(delta: float) -> void:
	if ball_ref == null:
		return

	if _pass_call_boost > 0.0:
		_pass_call_boost = maxf(_pass_call_boost - delta, 0.0)

	_update_fsm(delta)
	_check_ball_interaction()
	_update_run_arrow()
	if _char_visual != null:
		_char_visual.update_locomotion(velocity, facing_dir, delta, MatchCamera.BEHIND_GOAL_ROTATION)

func _update_fsm(delta: float) -> void:
	var accel: float = 720.0
	var move_spd: float = stats.get_move_speed()

	if ball_ref.is_gk_shielded() and ball_ref.holder != self and role != TacticsHelper.Role.GK:
		var holder_node: Node2D = ball_ref.holder
		if is_instance_valid(holder_node):
			var away_from_gk: Vector2 = global_position - holder_node.global_position
			if away_from_gk.length() < 38.0:
				var push_dir: Vector2 = away_from_gk.normalized() if away_from_gk.length() > 0.1 else Vector2(-1.0, 0.0)
				_apply_steered_velocity(push_dir, move_spd * 0.85, accel, delta)
				return

	if current_state == AIState.ANKLE_BROKEN:
		_recover_timer -= delta
		velocity = velocity.move_toward(_ankle_slide_dir * 28.0, accel * 0.60 * delta)
		move_and_slide()
		if _recover_timer <= 0.0:
			_set_stun_visible(false)
			current_state = AIState.POSITIONING
		return

	if current_state == AIState.RECOVER:
		_recover_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
		move_and_slide()
		if _recover_timer <= 0.0:
			current_state = AIState.POSITIONING
		return

	if current_state == AIState.TACKLE_WINDUP:
		_windup_timer -= delta
		_set_telegraph_visible(true)
		if is_instance_valid(_tackle_target):
			var aim_pt: Vector2 = ball_ref.global_position if ball_ref.holder == _tackle_target else _tackle_target.global_position
			var lunge_dir: Vector2 = (aim_pt - global_position).normalized()
			facing_dir = lunge_dir
			velocity = velocity.move_toward(lunge_dir * (move_spd * 1.05), accel * 1.2 * delta)
		move_and_slide()
		if _windup_timer <= 0.0:
			_execute_tackle_resolution(false)
		return

	_set_telegraph_visible(false)
	_set_stun_visible(false)

	# 1. Top bizdeyse: Sür, oyuncumuz pas isterse / boştaysa ver-kaç yap, kaleyle %100 karşı karşıyaysa bitir!
	if ball_ref.holder == self:
		_receive_timer = 0.0
		current_state = AIState.CARRY_BALL
		_run_carry_ball(delta, accel)
		return

	# 2. Kendisine atılan pası/ara pasını karşılama deparı!
	if current_state == AIState.RECEIVE_PASS:
		_receive_timer -= delta
		if ball_ref.holder != null or _receive_timer <= 0.0:
			current_state = AIState.POSITIONING
		else:
			# Top yaklaştıysa doğrudan topun kendisine, hala uzaktaysa buluşma noktasına %122 depar at
			var chase_pt: Vector2 = ball_ref.global_position if global_position.distance_to(ball_ref.global_position) < 62.0 else _receive_target_pos.lerp(ball_ref.global_position, 0.35)
			var to_spot: Vector2 = chase_pt - global_position
			if to_spot.length() > 4.0:
				_apply_steered_velocity(to_spot.normalized(), move_spd * 1.22, accel * 1.4, delta)
			else:
				velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
				move_and_slide()
			return

	var ball_team: int = _get_holder_team()
	var dist_to_ball: float = global_position.distance_to(ball_ref.global_position)

	if role == TacticsHelper.Role.GK:
		_run_goalkeeper(delta, move_spd, accel, dist_to_ball)
		return

	if ball_ref.holder == null and _is_closest_teammate_to_ball() and dist_to_ball < 240.0:
		current_state = AIState.CHASE_BALL
		var seek_dir: Vector2 = (ball_ref.global_position - global_position).normalized()
		_apply_steered_velocity(seek_dir, move_spd * 1.06, accel, delta)
		return

	# 3. GERÇEKÇİ SAVUNMA: Yalnızca en yakın 1 rakip kademeli baskı/jockey yapar
	if ball_team != -1 and ball_team != team_id and not ball_ref.is_gk_shielded() and _is_primary_presser(dist_to_ball):
		var carrier_node: Node2D = ball_ref.holder
		var dist_to_actual_ball: float = global_position.distance_to(ball_ref.global_position)
		var is_shielded_behind: bool = _is_carrier_shielding_ball(carrier_node)

		if not is_shielded_behind:
			if dist_to_actual_ball <= 12.5:
				_tackle_target = carrier_node
				_execute_tackle_resolution(true)
				return
			if dist_to_actual_ball <= 22.0:
				current_state = AIState.TACKLE_WINDUP
				_tackle_target = carrier_node
				_windup_timer = 0.24
				_set_telegraph_visible(true)
				return

		var own_goal: Vector2 = Vector2(-TacticsHelper.PITCH_HALF_W, 0.0) if team_id == 0 else Vector2(TacticsHelper.PITCH_HALF_W, 0.0)
		var goal_side: Vector2 = (own_goal - carrier_node.global_position).normalized()
		var press_target: Vector2 = ball_ref.global_position + goal_side * 16.0
		if is_shielded_behind:
			var side_sign: float = 1.0 if global_position.y >= carrier_node.global_position.y else -1.0
			press_target = ball_ref.global_position + Vector2(goal_side.x * 20.0, side_sign * 18.0)

		var jockey_speed: float = move_spd * (0.74 if dist_to_actual_ball > 34.0 else 0.86)
		current_state = AIState.JOCKEY_CONTAIN if dist_to_actual_ball > 34.0 else AIState.PRESS_CARRIER
		_apply_steered_velocity((press_target - global_position).normalized(), jockey_speed, accel, delta)
		return

	# 4. Senaryo Koşusu / Kademe
	current_state = AIState.POSITIONING
	var to_target: Vector2 = scenario_run_target - global_position
	if to_target.length() > 8.0:
		var spd_factor: float = clampf(to_target.length() / 48.0, 0.45, 0.92 if team_id == 0 else 0.72)
		_apply_steered_velocity(to_target.normalized(), move_spd * spd_factor, accel, delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
		move_and_slide()

func _is_carrier_shielding_ball(carrier_node: Node2D) -> bool:
	var dist_def_to_ball: float = global_position.distance_to(ball_ref.global_position)
	var dist_def_to_body: float = global_position.distance_to(carrier_node.global_position)
	var carrier_facing: Vector2 = Vector2.RIGHT
	if carrier_node is MatchPlayer:
		carrier_facing = (carrier_node as MatchPlayer).facing_dir
	elif carrier_node is AIFootballer:
		carrier_facing = (carrier_node as AIFootballer).facing_dir

	var carrier_to_def: Vector2 = (global_position - carrier_node.global_position).normalized()
	var def_is_behind: bool = carrier_facing.dot(carrier_to_def) < 0.08
	return def_is_behind and (dist_def_to_ball > dist_def_to_body - 1.5)

func _run_goalkeeper(delta: float, move_spd: float, accel: float, dist_to_ball: float) -> void:
	if ball_ref.holder == null and dist_to_ball < 72.0 and absf(ball_ref.global_position.x - home_position.x) < 90.0:
		var seek_dir: Vector2 = (ball_ref.global_position - global_position).normalized()
		_apply_steered_velocity(seek_dir, move_spd * 1.12, accel * 1.35, delta)
		return
	var anchor: Vector2 = TacticsHelper.compute_tactical_anchor(
		home_position,
		role,
		team_id,
		ball_ref.global_position,
		false
	)
	var to_anchor: Vector2 = anchor - global_position
	if to_anchor.length() > 3.0:
		_apply_steered_velocity(to_anchor.normalized(), move_spd * 1.12, accel * 1.3, delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
		move_and_slide()

func _run_carry_ball(delta: float, accel: float) -> void:
	var attack_goal: Vector2 = Vector2(TacticsHelper.PITCH_HALF_W, 0.0) if team_id == 0 else Vector2(-TacticsHelper.PITCH_HALF_W, 0.0)
	var to_goal: Vector2 = attack_goal - global_position
	var dist_to_goal: float = to_goal.length()
	var carry_dir: Vector2 = to_goal.normalized()

	if _decision_timer <= 0.0:
		_decision_timer = 0.42 if role == TacticsHelper.Role.GK else randf_range(0.75, 1.30)

	# Oyuncu Space ile pas istediyse hemen geri oyna!
	if team_id == 0 and _pass_call_boost > 0.0:
		_decision_timer = minf(_decision_timer, 0.14)

	_decision_timer -= delta

	var dribble_spd: float = stats.get_dribble_speed() * (0.20 if role == TacticsHelper.Role.GK else 0.90)
	facing_dir = carry_dir
	ball_ref.update_dribble_facing(facing_dir)
	_apply_steered_velocity(carry_dir, dribble_spd, accel, delta)

	if _decision_timer <= 0.0:
		# Yalnızca kaleyle çok net karşı karşıyaysa (ceza sahası içi, < 135 px) ve oyuncu pas istemediyse şut çeker!
		if team_id == 0 and dist_to_goal < 135.0 and _pass_call_boost <= 0.0:
			var aim_y: float = randf_range(-TacticsHelper.GOAL_HALF_H + 10.0, TacticsHelper.GOAL_HALF_H - 10.0)
			var shot_dir: Vector2 = (Vector2(attack_goal.x, aim_y) - global_position).normalized()
			var shot_spd: float = stats.get_max_kick_speed() * randf_range(0.84, 0.98)
			ball_ref.kick(self, team_id, shot_dir, shot_spd, randf_range(-0.28, 0.28), &"ai_shot")
			shot_fired.emit(self, team_id)
			_decision_timer = 0.0
			return

		# Aksi halde ver-kaç için oyuncumuza geri oyna (böylece pozisyon kesilmez, ver-kaç keyfi yaşanır!)
		if team_id == 0 and is_instance_valid(user_player):
			var lead_pt: Vector2 = user_player.global_position + user_player.velocity * 0.25
			ball_ref.pass_to(self, team_id, lead_pt, 0.0, &"ai_pass", 180.0, 290.0)
			pass_sent.emit(self, user_player, team_id)
			_pass_call_boost = 0.0
		else:
			ball_ref.kick(self, team_id, carry_dir, 260.0, 0.0, &"ai_clear")
		_decision_timer = 0.0

func _execute_tackle_resolution(is_point_blank: bool) -> void:
	_set_telegraph_visible(false)
	var succeeded: bool = false

	if is_instance_valid(_tackle_target) and ball_ref.holder == _tackle_target:
		if not _is_carrier_shielding_ball(_tackle_target):
			var dist_ball: float = global_position.distance_to(ball_ref.global_position)
			if dist_ball <= 19.5:
				var running_into_def: bool = false
				if _tackle_target is CharacterBody2D:
					var c_vel: Vector2 = (_tackle_target as CharacterBody2D).velocity
					if c_vel.length() > 15.0:
						var to_def: Vector2 = (global_position - _tackle_target.global_position).normalized()
						if c_vel.normalized().dot(to_def) > 0.42:
							running_into_def = true

				var target_stats: FootballerStats = _get_node_stats(_tackle_target)
				var defender_bonus: float = (26.0 if is_point_blank else 4.0) + (24.0 if running_into_def else 0.0)
				var attack_roll: float = float(stats.tackling) + defender_bonus + randf_range(-8.0, 12.0)
				var defend_roll: float = float(target_stats.dribbling) * 0.74 + randf_range(-10.0, 10.0)

				if attack_roll >= defend_roll:
					succeeded = true
					var push_dir: Vector2 = (ball_ref.global_position - global_position).normalized()
					ball_ref.knock_loose(self, team_id, push_dir, 120.0)
					if randf() < 0.62:
						ball_ref.claim(self, team_id, push_dir, role == TacticsHelper.Role.GK)

	tackle_attempted.emit(self, _tackle_target, succeeded)
	_tackle_target = null
	current_state = AIState.RECOVER
	_recover_timer = 0.35 if succeeded else 0.75

func _check_ball_interaction() -> void:
	if current_state == AIState.RECOVER or current_state == AIState.TACKLE_WINDUP or current_state == AIState.ANKLE_BROKEN:
		return
	if ball_ref.holder != null:
		return

	var dist: float = global_position.distance_to(ball_ref.global_position)
	var ball_speed: float = ball_ref.velocity.length()
	var control_radius: float = 21.0 if role == TacticsHelper.Role.GK else (17.5 if current_state == AIState.RECEIVE_PASS else 14.0)

	if dist <= control_radius and ball_ref.can_be_claimed_by(self, role == TacticsHelper.Role.GK):
		if ball_speed > 245.0 and role != TacticsHelper.Role.GK and ball_ref.last_touch_team != team_id:
			var intercept_chance: float = clampf((float(stats.marking) + float(stats.tackling)) / 240.0, 0.18, 0.68)
			if randf() > intercept_chance:
				return
		ball_ref.claim(self, team_id, facing_dir, role == TacticsHelper.Role.GK)
		_decision_timer = 0.0

func _apply_steered_velocity(seek_dir: Vector2, speed: float, accel: float, delta: float) -> void:
	var separation: Vector2 = Vector2.ZERO
	for other in all_footballers:
		if other == self or not is_instance_valid(other):
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist: float = diff.length()
		if dist > 0.01 and dist < 24.0:
			separation += (diff / dist) * ((24.0 - dist) / 24.0)

	var combined: Vector2 = (seek_dir + separation * 0.65).normalized()
	facing_dir = facing_dir.slerp(combined, clampf(10.0 * delta, 0.0, 1.0)).normalized()
	velocity = velocity.move_toward(combined * speed, accel * delta)
	move_and_slide()

func _is_primary_presser(dist_to_ball: float) -> bool:
	var press_range: float = lerpf(135.0, 210.0, float(stats.marking) / 100.0)
	if dist_to_ball > press_range:
		return false
	for other in all_footballers:
		if other == self or _get_node_team(other) != team_id:
			continue
		if other is AIFootballer:
			var other_ai := other as AIFootballer
			if other_ai.role == TacticsHelper.Role.GK or other_ai.current_state == AIState.ANKLE_BROKEN:
				continue
		if other.global_position.distance_to(ball_ref.global_position) < dist_to_ball:
			return false
	return true

func _is_closest_teammate_to_ball() -> bool:
	var my_dist: float = global_position.distance_to(ball_ref.global_position)
	for other in all_footballers:
		if other == self or _get_node_team(other) != team_id:
			continue
		if other is AIFootballer and (other as AIFootballer).role == TacticsHelper.Role.GK:
			continue
		if other.global_position.distance_to(ball_ref.global_position) < my_dist:
			return false
	return true

func _update_run_arrow() -> void:
	if _run_arrow == null:
		return
	if team_id == 0 and ball_ref.holder != self and velocity.length() > 14.0:
		_run_arrow.visible = true
		var dir: Vector2 = velocity.normalized()
		var tip: Vector2 = dir * 22.0
		var left_wing: Vector2 = tip - dir * 5.0 + dir.orthogonal() * 3.5
		var right_wing: Vector2 = tip - dir * 5.0 - dir.orthogonal() * 3.5
		_run_arrow.points = PackedVector2Array([dir * 8.0, tip, left_wing, tip, right_wing])
	else:
		_run_arrow.visible = false

func _get_holder_team() -> int:
	if ball_ref.holder == null:
		return -1
	return _get_node_team(ball_ref.holder)

func _get_node_team(node: Node2D) -> int:
	if node is MatchPlayer:
		return 0
	if node is AIFootballer:
		return (node as AIFootballer).team_id
	return -1

func _get_node_stats(node: Node2D) -> FootballerStats:
	if node is MatchPlayer:
		return (node as MatchPlayer).stats
	if node is AIFootballer:
		return (node as AIFootballer).stats
	return FootballerStats.new()

func _build_visuals() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.5
	col.shape = shape
	add_child(col)

	_run_arrow = Line2D.new()
	_run_arrow.width = 1.4
	_run_arrow.default_color = Color(0.45, 0.95, 1.0, 0.52)
	_run_arrow.visible = false
	add_child(_run_arrow)

	_char_visual = PROCEDURAL_CHAR_SCENE.instantiate() as ProceduralCharacter
	add_child(_char_visual)

	_highlight_ring = _create_circle_line(11.0, Color(1.0, 0.95, 0.25, 0.95), 2.0)
	_highlight_ring.visible = false
	add_child(_highlight_ring)

	_telegraph_ring = _create_circle_line(11.5, Color(1.0, 0.25, 0.2, 0.95), 2.0)
	_telegraph_ring.visible = false
	add_child(_telegraph_ring)

	_stun_ring = _create_circle_line(12.0, Color(0.35, 0.95, 1.0, 0.95), 2.0)
	_stun_ring.visible = false
	add_child(_stun_ring)

	# Kale arkası kamerada forma numarası karakterin hemen üstünde (+X yönü) dik okunsun
	_number_label = Label.new()
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.position = Vector2(12.0, -7.0)
	_number_label.size = Vector2(16.0, 14.0)
	_number_label.pivot_offset = Vector2(8.0, 7.0)
	_number_label.rotation = MatchCamera.BEHIND_GOAL_ROTATION
	_number_label.add_theme_font_size_override("font_size", 6)
	add_child(_number_label)

func _create_circle_line(radius: float, col: Color, w: float) -> Line2D:
	var line := Line2D.new()
	line.width = w
	line.default_color = col
	var pts := PackedVector2Array()
	for i in 17:
		var ang: float = (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	line.points = pts
	return line

func _apply_team_colors() -> void:
	if _char_visual != null:
		var kit_primary: Color
		var kit_secondary: Color
		if role == TacticsHelper.Role.GK:
			kit_primary = Color(0.95, 0.80, 0.16, 1.0) if team_id == 0 else Color(0.95, 0.52, 0.14, 1.0)
			kit_secondary = Color(0.16, 0.18, 0.22, 1.0)
		elif team_id == 0:
			kit_primary = Color(0.16, 0.52, 0.95, 1.0)
			kit_secondary = Color(0.92, 0.95, 0.98, 1.0)
		else:
			kit_primary = Color(0.90, 0.22, 0.25, 1.0)
			kit_secondary = Color(0.16, 0.16, 0.20, 1.0)
		# Deterministik seed: aynı forma numaralı oyuncu aynı 5 katmanlı yüze/saça/sakala sahip!
		var seed_id: int = team_id * 1000 + shirt_number * 37 + int(role) * 7
		var app: CharacterAppearance = CharacterAppearance.create_random(kit_primary, kit_secondary, seed_id)
		_char_visual.apply_appearance(app)
	if _number_label != null:
		_number_label.text = str(shirt_number)

func _set_telegraph_visible(vis: bool) -> void:
	if _telegraph_ring != null:
		_telegraph_ring.visible = vis

func _set_stun_visible(vis: bool) -> void:
	if _stun_ring != null:
		_stun_ring.visible = vis
