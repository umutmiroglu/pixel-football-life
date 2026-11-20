class_name NegotiationModal
extends PanelContainer

signal closed(did_transfer: bool)

const PROCEDURAL_CHAR_SCENE: PackedScene = preload("res://scenes/character/procedural_character.tscn")
const FOREIGN_COUNTRIES: PackedStringArray = ["EN", "ES", "IT", "DE", "BR", "FR"]

@onready var mode_renew_btn: Button = %ModeRenewBtn
@onready var mode_transfer_btn: Button = %ModeTransferBtn
@onready var close_btn: Button = %CloseBtn

@onready var portrait_holder: Node2D = %NegPortraitHolder
@onready var name_label: Label = %NegNameLabel
@onready var club_label: Label = %NegClubLabel
@onready var tags_label: Label = %NegTagsLabel
@onready var patience_bar: ProgressBar = %PatienceBar
@onready var patience_val: Label = %PatienceVal
@onready var speech_label: Label = %NegSpeechLabel

@onready var wage_minus_btn: Button = %WageMinusBtn
@onready var wage_val_label: Label = %WageValLabel
@onready var wage_plus_btn: Button = %WagePlusBtn

@onready var bonus_minus_btn: Button = %BonusMinusBtn
@onready var bonus_val_label: Label = %BonusValLabel
@onready var bonus_plus_btn: Button = %BonusPlusBtn

@onready var years_minus_btn: Button = %YearsMinusBtn
@onready var years_val_label: Label = %YearsValLabel
@onready var years_plus_btn: Button = %YearsPlusBtn

@onready var starter_check: CheckBox = %StarterCheck
@onready var submit_btn: Button = %SubmitOfferBtn

var _portrait_char: ProceduralCharacter = null
var _counterparty: NPCProfile = null
var _target_club_name: String = ""
var _target_country_code: String = "TR"
var _is_transfer: bool = false

var _patience: float = 100.0
var _patience_mult: float = 1.0
var _max_fair_wage: int = 550
var _max_fair_bonus: int = 300

var _offer_wage: int = 500
var _offer_bonus: int = 250
var _offer_years: int = 2
var _offer_starter: bool = false

var _negotiation_done: bool = false
var _transfer_signed: bool = false

func _ready() -> void:
	visible = false
	_portrait_char = PROCEDURAL_CHAR_SCENE.instantiate() as ProceduralCharacter
	_portrait_char.scale = Vector2(1.55, 1.55)
	portrait_holder.add_child(_portrait_char)

	mode_renew_btn.pressed.connect(_start_renewal_session)
	mode_transfer_btn.pressed.connect(_start_foreign_transfer_session)
	close_btn.pressed.connect(_on_close_pressed)

	wage_minus_btn.pressed.connect(func() -> void: _adjust_wage(-50))
	wage_plus_btn.pressed.connect(func() -> void: _adjust_wage(50))
	bonus_minus_btn.pressed.connect(func() -> void: _adjust_bonus(-50))
	bonus_plus_btn.pressed.connect(func() -> void: _adjust_bonus(50))
	years_minus_btn.pressed.connect(func() -> void: _adjust_years(-1))
	years_plus_btn.pressed.connect(func() -> void: _adjust_years(1))
	starter_check.toggled.connect(func(v: bool) -> void: _offer_starter = v)
	submit_btn.pressed.connect(_on_submit_offer)

func open_negotiation() -> void:
	visible = true
	_transfer_signed = false
	_start_renewal_session()

func _start_renewal_session() -> void:
	_is_transfer = false
	_target_club_name = GameState.current_club_name
	_target_country_code = GameState.current_country_code
	var chair: NPCProfile = UniverseDB.find_npc_by_id(&"chairman_main")
	if chair == null:
		chair = _make_temp_director(GameState.current_country_code)
	_counterparty = chair
	_init_session_numbers(1.0)
	speech_label.modulate = Color(0.92, 0.96, 1.0, 1.0)
	speech_label.text = "\"Otur bakalim %s. Kulubumuzde kalmak istiyorsan sartlarini masaya koy.\"" % GameState.player_name
	_refresh_ui()

func _start_foreign_transfer_session() -> void:
	_is_transfer = true
	var pool := PackedStringArray()
	for c in FOREIGN_COUNTRIES:
		if c != GameState.current_country_code:
			pool.append(c)
	if GameState.current_country_code != "TR":
		pool.append("TR")
	_target_country_code = pool[randi() % pool.size()]
	_target_club_name = NameGenerator.generate_club_name(_target_country_code)
	_counterparty = _make_temp_director(_target_country_code)
	var foreign_mult: float = randf_range(1.45, 1.85)
	_init_session_numbers(foreign_mult)
	speech_label.modulate = Color(0.75, 0.94, 1.0, 1.0)
	speech_label.text = "\"Merhaba %s! %s (%s) adina geldim. Seni yurt disina transfer etmek istiyoruz. Teklifini dinliyorum!\"" % [
		GameState.player_name, _target_club_name, _target_country_code
	]
	_refresh_ui()

func _make_temp_director(country_code: String) -> NPCProfile:
	var n := NPCProfile.new()
	n.id = &"foreign_director"
	n.full_name = "%s (Direktor)" % NameGenerator.generate_male_name(country_code, true)
	n.age = randi_range(42, 60)
	var temps: Array[StringName] = [&"calm", &"aggressive", &"arrogant", &"cheerful"]
	var ints: Array[StringName] = [&"money", &"tactics", &"cars"]
	var phils: Array[StringName] = [&"machiavellian", &"perfectionist", &"stoic", &"loyal"]
	n.temperament = temps[randi() % temps.size()]
	n.interest = ints[randi() % ints.size()]
	n.philosophy = phils[randi() % phils.size()]
	n.role = &"chairman"
	n.is_football_world = true
	n.affection = 50.0
	n.pitch_trust = 60.0
	n.appearance = CharacterAppearance.create_random(Color(0.22, 0.24, 0.34, 1.0), Color(0.12, 0.14, 0.18, 1.0))
	return n

func _init_session_numbers(club_mult: float) -> void:
	_negotiation_done = false
	_patience = 100.0
	_patience_mult = 1.0
	var temp_dict: Dictionary = UniverseDB.personalities_data.get("temperament", {})
	var t_info: Dictionary = temp_dict.get(String(_counterparty.temperament), {})
	_patience_mult = float(t_info.get("patience", 1.0))

	var perf_bonus: float = 1.0 + float(GameState.season_goals) * 0.08 + float(GameState.season_assists) * 0.05 + (GameState.fan_reputation - 45.0) * 0.004
	var personality_budget: float = 1.0
	if _counterparty.interest == &"money":
		personality_budget *= 0.90
	if not _is_transfer and _counterparty.philosophy == &"loyal":
		personality_budget *= 1.10

	var base_wage: float = float(maxi(GameState.weekly_wage, 450))
	_max_fair_wage = int(roundf((base_wage * club_mult * perf_bonus * personality_budget) / 50.0) * 50.0)
	_max_fair_wage = maxi(_max_fair_wage, 500)
	_max_fair_bonus = int(roundf((float(maxi(GameState.goal_bonus, 200)) * club_mult * perf_bonus) / 50.0) * 50.0)
	_max_fair_bonus = maxi(_max_fair_bonus, 250)

	_offer_wage = int(roundf(float(_max_fair_wage) * 0.95 / 50.0) * 50.0)
	_offer_bonus = int(roundf(float(_max_fair_bonus) * 0.95 / 50.0) * 50.0)
	_offer_years = 2
	_offer_starter = GameState.starter_guarantee
	starter_check.button_pressed = _offer_starter
	submit_btn.disabled = false
	submit_btn.text = "TEKLIFI MASAYA KOY"
	close_btn.text = "Ayril [X]"

func _adjust_wage(delta_val: int) -> void:
	if _negotiation_done:
		return
	_offer_wage = clampi(_offer_wage + delta_val, 300, 5000)
	_refresh_offer_labels()

func _adjust_bonus(delta_val: int) -> void:
	if _negotiation_done:
		return
	_offer_bonus = clampi(_offer_bonus + delta_val, 100, 3000)
	_refresh_offer_labels()

func _adjust_years(delta_val: int) -> void:
	if _negotiation_done:
		return
	_offer_years = clampi(_offer_years + delta_val, 1, 3)
	_refresh_offer_labels()

func _refresh_ui() -> void:
	if _counterparty != null:
		name_label.text = _counterparty.full_name
		club_label.text = "%s (%s)" % [_target_club_name, _target_country_code]
		var t1: String = UniverseDB.get_tag_label("temperament", _counterparty.temperament)
		var t2: String = UniverseDB.get_tag_label("interest", _counterparty.interest)
		var t3: String = UniverseDB.get_tag_label("philosophy", _counterparty.philosophy)
		tags_label.text = "[%s] [%s] [%s]" % [t1, t2, t3]
		if _portrait_char != null and _counterparty.appearance != null:
			_portrait_char.apply_appearance(_counterparty.appearance)
			_portrait_char.update_locomotion(Vector2.ZERO, Vector2.DOWN, 0.0, 0.0)

	patience_bar.value = _patience
	patience_val.text = "%d%%" % roundi(_patience)
	_refresh_offer_labels()

func _refresh_offer_labels() -> void:
	wage_val_label.text = "%d TL" % _offer_wage
	bonus_val_label.text = "%d TL" % _offer_bonus
	years_val_label.text = "%d Sezon" % _offer_years

func _on_submit_offer() -> void:
	if _negotiation_done or _counterparty == null:
		return

	var wage_ratio: float = float(_offer_wage) / float(maxi(_max_fair_wage, 1))
	var bonus_ratio: float = float(_offer_bonus) / float(maxi(_max_fair_bonus, 1))
	var greed: float = wage_ratio * 0.72 + bonus_ratio * 0.28

	# İlk 11 garantisi talep baskısı
	if _offer_starter:
		if GameState.manager_trust < 70.0 and GameState.season_goals < 2:
			greed += 0.16
		else:
			greed += 0.05

	# Uzun sözleşme kulüp lehinedir (hafif tolerans)
	if _offer_years == 3:
		greed -= 0.05
	elif _offer_years == 1:
		greed += 0.04

	if greed <= 1.02:
		_negotiation_done = true
		submit_btn.disabled = true
		submit_btn.text = "ANLASMA IMZALANDI!"
		GameState.apply_signed_contract(
			_target_club_name,
			_target_country_code,
			_offer_wage,
			_offer_bonus,
			_offer_years,
			_offer_starter,
			_is_transfer
		)
		speech_label.modulate = Color(0.45, 1.0, 0.58, 1.0)
		if _is_transfer:
			_transfer_signed = true
			speech_label.text = "\"Anlastik! %s (%s) formasina hos geldin! Bavulunu topla, yeni ulkede yeni kadro seni bekliyor!\"" % [_target_club_name, _target_country_code]
			close_btn.text = "Yeni Ulkeye Uc!"
		else:
			speech_label.text = "\"El sikistik! Yeni sozlesmen hayirli olsun %s. Haftalik %d TL maasla devam!\"" % [GameState.player_name, _offer_wage]
			close_btn.text = "Imzala & Cik"
		return

	# Reddedildi -> Sabır düşüşü!
	var drop: float = clampf((greed - 0.94) * 48.0 / maxf(_patience_mult, 0.45), 14.0, 56.0)
	_patience = maxf(_patience - drop, 0.0)
	patience_bar.value = _patience
	patience_val.text = "%d%%" % roundi(_patience)

	if _patience <= 0.0:
		_negotiation_done = true
		submit_btn.disabled = true
		submit_btn.text = "MASA DAGILDI!"
		speech_label.modulate = Color(1.0, 0.36, 0.32, 1.0)
		speech_label.text = "\"Sabrimi tasirdin! Bu sartlarla anlasmamiz imkansiz, gorusme bitmistir!\""
		return

	speech_label.modulate = Color(1.0, 0.82, 0.38, 1.0)
	if _counterparty.temperament == &"aggressive" or _counterparty.temperament == &"arrogant":
		speech_label.text = "\"Dalga mi geciyorsun? Bu rakamlar cok yuksek, hemen asagi cek!\""
	elif _counterparty.interest == &"money":
		speech_label.text = "\"Butce disiplinimiz var. Maasi veya gol primini biraz daha kirpman lazim.\""
	else:
		speech_label.text = "\"Seni cok istiyoruz ama bu sartlar bizi biraz asiyor. Daha makul bir teklifle gel.\""

func _on_close_pressed() -> void:
	visible = false
	closed.emit(_transfer_signed)
