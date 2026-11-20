class_name SoccerBall
extends CharacterBody2D

signal owner_changed(new_owner: Node2D, previous_owner: Node2D)
signal kicked(kicker: Node2D, direction: Vector2, speed: float, spin: float, kick_kind: StringName)
signal post_hit(impact_speed: float)
signal out_of_bounds(kind: StringName, exit_pos: Vector2, last_team: int)
signal pass_completed(passer: Node2D, receiver: Node2D, kick_kind: StringName, distance: float, is_forward: bool)
signal pass_intercepted(passer: Node2D, interceptor: Node2D)

@export var ground_friction: float = 210.0
@export var air_drag: float = 48.0
@export var spin_decay: float = 2.4
@export var magnus_strength: float = 3.1
@export var post_bounciness: float = 0.78
@export var gravity_z: float = 210.0
@export var ground_bounce_z: float = 0.45

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ball_visual: Polygon2D = $BallPolygon

var holder: Node2D = null
var last_touch_node: Node2D = null
var last_touch_team: int = -1
var last_passer_node: Node2D = null
var last_passer_team: int = -1
var last_kick_kind: StringName = &""
var last_kick_origin: Vector2 = Vector2.ZERO
var last_kick_had_pending_eval: bool = false

# 2.5D Yükseklik Fiziği (Aşırtma / Havadan Orta & Ayrı Zemin Gölgesi)
var height_z: float = 0.0
var vel_z: float = 0.0

var spin: float = 0.0
var _dribble_facing: Vector2 = Vector2.RIGHT
var _dribble_pulse: float = 0.0
var _pickup_cooldown: float = 0.0
var _ignore_claimer: Node2D = null
var _gk_shield_timer: float = 0.0
var _out_reported: bool = false
var _feint_push_timer: float = 0.0
var _shadow_poly: Polygon2D = null

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	_create_ground_shadow()

func _create_ground_shadow() -> void:
	_shadow_poly = Polygon2D.new()
	_shadow_poly.name = "BallShadow"
	_shadow_poly.color = Color(0.0, 0.0, 0.0, 0.42)
	_shadow_poly.z_index = -1
	# Elips zemin gölgesi (GDD 5.1 standartları)
	_shadow_poly.polygon = PackedVector2Array([
		Vector2(0, -3.5), Vector2(2.4, -2.5), Vector2(3.2, 0), Vector2(2.4, 2.5),
		Vector2(0, 3.5), Vector2(-2.4, 2.5), Vector2(-3.2, 0), Vector2(-2.4, -2.5)
	])
	add_child(_shadow_poly)

func is_airborne_high() -> bool:
	# Top 8.5 birimin üstündeyken yerdeki savunmacılar kesemez (Aşırtma / Orta!)
	return height_z > 8.5

func is_airborne_over_gk() -> bool:
	# Kaleci uzanma yüksekliği daha fazladır; gerçekçi aşırtma yüksekliği
	return height_z > 13.5

func _physics_process(delta: float) -> void:
	if _pickup_cooldown > 0.0:
		_pickup_cooldown = maxf(_pickup_cooldown - delta, 0.0)
		if _pickup_cooldown <= 0.0:
			_ignore_claimer = null

	if _gk_shield_timer > 0.0:
		_gk_shield_timer = maxf(_gk_shield_timer - delta, 0.0)

	if _feint_push_timer > 0.0:
		_feint_push_timer = maxf(_feint_push_timer - delta, 0.0)

	if is_instance_valid(holder):
		if not collision_shape.disabled:
			collision_shape.disabled = true
		height_z = 0.0
		vel_z = 0.0
		_update_dribble_physics(delta)
		_update_height_visuals()
		_check_out_of_bounds()
		return

	if collision_shape.disabled:
		collision_shape.disabled = false

	# 2.5D Dikey Yükseklik Entegrasyonu (Aşırtma / Sekme)
	if height_z > 0.0 or vel_z > 0.0:
		vel_z -= gravity_z * delta
		height_z += vel_z * delta
		if height_z <= 0.0:
			height_z = 0.0
			if absf(vel_z) > 26.0:
				vel_z = -vel_z * ground_bounce_z
				velocity *= 0.86
			else:
				vel_z = 0.0

	var current_speed: float = velocity.length()
	if current_speed > 0.5:
		if absf(spin) > 0.01:
			velocity = velocity.rotated(spin * magnus_strength * delta)
		# Havadayken sürtünme çok daha azdır (gerçekçi aşırtma süzülüşü!)
		var active_drag: float = air_drag if height_z > 0.5 else ground_friction
		velocity = velocity.move_toward(Vector2.ZERO, active_drag * delta)
		spin = move_toward(spin, 0.0, spin_decay * delta)

		var collision: KinematicCollision2D = move_and_collide(velocity * delta)
		if collision != null:
			var normal: Vector2 = collision.get_normal()
			velocity = velocity.bounce(normal) * post_bounciness
			spin *= 0.45
			post_hit.emit(current_speed)
	else:
		velocity = Vector2.ZERO
		spin = 0.0

	_update_height_visuals()
	_check_out_of_bounds()

func _update_height_visuals() -> void:
	if ball_visual == null:
		return
	# Kale arkası kamerada ekranın "Yukarı" yönü dünya +X'tir -> Top yükseldikçe +X yönünde hafif kayıp büyür!
	var h_ratio: float = clampf(height_z / 34.0, 0.0, 1.0)
	ball_visual.position = Vector2(height_z * 0.45, 0.0)
	var s: float = lerpf(1.0, 1.65, h_ratio)
	ball_visual.scale = Vector2(s, s)
	ball_visual.z_index = 4 if height_z > 4.0 else 1

	if _shadow_poly != null:
		var sh_scale: float = lerpf(1.0, 0.55, h_ratio)
		_shadow_poly.scale = Vector2(sh_scale, sh_scale)
		_shadow_poly.color.a = lerpf(0.42, 0.18, h_ratio)

func _update_dribble_physics(delta: float) -> void:
	var carrier_vel: Vector2 = Vector2.ZERO
	if holder is CharacterBody2D:
		carrier_vel = (holder as CharacterBody2D).velocity

	var carrier_speed: float = carrier_vel.length()
	var move_dir: Vector2 = carrier_vel.normalized() if carrier_speed > 8.0 else _dribble_facing
	if carrier_speed > 10.0:
		_dribble_facing = _dribble_facing.slerp(move_dir, clampf(12.0 * delta, 0.0, 1.0)).normalized()
		_dribble_pulse += delta * (carrier_speed * 0.14)
	else:
		_dribble_pulse = 0.0

	var speed_ratio: float = clampf(carrier_speed / 120.0, 0.0, 1.0)
	var touch_wave: float = absf(sin(_dribble_pulse)) * 5.2 * speed_ratio
	var feint_extra: float = 8.0 if _feint_push_timer > 0.0 else 0.0
	var desired_dist: float = lerpf(9.5, 13.5, speed_ratio) + touch_wave + feint_extra

	var target_pos: Vector2 = holder.global_position + _dribble_facing * desired_dist
	var follow_rate: float = lerpf(18.0, 13.5, speed_ratio)
	var t: float = 1.0 - exp(-follow_rate * delta)
	global_position = global_position.lerp(target_pos, t)
	velocity = carrier_vel
	spin = 0.0

func _check_out_of_bounds() -> void:
	if _out_reported:
		return
	var x: float = global_position.x
	var y: float = global_position.y
	var half_w: float = TacticsHelper.PITCH_HALF_W
	var half_h: float = TacticsHelper.PITCH_HALF_H
	var goal_h: float = TacticsHelper.GOAL_HALF_H

	if absf(y) > half_h + 4.0:
		_out_reported = true
		var prev_holder: Node2D = holder
		holder = null
		owner_changed.emit(null, prev_holder)
		out_of_bounds.emit(&"throw_in", Vector2(clampf(x, -half_w + 18.0, half_w - 18.0), signf(y) * (half_h - 6.0)), last_touch_team)
		return

	if absf(x) > half_w + 4.0 and absf(y) > goal_h + 2.0:
		_out_reported = true
		var prev_holder: Node2D = holder
		holder = null
		owner_changed.emit(null, prev_holder)
		var side_team: int = 0 if x < 0.0 else 1
		var kind: StringName = &"corner" if last_touch_team == side_team else &"goal_kick"
		out_of_bounds.emit(kind, global_position, last_touch_team)

func trigger_feint_touch(feint_dir: Vector2) -> void:
	if feint_dir.length_squared() > 0.01:
		_dribble_facing = feint_dir.normalized()
	_feint_push_timer = 0.22
	if is_instance_valid(holder):
		global_position = holder.global_position + _dribble_facing * 15.0

func is_gk_shielded() -> bool:
	return _gk_shield_timer > 0.0

func can_be_claimed_by(candidate: Node2D, is_goalkeeper: bool = false) -> bool:
	if _out_reported:
		return false
	if holder != null:
		return false
	if is_goalkeeper:
		if is_airborne_over_gk():
			return false
	else:
		if is_airborne_high():
			return false
	if _pickup_cooldown > 0.0 and candidate == _ignore_claimer:
		return false
	return true

func claim(new_holder: Node2D, team_id: int, initial_facing: Vector2, is_goalkeeper: bool = false) -> void:
	if holder == new_holder or _out_reported:
		return
	var prev_holder: Node2D = holder

	if last_kick_had_pending_eval and is_instance_valid(last_passer_node) and new_holder != last_passer_node:
		last_kick_had_pending_eval = false
		if team_id == last_passer_team:
			var dist: float = last_kick_origin.distance_to(new_holder.global_position)
			var is_fwd: bool = (new_holder.global_position.x - last_kick_origin.x) > 12.0 if team_id == 0 else (new_holder.global_position.x - last_kick_origin.x) < -12.0
			pass_completed.emit(last_passer_node, new_holder, last_kick_kind, dist, is_fwd)
		else:
			pass_intercepted.emit(last_passer_node, new_holder)

	holder = new_holder
	height_z = 0.0
	vel_z = 0.0
	last_touch_node = new_holder
	last_touch_team = team_id
	if is_goalkeeper:
		_gk_shield_timer = 0.65
	if initial_facing.length_squared() > 0.01:
		_dribble_facing = initial_facing.normalized()
	velocity = Vector2.ZERO
	spin = 0.0
	owner_changed.emit(holder, prev_holder)

func update_dribble_facing(facing: Vector2) -> void:
	if facing.length_squared() > 0.01:
		_dribble_facing = facing.normalized()

func kick(
	kicker: Node2D,
	kicker_team: int,
	direction: Vector2,
	launch_speed: float,
	curve_spin: float,
	kick_kind: StringName = &"shot",
	loft_velocity_z: float = 0.0
) -> void:
	var prev_holder: Node2D = holder
	holder = null
	_gk_shield_timer = 0.0
	_ignore_claimer = kicker
	_pickup_cooldown = 0.28
	last_touch_node = kicker
	last_touch_team = kicker_team
	last_passer_node = kicker
	last_passer_team = kicker_team
	last_kick_kind = kick_kind
	last_kick_origin = global_position
	last_kick_had_pending_eval = (kick_kind == &"pass_direct" or kick_kind == &"pass_through" or kick_kind == &"ai_pass" or kick_kind == &"pass_lob")

	var dir_norm: Vector2 = direction.normalized() if direction.length_squared() > 0.001 else _dribble_facing
	if is_instance_valid(kicker):
		global_position = kicker.global_position + dir_norm * 12.0
		reset_physics_interpolation()
	velocity = dir_norm * launch_speed
	spin = curve_spin
	height_z = 1.0 if loft_velocity_z > 0.0 else 0.0
	vel_z = loft_velocity_z
	owner_changed.emit(null, prev_holder)
	kicked.emit(kicker, dir_norm, launch_speed, curve_spin, kick_kind)

func pass_to(
	passer: Node2D,
	passer_team: int,
	target_pos: Vector2,
	curve_spin: float = 0.0,
	kick_kind: StringName = &"pass_direct",
	min_spd: float = 175.0,
	max_spd: float = 340.0,
	loft_z: float = 0.0
) -> void:
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()
	var drag_used: float = air_drag if loft_z > 0.0 else ground_friction
	var needed_speed: float = sqrt(2.0 * drag_used * dist + 72.0 * 72.0)
	var final_speed: float = clampf(needed_speed, min_spd, max_spd)
	var dir: Vector2 = to_target.normalized() if dist > 1.0 else _dribble_facing
	kick(passer, passer_team, dir, final_speed, curve_spin, kick_kind, loft_z)

func knock_loose(tackler: Node2D, tackler_team: int, push_dir: Vector2, impulse_speed: float = 140.0) -> void:
	var prev_holder: Node2D = holder
	holder = null
	_gk_shield_timer = 0.0
	_ignore_claimer = prev_holder
	_pickup_cooldown = 0.55
	last_touch_node = tackler
	last_touch_team = tackler_team
	last_kick_had_pending_eval = false
	height_z = 0.0
	vel_z = 0.0
	var dir_norm: Vector2 = push_dir.normalized() if push_dir.length_squared() > 0.001 else Vector2.LEFT
	velocity = dir_norm * impulse_speed
	spin = 0.0
	owner_changed.emit(null, prev_holder)

func reset_to(pos: Vector2) -> void:
	var prev_holder: Node2D = holder
	holder = null
	_out_reported = false
	_gk_shield_timer = 0.0
	_ignore_claimer = null
	_pickup_cooldown = 0.18
	last_touch_node = null
	last_touch_team = -1
	last_passer_node = null
	last_passer_team = -1
	last_kick_had_pending_eval = false
	height_z = 0.0
	vel_z = 0.0
	velocity = Vector2.ZERO
	spin = 0.0
	global_position = pos
	_update_height_visuals()
	reset_physics_interpolation()
	owner_changed.emit(null, prev_holder)

static func simulate_trajectory(
	start_pos: Vector2,
	direction: Vector2,
	launch_speed: float,
	curve_spin: float,
	friction_val: float,
	spin_decay_val: float,
	magnus_val: float,
	steps: int = 30,
	step_dt: float = 0.032,
	loft_z: float = 0.0,
	grav_z: float = 210.0,
	air_drag_val: float = 48.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var pos: Vector2 = start_pos
	var vel: Vector2 = direction.normalized() * launch_speed
	var s: float = curve_spin
	var hz: float = 1.0 if loft_z > 0.0 else 0.0
	var vz: float = loft_z
	points.append(pos)
	for _i in steps:
		if vel.length() <= 2.0:
			break
		if hz > 0.0 or vz > 0.0:
			vz -= grav_z * step_dt
			hz += vz * step_dt
			if hz <= 0.0:
				hz = 0.0
				vz = -vz * 0.45 if absf(vz) > 26.0 else 0.0
		if absf(s) > 0.01:
			vel = vel.rotated(s * magnus_val * step_dt)
		var d_val: float = air_drag_val if hz > 0.5 else friction_val
		vel = vel.move_toward(Vector2.ZERO, d_val * step_dt)
		s = move_toward(s, 0.0, spin_decay_val * step_dt)
		pos += vel * step_dt
		# Havadan çizgiyi görsel olarak yükseklikle (+X ofset) kavisli göster
		points.append(pos + Vector2(hz * 0.45, 0.0))
	return points
