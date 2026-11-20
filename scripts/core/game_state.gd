extends Node

signal day_advanced(total_day: int, week: int, day_of_week: int)
signal time_changed(minutes_from_midnight: int)
signal passed_out_at_night()
signal player_resources_changed()
signal pc_inbox_updated()
signal status_effects_changed()

const SEASON_WEEKS: int = 7
const WAKE_UP_MINUTES: int = 8 * 60     # 08:00
const PASS_OUT_MINUTES: int = 26 * 60   # 02:00 (ertesi gece)
const SECONDS_PER_TEN_MINUTES: float = 2.0 # 2 saniye = 10 oyun dakikası!
const DAY_NAMES: PackedStringArray = [
	"", "Pazartesi", "Sali", "Carsamba", "Persembe", "Cuma", "Cumartesi", "Pazar"
]

# Kariyer ve Takvim
var season: int = 1
var week: int = 1
var day_of_week: int = 3 # Çarşamba (Serbest Gün)
var total_days: int = 1
var weeks_at_club: int = 1
var current_time_minutes: int = WAKE_UP_MINUTES
var _clock_accum: float = 0.0
var _pass_out_triggered: bool = false
var trained_today: bool = false
var extra_shoot_done_today: bool = false
var interviewed_today: bool = false
var played_console_today: bool = false
var season_completed_pending: bool = false
var current_interior_id: StringName = &"home"
var training_deck_mode: StringName = &"team"

# Faz 6: Romantizm, Transfer Draması & Medya Krizleri
var romance_partner_name: String = ""
var romance_status: StringName = &"none" # none, dating, moved_together, long_distance, broken_up
var pending_romance_transfer_drama: bool = false
var pending_crisis_tag: String = ""
var world_archetypes: Dictionary = {}

# Ülke & Kulüp Kimliği (Transfer olunca ülke kodu değişir -> Tüm isimler o ülkeye göre yenilenir!)
var current_country_code: String = "TR"
var current_club_name: String = "Kasaba Spor"
var next_opponent_name: String = "Anadolu FK"
var fixture_opponents: Array[String] = []

# Oyuncu Profili & Sözleşme
var player_name: String = "Umut"
var player_age: int = 19
var player_stats: FootballerStats = null
var player_appearance: CharacterAppearance = null
var current_stamina: float = 100.0
var max_stamina: float = 100.0
var cash: int = 1200
var weekly_wage: int = 450
var goal_bonus: int = 250
var contract_seasons_left: int = 1
var starter_guarantee: bool = false
var passive_weekly_income: int = 0
var owned_items: Array[StringName] = []

# İtibarlar & Hoca Tarzı
var manager_style: int = MatchEvaluator.ManagerStyle.TIKI_TAKA
var manager_trust: float = 65.0
var fan_reputation: float = 45.0
var media_reputation: float = 50.0
var locker_room_morale: float = 65.0

# Durum Etkileri & Maç Modifiyerleri
var active_status_effects: Array[StringName] = []
var story_flags: Dictionary[String, bool] = {}
var pending_match_modifiers: Dictionary = {}

# Evdeki PC Hub'ı Verileri
var pc_messages: Array[Dictionary] = []
var pc_news: Array[Dictionary] = []
var pc_social_posts: Array[Dictionary] = []
var league_table: Array[Dictionary] = []
var shop_catalog: Array[Dictionary] = []

# Kariyer İstatistikleri & RPG Seviye Sistemi
var career_level: int = 1
var career_xp: int = 0
var free_stat_points: int = 0
var career_total_goals: int = 0
var career_total_assists: int = 0
var career_total_matches: int = 0
var career_trophies: int = 0
var countries_played: Array[String] = ["TR"]

var season_goals: int = 0
var season_assists: int = 0
var season_matches: int = 0
var season_rating_sum: float = 0.0
var last_match_summary: String = ""

var pending_town_spawn: StringName = &"home"

func _ready() -> void:
	_load_shop_catalog()
	_load_world_archetypes()
	_init_new_career_defaults("", FootballerStats.Position.CAM)

func _load_world_archetypes() -> void:
	world_archetypes.clear()
	var path: String = "res://data/json/world_archetypes.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var arch: Variant = (parsed as Dictionary).get("archetypes", {})
		if arch is Dictionary:
			world_archetypes = arch as Dictionary

func get_current_world_archetype() -> Dictionary:
	return world_archetypes.get(current_country_code, world_archetypes.get("TR", {
		"city_type": "Anadolu Kasabasi",
		"tint": [1.0, 1.0, 1.0, 1.0],
		"weather": "clear",
		"square_label": "KASABA MEYDANI",
		"vibe_note": ""
	})) as Dictionary

func has_item(item_id: StringName) -> bool:
	return item_id in owned_items

func _load_shop_catalog() -> void:
	shop_catalog.clear()
	var path: String = "res://data/json/shop_items.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for item in (parsed as Dictionary).get("items", []):
			if item is Dictionary:
				shop_catalog.append(item as Dictionary)

func start_new_career(
	chosen_name: String,
	chosen_position: FootballerStats.Position,
	custom_appearance: CharacterAppearance = null,
	bonus_stats: Dictionary = {}
) -> void:
	_init_new_career_defaults(chosen_name, chosen_position)
	if custom_appearance != null:
		player_appearance = custom_appearance
	for stat_key in bonus_stats.keys():
		var pts: int = int(bonus_stats[stat_key])
		if pts > 0:
			add_stat_delta(str(stat_key), pts)
	UniverseDB.generate_town_cast_for_country(current_country_code)
	QuestDirector.reset_all()
	save_to_disk()
	player_resources_changed.emit()

func get_xp_for_next_level() -> int:
	return 100 + (career_level - 1) * 35

func add_career_xp(amount: int) -> bool:
	if amount <= 0:
		return false
	career_xp += amount
	var leveled_up: bool = false
	var need: int = get_xp_for_next_level()
	while career_xp >= need:
		career_xp -= need
		career_level += 1
		free_stat_points += 2
		leveled_up = true
		need = get_xp_for_next_level()
	# Seviye sistemi arka planda birikir — puanlar gece uyundugunda dagitilir!
	player_resources_changed.emit()
	return leveled_up

func tick_clock(delta: float, is_paused: bool) -> void:
	if is_paused or _pass_out_triggered:
		return
	_clock_accum += delta
	while _clock_accum >= SECONDS_PER_TEN_MINUTES:
		_clock_accum -= SECONDS_PER_TEN_MINUTES
		advance_time_minutes(10)

func advance_time_minutes(mins: int) -> void:
	if mins <= 0:
		return
	current_time_minutes = mini(current_time_minutes + mins, PASS_OUT_MINUTES)
	time_changed.emit(current_time_minutes)
	if current_time_minutes >= PASS_OUT_MINUTES and not _pass_out_triggered:
		_pass_out_triggered = true
		passed_out_at_night.emit()

func get_time_string() -> String:
	var wrapped: int = current_time_minutes % (24 * 60)
	var hh: int = wrapped / 60
	var mm: int = wrapped % 60
	return "%02d:%02d" % [hh, mm]

func get_daylight_tint() -> Color:
	# 08:00..16:30 parlak gunduz -> 16:30..19:30 sicak gunbatimi -> 19:30..02:00 lacivert gece
	if current_time_minutes < 16 * 60 + 30:
		return Color(1.0, 1.0, 1.0, 1.0)
	if current_time_minutes < 19 * 60 + 30:
		var t: float = float(current_time_minutes - (16 * 60 + 30)) / 180.0
		return Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.0, 0.76, 0.56, 1.0), t)
	if current_time_minutes < 21 * 60 + 30:
		var t2: float = float(current_time_minutes - (19 * 60 + 30)) / 120.0
		return Color(1.0, 0.76, 0.56, 1.0).lerp(Color(0.38, 0.44, 0.70, 1.0), t2)
	return Color(0.32, 0.38, 0.62, 1.0)

func spend_stat_point(stat_name: String) -> String:
	if free_stat_points <= 0:
		return ""
	var note: String = add_stat_delta(stat_name, 1)
	if not note.is_empty():
		free_stat_points -= 1
		SoundFX.play_click()
		player_resources_changed.emit()
		save_to_disk()
	return note

func export_career_legacy() -> String:
	var title_rank: String = "Dunya Efsanesi" if (career_trophies >= 3 or career_total_goals >= 30) else (
		"Yildiz 10 Numara" if (career_trophies >= 1 or career_total_goals >= 12) else "Kasaba Emektari"
	)
	var legacy: Dictionary = {
		"schema_version": 1,
		"legacy_title": title_rank,
		"player_name": player_name,
		"retired_age": player_age,
		"position": player_stats.get_position_code() if player_stats != null else "CAM",
		"career_level": career_level,
		"seasons_played": season,
		"career_total_matches": career_total_matches,
		"career_total_goals": career_total_goals,
		"career_total_assists": career_total_assists,
		"career_trophies": career_trophies,
		"countries_played": countries_played,
		"final_club": current_club_name,
		"final_country": current_country_code,
		"final_cash": cash,
		"passive_weekly_income": passive_weekly_income,
		"fan_reputation": roundi(fan_reputation),
		"media_reputation": roundi(media_reputation),
		"romance_status": String(romance_status),
		"romance_partner": romance_partner_name
	}
	var path: String = "user://career_legacy.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(legacy, "\t"))
		f.flush()
		f.close()
		return ProjectSettings.globalize_path(path)
	return ""

func _init_new_career_defaults(chosen_name: String = "", chosen_position: FootballerStats.Position = FootballerStats.Position.CAM) -> void:
	NameGenerator.reset_used_names()
	season = 1
	week = 1
	day_of_week = 3 # Çarşamba (İlk gün serbest gün -> kasabayı keşfet, ilk olayı gör!)
	total_days = 1
	weeks_at_club = 1
	current_time_minutes = WAKE_UP_MINUTES
	_clock_accum = 0.0
	_pass_out_triggered = false
	trained_today = false
	extra_shoot_done_today = false
	interviewed_today = false
	played_console_today = false
	season_completed_pending = false
	romance_partner_name = ""
	romance_status = &"none"
	pending_romance_transfer_drama = false
	pending_crisis_tag = ""

	current_country_code = "TR"
	player_name = chosen_name.strip_edges()
	if player_name.is_empty():
		player_name = NameGenerator.generate_male_name(current_country_code, false)
	player_age = 19
	current_club_name = NameGenerator.generate_club_name(current_country_code)

	match chosen_position:
		FootballerStats.Position.ST:
			player_stats = FootballerStats.create_preset(76, 72, 68, 70, 82, 82, 74, 44, 44, 66, FootballerStats.Position.ST)
		FootballerStats.Position.WING:
			player_stats = FootballerStats.create_preset(84, 82, 72, 74, 76, 74, 78, 46, 46, 66, FootballerStats.Position.WING)
		_:
			player_stats = FootballerStats.create_preset(74, 78, 80, 82, 76, 76, 80, 50, 48, 66, FootballerStats.Position.CAM)

	# GDD 2.4: Nadir (%10) Fiziksel Anomali genetik özelliği
	player_stats.is_physical_anomaly = (randf() < 0.10)
	player_appearance = CharacterAppearance.create_random(Color(0.14, 0.84, 0.98, 1.0), Color(0.95, 0.97, 1.0, 1.0), 1010)

	current_stamina = 100.0
	max_stamina = 100.0
	cash = 1200
	weekly_wage = 450
	goal_bonus = 250
	contract_seasons_left = 1
	starter_guarantee = false
	passive_weekly_income = 0
	owned_items.clear()

	manager_trust = 65.0
	fan_reputation = 45.0
	media_reputation = 50.0
	locker_room_morale = 65.0
	active_status_effects.clear()
	story_flags.clear()
	pending_match_modifiers.clear()

	season_goals = 0
	season_assists = 0
	season_matches = 0
	season_rating_sum = 0.0
	career_level = 1
	career_xp = 0
	free_stat_points = 0
	career_total_goals = 0
	career_total_assists = 0
	career_total_matches = 0
	career_trophies = 0
	countries_played = ["TR"]
	last_match_summary = ""
	pending_town_spawn = &"home"

	_init_league_table()
	_init_starter_pc_feeds()

func _init_league_table() -> void:
	league_table.clear()
	fixture_opponents.clear()
	league_table.append({ "name": current_club_name, "played": 0, "pts": 0, "gd": 0, "is_player_club": true })
	for _i in SEASON_WEEKS:
		var opp_club: String = NameGenerator.generate_club_name(current_country_code)
		league_table.append({
			"name": opp_club,
			"played": 0,
			"pts": 0,
			"gd": 0,
			"is_player_club": false
		})
		fixture_opponents.append(opp_club)
	fixture_opponents.shuffle()
	next_opponent_name = fixture_opponents[0] if not fixture_opponents.is_empty() else "Anadolu FK"

func _init_starter_pc_feeds() -> void:
	var anomaly_note: String = " [Nadir Genetik: FIZIKSEL ANOMALI!]" if player_stats.is_physical_anomaly else ""
	pc_messages = [
		{
			"sender": "Kulup Sekreterligi",
			"title": "Hos Geldin %s!" % player_name,
			"text": "%s formasiyla Sezon %d basladi (%d haftalik lig)!%s Antrenman gunlerinde otobusle tesislerde calis, serbest gunlerde kasabayi gez, Pazar gunu stadyuma cik!" % [
				current_club_name, season, SEASON_WEEKS, anomaly_note
			],
			"day": total_days
		}
	]
	pc_news = [
		{
			"headline": "%s Yeni Genc Yetenegi %s (%s) Ile Sozlesme Imzaladi" % [current_club_name, player_name, player_stats.get_position_code()],
			"text": "Ligin iddiali ekibi %s, %d yasindaki yetenegi kadrosuna katti. Ilk rakip: %s." % [current_club_name, player_age, next_opponent_name],
			"day": total_days
		}
	]
	pc_social_posts = [
		{
			"author": "@KasabaTribunu",
			"tag": "#YeniSezon",
			"text": "Yeni transfer %s bakalim bu %d haftalik maratonda bizi sampiyonluga tasiyabilecek mi?" % [player_name, SEASON_WEEKS],
			"day": total_days
		}
	]

func get_day_label() -> String:
	var d_name: String = DAY_NAMES[clampi(day_of_week, 1, 7)]
	return "S%d H%d/%d — %s (%s)" % [season, mini(week, SEASON_WEEKS), SEASON_WEEKS, d_name, get_day_type_label()]

func get_day_type_label() -> String:
	if day_of_week == 7:
		return "MAC GUNU!"
	if day_of_week in [1, 2, 4]:
		return "Antrenman"
	return "Serbest Gun"

func is_match_day() -> bool:
	return day_of_week == 7

func is_training_day() -> bool:
	return day_of_week in [1, 2, 4]

func is_free_day() -> bool:
	return day_of_week in [3, 5, 6]

func get_player_league_rank() -> int:
	for i in range(league_table.size()):
		if bool(league_table[i].get("is_player_club", false)):
			return i + 1
	return 1

func get_season_average_rating() -> float:
	if season_matches <= 0:
		return 6.5
	return season_rating_sum / float(season_matches)

func has_status(st: StringName) -> bool:
	var low: String = String(st).to_lower()
	for s in active_status_effects:
		if String(s).to_lower() == low:
			return true
	return false

func add_status(st: StringName) -> void:
	if not has_status(st):
		active_status_effects.append(st)
		status_effects_changed.emit()

func clear_status(st: StringName) -> void:
	var low: String = String(st).to_lower()
	for i in range(active_status_effects.size() - 1, -1, -1):
		if String(active_status_effects[i]).to_lower() == low:
			active_status_effects.remove_at(i)
	status_effects_changed.emit()

func modify_cash(delta_val: int) -> void:
	cash = maxi(cash + delta_val, 0)
	player_resources_changed.emit()

func modify_stamina(delta_val: float) -> void:
	current_stamina = clampf(current_stamina + delta_val, 5.0, max_stamina)
	player_resources_changed.emit()

func set_stamina(val: float) -> void:
	current_stamina = clampf(val, 5.0, max_stamina)
	player_resources_changed.emit()

func add_flag(flag_name: String) -> void:
	story_flags[flag_name] = true

func has_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)

func add_stat_delta(stat_name: String, delta_val: int) -> String:
	if player_stats == null or delta_val == 0:
		return ""
	var prev_eff_spd: float = player_stats.get_effective_speed()
	match stat_name:
		"speed": player_stats.speed = clampi(player_stats.speed + delta_val, 1, 100)
		"dribbling": player_stats.dribbling = clampi(player_stats.dribbling + delta_val, 1, 100)
		"passing": player_stats.passing = clampi(player_stats.passing + delta_val, 1, 100)
		"vision": player_stats.vision = clampi(player_stats.vision + delta_val, 1, 100)
		"positioning": player_stats.positioning = clampi(player_stats.positioning + delta_val, 1, 100)
		"shooting": player_stats.shooting = clampi(player_stats.shooting + delta_val, 1, 100)
		"curve": player_stats.curve = clampi(player_stats.curve + delta_val, 1, 100)
		"physical": player_stats.physical = clampi(player_stats.physical + delta_val, 1, 100)
		"stamina": player_stats.stamina = clampi(player_stats.stamina + delta_val, 1, 100)
		_: return ""

	var note: String = "%s %+d" % [stat_name.capitalize(), delta_val]
	if stat_name == "physical" and player_stats.get_effective_speed() < prev_eff_spd - 0.1:
		note += " (Yuksek kas kutlesi hizini hafifce azaltti!)"
	player_resources_changed.emit()
	return note

func purchase_shop_item(item_id: StringName) -> Dictionary:
	for item in shop_catalog:
		if StringName(str(item.get("id", ""))) != item_id:
			continue
		var is_consumable: bool = bool(item.get("consumable", false))
		if not is_consumable and (item_id in owned_items):
			return { "ok": false, "message": "Bu esyaya zaten sahipsin!" }
		var price: int = int(item.get("price", 0))
		if cash < price:
			return { "ok": false, "message": "Yeterli nakit yok! (%d TL gerekli)" % price }

		cash -= price
		if not is_consumable:
			owned_items.append(item_id)

		var eff: Dictionary = item.get("effects", {})
		if eff.has("stat"):
			add_stat_delta(str(eff["stat"]), int(eff.get("stat_delta", 0)))
		if eff.has("stat2"):
			add_stat_delta(str(eff["stat2"]), int(eff.get("stat2_delta", 0)))
		if bool(eff.get("full_recovery", false)):
			clear_status(&"Hangover")
			clear_status(&"HangoverActive")
			current_stamina = max_stamina
		if eff.has("max_stamina_delta"):
			max_stamina = clampf(max_stamina + float(eff["max_stamina_delta"]), 100.0, 140.0)
			current_stamina = max_stamina
		if eff.has("passive_income_delta"):
			passive_weekly_income += int(eff["passive_income_delta"])
		if eff.has("fan_rep_delta"):
			fan_reputation = clampf(fan_reputation + float(eff["fan_rep_delta"]), 0.0, 100.0)
			add_pc_social("@KasabaMagazin", "#LuksHayat", "%s yeni aldigi %s ile kasaba caddelerinde goruntulendi!" % [player_name, str(item["name"])])
		if eff.has("media_rep_delta"):
			media_reputation = clampf(media_reputation + float(eff["media_rep_delta"]), 0.0, 100.0)

		SoundFX.play_cash()
		player_resources_changed.emit()
		return { "ok": true, "message": "%s satin alindi!" % str(item.get("name", "Esya")) }
	return { "ok": false, "message": "Esya bulunamadi." }

func apply_signed_contract(
	new_club_name: String,
	new_country_code: String,
	new_wage: int,
	new_goal_bonus: int,
	new_seasons: int,
	new_starter: bool,
	is_transfer: bool
) -> void:
	weekly_wage = new_wage
	goal_bonus = new_goal_bonus
	contract_seasons_left = new_seasons
	starter_guarantee = new_starter

	if is_transfer:
		if romance_status == &"dating" and not romance_partner_name.is_empty():
			pending_romance_transfer_drama = true
		current_club_name = new_club_name
		current_country_code = new_country_code
		if not (current_country_code in countries_played):
			countries_played.append(current_country_code)
		weeks_at_club = 1
		manager_trust = 62.0
		NameGenerator.reset_used_names()
		_init_league_table()
		UniverseDB.generate_town_cast_for_country(current_country_code)
		add_pc_news(
			"FLAS TRANSFER: %s -> %s (%s)!" % [player_name, current_club_name, current_country_code],
			"Yeni haftalik maas %d TL, gol primi %d TL. Yeni ulkede yepyeni bir kadro seni bekliyor!" % [weekly_wage, goal_bonus]
		)
		add_pc_social("@TransferFirtinasi", "#ResmiAciklama", "%s resmen %s (%s) formasini giydi! Yeni ligde basarilar!" % [player_name, current_club_name, current_country_code])
	else:
		add_pc_news(
			"SOZLESME YENILENDI: %s %s Ile Devam Ediyor" % [player_name, current_club_name],
			"Haftalik maas %d TL, gol primi %d TL, %d sezonluk anlasma imzalandi." % [weekly_wage, goal_bonus, contract_seasons_left]
		)

	player_resources_changed.emit()
	save_to_disk()

func advance_to_next_season() -> void:
	season += 1
	week = 1
	day_of_week = 1 # Yeni sezon Pazartesi antrenmanıyla başlar
	player_age += 1
	contract_seasons_left = maxi(contract_seasons_left - 1, 0)
	season_matches = 0
	season_goals = 0
	season_assists = 0
	season_rating_sum = 0.0
	season_completed_pending = false
	trained_today = false
	extra_shoot_done_today = false
	current_stamina = max_stamina
	clear_status(&"Hangover")
	clear_status(&"HangoverActive")

	# Mevcut lig tablosundaki kulüpleri koruyup puanları sıfırla (transfer olduysa zaten yenilenmiştir)
	if league_table.size() < 2:
		_init_league_table()
	else:
		fixture_opponents.clear()
		for row in league_table:
			row["played"] = 0
			row["pts"] = 0
			row["gd"] = 0
			if not bool(row.get("is_player_club", false)):
				fixture_opponents.append(str(row["name"]))
		fixture_opponents.shuffle()
		if not fixture_opponents.is_empty():
			next_opponent_name = fixture_opponents[0]

	add_pc_news(
		"SEZON %d BASLIYOR! (%s — %s)" % [season, current_club_name, current_country_code],
		"Yeni %d haftalik lig maratonu acildi! Ilk hafta rakibimiz: %s." % [SEASON_WEEKS, next_opponent_name]
	)
	player_resources_changed.emit()
	save_to_disk()

func add_pc_message(sender: String, title: String, text: String) -> void:
	pc_messages.push_front({ "sender": sender, "title": title, "text": text, "day": total_days })
	pc_inbox_updated.emit()

func add_pc_news(headline: String, text: String) -> void:
	pc_news.push_front({ "headline": headline, "text": text, "day": total_days })
	pc_inbox_updated.emit()

func add_pc_social(author: String, tag: String, text: String) -> void:
	pc_social_posts.push_front({ "author": author, "tag": tag, "text": text, "day": total_days })
	pc_inbox_updated.emit()

func sleep_and_advance_day(passed_out: bool = false) -> String:
	var woke_hangover: bool = has_status(&"Hangover")
	if woke_hangover:
		current_stamina = minf(56.0 if passed_out else 62.0, max_stamina)
		clear_status(&"Hangover")
		add_status(&"HangoverActive")
	else:
		clear_status(&"HangoverActive")
		current_stamina = minf(68.0, max_stamina) if passed_out else max_stamina

	current_time_minutes = WAKE_UP_MINUTES
	_clock_accum = 0.0
	_pass_out_triggered = false
	trained_today = false
	extra_shoot_done_today = false
	interviewed_today = false
	played_console_today = false
	total_days += 1
	day_of_week += 1
	var payday_note: String = ""
	if day_of_week > 7:
		day_of_week = 1
		week += 1
		weeks_at_club += 1
		var total_income: int = weekly_wage + passive_weekly_income
		cash += total_income
		payday_note = " (Haftalik Maas + Gelir: +%d TL!)" % total_income
		if romance_status == &"long_distance" and not romance_partner_name.is_empty():
			add_pc_message(
				romance_partner_name,
				"Seni Cok Ozledim! [Goruntulu Mesaj]",
				"Yeni sehrinde her sey yolunda mi %s? Hafta sonu macini ekrandan izleyecegim, kendine iyi bak!" % player_name
			)

	# Faz 6: Medya / Taraftar Kriz Tetikleyici
	if woke_hangover and randf() < 0.60:
		pending_crisis_tag = "hangover"
	elif total_days > 2 and (total_days % 4 == 0):
		pending_crisis_tag = "general"

	day_advanced.emit(total_days, week, day_of_week)
	time_changed.emit(current_time_minutes)
	player_resources_changed.emit()
	save_to_disk()

	if passed_out:
		return "Gece 02:00'de yorgunluktan bayildin! Sabah 08:00 — [Stamina %%%d]%s" % [roundi(current_stamina), payday_note]
	if has_status(&"HangoverActive"):
		return "Basin zonklayarak uyandin! [Aksamdan Kalma: Stamina %%%d]%s" % [roundi(current_stamina), payday_note]
	return "Yeni gun: %s%s — Oto-kaydedildi!" % [get_day_label(), payday_note]

func record_match_result(
	home_g: int,
	away_g: int,
	rating: float,
	new_coach_trust: float,
	user_goals: int,
	user_assists: int,
	key_passes: int,
	dribbles_won: int,
	ended_stamina: float
) -> PackedStringArray:
	var played_opp: String = next_opponent_name
	season_matches += 1
	season_goals += user_goals
	season_assists += user_assists
	career_total_matches += 1
	career_total_goals += user_goals
	career_total_assists += user_assists
	season_rating_sum += rating
	manager_trust = new_coach_trust
	current_stamina = clampf(ended_stamina, 15.0, max_stamina)
	var earned_xp: int = 25 + user_goals * 18 + user_assists * 14 + key_passes * 6 + (15 if rating >= 7.5 else 0)
	add_career_xp(earned_xp)

	# GDD 2.4: Hibrit Maç İçi Kullanıma Bağlı Stat Gelişimi!
	var growth_notes := PackedStringArray()
	if user_goals >= 1:
		growth_notes.append(add_stat_delta("shooting", 1))
	if user_assists >= 1 or key_passes >= 2:
		growth_notes.append(add_stat_delta("passing", 1))
		growth_notes.append(add_stat_delta("vision", 1))
	if dribbles_won >= 2:
		growth_notes.append(add_stat_delta("dribbling", 1))
	if rating >= 7.5:
		growth_notes.append(add_stat_delta("positioning", 1))

	var bonus: int = user_goals * goal_bonus + user_assists * 150 + (300 if home_g > away_g else (100 if home_g == away_g else 0))
	cash += bonus
	if rating >= 7.5:
		fan_reputation = clampf(fan_reputation + 6.0, 0.0, 100.0)
		add_pc_social("@KasabaTribunu", "#MacinAdami", "%s bugun sahada sov yapti! Puan: %.1f (%d Gol, %d Asist)" % [player_name, rating, user_goals, user_assists])
	elif rating < 5.5:
		fan_reputation = clampf(fan_reputation - 4.0, 0.0, 100.0)

	var pts_earned: int = 3 if home_g > away_g else (1 if home_g == away_g else 0)
	var opp_pts: int = 0 if home_g > away_g else (1 if home_g == away_g else 3)
	for entry in league_table:
		entry["played"] = int(entry["played"]) + 1
		if bool(entry.get("is_player_club", false)):
			entry["pts"] = int(entry["pts"]) + pts_earned
			entry["gd"] = int(entry["gd"]) + (home_g - away_g)
		elif str(entry.get("name", "")) == played_opp:
			entry["pts"] = int(entry["pts"]) + opp_pts
			entry["gd"] = int(entry["gd"]) + (away_g - home_g)
		else:
			var r_pts: int = [0, 1, 3][randi() % 3]
			entry["pts"] = int(entry["pts"]) + r_pts
			entry["gd"] = int(entry["gd"]) + randi_range(-2, 2)

	league_table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["pts"]) != int(b["pts"]):
			return int(a["pts"]) > int(b["pts"])
		return int(a["gd"]) > int(b["gd"])
	)

	var growth_str: String = (" | Gelisim: " + ", ".join(growth_notes)) if not growth_notes.is_empty() else ""
	add_pc_news(
		"MAC SONUCU: %s %d - %d %s" % [current_club_name, home_g, away_g, played_opp],
		"%s sahada %.1f puanla oynadi (%d gol, %d asist). Prim: +%d TL%s" % [player_name, rating, user_goals, user_assists, bonus, growth_str]
	)

	pending_match_modifiers.clear()
	if season_matches >= SEASON_WEEKS:
		season_completed_pending = true
	elif not fixture_opponents.is_empty():
		next_opponent_name = fixture_opponents[season_matches % fixture_opponents.size()]

	last_match_summary = "Son Mac: %d-%d | Puan: %.1f | Prim: +%d TL%s" % [home_g, away_g, rating, bonus, growth_str]
	pending_town_spawn = &"bus_stop"
	player_resources_changed.emit()
	save_to_disk()
	return growth_notes

func save_to_disk() -> void:
	var owned_str: Array[String] = []
	for oid in owned_items:
		owned_str.append(String(oid))
	var stats_dict: Dictionary = {}
	if player_stats != null:
		stats_dict = {
			"position": int(player_stats.position),
			"speed": player_stats.speed,
			"dribbling": player_stats.dribbling,
			"passing": player_stats.passing,
			"vision": player_stats.vision,
			"positioning": player_stats.positioning,
			"shooting": player_stats.shooting,
			"curve": player_stats.curve,
			"physical": player_stats.physical,
			"stamina": player_stats.stamina,
			"is_physical_anomaly": player_stats.is_physical_anomaly
		}
	var payload: Dictionary = {
		"season": season,
		"week": week,
		"day_of_week": day_of_week,
		"total_days": total_days,
		"weeks_at_club": weeks_at_club,
		"season_completed_pending": season_completed_pending,
		"current_country_code": current_country_code,
		"current_club_name": current_club_name,
		"next_opponent_name": next_opponent_name,
		"fixture_opponents": fixture_opponents,
		"league_table": league_table,
		"player_name": player_name,
		"player_age": player_age,
		"player_stats": stats_dict,
		"cash": cash,
		"weekly_wage": weekly_wage,
		"goal_bonus": goal_bonus,
		"contract_seasons_left": contract_seasons_left,
		"starter_guarantee": starter_guarantee,
		"passive_weekly_income": passive_weekly_income,
		"owned_items": owned_str,
		"current_stamina": current_stamina,
		"max_stamina": max_stamina,
		"manager_trust": manager_trust,
		"fan_reputation": fan_reputation,
		"media_reputation": media_reputation,
		"story_flags": story_flags,
		"romance_partner_name": romance_partner_name,
		"romance_status": String(romance_status),
		"career_level": career_level,
		"career_xp": career_xp,
		"free_stat_points": free_stat_points,
		"career_total_goals": career_total_goals,
		"career_total_assists": career_total_assists,
		"career_total_matches": career_total_matches,
		"career_trophies": career_trophies,
		"countries_played": countries_played,
		"season_goals": season_goals,
		"season_assists": season_assists,
		"season_matches": season_matches,
		"season_rating_sum": season_rating_sum,
		"appearance": player_appearance.to_dict() if player_appearance != null else {}
	}
	SaveManager.save_career(payload)

func load_from_disk() -> bool:
	var data: Dictionary = SaveManager.load_career()
	if data.is_empty():
		return false

	season = int(data.get("season", 1))
	week = int(data.get("week", 1))
	day_of_week = int(data.get("day_of_week", 3))
	total_days = int(data.get("total_days", 1))
	weeks_at_club = int(data.get("weeks_at_club", 1))
	season_completed_pending = bool(data.get("season_completed_pending", false))
	current_country_code = str(data.get("current_country_code", "TR"))
	current_club_name = str(data.get("current_club_name", "Kasaba Spor"))
	next_opponent_name = str(data.get("next_opponent_name", "Anadolu FK"))
	player_name = str(data.get("player_name", "Umut"))
	player_age = int(data.get("player_age", 19))

	cash = int(data.get("cash", 1200))
	weekly_wage = int(data.get("weekly_wage", 450))
	goal_bonus = int(data.get("goal_bonus", 250))
	contract_seasons_left = int(data.get("contract_seasons_left", 1))
	starter_guarantee = bool(data.get("starter_guarantee", false))
	passive_weekly_income = int(data.get("passive_weekly_income", 0))
	current_stamina = float(data.get("current_stamina", 100.0))
	max_stamina = float(data.get("max_stamina", 100.0))
	manager_trust = float(data.get("manager_trust", 65.0))
	fan_reputation = float(data.get("fan_reputation", 45.0))
	media_reputation = float(data.get("media_reputation", 50.0))
	romance_partner_name = str(data.get("romance_partner_name", ""))
	romance_status = StringName(str(data.get("romance_status", "none")))
	career_level = int(data.get("career_level", 1))
	career_xp = int(data.get("career_xp", 0))
	free_stat_points = int(data.get("free_stat_points", 0))
	career_total_goals = int(data.get("career_total_goals", 0))
	career_total_assists = int(data.get("career_total_assists", 0))
	career_total_matches = int(data.get("career_total_matches", 0))
	career_trophies = int(data.get("career_trophies", 0))
	var cp: Variant = data.get("countries_played", ["TR"])
	countries_played.clear()
	if cp is Array:
		for c_code in (cp as Array):
			countries_played.append(str(c_code))
	if countries_played.is_empty():
		countries_played.append(current_country_code)
	season_goals = int(data.get("season_goals", 0))
	season_assists = int(data.get("season_assists", 0))
	season_matches = int(data.get("season_matches", 0))
	season_rating_sum = float(data.get("season_rating_sum", 0.0))

	owned_items.clear()
	for oid in data.get("owned_items", []):
		owned_items.append(StringName(str(oid)))

	story_flags.clear()
	var sf: Variant = data.get("story_flags", {})
	if sf is Dictionary:
		for k in (sf as Dictionary).keys():
			story_flags[str(k)] = bool((sf as Dictionary)[k])

	var sd: Variant = data.get("player_stats", {})
	if sd is Dictionary and not (sd as Dictionary).is_empty():
		var d: Dictionary = sd as Dictionary
		player_stats = FootballerStats.create_preset(
			int(d.get("speed", 74)),
			int(d.get("dribbling", 78)),
			int(d.get("passing", 76)),
			int(d.get("vision", 78)),
			int(d.get("positioning", 72)),
			int(d.get("shooting", 76)),
			int(d.get("curve", 80)),
			50, 48, 66,
			int(d.get("position", 0)) as FootballerStats.Position,
			int(d.get("physical", 64)),
			int(d.get("stamina", 74))
		)
		player_stats.is_physical_anomaly = bool(d.get("is_physical_anomaly", false))

	var app_d: Variant = data.get("appearance", {})
	if app_d is Dictionary and not (app_d as Dictionary).is_empty():
		player_appearance = CharacterAppearance.from_dict(app_d as Dictionary)

	var lt: Variant = data.get("league_table", [])
	if lt is Array and not (lt as Array).is_empty():
		league_table.clear()
		for row in (lt as Array):
			if row is Dictionary:
				league_table.append(row as Dictionary)
	else:
		_init_league_table()

	var fx: Variant = data.get("fixture_opponents", [])
	fixture_opponents.clear()
	if fx is Array:
		for opp in (fx as Array):
			fixture_opponents.append(str(opp))

	UniverseDB.generate_town_cast_for_country(current_country_code)
	_init_starter_pc_feeds()
	trained_today = false
	extra_shoot_done_today = false
	current_time_minutes = WAKE_UP_MINUTES
	_clock_accum = 0.0
	_pass_out_triggered = false
	pending_town_spawn = &"home"
	player_resources_changed.emit()
	return true
