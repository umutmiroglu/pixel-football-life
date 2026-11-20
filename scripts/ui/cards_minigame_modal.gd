class_name CardsMinigameModal
extends PanelContainer

signal closed(summary_text: String)

const BET_AMOUNT: int = 50

@onready var title_label: Label = %CardsTitleLabel
@onready var opponent_label: Label = %OpponentHandLabel
@onready var player_label: Label = %PlayerHandLabel
@onready var status_label: Label = %CardsStatusLabel
@onready var hit_btn: Button = %HitBtn
@onready var stand_btn: Button = %StandBtn
@onready var deal_btn: Button = %DealBtn
@onready var tea_btn: Button = %TeaBtn
@onready var close_btn: Button = %CardsCloseBtn

var _opponent_npc: NPCProfile = null
var _player_cards: Array[int] = []
var _opp_cards: Array[int] = []
var _round_active: bool = false
var _last_summary: String = ""

func _ready() -> void:
	visible = false
	hit_btn.pressed.connect(_on_hit)
	stand_btn.pressed.connect(_on_stand)
	deal_btn.pressed.connect(_start_new_hand)
	tea_btn.pressed.connect(_on_drink_tea)
	close_btn.pressed.connect(_on_close)

func open_cafe_table() -> void:
	visible = true
	_last_summary = ""
	_round_active = false
	_opponent_npc = _pick_table_opponent()
	var opp_name: String = _opponent_npc.full_name if _opponent_npc != null else "Kasabali"
	title_label.text = "KOSE KAHVE — 21 MASASI (%s)" % opp_name
	opponent_label.text = "%s Eli: --" % opp_name
	player_label.text = "Senin Elin: --"
	status_label.modulate = Color(0.88, 0.95, 1.0, 1.0)
	status_label.text = "Nakit: %d TL | 50 TL bahisle 21 oyna veya cay ic!" % GameState.cash
	_set_round_buttons(false)

func _pick_table_opponent() -> NPCProfile:
	var candidates: Array[NPCProfile] = []
	for n in UniverseDB.npcs:
		if n.role == &"teammate" or n.role == &"shopkeeper" or n.role == &"captain":
			candidates.append(n)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _draw_card() -> int:
	return randi_range(2, 11)

func _hand_sum(cards: Array[int]) -> int:
	var total: int = 0
	var aces: int = 0
	for c in cards:
		total += c
		if c == 11:
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

func _format_hand(cards: Array[int], hide_second: bool = false) -> String:
	var parts := PackedStringArray()
	for i in range(cards.size()):
		if hide_second and i >= 1:
			parts.append("?")
		else:
			parts.append("A" if cards[i] == 11 else str(cards[i]))
	if hide_second:
		return "[%s]" % ", ".join(parts)
	return "[%s] = %d" % [", ".join(parts), _hand_sum(cards)]

func _start_new_hand() -> void:
	if GameState.cash < BET_AMOUNT:
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "21 oynamak icin en az %d TL gerekli!" % BET_AMOUNT
		return
	GameState.modify_cash(-BET_AMOUNT)
	_player_cards = [_draw_card(), _draw_card()]
	_opp_cards = [_draw_card(), _draw_card()]
	_round_active = true
	_set_round_buttons(true)
	_refresh_hands(true)

	if _hand_sum(_player_cards) == 21:
		_resolve_hand()
	else:
		status_label.modulate = Color(0.95, 0.92, 0.55, 1.0)
		status_label.text = "Bahis: 50 TL | Kart cek veya Kal!"

func _on_hit() -> void:
	if not _round_active:
		return
	_player_cards.append(_draw_card())
	_refresh_hands(true)
	if _hand_sum(_player_cards) >= 21:
		_resolve_hand()

func _on_stand() -> void:
	if not _round_active:
		return
	while _hand_sum(_opp_cards) < 17:
		_opp_cards.append(_draw_card())
	_resolve_hand()

func _resolve_hand() -> void:
	_round_active = false
	_set_round_buttons(false)
	_refresh_hands(false)

	var p_sum: int = _hand_sum(_player_cards)
	var o_sum: int = _hand_sum(_opp_cards)

	if p_sum > 21:
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "21'i astin! (-50 TL) | Nakit: %d TL" % GameState.cash
		_last_summary = "Kose Kahve 21 masasi: Sanssiz el (-50 TL)."
	elif o_sum > 21 or p_sum > o_sum:
		GameState.modify_cash(BET_AMOUNT * 2)
		if _opponent_npc != null:
			_opponent_npc.affection = clampf(_opponent_npc.affection + 3.0, 0.0, 100.0)
			UniverseDB.relationships_changed.emit()
		status_label.modulate = Color(0.45, 1.0, 0.58, 1.0)
		status_label.text = "KAZANDIN! (+50 TL net & Samimiyet +3) | Nakit: %d TL" % GameState.cash
		_last_summary = "Kose Kahve 21 masasi: Galibiyet (+50 TL)!"
	elif p_sum == o_sum:
		GameState.modify_cash(BET_AMOUNT)
		status_label.modulate = Color(0.75, 0.92, 1.0, 1.0)
		status_label.text = "BERABERE! Bahis iade edildi. | Nakit: %d TL" % GameState.cash
		_last_summary = "Kose Kahve 21 masasi: Berabere."
	else:
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "Rakip kazandi! (-50 TL) | Nakit: %d TL" % GameState.cash
		_last_summary = "Kose Kahve 21 masasi: Rakip aldi (-50 TL)."

func _on_drink_tea() -> void:
	if _round_active:
		return
	if GameState.cash < 35:
		status_label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		status_label.text = "Cay icin yeterli nakit yok (35 TL)."
		return
	GameState.modify_cash(-35)
	GameState.modify_stamina(16.0)
	status_label.modulate = Color(0.65, 0.98, 0.72, 1.0)
	status_label.text = "Sicak cay iyi geldi! (Stamina: %%%d | Nakit: %d TL)" % [roundi(GameState.current_stamina), GameState.cash]
	_last_summary = "Kose Kahve'de cay molasi verdin."

func _refresh_hands(hide_opp: bool) -> void:
	var opp_name: String = _opponent_npc.full_name if _opponent_npc != null else "Kasabali"
	opponent_label.text = "%s: %s" % [opp_name, _format_hand(_opp_cards, hide_opp)]
	player_label.text = "Senin Elin: %s" % _format_hand(_player_cards, false)

func _set_round_buttons(in_round: bool) -> void:
	hit_btn.visible = in_round
	stand_btn.visible = in_round
	deal_btn.visible = not in_round
	tea_btn.visible = not in_round
	close_btn.disabled = in_round

func _on_close() -> void:
	visible = false
	closed.emit(_last_summary)
