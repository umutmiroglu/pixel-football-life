class_name CafeCardsScene
extends Control

const INTERIOR_SCENE_PATH: String = "res://scenes/world/building_interior.tscn"
const PROCEDURAL_CHAR_SCENE: PackedScene = preload("res://scenes/character/procedural_character.tscn")
const BET_AMOUNT: int = 50
const SUITS: PackedStringArray = ["♠", "♥", "♦", "♣"]

@onready var opp_holder: Node2D = %OppCharHolder
@onready var opp_name_label: Label = %OppNameLabel
@onready var speech_label: Label = %OppSpeechLabel
@onready var cash_label: Label = %TableCashLabel
@onready var opp_cards_box: HBoxContainer = %OppCardsBox
@onready var player_cards_box: HBoxContainer = %PlayerCardsBox
@onready var opp_sum_label: Label = %OppSumLabel
@onready var player_sum_label: Label = %PlayerSumLabel
@onready var status_label: Label = %TableStatusLabel

@onready var deal_btn: Button = %TableDealBtn
@onready var hit_btn: Button = %TableHitBtn
@onready var stand_btn: Button = %TableStandBtn
@onready var tea_btn: Button = %TableTeaBtn
@onready var leave_btn: Button = %TableLeaveBtn

var _opp_npc: NPCProfile = null
var _opp_visual: ProceduralCharacter = null
var _player_cards: Array[Dictionary] = []
var _opp_cards: Array[Dictionary] = []
var _round_active: bool = false

func _ready() -> void:
	Engine.time_scale = 1.0
	_opp_npc = _pick_opponent()
	_opp_visual = PROCEDURAL_CHAR_SCENE.instantiate() as ProceduralCharacter
	_opp_visual.scale = Vector2(1.85, 1.85)
	opp_holder.add_child(_opp_visual)
	if _opp_npc != null and _opp_npc.appearance != null:
		_opp_visual.apply_appearance(_opp_npc.appearance)
		_opp_visual.update_locomotion(Vector2.ZERO, Vector2.DOWN, 0.0, 0.0)
	opp_name_label.text = _opp_npc.full_name if _opp_npc != null else "Kasabali"
	speech_label.text = "\"Hadi bakalim %s, 50 TL ortaya koy da 21 atalim!\"" % GameState.player_name

	deal_btn.pressed.connect(_start_hand)
	hit_btn.pressed.connect(_on_hit)
	stand_btn.pressed.connect(_on_stand)
	tea_btn.pressed.connect(_on_tea)
	leave_btn.pressed.connect(_on_leave)

	_set_in_round(false)
	_refresh_cash()

func _pick_opponent() -> NPCProfile:
	var pool: Array[NPCProfile] = []
	for n in UniverseDB.npcs:
		if n.role == &"teammate" or n.role == &"shopkeeper" or n.role == &"captain":
			pool.append(n)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _draw_card() -> Dictionary:
	var r: int = randi_range(1, 13)
	var suit: String = SUITS[randi() % SUITS.size()]
	var rank_str: String = "A" if r == 1 else ("J" if r == 11 else ("Q" if r == 12 else ("K" if r == 13 else str(r))))
	var val: int = 11 if r == 1 else (10 if r >= 10 else r)
	var is_red: bool = (suit == "♥" or suit == "♦")
	return { "rank": rank_str, "suit": suit, "val": val, "red": is_red }

func _calc_sum(cards: Array[Dictionary]) -> int:
	var total: int = 0
	var aces: int = 0
	for c in cards:
		total += int(c["val"])
		if int(c["val"]) == 11:
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

func _make_card_widget(card: Dictionary, hidden: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(22.0, 30.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.3, 0.56, 1.0) if hidden else Color(0.96, 0.96, 0.98, 1.0)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.88, 0.88, 0.94, 1.0) if hidden else Color(0.18, 0.2, 0.26, 1.0)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 2
	p.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 7)
	if hidden:
		lbl.text = "?"
		lbl.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 1.0))
	else:
		lbl.text = "%s\n%s" % [str(card["rank"]), str(card["suit"])]
		lbl.add_theme_color_override("font_color", Color(0.82, 0.14, 0.18, 1.0) if bool(card["red"]) else Color(0.1, 0.12, 0.18, 1.0))
	p.add_child(lbl)

	p.pivot_offset = Vector2(11.0, 15.0)
	p.scale = Vector2(0.4, 0.4)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return p

func _render_hands(hide_opp_second: bool) -> void:
	for c in opp_cards_box.get_children():
		c.queue_free()
	for c in player_cards_box.get_children():
		c.queue_free()

	for i in range(_opp_cards.size()):
		opp_cards_box.add_child(_make_card_widget(_opp_cards[i], hide_opp_second and i >= 1))
	for c in _player_cards:
		player_cards_box.add_child(_make_card_widget(c, false))

	opp_sum_label.text = "Rakip: ?" if hide_opp_second else "Rakip: %d" % _calc_sum(_opp_cards)
	player_sum_label.text = "Senin Elin: %d" % _calc_sum(_player_cards)

func _start_hand() -> void:
	if GameState.cash < BET_AMOUNT:
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "Masaya oturmak icin en az %d TL gerekli!" % BET_AMOUNT
		return
	GameState.modify_cash(-BET_AMOUNT)
	SoundFX.play_card()
	_refresh_cash()
	_player_cards = [_draw_card(), _draw_card()]
	_opp_cards = [_draw_card(), _draw_card()]
	_round_active = true
	_set_in_round(true)
	_render_hands(true)
	speech_label.text = "\"Kartlar dagitildi! Bakalim riske girecek misin?\""
	status_label.modulate = Color(1.0, 0.92, 0.48, 1.0)
	status_label.text = "Ortada 100 TL var! Kart Cek veya Kal."
	if _calc_sum(_player_cards) == 21:
		_resolve_hand()

func _on_hit() -> void:
	if not _round_active:
		return
	SoundFX.play_card()
	_player_cards.append(_draw_card())
	_render_hands(true)
	speech_label.text = "\"Cesur hamle!\""
	if _calc_sum(_player_cards) >= 21:
		_resolve_hand()

func _on_stand() -> void:
	if not _round_active:
		return
	while _calc_sum(_opp_cards) < 17:
		_opp_cards.append(_draw_card())
	_resolve_hand()

func _resolve_hand() -> void:
	_round_active = false
	_set_in_round(false)
	_render_hands(false)
	var p_sum: int = _calc_sum(_player_cards)
	var o_sum: int = _calc_sum(_opp_cards)

	if p_sum > 21:
		speech_label.text = "\"Haha, 21'i astin dostum! Bu el benim.\""
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "YANDIN! (-50 TL)"
	elif o_sum > 21 or p_sum > o_sum:
		SoundFX.play_cash()
		GameState.modify_cash(BET_AMOUNT * 2)
		if _opp_npc != null:
			_opp_npc.affection = clampf(_opp_npc.affection + 3.0, 0.0, 100.0)
			UniverseDB.relationships_changed.emit()
		speech_label.text = "\"Helal olsun %s! Iyi okudun masayi.\"" % GameState.player_name
		status_label.modulate = Color(0.45, 1.0, 0.58, 1.0)
		status_label.text = "KAZANDIN! (+50 TL net & Samimiyet +3)"
	elif p_sum == o_sum:
		GameState.modify_cash(BET_AMOUNT)
		speech_label.text = "\"Berabere! Paralar iade.\""
		status_label.modulate = Color(0.72, 0.94, 1.0, 1.0)
		status_label.text = "BERABERE (Bahis iade)"
	else:
		speech_label.text = "\"Kusura bakma, kagitlar benden yana!\""
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "RAKIP KAZANDI (-50 TL)"
	_refresh_cash()

func _on_tea() -> void:
	if _round_active:
		return
	if GameState.cash < 35:
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "Cay icin 35 TL gerekli!"
		return
	GameState.modify_cash(-35)
	GameState.modify_stamina(16.0)
	_refresh_cash()
	speech_label.text = "\"Afiyet olsun! Tavsan kani cay iyi gider.\""
	status_label.modulate = Color(0.65, 0.98, 0.72, 1.0)
	status_label.text = "Cay ictin! Stamina: %%%d" % roundi(GameState.current_stamina)

func _set_in_round(v: bool) -> void:
	hit_btn.visible = v
	stand_btn.visible = v
	deal_btn.visible = not v
	tea_btn.visible = not v
	leave_btn.disabled = v

func _refresh_cash() -> void:
	cash_label.text = "Nakit: %d TL | STAM: %%%d" % [GameState.cash, roundi(GameState.current_stamina)]

func _on_leave() -> void:
	GameState.current_interior_id = &"corner_cafe"
	get_tree().change_scene_to_file(INTERIOR_SCENE_PATH)
