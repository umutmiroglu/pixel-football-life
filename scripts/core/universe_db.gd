extends Node

signal relationships_changed()

const PERSONALITIES_PATH: String = "res://data/json/personalities.json"
const DIALOGUES_PATH: String = "res://data/json/dialogues.json"

var personalities_data: Dictionary = {}
var dialogues_data: Dictionary = {}
var npcs: Array[NPCProfile] = []

func _ready() -> void:
	personalities_data = _read_json_dict(PERSONALITIES_PATH)
	dialogues_data = _read_json_dict(DIALOGUES_PATH)
	generate_town_cast_for_country(GameState.current_country_code)

func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("UniverseDB missing JSON: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}

func generate_town_cast_for_country(country_code: String) -> void:
	npcs.clear()
	var home_primary := Color(0.16, 0.52, 0.95, 1.0)
	var home_secondary := Color(0.92, 0.95, 0.98, 1.0)

	# 1. Teknik Direktör (ülkeye göre rastgele isim + Mükemmeliyetçi / Taktik Dehası)
	var coach_name: String = "%s Hoca" % NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"coach_main", coach_name, 46, 0, &"calm", &"tactics", &"perfectionist", &"coach", Color(0.18, 0.22, 0.28, 1.0), Color(0.12, 0.14, 0.18, 1.0), 58.0, 65.0))

	# 2. Takım Kaptanı (#4 Stoper - Sadık / Aile Odaklı)
	var capt_name: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"capt_main", "%s (Kaptan)" % capt_name, 31, 4, &"calm", &"family", &"loyal", &"captain", home_primary, home_secondary, 56.0, 68.0))

	# 3. Takım Arkadaşı (#7 - İçe Dönük + Gece Hayatı -> 'Aldatan Eş' görevini doğal olarak tetikler!)
	var intro_mate: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"mate_nightlife", intro_mate, 24, 7, &"introverted", &"nightlife", &"stoic", &"teammate", home_primary, home_secondary, 58.0, 64.0))

	# 4. Takım Arkadaşı (#9 Santrfor - Kibirli / Makyavelist)
	var fwd_mate: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"mate_striker", fwd_mate, 25, 9, &"arrogant", &"cars", &"machiavellian", &"teammate", home_primary, home_secondary, 46.0, 62.0))

	# 5. Takım Arkadaşı (#8 Orta Saha - Neşeli / Taktik)
	var mid_mate: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"mate_mid", mid_mate, 23, 8, &"cheerful", &"tactics", &"loyal", &"teammate", home_primary, home_secondary, 62.0, 72.0))

	# 6. Menajer (Para Düşkünü / Makyavelist)
	var agent_name: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"agent_main", "%s (Menajer)" % agent_name, 38, 0, &"arrogant", &"money", &"machiavellian", &"agent", Color(0.28, 0.22, 0.34, 1.0), Color(0.14, 0.14, 0.16, 1.0), 52.0, 55.0))

	# 7. Gazeteci (Sivil - Tek Eksen)
	var press_name: String = NameGenerator.generate_female_name(country_code, false)
	npcs.append(_make_npc(&"press_main", "%s (Gazeteci)" % press_name, 27, 0, &"cheerful", &"money", &"machiavellian", &"journalist", Color(0.75, 0.32, 0.42, 1.0), Color(0.2, 0.22, 0.28, 1.0), 50.0, 0.0))

	# 8. Kafe Baristası / Partner Adayı (Sivil - Tek Eksen)
	var barista_name: String = NameGenerator.generate_female_name(country_code, false)
	var barista: NPCProfile = _make_npc(&"barista_main", "%s (Gol Kafe)" % barista_name, 22, 0, &"introverted", &"family", &"loyal", &"barista", Color(0.26, 0.62, 0.48, 1.0), Color(0.22, 0.24, 0.30, 1.0), 58.0, 0.0)
	barista.is_romantic_partner = true
	npcs.append(barista)

	# 9. Spor Mağazası Esnafı (Sivil)
	var shop_name: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"shop_owner", "%s (Spor Mag.)" % shop_name, 41, 0, &"cheerful", &"money", &"stoic", &"shopkeeper", Color(0.82, 0.56, 0.20, 1.0), Color(0.20, 0.22, 0.26, 1.0), 52.0, 0.0))

	# 10. Kulüp Başkanı (Kulüp Evi / Lokal)
	var chair_name: String = NameGenerator.generate_male_name(country_code, false)
	npcs.append(_make_npc(&"chairman_main", "%s (Baskan)" % chair_name, 54, 0, &"aggressive", &"money", &"machiavellian", &"chairman", Color(0.18, 0.20, 0.26, 1.0), Color(0.12, 0.14, 0.18, 1.0), 50.0, 58.0))

	# 11. Köşe Kahve (2. Kafe) Baristası / Müdavimi (Sivil)
	var cafe2_name: String = NameGenerator.generate_female_name(country_code, false)
	npcs.append(_make_npc(&"cafe2_host", "%s (Kose Kahve)" % cafe2_name, 34, 0, &"calm", &"family", &"loyal", &"shopkeeper", Color(0.58, 0.42, 0.26, 1.0), Color(0.22, 0.20, 0.18, 1.0), 54.0, 0.0))

	relationships_changed.emit()

func _make_npc(
	p_id: StringName,
	p_name: String,
	p_age: int,
	p_num: int,
	p_temp: StringName,
	p_int: StringName,
	p_phil: StringName,
	p_role: StringName,
	p_col1: Color,
	p_col2: Color,
	p_aff: float,
	p_trust: float
) -> NPCProfile:
	var n := NPCProfile.new()
	n.id = p_id
	n.full_name = p_name
	n.age = p_age
	n.shirt_number = p_num
	n.temperament = p_temp
	n.interest = p_int
	n.philosophy = p_phil
	n.role = p_role
	n.is_football_world = (p_role in NPCProfile.FOOTBALL_ROLES)
	n.affection = p_aff
	n.pitch_trust = p_trust if n.is_football_world else 0.0
	n.appearance = CharacterAppearance.create_random(p_col1, p_col2)
	return n

func find_npc_by_id(npc_id: StringName) -> NPCProfile:
	for n in npcs:
		if n.id == npc_id:
			return n
	return null

func get_tag_label(category: String, tag: StringName) -> String:
	var cat: Dictionary = personalities_data.get(category, {})
	var entry: Dictionary = cat.get(String(tag), {})
	return str(entry.get("label", String(tag)))

func get_average_team_pitch_trust() -> int:
	var sum: float = 0.0
	var count: int = 0
	for npc in npcs:
		if npc.role == &"teammate" or npc.role == &"captain":
			sum += npc.pitch_trust
			count += 1
	if count == 0:
		return 65
	return clampi(roundi(sum / float(count)), 10, 100)
