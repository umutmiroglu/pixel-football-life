class_name NPCProfile
extends Resource

const FOOTBALL_ROLES: Array[StringName] = [
	&"captain",
	&"teammate",
	&"coach",
	&"agent",
	&"chairman"
]

@export var id: StringName = &""
@export var full_name: String = "NPC"
@export var age: int = 24
@export var shirt_number: int = 0
@export var appearance: CharacterAppearance = null

# GDD 3.2: 4 Etiketli Modüler Kişilik (standart English ID: temperament, interest, philosophy, role)
@export var temperament: StringName = &"calm"
@export var interest: StringName = &"tactics"
@export var philosophy: StringName = &"stoic"
@export var role: StringName = &"teammate"

# GDD 3.3: Bağlama Göre İlişki Ekseni
@export var is_football_world: bool = true
@export_range(0.0, 100.0) var affection: float = 50.0
@export_range(0.0, 100.0) var pitch_trust: float = 55.0
@export var is_romantic_partner: bool = false

func get_tag_list() -> Array[StringName]:
	return [temperament, interest, philosophy, role]

func has_tag(tag_expr: StringName) -> bool:
	# Hem düz ("nightlife") hem kategorili ("interest:nightlife") etiket formatını destekler!
	var s: String = String(tag_expr)
	if s.contains(":"):
		var parts: PackedStringArray = s.split(":", false, 1)
		if parts.size() == 2:
			var cat: String = parts[0]
			var val := StringName(parts[1])
			match cat:
				"temperament":
					return temperament == val
				"interest", "obsession":
					return interest == val
				"philosophy":
					return philosophy == val
				"role":
					return role == val
		return false
	return temperament == tag_expr or interest == tag_expr or philosophy == tag_expr or role == tag_expr

func modify_affection(delta_val: float) -> void:
	affection = clampf(affection + delta_val, 0.0, 100.0)

func modify_pitch_trust(delta_val: float) -> void:
	if not is_football_world:
		return
	pitch_trust = clampf(pitch_trust + delta_val, 0.0, 100.0)

func is_willing_to_relocate_on_transfer() -> bool:
	if philosophy == &"loyal" or interest == &"family":
		return false
	return affection >= 70.0

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"full_name": full_name,
		"age": age,
		"shirt_number": shirt_number,
		"temperament": String(temperament),
		"interest": String(interest),
		"philosophy": String(philosophy),
		"role": String(role),
		"is_football_world": is_football_world,
		"affection": affection,
		"pitch_trust": pitch_trust,
		"is_romantic_partner": is_romantic_partner,
		"appearance": appearance.to_dict() if appearance != null else {}
	}

static func from_dict(d: Dictionary) -> NPCProfile:
	var p := NPCProfile.new()
	p.id = StringName(str(d.get("id", "")))
	p.full_name = str(d.get("full_name", "NPC"))
	p.age = int(d.get("age", 24))
	p.shirt_number = int(d.get("shirt_number", 0))
	p.temperament = StringName(str(d.get("temperament", "calm")))
	p.interest = StringName(str(d.get("interest", "tactics")))
	p.philosophy = StringName(str(d.get("philosophy", "stoic")))
	p.role = StringName(str(d.get("role", "teammate")))
	p.is_football_world = bool(d.get("is_football_world", p.role in FOOTBALL_ROLES))
	p.affection = clampf(float(d.get("affection", 50.0)), 0.0, 100.0)
	p.pitch_trust = clampf(float(d.get("pitch_trust", 55.0)), 0.0, 100.0)
	p.is_romantic_partner = bool(d.get("is_romantic_partner", false))
	var app_dict: Variant = d.get("appearance", {})
	if app_dict is Dictionary and not (app_dict as Dictionary).is_empty():
		p.appearance = CharacterAppearance.from_dict(app_dict as Dictionary)
	else:
		p.appearance = CharacterAppearance.create_random()
	return p
