class_name SleepTransitionOverlay
extends Control

signal sleep_finished(summary_msg: String)

const STATS_META: Array[Dictionary] = [
	{ "key": "speed", "label": "Hiz" },
	{ "key": "dribbling", "label": "Calim" },
	{ "key": "passing", "label": "Pas" },
	{ "key": "vision", "label": "Vizyon" },
	{ "key": "positioning", "label": "Pozisyon" },
	{ "key": "shooting", "label": "Sut" },
	{ "key": "curve", "label": "Falso" },
	{ "key": "physical", "label": "Fizik" },
	{ "key": "stamina", "label": "Kondisyon" }
]

@onready var fade_rect: ColorRect = %SleepFadeRect
@onready var night_card: PanelContainer = %NightCard
@onready var title_label: Label = %NightTitleLabel
@onready var msg_label: Label = %NightMsgLabel
@onready var levelup_box: VBoxContainer = %LevelUpBox
@onready var points_label: Label = %NightPointsLabel
@onready var stats_grid: GridContainer = %NightStatsGrid
@onready var wake_btn: Button = %WakeUpBtn

var _busy: bool = false
var _last_msg: String = ""

func _ready() -> void:
	visible = false
	night_card.visible = false
	fade_rect.color = Color(0.01, 0.02, 0.05, 0.0)
	wake_btn.pressed.connect(_on_wake_pressed)

func trigger_sleep(passed_out: bool = false) -> void:
	if _busy:
		return
	_busy = true
	visible = true
	night_card.visible = false
	fade_rect.color = Color(0.01, 0.02, 0.05, 0.0)

	# 1. Hava yumusakca kararsin (Geceye gecis)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_on_darkness_reached.bind(passed_out))

func _on_darkness_reached(passed_out: bool) -> void:
	_last_msg = GameState.sleep_and_advance_day(passed_out)
	if not GameState.pending_crisis_tag.is_empty():
		_last_msg += "\n[!] GUNDEMDE ACIL BASIN HABERI VAR!"

	night_card.visible = true
	msg_label.text = _last_msg

	if GameState.free_stat_points > 0:
		SoundFX.play_level_up()
		title_label.text = "★ SEVIYE ATLADIN! (SEVIYE %d) ★" % GameState.career_level
		title_label.modulate = Color(1.0, 0.9, 0.28, 1.0)
		levelup_box.visible = true
		_rebuild_levelup_grid()
	else:
		title_label.text = "GECE GECIYOR... (08:00)" if not passed_out else "GECE 02:00 — YORGUNLUKTAN BAYILDIN!"
		title_label.modulate = Color(0.62, 0.88, 1.0, 1.0) if not passed_out else Color(1.0, 0.45, 0.38, 1.0)
		levelup_box.visible = false
		wake_btn.disabled = false
		wake_btn.text = "Yeni Gune Uyan (08:00)"
		wake_btn.grab_focus()

func _rebuild_levelup_grid() -> void:
	for c in stats_grid.get_children():
		c.queue_free()

	points_label.text = "Dagitilacak RPG Puani: %d  (Kalan puanlari dagit!)" % GameState.free_stat_points
	points_label.modulate = Color(0.45, 1.0, 0.58, 1.0) if GameState.free_stat_points > 0 else Color(0.75, 0.9, 1.0, 1.0)

	var st: FootballerStats = GameState.player_stats
	if st != null:
		for meta in STATS_META:
			var k: String = str(meta["key"])
			var cur_val: int = int(st.get(k))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 3)

			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 5)
			lbl.text = "%s: %d" % [str(meta["label"]), cur_val]
			row.add_child(lbl)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(24.0, 0.0)
			btn.add_theme_font_size_override("font_size", 5)
			btn.text = "+1"
			btn.disabled = (GameState.free_stat_points <= 0 or cur_val >= 100)
			btn.pressed.connect(_on_spend_point.bind(k))
			row.add_child(btn)

			stats_grid.add_child(row)

	wake_btn.disabled = (GameState.free_stat_points > 0)
	wake_btn.text = "Once %d Puani Dagit" % GameState.free_stat_points if GameState.free_stat_points > 0 else "Yeni Gune Uyan (08:00)"
	if not wake_btn.disabled:
		wake_btn.grab_focus()

func _on_spend_point(stat_key: String) -> void:
	GameState.spend_stat_point(stat_key)
	_rebuild_levelup_grid()

func _on_wake_pressed() -> void:
	if wake_btn.disabled:
		return
	SoundFX.play_click()
	night_card.visible = false
	# 2. Sabaha yumusak aydinlanma!
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_morning_complete)

func _on_morning_complete() -> void:
	visible = false
	_busy = false
	sleep_finished.emit(_last_msg)
