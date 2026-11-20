class_name MatchCamera
extends Camera2D

enum CameraMode {
	SIM_WIDE,
	PLAYER_FOLLOW,
	PLAYER_AIM,
	RESOLVE_BALL
}

const BEHIND_GOAL_ROTATION: float = PI * 0.5 # +90°: Rakip kale (+X) ekranın tam ÜSTÜNDE, bizim kale (-X) ARKAMIZDA!

@export var decay: float = 1.65
@export var max_offset: Vector2 = Vector2(10.0, 7.0)
@export var max_roll: float = 0.055

var primary_target: Node2D = null
var ball_target: Node2D = null
var current_mode: CameraMode = CameraMode.PLAYER_FOLLOW

var trauma: float = 0.0
var _noise_time: float = 0.0
var _zoom_tween: Tween = null
var _follow_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	ignore_rotation = false
	rotation = BEHIND_GOAL_ROTATION
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	make_current()

func setup_targets(p_player: Node2D, p_ball: Node2D) -> void:
	primary_target = p_player
	ball_target = p_ball
	if primary_target != null:
		# Oyuncuyu ekranın alt %32'sine yerleştir ki önündeki kale ve savunma bloğu genişçe görünsün
		_follow_pos = primary_target.global_position + Vector2(56.0, 0.0)
		global_position = _follow_pos

func set_camera_mode(mode: CameraMode) -> void:
	current_mode = mode
	var target_zoom: Vector2 = Vector2(0.80, 0.80)
	var duration: float = 0.30

	match mode:
		CameraMode.SIM_WIDE:
			target_zoom = Vector2(0.46, 0.46)
			duration = 0.45
		CameraMode.PLAYER_FOLLOW:
			# Kale arkası aksiyon açısı: önündeki tüm koşu yolları ve kale net okunur
			target_zoom = Vector2(0.80, 0.80)
			duration = 0.28
		CameraMode.PLAYER_AIM:
			# Dur-Seç anında nişan ve falso için hafif yakınlaşma
			target_zoom = Vector2(0.94, 0.94)
			duration = 0.22
		CameraMode.RESOLVE_BALL:
			target_zoom = Vector2(0.76, 0.76)
			duration = 0.26

	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_ignore_time_scale(true)
	_zoom_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(self, "zoom", target_zoom, duration)

func punch_zoom(boost: float = 0.09) -> void:
	# Mükemmel çalım veya sert vuruşta kısa sinematik zoom darbesi
	var base_z: Vector2 = zoom
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	zoom = base_z + Vector2(boost, boost)
	_zoom_tween = create_tween()
	_zoom_tween.set_ignore_time_scale(true)
	_zoom_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(self, "zoom", base_z, 0.24)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	var real_dt: float = delta / maxf(Engine.time_scale, 0.0001)
	var desired: Vector2 = _follow_pos

	match current_mode:
		CameraMode.SIM_WIDE:
			if is_instance_valid(ball_target):
				desired = ball_target.global_position * 0.65
		CameraMode.PLAYER_FOLLOW:
			if is_instance_valid(primary_target) and is_instance_valid(ball_target):
				# Kale arkası framing: oyuncu ekranın alt kısmında, kaleye (+X) doğru +56 px look-ahead!
				var focus: Vector2 = primary_target.global_position.lerp(ball_target.global_position, 0.32)
				desired = focus + Vector2(56.0, 0.0)
		CameraMode.PLAYER_AIM:
			if is_instance_valid(primary_target):
				var mouse_delta: Vector2 = (get_global_mouse_position() - primary_target.global_position).limit_length(55.0)
				desired = primary_target.global_position + Vector2(48.0, 0.0) + mouse_delta * 0.42
		CameraMode.RESOLVE_BALL:
			if is_instance_valid(ball_target):
				desired = ball_target.global_position + Vector2(22.0, 0.0)

	var follow_rate: float = 6.0 if current_mode == CameraMode.SIM_WIDE else 9.0
	var t: float = 1.0 - exp(-follow_rate * real_dt)
	_follow_pos = _follow_pos.lerp(desired, t)
	global_position = _follow_pos

func _process(delta: float) -> void:
	if trauma <= 0.0:
		rotation = BEHIND_GOAL_ROTATION
		return
	var real_dt: float = delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - decay * real_dt, 0.0)
	var shake: float = trauma * trauma
	_noise_time += real_dt * 34.0
	offset = Vector2(
		max_offset.x * shake * sin(_noise_time * 1.7),
		max_offset.y * shake * sin(_noise_time * 2.3)
	)
	rotation = BEHIND_GOAL_ROTATION + max_roll * shake * sin(_noise_time * 1.1)
	if trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = BEHIND_GOAL_ROTATION
