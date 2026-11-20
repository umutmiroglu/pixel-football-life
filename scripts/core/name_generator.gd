class_name NameGenerator
extends RefCounted

const NAMES_PATH: String = "res://data/json/names.json"

static var _data: Dictionary = {}
static var _used_names: Dictionary[String, bool] = {}

static func _ensure_loaded() -> void:
	if not _data.is_empty():
		return
	if not FileAccess.file_exists(NAMES_PATH):
		push_error("NameGenerator missing JSON: " + NAMES_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH))
	if parsed is Dictionary:
		_data = parsed as Dictionary

static func reset_used_names() -> void:
	_used_names.clear()

static func get_available_countries() -> PackedStringArray:
	_ensure_loaded()
	var countries: Dictionary = _data.get("countries", {})
	var out := PackedStringArray()
	for k in countries.keys():
		out.append(str(k))
	return out

static func generate_male_name(country_code: String = "TR", with_surname: bool = true) -> String:
	return _generate_person_name(country_code, "male_first", with_surname)

static func generate_female_name(country_code: String = "TR", with_surname: bool = true) -> String:
	return _generate_person_name(country_code, "female_first", with_surname)

static func generate_club_name(country_code: String = "TR") -> String:
	_ensure_loaded()
	var countries: Dictionary = _data.get("countries", {})
	var c: Dictionary = countries.get(country_code, countries.get("TR", {}))
	var prefixes: Array = c.get("club_prefixes", ["Kasaba"])
	var suffixes: Array = c.get("club_suffixes", ["Spor"])
	for _attempt in 16:
		var cand: String = "%s %s" % [str(prefixes[randi() % prefixes.size()]), str(suffixes[randi() % suffixes.size()])]
		if not _used_names.has(cand):
			_used_names[cand] = true
			return cand
	return "%s %s" % [str(prefixes[randi() % prefixes.size()]), str(suffixes[randi() % suffixes.size()])]

static func _generate_person_name(country_code: String, first_key: String, with_surname: bool) -> String:
	_ensure_loaded()
	var countries: Dictionary = _data.get("countries", {})
	var c: Dictionary = countries.get(country_code, countries.get("TR", {}))
	var firsts: Array = c.get(first_key, ["Alex"])
	var surnames: Array = c.get("surnames", ["Demir"])
	for _attempt in 24:
		var f: String = str(firsts[randi() % firsts.size()])
		var full: String = ("%s %s" % [f, str(surnames[randi() % surnames.size()])]) if with_surname else f
		if not _used_names.has(full):
			_used_names[full] = true
			return full
	var fallback: String = str(firsts[randi() % firsts.size()])
	return ("%s %s" % [fallback, str(surnames[randi() % surnames.size()])]) if with_surname else fallback

static func format_template(text: String, vars: Dictionary) -> String:
	var result: String = text
	for k in vars.keys():
		result = result.replace("{%s}" % str(k), str(vars[k]))
	return result
