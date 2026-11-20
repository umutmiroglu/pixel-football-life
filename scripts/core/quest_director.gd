extends Node

signal active_triggers_changed()
signal scheduled_event_delivered(channel: String, title: String)

const QUESTS_DIR: String = "res://data/json/quests"

# Yüklenen tüm multi-act yan görev tanımları: quest_id -> Dictionary
var quest_definitions: Dictionary = {}

# Aktif / tamamlanmış görev durumları
var started_quests: Dictionary = {}       # quest_id -> { "cast_vars": Dictionary, "bound_npc_id": StringName, "finished": bool }
var pending_triggers: Array[Dictionary] = [] # [{ "quest_id": String, "node_id": String, "location": String, "unlock_day": int }]
var pending_scheduled_events: Array[Dictionary] = [] # [{ "quest_id": String, "event_id": String, "trigger_day": int }]

func _ready() -> void:
	_load_all_quest_files()
	GameState.day_advanced.connect(_on_day_advanced)

func reset_all() -> void:
	started_quests.clear()
	pending_triggers.clear()
	pending_scheduled_events.clear()
	active_triggers_changed.emit()

func _load_all_quest_files() -> void:
	quest_definitions.clear()
	var dir := DirAccess.open(QUESTS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var path: String = "%s/%s" % [QUESTS_DIR, fname]
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var qd: Dictionary = parsed as Dictionary
				var qid: String = str(qd.get("quest_id", fname.get_basename()))
				quest_definitions[qid] = qd
		fname = dir.get_next()
	dir.list_dir_end()

func check_location_trigger(location_id: String, ignore_day_delay: bool = false) -> Dictionary:
	# 1. Önce bekleyen devam düğümlerine (unlock_trigger) bak!
	for i in range(pending_triggers.size()):
		var trig: Dictionary = pending_triggers[i]
		if str(trig.get("location", "")) == location_id:
			var unlock_day: int = int(trig.get("unlock_day", 0))
			if ignore_day_delay or GameState.total_days >= unlock_day:
				var qid: String = str(trig["quest_id"])
				var nid: String = str(trig["node_id"])
				pending_triggers.remove_at(i)
				active_triggers_changed.emit()
				return _build_node_packet(qid, nid)

	# 2. Yeni başlayabilecek görevlerin triggers bloğunu kontrol et!
	for qid in quest_definitions.keys():
		if started_quests.has(qid):
			continue
		var qd: Dictionary = quest_definitions[qid]
		var tr: Dictionary = qd.get("triggers", {})
		if str(tr.get("location", "")) != location_id:
			continue
		var p_cond: Dictionary = tr.get("player_conditions", {})
		var min_weeks: int = int(p_cond.get("min_weeks_at_club", 0))
		if not ignore_day_delay and GameState.weeks_at_club < min_weeks:
			continue

		var bound_npc: NPCProfile = _find_matching_npc_for_binding(tr.get("npc_binding", {}))
		if tr.has("npc_binding") and bound_npc == null:
			continue

		_initialize_quest_cast(qid, bound_npc)
		var first_node_id: String = _get_first_node_id(qd)
		active_triggers_changed.emit()
		return _build_node_packet(qid, first_node_id)

	return {}

func has_available_trigger_at(location_id: String) -> bool:
	for trig in pending_triggers:
		if str(trig.get("location", "")) == location_id and GameState.total_days >= int(trig.get("unlock_day", 0)):
			return true
	for qid in quest_definitions.keys():
		if started_quests.has(qid):
			continue
		var qd: Dictionary = quest_definitions[qid]
		var tr: Dictionary = qd.get("triggers", {})
		if str(tr.get("location", "")) == location_id:
			var min_weeks: int = int((tr.get("player_conditions", {}) as Dictionary).get("min_weeks_at_club", 0))
			if GameState.weeks_at_club >= min_weeks:
				if not tr.has("npc_binding") or _find_matching_npc_for_binding(tr.get("npc_binding", {})) != null:
					return true
	return false

func get_active_quest_hint() -> String:
	for trig in pending_triggers:
		var qid: String = str(trig["quest_id"])
		var title: String = str((quest_definitions.get(qid, {}) as Dictionary).get("title", qid))
		var loc: String = _localize_location(str(trig["location"]))
		var days_left: int = maxi(int(trig["unlock_day"]) - GameState.total_days, 0)
		if days_left == 0:
			return "GOREV HAZIR [%s]: %s konumuna git!" % [title, loc]
		return "GOREV [%s]: %d gun sonra -> %s" % [title, days_left, loc]
	return ""

func get_next_node_packet(quest_id: String, node_id: String) -> Dictionary:
	return _build_node_packet(quest_id, node_id)

func apply_node_or_choice_effects(quest_id: String, effects: Dictionary) -> Dictionary:
	var result: Dictionary = { "notes": PackedStringArray(), "transition_to_match": false }
	if effects.is_empty():
		return result

	var notes: PackedStringArray = PackedStringArray()
	var q_state: Dictionary = started_quests.get(quest_id, {})
	var bound_npc: NPCProfile = UniverseDB.find_npc_by_id(StringName(str(q_state.get("bound_npc_id", ""))))

	if effects.has("cash_delta"):
		var dc: int = int(effects["cash_delta"])
		GameState.modify_cash(dc)
		notes.append("%+d TL" % dc)

	if effects.has("stamina_delta"):
		var ds: float = float(effects["stamina_delta"])
		GameState.modify_stamina(ds)
		notes.append("Stamina %+d" % roundi(ds))

	if effects.has("status_effect_add"):
		var st_name := StringName(str(effects["status_effect_add"]))
		GameState.add_status(st_name)
		notes.append("DURUM: %s" % String(st_name))

	if effects.has("npc_closeness_delta") and bound_npc != null:
		var da: float = float(effects["npc_closeness_delta"])
		bound_npc.modify_affection(da)
		notes.append("%s Samimiyet %+d" % [bound_npc.full_name, roundi(da)])

	if effects.has("npc_team_trust_delta") and bound_npc != null:
		var dt: float = float(effects["npc_team_trust_delta"])
		bound_npc.modify_pitch_trust(dt)
		notes.append("%s Saha Guveni %+d" % [bound_npc.full_name, roundi(dt)])

	if effects.has("npc_team_trust_set") and bound_npc != null:
		bound_npc.pitch_trust = clampf(float(effects["npc_team_trust_set"]), 0.0, 100.0)
		notes.append("%s Saha Guveni = %d" % [bound_npc.full_name, roundi(bound_npc.pitch_trust)])

	if effects.has("locker_room_morale_delta"):
		GameState.locker_room_morale = clampf(GameState.locker_room_morale + float(effects["locker_room_morale_delta"]), 0.0, 100.0)
	if effects.has("media_reputation_delta"):
		GameState.media_reputation = clampf(GameState.media_reputation + float(effects["media_reputation_delta"]), 0.0, 100.0)
	if effects.has("fan_reputation_delta"):
		GameState.fan_reputation = clampf(GameState.fan_reputation + float(effects["fan_reputation_delta"]), 0.0, 100.0)

	if effects.has("flags_add") and effects["flags_add"] is Array:
		for fl in (effects["flags_add"] as Array):
			GameState.add_flag(str(fl))

	if effects.has("match_modifiers") and effects["match_modifiers"] is Dictionary:
		for mk in (effects["match_modifiers"] as Dictionary).keys():
			GameState.pending_match_modifiers[str(mk)] = (effects["match_modifiers"] as Dictionary)[mk]

	if effects.has("unlock_trigger") and effects["unlock_trigger"] is Dictionary:
		var ut: Dictionary = effects["unlock_trigger"] as Dictionary
		pending_triggers.append({
			"quest_id": quest_id,
			"node_id": str(ut.get("node_id", "")),
			"location": str(ut.get("location", "")),
			"unlock_day": GameState.total_days + int(ut.get("delay_days", 1))
		})
		active_triggers_changed.emit()

	if effects.has("schedule_event") and effects["schedule_event"] is Dictionary:
		var se: Dictionary = effects["schedule_event"] as Dictionary
		pending_scheduled_events.append({
			"quest_id": quest_id,
			"event_id": str(se.get("event_id", "")),
			"trigger_day": GameState.total_days + int(se.get("delay_days", 7))
		})

	if bool(effects.get("transition_to_match", false)):
		result["transition_to_match"] = true

	UniverseDB.relationships_changed.emit()
	result["notes"] = notes
	return result

func mark_quest_finished(quest_id: String) -> void:
	if started_quests.has(quest_id):
		(started_quests[quest_id] as Dictionary)["finished"] = true

func _on_day_advanced(total_day: int, _week: int, _dow: int) -> void:
	for i in range(pending_scheduled_events.size() - 1, -1, -1):
		var ev_entry: Dictionary = pending_scheduled_events[i]
		if total_day >= int(ev_entry.get("trigger_day", 0)):
			_deliver_scheduled_event(str(ev_entry["quest_id"]), str(ev_entry["event_id"]))
			pending_scheduled_events.remove_at(i)
	active_triggers_changed.emit()

func _deliver_scheduled_event(quest_id: String, event_id: String) -> void:
	var qd: Dictionary = quest_definitions.get(quest_id, {})
	var events_map: Dictionary = qd.get("scheduled_events", {})
	if not events_map.has(event_id):
		return
	var ev: Dictionary = events_map[event_id]
	var vars: Dictionary = (started_quests.get(quest_id, {}) as Dictionary).get("cast_vars", {})
	var channel: String = str(ev.get("delivery_channel", "home_pc_news"))
	var body_txt: String = NameGenerator.format_template(str(ev.get("text", "")), vars)

	match channel:
		"home_pc_messages":
			var sender: String = NameGenerator.format_template(str(ev.get("sender", "Bilinmeyen")), vars)
			var title: String = NameGenerator.format_template(str(ev.get("title", "Yeni Mesaj")), vars)
			GameState.add_pc_message(sender, title, body_txt)
			scheduled_event_delivered.emit(channel, title)
		"home_pc_news":
			var headline: String = NameGenerator.format_template(str(ev.get("headline", "Son Dakika")), vars)
			GameState.add_pc_news(headline, body_txt)
			scheduled_event_delivered.emit(channel, headline)
		"home_pc_social_media":
			var author: String = str(ev.get("author", "@FutbolGundem"))
			var tag: String = str(ev.get("trending_tag", "#Gundem"))
			GameState.add_pc_social(author, tag, body_txt)
			scheduled_event_delivered.emit(channel, tag)

	if ev.has("effects") and ev["effects"] is Dictionary:
		apply_node_or_choice_effects(quest_id, ev["effects"] as Dictionary)

func _initialize_quest_cast(quest_id: String, bound_npc: NPCProfile) -> void:
	var cc: String = GameState.current_country_code
	var vars: Dictionary = {
		"player_name": GameState.player_name,
		"teammate_name": bound_npc.full_name if bound_npc != null else NameGenerator.generate_male_name(cc, false),
		"wife_name": NameGenerator.generate_female_name(cc, false),
		"ex_gf_name": NameGenerator.generate_female_name(cc, false),
		"lover_name": NameGenerator.generate_male_name(cc, false)
	}
	started_quests[quest_id] = {
		"cast_vars": vars,
		"bound_npc_id": String(bound_npc.id) if bound_npc != null else "",
		"finished": false
	}

func _build_node_packet(quest_id: String, node_id: String) -> Dictionary:
	var qd: Dictionary = quest_definitions.get(quest_id, {})
	var nodes: Dictionary = qd.get("nodes", {})
	if not nodes.has(node_id):
		return {}
	var node_d: Dictionary = (nodes[node_id] as Dictionary).duplicate(true)
	var q_state: Dictionary = started_quests.get(quest_id, {})
	var vars: Dictionary = q_state.get("cast_vars", { "player_name": GameState.player_name })
	var cast_def: Dictionary = qd.get("cast", {})

	# Diyalog satırlarındaki tüm {placeholder} değişkenlerini doldur
	var formatted_lines: Array[Dictionary] = []
	for line_item in node_d.get("dialogue", []):
		if line_item is Dictionary:
			var ld: Dictionary = (line_item as Dictionary).duplicate()
			var spk_key: String = str(ld.get("speaker", "narrator"))
			var spk_display: String = NameGenerator.format_template(str(cast_def.get(spk_key, spk_key)), vars)
			ld["speaker_key"] = spk_key
			ld["speaker_name"] = "ANLATICI" if spk_key == "narrator" else spk_display
			ld["text"] = NameGenerator.format_template(str(ld.get("text", "")), vars)
			formatted_lines.append(ld)

	var formatted_choices: Array[Dictionary] = []
	for ch_item in node_d.get("choices", []):
		if ch_item is Dictionary:
			var cd: Dictionary = (ch_item as Dictionary).duplicate(true)
			cd["label"] = NameGenerator.format_template(str(cd.get("label", "Sec")), vars)
			formatted_choices.append(cd)

	return {
		"quest_id": quest_id,
		"quest_title": str(qd.get("title", quest_id)),
		"node_id": node_id,
		"bound_npc_id": StringName(str(q_state.get("bound_npc_id", ""))),
		"dialogue": formatted_lines,
		"choices": formatted_choices,
		"effects": node_d.get("effects", {}),
		"next": node_d.get("next", null),
		"is_ending": bool(node_d.get("is_ending", false))
	}

func _find_matching_npc_for_binding(binding: Dictionary) -> NPCProfile:
	if binding.is_empty():
		return null
	var req_role: String = str(binding.get("role", ""))
	var req_tags: Array = binding.get("required_tags_all", [])
	for npc in UniverseDB.npcs:
		if not req_role.is_empty() and String(npc.role) != req_role:
			continue
		var ok: bool = true
		for t in req_tags:
			if not npc.has_tag(StringName(str(t))):
				ok = false
				break
		if ok:
			return npc
	return null

func _get_first_node_id(qd: Dictionary) -> String:
	var nodes: Dictionary = qd.get("nodes", {})
	if nodes.has("act1_cafe_intro"):
		return "act1_cafe_intro"
	var keys: Array = nodes.keys()
	return str(keys[0]) if not keys.is_empty() else ""

func _localize_location(loc: String) -> String:
	match loc:
		"cafe_interior": return "Gol Kafe"
		"cafe_back_alley": return "Kafe Arka Sokagi"
		"training_ground_exit": return "Antrenman Tesisleri (Otobus ile)"
		"home_pc_messages": return "Evdeki Bilgisayar (Mesajlar)"
		"nightclub_interior": return "Gece Kulubu"
		"locker_room_pre_match": return "Stadyum Soyunma Odasi (Otobus ile)"
	return loc
