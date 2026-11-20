class_name MatchHUD
extends CanvasLayer

signal sim_speed_requested(speed_mult: float)
signal debug_stat_changed(stat_key: StringName, new_value: int)
signal debug_style_cycle_requested()
signal debug_position_cycle_requested()
signal debug_appearance_randomize_requested()

@onready var top_panel: ColorRect = %TopPanel
@onready var bottom_panel: ColorRect = %BottomPanel
@onready var score_label: Label = %ScoreLabel
@onready var clock_label: Label = %ClockLabel
@onready var speed_label: Label = %SpeedLabel
@onready var rating_label: Label = %RatingLabel
@onready var coach_label: Label = %CoachLabel
@onready var commentary_label: Label = %CommentaryLabel
@onready var turn_vignette: Control = %TurnVignette
@onready var bottom_action_bar: HBoxContainer = %BottomActionBar
@onready var power_bar: ProgressBar = %PowerBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var spin_label: Label = %SpinLabel
@onready var lob_label: Label = %LobLabel
@onready var controls_hint: Label = %ControlsHint
@onready var banner_label: Label = %BannerLabel

@onready var debug_panel: PanelContainer = %DebugPanel
@onready var pos_slider: HSlider = %PosSlider
@onready var pos_val: Label = %PosVal
@onready var trust_slider: HSlider = %TrustSlider
@onready var trust_val: Label = %TrustVal
@onready var mark_slider: HSlider = %MarkSlider
@onready var mark_val: Label = %MarkVal
@onready var stam_slider: HSlider = %StamSlider
@onready var stam_val: Label = %StamVal
@onready var style_button: Button = %StyleButton
@onready var position_button: Button = %PositionButton
@onready var appearance_button: Button = %AppearanceButton

var _banner_tween: Tween = null

func _ready() -> void:
	power_bar.min_value = 0.0
	power_bar.max_value = 100.0
	power_bar.value = 0.0
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	banner_label.modulate.a = 0.0
	turn_vignette.visible = false
	bottom_action_bar.visible = false
	debug_panel.visible = false

	pos_slider.value_changed.connect(_on_pos_slider_changed)
	trust_slider.value_changed.connect(_on_trust_slider_changed)
	mark_slider.value_changed.connect(_on_mark_slider_changed)
	stam_slider.value_changed.connect(_on_stam_slider_changed)
	style_button.pressed.connect(_on_style_button_pressed)
	position_button.pressed.connect(_on_position_button_pressed)
	appearance_button.pressed.connect(_on_appearance_button_pressed)

func toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible

func set_action_hud_visible(vis: bool) -> void:
	top_panel.visible = vis
	bottom_panel.visible = vis
	if not vis:
		turn_vignette.visible = false
		bottom_action_bar.visible = false

func sync_debug_values(positioning: int, trust: int, opp_marking: int, start_stamina: int, style_name: String, pos_code: String) -> void:
	pos_slider.set_value_no_signal(positioning)
	pos_val.text = str(positioning)
	trust_slider.set_value_no_signal(trust)
	trust_val.text = str(trust)
	mark_slider.set_value_no_signal(opp_marking)
	mark_val.text = str(opp_marking)
	stam_slider.set_value_no_signal(start_stamina)
	stam_val.text = str(start_stamina)
	style_button.text = "Hoca: %s" % style_name
	position_button.text = "Mevki: %s" % pos_code

func on_match_state_changed(state_name: String, is_player_turn: bool, has_ball: bool) -> void:
	turn_vignette.visible = is_player_turn
	bottom_action_bar.visible = is_player_turn
	if is_player_turn:
		if has_ball:
			controls_hint.text = "Sol:Sut | Sag/X:Pas | C:Ara | F:Asirtma | Shift:Calim"
		else:
			controls_hint.text = "VER-KAC! WASD: Bosa Kac | SPACE: Pas Iste"
	else:
		controls_hint.text = "[1/2/3] Hiz | [TAB] Test | %s" % state_name

func on_clock_updated(minute: int, sim_speed: float) -> void:
	clock_label.text = "%02d'" % minute
	speed_label.text = "[%.0fx]" % sim_speed

func on_score_changed(home_goals: int, away_goals: int) -> void:
	score_label.text = "%s %d - %d %s" % [GameState.current_club_name, home_goals, away_goals, GameState.next_opponent_name]

func on_ratings_updated(match_rating: float, manager_trust: float, style_name: String) -> void:
	rating_label.text = "PUAN: %.1f" % match_rating
	if match_rating >= 7.5:
		rating_label.modulate = Color(0.3, 1.0, 0.45, 1.0)
	elif match_rating < 5.5:
		rating_label.modulate = Color(1.0, 0.42, 0.35, 1.0)
	else:
		rating_label.modulate = Color(1.0, 0.92, 0.55, 1.0)

	coach_label.text = "%s: %%%d" % [style_name, roundi(manager_trust)]
	style_button.text = "Hoca Tarzi: %s" % style_name
	if manager_trust >= 70.0:
		coach_label.modulate = Color(0.45, 0.92, 1.0, 1.0)
	elif manager_trust < 45.0:
		coach_label.modulate = Color(1.0, 0.38, 0.32, 1.0)
	else:
		coach_label.modulate = Color(0.92, 0.92, 0.95, 1.0)

func on_commentary_logged(minute_str: String, text: String, highlight_color: Color) -> void:
	commentary_label.text = "%s  %s" % [minute_str, text]
	commentary_label.modulate = highlight_color

func on_shot_metrics_changed(power_ratio: float, spin_ratio: float, is_charging: bool, is_lob: bool) -> void:
	power_bar.value = power_ratio * 100.0
	var spin_pct: int = roundi(spin_ratio * 100.0)
	if spin_pct < -5:
		spin_label.text = "<<%d%%" % abs(spin_pct)
		spin_label.modulate = Color(0.45, 0.85, 1.0, 1.0)
	elif spin_pct > 5:
		spin_label.text = "%d%%>>" % spin_pct
		spin_label.modulate = Color(1.0, 0.65, 0.35, 1.0)
	else:
		spin_label.text = "DUZ"
		spin_label.modulate = Color(0.85, 0.88, 0.92, 1.0)

	if is_lob:
		lob_label.text = "[HAVADAN]"
		lob_label.modulate = Color(0.4, 0.98, 1.0, 1.0)
	else:
		lob_label.text = "[YERDEN]"
		lob_label.modulate = Color(0.7, 0.78, 0.82, 0.85)

	if is_charging:
		power_bar.modulate = Color(1.0, 0.85, 0.25, 1.0).lerp(Color(1.0, 0.25, 0.2, 1.0), power_ratio)
	else:
		power_bar.modulate = Color(0.3, 0.85, 0.5, 1.0)

func on_stamina_changed(cur: float, _max_val: float) -> void:
	stamina_bar.value = cur
	if cur >= 50.0:
		stamina_bar.modulate = Color(0.3, 0.95, 0.45, 1.0)
	elif cur >= 30.0:
		stamina_bar.modulate = Color(1.0, 0.82, 0.25, 1.0)
	else:
		stamina_bar.modulate = Color(1.0, 0.3, 0.25, 1.0)

func show_banner(message: String, color: Color, hold_time: float = 0.85) -> void:
	banner_label.text = message
	banner_label.modulate = color
	banner_label.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_ignore_time_scale(true)
	_banner_tween.tween_interval(hold_time)
	_banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.30)

func _on_pos_slider_changed(val: float) -> void:
	var iv: int = roundi(val)
	pos_val.text = str(iv)
	debug_stat_changed.emit(&"positioning", iv)

func _on_trust_slider_changed(val: float) -> void:
	var iv: int = roundi(val)
	trust_val.text = str(iv)
	debug_stat_changed.emit(&"team_trust", iv)

func _on_mark_slider_changed(val: float) -> void:
	var iv: int = roundi(val)
	mark_val.text = str(iv)
	debug_stat_changed.emit(&"opp_marking", iv)

func _on_stam_slider_changed(val: float) -> void:
	var iv: int = roundi(val)
	stam_val.text = str(iv)
	debug_stat_changed.emit(&"start_stamina", iv)

func _on_style_button_pressed() -> void:
	debug_style_cycle_requested.emit()

func _on_position_button_pressed() -> void:
	debug_position_cycle_requested.emit()

func _on_appearance_button_pressed() -> void:
	debug_appearance_randomize_requested.emit()
