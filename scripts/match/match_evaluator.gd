class_name MatchEvaluator
extends Node

signal ratings_updated(match_rating: float, manager_trust: float, style_name: String)
signal coach_feedback_emitted(message: String, is_positive: bool)

enum ManagerStyle {
	TIKI_TAKA,      # Kısa pas & ver-kaç sever, bencil uzak şut ve çalım kaybından nefret eder
	DIRECT_COUNTER, # Dikey ara pası & hızlı şut sever, yavaş yana paslardan hoşlanmaz
	FREE_FLAIR      # Çalım, falsolu vuruş ve bireysel yaratıcılığı ödüllendirir
}

@export var current_style: ManagerStyle = ManagerStyle.TIKI_TAKA

var match_rating: float = 6.0
var manager_trust: float = 65.0

var passes_completed: int = 0
var key_passes: int = 0
var dribbles_won: int = 0
var shots_taken: int = 0
var goals_scored: int = 0
var assists_made: int = 0
var turnovers: int = 0

func get_style_name() -> String:
	match current_style:
		ManagerStyle.TIKI_TAKA:
			return "Tiki-Taka (Pas)"
		ManagerStyle.DIRECT_COUNTER:
			return "Dikey / Kontra"
		ManagerStyle.FREE_FLAIR:
			return "Ozgur Yildiz"
	return "Dengeli"

func set_manager_style(new_style: ManagerStyle) -> void:
	current_style = new_style
	_emit_state()

func reset_match() -> void:
	match_rating = 6.0
	manager_trust = 65.0
	passes_completed = 0
	key_passes = 0
	dribbles_won = 0
	shots_taken = 0
	goals_scored = 0
	assists_made = 0
	turnovers = 0
	_emit_state()

func record_pass_completed(is_through_ball: bool, pass_distance: float, is_forward: bool) -> void:
	passes_completed += 1
	var rating_delta: float = 0.28 if is_through_ball else 0.14
	if is_through_ball:
		key_passes += 1
	_add_rating(rating_delta)

	var trust_delta: float = 0.0
	match current_style:
		ManagerStyle.TIKI_TAKA:
			if pass_distance < 210.0:
				trust_delta = 3.5
				coach_feedback_emitted.emit("Hoca kenardan alkisliyor: 'Harika pas ritmi!'", true)
			else:
				trust_delta = 1.5
		ManagerStyle.DIRECT_COUNTER:
			if is_through_ball or (is_forward and pass_distance >= 130.0):
				trust_delta = 5.0
				coach_feedback_emitted.emit("Hoca memnun: 'Iste bu! Savunmayi dikine deldik!'", true)
			elif not is_forward:
				trust_delta = -2.0
				coach_feedback_emitted.emit("Hoca ellerini acti: 'Geri oynama, ileri bak!'", false)
		ManagerStyle.FREE_FLAIR:
			trust_delta = 3.0 if is_through_ball else 0.8

	_add_trust(trust_delta)

func record_shot(distance_to_goal: float, spin_magnitude: float, had_open_teammate: bool) -> void:
	shots_taken += 1
	_add_rating(0.15)

	match current_style:
		ManagerStyle.TIKI_TAKA:
			if distance_to_goal > 220.0 and had_open_teammate:
				_add_trust(-6.0)
				coach_feedback_emitted.emit("Hoca ofkeli: 'Bosta arkadasin vardi, neden uzaktan vurdun?!'", false)
			elif distance_to_goal <= 165.0:
				_add_trust(2.5)
		ManagerStyle.DIRECT_COUNTER:
			if distance_to_goal <= 250.0:
				_add_trust(3.0)
		ManagerStyle.FREE_FLAIR:
			if spin_magnitude >= 0.45:
				_add_trust(4.5)
				coach_feedback_emitted.emit("Hoca gulumsuyor: 'Klas bir falso denemesi!'", true)
			else:
				_add_trust(1.5)

func record_dribble_burst_success() -> void:
	dribbles_won += 1
	_add_rating(0.24)
	match current_style:
		ManagerStyle.TIKI_TAKA:
			_add_trust(0.5)
		ManagerStyle.DIRECT_COUNTER:
			_add_trust(2.0)
		ManagerStyle.FREE_FLAIR:
			_add_trust(4.5)
			coach_feedback_emitted.emit("Hoca hayran kaldi: 'Bileklerine saglik!'", true)

func record_goal(by_user: bool) -> void:
	if by_user:
		goals_scored += 1
		_add_rating(1.15)
		_add_trust(8.0)
		coach_feedback_emitted.emit("Hoca yedek kulubesinden firladi: 'MUTHIS GOL!'", true)
	else:
		_add_rating(0.20)
		_add_trust(2.0)

func record_assist() -> void:
	assists_made += 1
	_add_rating(0.90)
	_add_trust(9.0)
	coach_feedback_emitted.emit("Hoca: 'Altin degerinde asist!'", true)

func record_turnover(by_pass_intercept: bool) -> void:
	turnovers += 1
	_add_rating(-0.28)
	var penalty: float = -4.0
	if current_style == ManagerStyle.TIKI_TAKA:
		penalty = -6.5 if not by_pass_intercept else -5.0
		coach_feedback_emitted.emit("Hoca sinirlendi: 'Topu bu kadar kolay kaybedemezsin!'", false)
	elif current_style == ManagerStyle.DIRECT_COUNTER:
		penalty = -3.5
	else:
		penalty = -2.5
	_add_trust(penalty)

func _add_rating(delta_val: float) -> void:
	match_rating = clampf(match_rating + delta_val, 1.0, 10.0)
	_emit_state()

func _add_trust(delta_val: float) -> void:
	manager_trust = clampf(manager_trust + delta_val, 0.0, 100.0)
	_emit_state()

func _emit_state() -> void:
	ratings_updated.emit(match_rating, manager_trust, get_style_name())
