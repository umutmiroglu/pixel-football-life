class_name ScenarioGenerator
extends RefCounted

enum ScenarioType {
	COUNTER_THROUGH,    # 1. Hızlı Kontra (3v2) — CAM / ST / WING
	PLAYMAKER_POCKET,   # 2. Yay Önünde Oyun Kur — CAM
	WING_ONE_VS_ONE,    # 3. Kanatta 1v1 İçeri Kırma — WING
	BOX_FINISH,         # 4. Ceza Sahasında Altın Fırsat — ST / CAM
	ONE_ON_ONE_GK,      # 5. Kaleciyle Karşı Karşıya (Aşırtma / Plase!) — ST / WING
	LATE_BOX_ARRIVAL,   # 6. İkinci Dalga / Yaydan Ceza Sahasına Sızma — CAM
	BYLINE_CUTBACK,     # 7. Çizgiye İn & Geriye Çıkar (Cutback / Orta) — WING
	BACK_TO_GOAL_HOLDUP,# 8. Sırtı Dönük Pivot / Top Saklama & Dönüş — ST
	FREE_KICK_EDGE      # 9. Ceza Sahası Önü Serbest Vuruş (Baraj Üstü Falso / Aşırtma!) — Tümü
}

class ActorSpawn:
	var team_id: int
	var number: int
	var label: String
	var role: TacticsHelper.Role
	var pos: Vector2
	var run_target: Vector2

	func _init(
		p_team: int,
		p_num: int,
		p_label: String,
		p_role: TacticsHelper.Role,
		p_pos: Vector2,
		p_run_target: Vector2
	) -> void:
		team_id = p_team
		number = p_num
		label = p_label
		role = p_role
		pos = p_pos
		run_target = p_run_target

class ScenarioData:
	var type: ScenarioType
	var title: String
	var intro_commentary: String
	var player_pos: Vector2
	var ball_start_pos: Vector2
	var passer_index: int = -1
	var actors: Array[ActorSpawn] = []
	var turn_time_limit: float = 10.0

static func generate_scenario(
	player_stats: FootballerStats,
	opp_marking: int,
	preferred_type: int = -1
) -> ScenarioData:
	var s_type: ScenarioType
	if preferred_type >= 0 and preferred_type <= 8:
		s_type = preferred_type as ScenarioType
	else:
		s_type = _pick_weighted_scenario(player_stats)

	var tightness: float = lerpf(24.0, -14.0, float(opp_marking) / 100.0)
	var flip_y: float = -1.0 if randf() < 0.5 else 1.0

	match s_type:
		ScenarioType.COUNTER_THROUGH:
			return _build_counter_through(tightness, flip_y)
		ScenarioType.PLAYMAKER_POCKET:
			return _build_playmaker_pocket(tightness, flip_y)
		ScenarioType.WING_ONE_VS_ONE:
			return _build_wing_1v1(tightness, flip_y)
		ScenarioType.BOX_FINISH:
			return _build_box_finish(tightness, flip_y)
		ScenarioType.ONE_ON_ONE_GK:
			return _build_one_on_one_gk(tightness, flip_y)
		ScenarioType.LATE_BOX_ARRIVAL:
			return _build_late_box_arrival(tightness, flip_y)
		ScenarioType.BYLINE_CUTBACK:
			return _build_byline_cutback(tightness, flip_y)
		ScenarioType.BACK_TO_GOAL_HOLDUP:
			return _build_back_to_goal_holdup(tightness, flip_y)
		ScenarioType.FREE_KICK_EDGE:
			return _build_free_kick_edge(flip_y)

	return _build_playmaker_pocket(tightness, flip_y)

static func _pick_weighted_scenario(player_stats: FootballerStats) -> ScenarioType:
	# Mevkiye (ST / WING / CAM) göre gerçekçi pozisyon havuzu!
	var pool: Array[ScenarioType] = []
	var high_pos: bool = player_stats.positioning >= 70

	match player_stats.position:
		FootballerStats.Position.ST:
			pool = [
				ScenarioType.BOX_FINISH, ScenarioType.BOX_FINISH,
				ScenarioType.ONE_ON_ONE_GK, ScenarioType.ONE_ON_ONE_GK,
				ScenarioType.BACK_TO_GOAL_HOLDUP, ScenarioType.BACK_TO_GOAL_HOLDUP,
				ScenarioType.COUNTER_THROUGH,
				ScenarioType.FREE_KICK_EDGE
			]
			if high_pos:
				pool.append(ScenarioType.ONE_ON_ONE_GK)
				pool.append(ScenarioType.BOX_FINISH)

		FootballerStats.Position.WING:
			pool = [
				ScenarioType.WING_ONE_VS_ONE, ScenarioType.WING_ONE_VS_ONE,
				ScenarioType.BYLINE_CUTBACK, ScenarioType.BYLINE_CUTBACK,
				ScenarioType.COUNTER_THROUGH, ScenarioType.COUNTER_THROUGH,
				ScenarioType.ONE_ON_ONE_GK,
				ScenarioType.FREE_KICK_EDGE
			]
			if high_pos:
				pool.append(ScenarioType.BYLINE_CUTBACK)

		_: # CAM (10 Numara)
			pool = [
				ScenarioType.PLAYMAKER_POCKET, ScenarioType.PLAYMAKER_POCKET,
				ScenarioType.LATE_BOX_ARRIVAL, ScenarioType.LATE_BOX_ARRIVAL,
				ScenarioType.COUNTER_THROUGH, ScenarioType.COUNTER_THROUGH,
				ScenarioType.BOX_FINISH,
				ScenarioType.FREE_KICK_EDGE, ScenarioType.FREE_KICK_EDGE
			]
			if high_pos:
				pool.append(ScenarioType.LATE_BOX_ARRIVAL)

	return pool[randi() % pool.size()]

static func _build_counter_through(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.COUNTER_THROUGH
	d.title = "HIZLI KONTRA! (3v2)"
	d.intro_commentary = "9 numara sol bosluga kosuyor! [C] Ara Pasi, [Sag Tik] Pas veya [Sol Tik] Sut!"
	d.player_pos = Vector2(95.0, 22.0 * flip_y)
	d.ball_start_pos = d.player_pos + Vector2(10.0, 0.0)
	d.passer_index = -1

	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(150.0, -96.0 * flip_y), Vector2(405.0, -58.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "KNT", TacticsHelper.Role.FWD, Vector2(125.0, 128.0 * flip_y), Vector2(385.0, 92.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 8, "MO", TacticsHelper.Role.MID, Vector2(15.0, -25.0 * flip_y), Vector2(225.0, -12.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(454.0, 0.0), Vector2(454.0, 0.0)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(268.0 - tightness * 0.35, -18.0 * flip_y), Vector2(375.0, -14.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(292.0 - tightness * 0.35, 68.0 * flip_y), Vector2(385.0, 48.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 6, "DOS", TacticsHelper.Role.MID, Vector2(15.0 + tightness * 0.25, 58.0 * flip_y), Vector2(175.0, 35.0 * flip_y)))
	return d

static func _build_playmaker_pocket(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.PLAYMAKER_POCKET
	d.title = "YAY ONUNDE OYUN KUR!"
	d.intro_commentary = "Onun acik! Kanatlara [Sag Tik/X], 9'a [C] ara pasi veya [F] havadan orta!"
	d.player_pos = Vector2(205.0, 14.0 * flip_y)
	d.passer_index = 0
	d.ball_start_pos = Vector2(118.0, 46.0 * flip_y)

	d.actors.append(ActorSpawn.new(0, 8, "MO", TacticsHelper.Role.MID, Vector2(110.0, 48.0 * flip_y), Vector2(170.0, 42.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(310.0, -58.0 * flip_y), Vector2(418.0, -34.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 7, "SGK", TacticsHelper.Role.FWD, Vector2(252.0, 128.0 * flip_y), Vector2(398.0, 82.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "SLK", TacticsHelper.Role.FWD, Vector2(248.0, -124.0 * flip_y), Vector2(392.0, -82.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(455.0, 0.0), Vector2(455.0, 0.0)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(355.0, -24.0 * flip_y), Vector2(395.0, -20.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(362.0, 42.0 * flip_y), Vector2(398.0, 38.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 6, "DOS", TacticsHelper.Role.MID, Vector2(302.0 - tightness * 0.4, -8.0 * flip_y), Vector2(310.0, 0.0)))
	d.actors.append(ActorSpawn.new(1, 2, "BEK", TacticsHelper.Role.DEF, Vector2(342.0, 128.0 * flip_y), Vector2(390.0, 96.0 * flip_y)))
	return d

static func _build_wing_1v1(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.WING_ONE_VS_ONE
	d.title = "KANATTA BIRE BIR!"
	d.intro_commentary = "Karsinda tek bek var! [Shift] ile iceri kir veya [F] ile havadan orta kes!"
	d.player_pos = Vector2(232.0, 168.0 * flip_y)
	d.ball_start_pos = d.player_pos + Vector2(10.0, 0.0)
	d.passer_index = -1

	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(308.0, 14.0 * flip_y), Vector2(422.0, 12.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "KNT", TacticsHelper.Role.FWD, Vector2(288.0, -96.0 * flip_y), Vector2(412.0, -54.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 8, "MO", TacticsHelper.Role.MID, Vector2(185.0, 68.0 * flip_y), Vector2(305.0, 56.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(456.0, 14.0 * flip_y), Vector2(456.0, 0.0)))
	d.actors.append(ActorSpawn.new(1, 2, "BEK", TacticsHelper.Role.DEF, Vector2(328.0 - tightness * 0.35, 146.0 * flip_y), Vector2(348.0, 125.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(378.0, 26.0 * flip_y), Vector2(410.0, 20.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(374.0, -48.0 * flip_y), Vector2(410.0, -35.0 * flip_y)))
	return d

static func _build_box_finish(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.BOX_FINISH
	d.title = "CEZA SAHASINDA ALTIN FIRSAT!"
	d.intro_commentary = "Top ayagina geliyor! Falsolu plase [Sol Tik] ya da arka direkteki 9'a [Sag Tik]!"
	d.player_pos = Vector2(315.0, 48.0 * flip_y)
	d.passer_index = 0
	d.ball_start_pos = Vector2(230.0, 108.0 * flip_y)

	d.actors.append(ActorSpawn.new(0, 7, "SGK", TacticsHelper.Role.FWD, Vector2(224.0, 112.0 * flip_y), Vector2(298.0, 95.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(346.0, -68.0 * flip_y), Vector2(424.0, -40.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(455.0, 12.0 * flip_y), Vector2(444.0, 10.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(394.0 - tightness * 0.3, 18.0 * flip_y), Vector2(405.0, 16.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(376.0, -50.0 * flip_y), Vector2(404.0, -34.0 * flip_y)))
	return d

static func _build_one_on_one_gk(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.ONE_ON_ONE_GK
	d.title = "KALECIYLE KARSI KARSIYA!"
	d.intro_commentary = "Savunma arkasina siktin! Kaleci aciliyor — [F] Asirtma veya koseye plase!"
	d.player_pos = Vector2(275.0, 18.0 * flip_y)
	d.ball_start_pos = d.player_pos + Vector2(10.0, 0.0)
	d.passer_index = -1

	d.actors.append(ActorSpawn.new(0, 11, "KNT", TacticsHelper.Role.FWD, Vector2(220.0, -108.0 * flip_y), Vector2(395.0, -54.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 8, "MO", TacticsHelper.Role.MID, Vector2(145.0, 62.0 * flip_y), Vector2(290.0, 42.0 * flip_y)))

	# Kaleci kalesinden biraz öne çıkmış (Aşırtma için ideal!) + arkadan kovalayan stoperler
	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(422.0, 8.0 * flip_y), Vector2(412.0, 8.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(220.0 + tightness * 0.3, -24.0 * flip_y), Vector2(360.0, -10.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(228.0 + tightness * 0.3, 56.0 * flip_y), Vector2(365.0, 32.0 * flip_y)))
	return d

static func _build_late_box_arrival(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.LATE_BOX_ARRIVAL
	d.title = "IKINCI DALGA SIZMASI!"
	d.intro_commentary = "Kanat oyuncun cizgiden yay ustune cikardi! Gelisine falso veya tek pas!"
	d.player_pos = Vector2(272.0, -12.0 * flip_y)
	d.passer_index = 0
	d.ball_start_pos = Vector2(362.0, 148.0 * flip_y)

	d.actors.append(ActorSpawn.new(0, 7, "KNT", TacticsHelper.Role.FWD, Vector2(370.0, 154.0 * flip_y), Vector2(405.0, 122.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(382.0, -44.0 * flip_y), Vector2(428.0, -24.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "SLK", TacticsHelper.Role.FWD, Vector2(315.0, -125.0 * flip_y), Vector2(410.0, -76.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(456.0, 12.0 * flip_y), Vector2(456.0, 0.0)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(390.0, 20.0 * flip_y), Vector2(405.0, 10.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(385.0, -32.0 * flip_y), Vector2(410.0, -25.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 6, "DOS", TacticsHelper.Role.MID, Vector2(316.0 - tightness * 0.3, 44.0 * flip_y), Vector2(330.0, 18.0 * flip_y)))
	return d

static func _build_byline_cutback(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.BYLINE_CUTBACK
	d.title = "CIZGIYE IN & ORTA KES!"
	d.intro_commentary = "Son cizgidesin! Penalti noktasina [Sag Tik/X] yerden veya [F] havadan kes!"
	d.player_pos = Vector2(388.0, 162.0 * flip_y)
	d.ball_start_pos = d.player_pos + Vector2(6.0, -6.0 * flip_y)
	d.passer_index = -1

	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(375.0, 20.0 * flip_y), Vector2(425.0, 8.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 10, "OOS", TacticsHelper.Role.MID, Vector2(318.0, -14.0 * flip_y), Vector2(372.0, -6.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "KNT", TacticsHelper.Role.FWD, Vector2(342.0, -112.0 * flip_y), Vector2(418.0, -56.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(458.0, 24.0 * flip_y), Vector2(456.0, 10.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 2, "BEK", TacticsHelper.Role.DEF, Vector2(412.0, 118.0 * flip_y), Vector2(405.0, 128.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(402.0 - tightness * 0.2, 22.0 * flip_y), Vector2(416.0, 12.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(396.0, -44.0 * flip_y), Vector2(412.0, -34.0 * flip_y)))
	return d

static func _build_back_to_goal_holdup(tightness: float, flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.BACK_TO_GOAL_HOLDUP
	d.title = "SIRTI DONUK PIVOT!"
	d.intro_commentary = "Stoper sirtinda! Topu sakla, [Shift] ile don ya da kanattaki kosucuya [C] birak!"
	d.player_pos = Vector2(288.0, 10.0 * flip_y)
	d.passer_index = 0
	d.ball_start_pos = Vector2(180.0, 16.0 * flip_y)

	d.actors.append(ActorSpawn.new(0, 8, "MO", TacticsHelper.Role.MID, Vector2(172.0, 18.0 * flip_y), Vector2(262.0, 16.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 7, "SGK", TacticsHelper.Role.FWD, Vector2(240.0, 118.0 * flip_y), Vector2(408.0, 68.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "SLK", TacticsHelper.Role.FWD, Vector2(240.0, -118.0 * flip_y), Vector2(408.0, -68.0 * flip_y)))

	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(455.0, 0.0), Vector2(455.0, 0.0)))
	# Stoper tam önümüzde/kaleye yakın, biz sırtımızla topu saklayıp döneceğiz
	d.actors.append(ActorSpawn.new(1, 4, "STP", TacticsHelper.Role.DEF, Vector2(336.0 - tightness * 0.25, 12.0 * flip_y), Vector2(355.0, 10.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "STP", TacticsHelper.Role.DEF, Vector2(364.0, -48.0 * flip_y), Vector2(390.0, -32.0 * flip_y)))
	return d

static func _build_free_kick_edge(flip_y: float) -> ScenarioData:
	var d := ScenarioData.new()
	d.type = ScenarioType.FREE_KICK_EDGE
	d.title = "TEHLIKELI SERBEST VURUS!"
	d.intro_commentary = "Baraj kuruldu! [F] Asirtma + [Q/E] Falso ile 90'a asabilirsin!"
	d.player_pos = Vector2(292.0, 44.0 * flip_y)
	d.ball_start_pos = d.player_pos + Vector2(10.0, -4.0 * flip_y)
	d.passer_index = -1

	d.actors.append(ActorSpawn.new(0, 9, "SNT", TacticsHelper.Role.FWD, Vector2(362.0, -56.0 * flip_y), Vector2(422.0, -28.0 * flip_y)))
	d.actors.append(ActorSpawn.new(0, 11, "KNT", TacticsHelper.Role.FWD, Vector2(342.0, 110.0 * flip_y), Vector2(414.0, 62.0 * flip_y)))

	# Baraj (3 oyuncu yan yana!) + Kaleci uzak köşede
	d.actors.append(ActorSpawn.new(1, 1, "KL", TacticsHelper.Role.GK, Vector2(458.0, -18.0 * flip_y), Vector2(458.0, -14.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 4, "BRJ", TacticsHelper.Role.DEF, Vector2(356.0, 26.0 * flip_y), Vector2(356.0, 26.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 5, "BRJ", TacticsHelper.Role.DEF, Vector2(358.0, 42.0 * flip_y), Vector2(358.0, 42.0 * flip_y)))
	d.actors.append(ActorSpawn.new(1, 6, "BRJ", TacticsHelper.Role.MID, Vector2(354.0, 10.0 * flip_y), Vector2(354.0, 10.0 * flip_y)))
	return d
