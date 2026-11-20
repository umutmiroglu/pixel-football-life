class_name FMSimOverlay
extends Control

signal speed_selected(mult: float)
signal restart_match_requested()
signal trigger_now_requested()
signal social_panel_requested()

@onready var sim_clock_label: Label = %SimClockLabel
@onready var sim_score_label: Label = %SimScoreLabel
@onready var sim_stats_label: Label = %SimStatsLabel
@onready var sim_rating_label: Label = %SimRatingLabel
@onready var sim_stamina_label: Label = %SimStaminaLabel
@onready var sim_coach_label: Label = %SimCoachLabel
@onready var feed_label: RichTextLabel = %FeedLabel
@onready var radar_canvas: Control = %RadarCanvas
@onready var speed_1_btn: Button = %Speed1Btn
@onready var speed_2_btn: Button = %Speed2Btn
@onready var speed_4_btn: Button = %Speed4Btn
@onready var trigger_btn: Button = %TriggerBtn
@onready var social_btn: Button = %SocialBtn

@onready var full_time_panel: PanelContainer = %FullTimePanel
@onready var ft_summary_label: Label = %FTSummaryLabel
@onready var new_match_btn: Button = %NewMatchBtn

# FM 2D Taktik Radarının görsel simülasyonu — top daima oyuncunun ayağına tam oturur!
var _radar_ball: Vector2 = Vector2(0.40, 0.50)
var _radar_possession_team: int = 0
var _radar_holder_idx: int = 6
var _radar_pass_from_pos: Vector2 = Vector2(0.40, 0.50)
var _radar_pass_progress: float = 1.0 # < 1.0 iken top havada/pas halinde hedef oyuncunun canlı ayağına gider
var _radar_pass_speed: float = 2.6
var _radar_hold_timer: float = 0.65

var _radar_home_dots: PackedVector2Array = PackedVector2Array()
var _radar_away_dots: PackedVector2Array = PackedVector2Array()
var _base_home: PackedVector2Array = PackedVector2Array()
var _base_away: PackedVector2Array = PackedVector2Array()
var _radar_user_idx: int = 7
var _feed_lines: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_init_radar_formations()
	radar_canvas.draw.connect(_on_radar_draw)
	speed_1_btn.pressed.connect(func() -> void: speed_selected.emit(1.0))
	speed_2_btn.pressed.connect(func() -> void: speed_selected.emit(2.0))
	speed_4_btn.pressed.connect(func() -> void: speed_selected.emit(4.0))
	trigger_btn.pressed.connect(func() -> void: trigger_now_requested.emit())
	social_btn.pressed.connect(func() -> void: social_panel_requested.emit())
	new_match_btn.pressed.connect(func() -> void: restart_match_requested.emit())
	full_time_panel.visible = false

func _init_radar_formations() -> void:
	_base_home = PackedVector2Array([
		Vector2(0.06, 0.50),
		Vector2(0.22, 0.18), Vector2(0.20, 0.40), Vector2(0.20, 0.60), Vector2(0.22, 0.82),
		Vector2(0.38, 0.35), Vector2(0.40, 0.65),
		Vector2(0.54, 0.50), # 10 Numara (Bizim karakter)
		Vector2(0.64, 0.20), Vector2(0.64, 0.80), Vector2(0.72, 0.50)
	])
	_base_away = PackedVector2Array([
		Vector2(0.94, 0.50),
		Vector2(0.78, 0.18), Vector2(0.80, 0.40), Vector2(0.80, 0.60), Vector2(0.78, 0.82),
		Vector2(0.60, 0.18), Vector2(0.62, 0.40), Vector2(0.62, 0.60), Vector2(0.60, 0.82),
		Vector2(0.45, 0.38), Vector2(0.45, 0.62)
	])
	_radar_home_dots = _base_home.duplicate()
	_radar_away_dots = _base_away.duplicate()
	_radar_ball = _get_holder_foot_pos()

func _process(delta: float) -> void:
	if not visible or full_time_panel.visible:
		return

	# 1. Önce oyuncuları akıcı biçimde blok halinde hareket ettir
	var shift_x: float = (_radar_ball.x - 0.5) * 0.24
	var shift_y: float = (_radar_ball.y - 0.5) * 0.16
	var t_now: float = Time.get_ticks_msec() * 0.0018

	for i in range(1, _radar_home_dots.size()):
		var jitter := Vector2(sin(t_now + i * 1.7) * 0.022, cos(t_now * 0.8 + i * 2.1) * 0.026)
		var target_h := Vector2(clampf(_base_home[i].x + shift_x + jitter.x, 0.10, 0.90), clampf(_base_home[i].y + shift_y + jitter.y, 0.08, 0.92))
		_radar_home_dots[i] = _radar_home_dots[i].lerp(target_h, clampf(delta * 3.2, 0.0, 1.0))

	for i in range(1, _radar_away_dots.size()):
		var jitter_a := Vector2(cos(t_now + i * 1.3) * 0.022, sin(t_now * 0.9 + i * 1.9) * 0.026)
		var target_a := Vector2(clampf(_base_away[i].x + shift_x + jitter_a.x, 0.10, 0.90), clampf(_base_away[i].y + shift_y + jitter_a.y, 0.08, 0.92))
		_radar_away_dots[i] = _radar_away_dots[i].lerp(target_a, clampf(delta * 3.2, 0.0, 1.0))

	# 2. Top ya aktif oyuncunun tam ayağında taşınır ya da alıcının canlı ayağına doğru pas gider!
	var target_foot: Vector2 = _get_holder_foot_pos()
	if _radar_pass_progress < 1.0:
		_radar_pass_progress = minf(_radar_pass_progress + delta * _radar_pass_speed, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - _radar_pass_progress, 2.0)
		_radar_ball = _radar_pass_from_pos.lerp(target_foot, ease_t)
	else:
		# Top tam oyuncunun ayağında!
		_radar_ball = target_foot
		_radar_hold_timer -= delta
		if _radar_hold_timer <= 0.0:
			_start_next_radar_pass()

	radar_canvas.queue_redraw()

func _start_next_radar_pass() -> void:
	_radar_pass_from_pos = _radar_ball
	_radar_pass_progress = 0.0
	_radar_hold_timer = randf_range(0.40, 0.85)

	# %22 ihtimalle top el değiştirir (rakip kapar), %78 aynı takım paslaşır
	if randf() < 0.22:
		_radar_possession_team = 1 - _radar_possession_team
		var new_dots: PackedVector2Array = _radar_home_dots if _radar_possession_team == 0 else _radar_away_dots
		_radar_holder_idx = _find_nearest_dot(new_dots, _radar_ball, -1)
	else:
		var dots: PackedVector2Array = _radar_home_dots if _radar_possession_team == 0 else _radar_away_dots
		var next_idx: int = randi_range(1, dots.size() - 1)
		if next_idx == _radar_holder_idx:
			next_idx = ((next_idx) % (dots.size() - 1)) + 1
		_radar_holder_idx = next_idx

	var dist: float = _radar_pass_from_pos.distance_to(_get_holder_foot_pos())
	_radar_pass_speed = clampf(0.45 / maxf(dist, 0.12), 1.8, 3.8)

func _get_holder_foot_pos() -> Vector2:
	var dots: PackedVector2Array = _radar_home_dots if _radar_possession_team == 0 else _radar_away_dots
	var idx: int = clampi(_radar_holder_idx, 0, dots.size() - 1)
	var foot_offset := Vector2(0.014 if _radar_possession_team == 0 else -0.014, 0.0)
	return dots[idx] + foot_offset

func _find_nearest_dot(dots: PackedVector2Array, pos: Vector2, exclude_idx: int) -> int:
	var best_i: int = 1
	var best_d: float = 999.0
	for i in range(1, dots.size()):
		if i == exclude_idx:
			continue
		var d: float = dots[i].distance_to(pos)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

func _on_radar_draw() -> void:
	var sz: Vector2 = radar_canvas.size
	if sz.x < 10.0 or sz.y < 10.0:
		return

	# Çim zemin ve şeritler
	radar_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.11, 0.31, 0.17, 1.0), true)
	for s in 6:
		if s % 2 == 0:
			var sx: float = sz.x * (float(s) / 6.0)
			radar_canvas.draw_rect(Rect2(Vector2(sx, 0.0), Vector2(sz.x / 6.0, sz.y)), Color(0.13, 0.35, 0.19, 1.0), true)

	# Saha çizgileri
	var lc := Color(0.88, 0.96, 0.88, 0.55)
	radar_canvas.draw_rect(Rect2(Vector2(2, 2), sz - Vector2(4, 4)), lc, false, 1.2)
	radar_canvas.draw_line(Vector2(sz.x * 0.5, 2), Vector2(sz.x * 0.5, sz.y - 2), lc, 1.2)
	radar_canvas.draw_arc(sz * 0.5, sz.y * 0.18, 0.0, TAU, 24, lc, 1.2)
	radar_canvas.draw_rect(Rect2(Vector2(2, sz.y * 0.25), Vector2(sz.x * 0.14, sz.y * 0.5)), lc, false, 1.2)
	radar_canvas.draw_rect(Rect2(Vector2(sz.x * 0.86 - 2, sz.y * 0.25), Vector2(sz.x * 0.14, sz.y * 0.5)), lc, false, 1.2)

	# Pas havadayken şeffaf pas izi çiz
	if _radar_pass_progress < 1.0:
		var from_px := Vector2(_radar_pass_from_pos.x * sz.x, _radar_pass_from_pos.y * sz.y)
		var ball_px := Vector2(_radar_ball.x * sz.x, _radar_ball.y * sz.y)
		radar_canvas.draw_line(from_px, ball_px, Color(1.0, 1.0, 0.85, 0.42), 1.0)

	# 11 Ev Sahibi Oyuncu (Mavi)
	for i in _radar_home_dots.size():
		var pt := Vector2(_radar_home_dots[i].x * sz.x, _radar_home_dots[i].y * sz.y)
		if i == _radar_user_idx:
			radar_canvas.draw_circle(pt, 4.6, Color(1.0, 0.9, 0.2, 0.9))
			radar_canvas.draw_circle(pt, 3.0, Color(0.18, 0.88, 1.0, 1.0))
		elif i == 0:
			radar_canvas.draw_circle(pt, 2.8, Color(0.95, 0.82, 0.2, 1.0))
		else:
			radar_canvas.draw_circle(pt, 2.8, Color(0.22, 0.58, 1.0, 1.0))
		# Top bu oyuncunun ayağındaysa ince beyaz kontrol halkası
		if _radar_possession_team == 0 and i == _radar_holder_idx and _radar_pass_progress >= 1.0:
			radar_canvas.draw_arc(pt, 4.4, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.8), 0.9)

	# 11 Deplasman Oyuncusu (Kırmızı)
	for i in _radar_away_dots.size():
		var pt_a := Vector2(_radar_away_dots[i].x * sz.x, _radar_away_dots[i].y * sz.y)
		var c_a := Color(0.95, 0.55, 0.15, 1.0) if i == 0 else Color(0.92, 0.26, 0.28, 1.0)
		radar_canvas.draw_circle(pt_a, 2.8, c_a)
		if _radar_possession_team == 1 and i == _radar_holder_idx and _radar_pass_progress >= 1.0:
			radar_canvas.draw_arc(pt_a, 4.4, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.8), 0.9)

	# Top (oyuncunun tam ayağında veya havada)
	var bp := Vector2(_radar_ball.x * sz.x, _radar_ball.y * sz.y)
	radar_canvas.draw_circle(bp, 2.2, Color(1.0, 1.0, 0.92, 1.0))

func update_header(minute: int, sim_speed: float, home_g: int, away_g: int, possession_pct: int, home_shots: int, away_shots: int, home_name: String = "EV SAHIBI", away_name: String = "DEPLASMAN") -> void:
	sim_clock_label.text = "%02d'  [%.0fx]" % [minute, sim_speed]
	sim_score_label.text = "%s  %d - %d  %s" % [home_name, home_g, away_g, away_name]
	sim_stats_label.text = "Topa Sahip Olma: %%%d - %%%d   |   Sut: %d - %d" % [possession_pct, 100 - possession_pct, home_shots, away_shots]

func update_ratings(match_rating: float, manager_trust: float, style_name: String) -> void:
	sim_rating_label.text = "PUAN: %.1f" % match_rating
	sim_coach_label.text = "HOCA (%s): %%%d" % [style_name, roundi(manager_trust)]

func update_stamina(current_stam: float, _max_stam: float) -> void:
	var pct: int = roundi(current_stam)
	sim_stamina_label.text = "STAM: %%%d" % pct
	if pct >= 50:
		sim_stamina_label.modulate = Color(0.35, 0.96, 0.5, 1.0)
	elif pct >= 30:
		sim_stamina_label.modulate = Color(1.0, 0.85, 0.28, 1.0)
	else:
		sim_stamina_label.modulate = Color(1.0, 0.32, 0.28, 1.0)

func append_feed(minute_str: String, text: String, hex_color: String = "#dce8f5") -> void:
	_feed_lines.append("[color=%s][b]%s[/b] %s[/color]" % [hex_color, minute_str, text])
	if _feed_lines.size() > 14:
		_feed_lines = _feed_lines.slice(_feed_lines.size() - 14)
	feed_label.text = "\n".join(_feed_lines)

func clear_feed() -> void:
	_feed_lines.clear()
	feed_label.text = ""
	full_time_panel.visible = false

func show_full_time(summary_text: String) -> void:
	ft_summary_label.text = summary_text
	full_time_panel.visible = true
