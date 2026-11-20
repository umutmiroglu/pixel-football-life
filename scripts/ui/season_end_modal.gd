class_name SeasonEndModal
extends PanelContainer

signal negotiate_requested()
signal next_season_requested()

@onready var title_label: Label = %SeasonEndTitle
@onready var summary_label: Label = %SeasonEndSummary
@onready var negotiate_btn: Button = %SeasonNegotiateBtn
@onready var next_season_btn: Button = %SeasonContinueBtn

var _prize_awarded: bool = false

func _ready() -> void:
	visible = false
	negotiate_btn.pressed.connect(_on_negotiate_pressed)
	next_season_btn.pressed.connect(_on_next_season_pressed)

func open_season_end() -> void:
	visible = true
	var rank: int = GameState.get_player_league_rank()
	var prize: int = 2000 if rank == 1 else (1000 if rank <= 3 else 400)
	if not _prize_awarded:
		_prize_awarded = true
		GameState.modify_cash(prize)
		if rank == 1:
			GameState.career_trophies += 1
			GameState.add_career_xp(60)
			GameState.fan_reputation = clampf(GameState.fan_reputation + 15.0, 0.0, 100.0)
			GameState.media_reputation = clampf(GameState.media_reputation + 12.0, 0.0, 100.0)
			GameState.add_pc_news(
				"SAMPIYON %s! (SEZON %d)" % [GameState.current_club_name, GameState.season],
				"%s harika bir sezon gecirdi (%d Gol, %d Asist, %.1f Ort. Puan)! Sampiyonluk primi +%d TL!" % [
					GameState.player_name, GameState.season_goals, GameState.season_assists, GameState.get_season_average_rating(), prize
				]
			)

	var trophy_banner: String = "SAMPIYON OLDUN! [KUPA +2000 TL]" if rank == 1 else (
		"LIGI %d. SIRADA BITIRDIN! [PRIM +%d TL]" % [rank, prize]
	)
	title_label.text = "SEZON %d TAMAMLANDI!" % GameState.season
	title_label.modulate = Color(1.0, 0.9, 0.25, 1.0) if rank == 1 else Color(0.55, 0.94, 1.0, 1.0)

	summary_label.text = (
		"%s\n\n"
		+ "Kulup: %s (%s)\n"
		+ "Oynanan Mac: %d  |  Gol: %d  |  Asist: %d\n"
		+ "Sezon Puan Ortalamasi: %.1f / 10.0\n"
		+ "Toplam Nakit: %d TL  |  Haftalik Pasif Gelir: +%d TL\n\n"
		+ "Yeni sezon oncesi sozlesmeni yenileyebilir veya yurt disina transfer olabilirsin!"
	) % [
		trophy_banner,
		GameState.current_club_name, GameState.current_country_code,
		GameState.season_matches, GameState.season_goals, GameState.season_assists,
		GameState.get_season_average_rating(),
		GameState.cash, GameState.passive_weekly_income
	]

func _on_negotiate_pressed() -> void:
	visible = false
	_prize_awarded = false
	negotiate_requested.emit()

func _on_next_season_pressed() -> void:
	visible = false
	_prize_awarded = false
	next_season_requested.emit()
