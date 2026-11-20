class_name FootballerStats
extends Resource

enum Position {
	CAM,  # 10 Numara / Ofansif Orta Saha
	ST,   # Santrfor / Bitirici
	WING  # Kanat (LW / RW)
}

@export var position: Position = Position.CAM
@export_range(1, 100) var speed: int = 65
@export_range(1, 100) var dribbling: int = 68
@export_range(1, 100) var passing: int = 66
@export_range(1, 100) var vision: int = 65
@export_range(1, 100) var positioning: int = 68
@export_range(1, 100) var shooting: int = 66
@export_range(1, 100) var curve: int = 68
@export_range(1, 100) var physical: int = 62
@export_range(1, 100) var stamina: int = 72
@export_range(1, 100) var marking: int = 62
@export_range(1, 100) var tackling: int = 62
@export_range(1, 100) var team_trust: int = 58
@export var is_physical_anomaly: bool = false

func get_position_code() -> String:
	match position:
		Position.CAM:
			return "CAM (10)"
		Position.ST:
			return "ST (9)"
		Position.WING:
			return "WING (11)"
	return "CAM"

func get_effective_speed() -> float:
	# GDD 2.4 Fizik-Hız Dengesi: Physical > 75 hızda hafif düşüş yaratır (Physical Anomaly hariç!)
	var penalty: float = 0.0
	if not is_physical_anomaly and physical > 75:
		penalty = float(physical - 75) * 0.45
	return clampf(float(speed) - penalty, 15.0, 100.0)

func get_move_speed() -> float:
	return lerpf(62.0, 98.0, get_effective_speed() / 100.0)

func get_dribble_speed() -> float:
	return lerpf(55.0, 88.0, (get_effective_speed() * 0.55 + float(dribbling) * 0.45) / 100.0)

func get_max_kick_speed() -> float:
	return lerpf(275.0, 465.0, float(shooting) / 100.0)

func get_max_spin() -> float:
	return lerpf(0.65, 1.65, float(curve) / 100.0)

func get_stamina_drain_multiplier() -> float:
	return lerpf(1.35, 0.65, float(stamina) / 100.0)

func get_pass_error_radians() -> float:
	return lerpf(0.14, 0.01, float(passing) / 100.0)

static func create_preset(
	p_speed: int,
	p_dribbling: int,
	p_passing: int,
	p_vision: int,
	p_positioning: int,
	p_shooting: int,
	p_curve: int,
	p_marking: int,
	p_tackling: int,
	p_trust: int,
	p_pos: Position = Position.CAM,
	p_physical: int = 64,
	p_stamina: int = 74
) -> FootballerStats:
	var s := FootballerStats.new()
	s.position = p_pos
	s.speed = clampi(p_speed, 1, 100)
	s.dribbling = clampi(p_dribbling, 1, 100)
	s.passing = clampi(p_passing, 1, 100)
	s.vision = clampi(p_vision, 1, 100)
	s.positioning = clampi(p_positioning, 1, 100)
	s.shooting = clampi(p_shooting, 1, 100)
	s.curve = clampi(p_curve, 1, 100)
	s.physical = clampi(p_physical, 1, 100)
	s.stamina = clampi(p_stamina, 1, 100)
	s.marking = clampi(p_marking, 1, 100)
	s.tackling = clampi(p_tackling, 1, 100)
	s.team_trust = clampi(p_trust, 1, 100)
	return s
