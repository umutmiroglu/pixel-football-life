class_name DialogueRunner
extends RefCounted

static func build_daily_chat(
	npc: NPCProfile,
	dialogues_data: Dictionary,
	personalities_data: Dictionary,
	has_hangover: bool
) -> Dictionary:
	var openings_map: Dictionary = dialogues_data.get("openings_by_temperament", {})
	var bodies_map: Dictionary = dialogues_data.get("body_by_interest", {})
	var hangover_map: Dictionary = dialogues_data.get("hangover_reaction_by_philosophy", {})

	var temp_key: String = String(npc.temperament)
	var int_key: String = String(npc.interest)
	var phil_key: String = String(npc.philosophy)

	var opening_pool: Array = openings_map.get(temp_key, ["Selam."])
	var body_pool: Array = bodies_map.get(int_key, ["Bugun guzel bir gun."])

	var opening: String = str(opening_pool[randi() % opening_pool.size()]) if not opening_pool.is_empty() else "Selam."
	var body: String = str(body_pool[randi() % body_pool.size()]) if not body_pool.is_empty() else ""

	var line_text: String = "%s\n%s" % [opening, body]
	if has_hangover and hangover_map.has(phil_key):
		line_text = "[AKSAMDAN KALMA TEPKISI]\n%s" % str(hangover_map[phil_key])

	var raw_choices: Array = dialogues_data.get("daily_choices", [])
	var choices_out: Array[Dictionary] = []
	for item in raw_choices:
		if item is Dictionary:
			var c: Dictionary = (item as Dictionary).duplicate(true)
			if not npc.is_football_world and str(c.get("id", "")) == "talk_football":
				c["text"] = "Kasaba ve gunluk hayat hakkinda konus."
				c["effects"] = { "affection": 7, "pitch_trust": 0 }
			choices_out.append(c)

	return {
		"title": "%s — Gunluk Sohbet" % npc.full_name,
		"line": line_text,
		"choices": choices_out,
		"personalities_ref": personalities_data
	}

static func resolve_daily_choice(npc: NPCProfile, choice: Dictionary, _personalities_data: Dictionary) -> Dictionary:
	var eff: Dictionary = choice.get("effects", {})
	var aff_delta: float = float(eff.get("affection", 0.0))
	var trust_delta: float = float(eff.get("pitch_trust", 0.0))
	var feedback: String = ""

	if bool(eff.get("ego_check", false)):
		if npc.temperament == &"arrogant" or npc.philosophy == &"perfectionist":
			aff_delta = -6.0
			trust_delta = -4.0
			feedback = "%s bu ozguveni biraz ukalaca buldu." % npc.full_name
		else:
			aff_delta = 6.0
			trust_delta = 8.0
			feedback = "%s hirsina hayran kaldi!" % npc.full_name
	else:
		if str(choice.get("id", "")) == "talk_football" and npc.interest == &"tactics":
			trust_delta *= 1.5
			feedback = "%s taktik bakis acini cok begendi! (Bonus Guven)" % npc.full_name
		elif str(choice.get("id", "")) == "talk_friendly" and (npc.temperament == &"cheerful" or npc.philosophy == &"hedonist"):
			aff_delta *= 1.4
			feedback = "%s sohbetinden cok keyif aldi! (Bonus Samimiyet)" % npc.full_name
		else:
			feedback = "%s ile aran biraz daha isindi." % npc.full_name

	npc.modify_affection(aff_delta)
	npc.modify_pitch_trust(trust_delta)
	UniverseDB.relationships_changed.emit()

	return {
		"feedback": feedback,
		"affection_delta": aff_delta,
		"pitch_trust_delta": trust_delta if npc.is_football_world else 0.0
	}
