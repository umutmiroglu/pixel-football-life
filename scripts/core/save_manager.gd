class_name SaveManager
extends RefCounted

# GDD 1.1: Stardew Kayıt Felsefesi — Tek slota yalnızca gün sonu uyunduğunda atomik otomatik kayıt!
const SAVE_PATH: String = "user://career_save.json"
const SAVE_TMP_PATH: String = "user://career_save.json.tmp"
const SAVE_SCHEMA_VERSION: int = 1

static func save_career(payload: Dictionary) -> bool:
	payload["schema_version"] = SAVE_SCHEMA_VERSION
	var json_str: String = JSON.stringify(payload, "\t")
	var f := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager failed to open temp file for writing.")
		return false
	f.store_string(json_str)
	f.flush()
	f.close()

	var abs_tmp: String = ProjectSettings.globalize_path(SAVE_TMP_PATH)
	var abs_dst: String = ProjectSettings.globalize_path(SAVE_PATH)
	var err: Error = DirAccess.rename_absolute(abs_tmp, abs_dst)
	if err != OK:
		# Windows üzerinde hedef dosya varsa silip tekrar taşı
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(abs_dst)
		err = DirAccess.rename_absolute(abs_tmp, abs_dst)
	return err == OK

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func load_career() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var txt: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
