class_name TacticsHelper
extends RefCounted

enum Role {
	GK,
	DEF,
	MID,
	FWD
}

const PITCH_HALF_W: float = 480.0
const PITCH_HALF_H: float = 270.0
const GOAL_HALF_H: float = 46.0

class FormationSlot:
	var label: String
	var number: int
	var role: Role
	var home_pos: Vector2
	var is_user_slot: bool

	func _init(p_label: String, p_num: int, p_role: Role, p_pos: Vector2, p_user: bool = false) -> void:
		label = p_label
		number = p_num
		role = p_role
		home_pos = p_pos
		is_user_slot = p_user

# Ev sahibi (Takım 0 - Mavi) soldan sağa (+X) hücum eder: 4-2-3-1 / 4-3-3
static func get_home_formation() -> Array[FormationSlot]:
	var slots: Array[FormationSlot] = [
		FormationSlot.new("KL", 1, Role.GK, Vector2(-452.0, 0.0)),
		FormationSlot.new("SLB", 3, Role.DEF, Vector2(-310.0, -165.0)),
		FormationSlot.new("STP", 4, Role.DEF, Vector2(-335.0, -58.0)),
		FormationSlot.new("STP", 5, Role.DEF, Vector2(-335.0, 58.0)),
		FormationSlot.new("SGB", 2, Role.DEF, Vector2(-310.0, 165.0)),
		FormationSlot.new("DOS", 6, Role.MID, Vector2(-180.0, -75.0)),
		FormationSlot.new("MO", 8, Role.MID, Vector2(-150.0, 75.0)),
		# Bizim karakterimiz: 10 Numara (Ofansif Orta Saha / Oyun Kurucu)
		FormationSlot.new("OOS", 10, Role.MID, Vector2(-20.0, 0.0), true),
		FormationSlot.new("SLK", 11, Role.FWD, Vector2(65.0, -155.0)),
		FormationSlot.new("SGK", 7, Role.FWD, Vector2(65.0, 155.0)),
		FormationSlot.new("SNT", 9, Role.FWD, Vector2(130.0, 0.0)),
	]
	return slots

# Deplasman (Takım 1 - Kırmızı) sağdan sola (-X) hücum eder: 4-4-2
static func get_away_formation() -> Array[FormationSlot]:
	var slots: Array[FormationSlot] = [
		FormationSlot.new("KL", 1, Role.GK, Vector2(452.0, 0.0)),
		FormationSlot.new("SGB", 2, Role.DEF, Vector2(315.0, -165.0)),
		FormationSlot.new("STP", 4, Role.DEF, Vector2(340.0, -58.0)),
		FormationSlot.new("STP", 5, Role.DEF, Vector2(340.0, 58.0)),
		FormationSlot.new("SLB", 3, Role.DEF, Vector2(315.0, 165.0)),
		FormationSlot.new("SGK", 7, Role.MID, Vector2(165.0, -165.0)),
		FormationSlot.new("MO", 6, Role.MID, Vector2(185.0, -55.0)),
		FormationSlot.new("MO", 8, Role.MID, Vector2(185.0, 55.0)),
		FormationSlot.new("SLK", 11, Role.MID, Vector2(165.0, 165.0)),
		FormationSlot.new("SNT", 9, Role.FWD, Vector2(40.0, -55.0)),
		FormationSlot.new("SNT", 10, Role.FWD, Vector2(40.0, 55.0)),
	]
	return slots

# FM 2D tarzı dinamik blok kayması: Topun konumuna göre her oyuncunun taktik pozisyonu
static func compute_tactical_anchor(
	home_pos: Vector2,
	role: Role,
	team_id: int,
	ball_pos: Vector2,
	team_has_ball: bool
) -> Vector2:
	var attack_dir: float = 1.0 if team_id == 0 else -1.0

	if role == Role.GK:
		var gx: float = -454.0 if team_id == 0 else 454.0
		var gy: float = clampf(ball_pos.y * 0.28, -GOAL_HALF_H + 8.0, GOAL_HALF_H - 8.0)
		return Vector2(gx, gy)

	var x_influence: float = 0.42
	var y_influence: float = 0.30
	var possession_push: float = 0.0

	match role:
		Role.DEF:
			x_influence = 0.34
			y_influence = 0.24
			possession_push = 55.0 if team_has_ball else -45.0
		Role.MID:
			x_influence = 0.48
			y_influence = 0.32
			possession_push = 75.0 if team_has_ball else -50.0
		Role.FWD:
			x_influence = 0.44
			y_influence = 0.26
			possession_push = 95.0 if team_has_ball else -35.0

	var target_x: float = home_pos.x + ball_pos.x * x_influence + attack_dir * possession_push
	var target_y: float = home_pos.y + ball_pos.y * y_influence

	# Saha içi güvenli sınırlar
	var min_x: float = -PITCH_HALF_W + 40.0
	var max_x: float = PITCH_HALF_W - 40.0
	if role == Role.DEF:
		if team_id == 0:
			max_x = 120.0
		else:
			min_x = -120.0

	return Vector2(
		clampf(target_x, min_x, max_x),
		clampf(target_y, -PITCH_HALF_H + 24.0, PITCH_HALF_H - 24.0)
	)
