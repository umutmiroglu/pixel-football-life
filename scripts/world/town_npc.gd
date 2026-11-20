class_name TownNPC
extends StaticBody2D

const PROCEDURAL_CHAR_SCENE: PackedScene = preload("res://scenes/character/procedural_character.tscn")

var npc_profile: NPCProfile = null
var _char_visual: ProceduralCharacter = null
var _name_label: Label = null
var _quest_badge: Label = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 2
	add_to_group("town_npcs")
	_build_visuals()
	if npc_profile != null:
		_apply_profile()

func setup(profile: NPCProfile, spawn_pos: Vector2) -> void:
	npc_profile = profile
	global_position = spawn_pos
	if _char_visual != null:
		_apply_profile()

func set_quest_badge_visible(vis: bool) -> void:
	if _quest_badge != null:
		_quest_badge.visible = vis

func _build_visuals() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.5
	col.shape = shape
	add_child(col)

	_char_visual = PROCEDURAL_CHAR_SCENE.instantiate() as ProceduralCharacter
	add_child(_char_visual)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-36.0, -24.0)
	_name_label.size = Vector2(72.0, 12.0)
	_name_label.add_theme_font_size_override("font_size", 5)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.95))
	add_child(_name_label)

	_quest_badge = Label.new()
	_quest_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_badge.position = Vector2(-12.0, -34.0)
	_quest_badge.size = Vector2(24.0, 12.0)
	_quest_badge.add_theme_font_size_override("font_size", 8)
	_quest_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	_quest_badge.text = "[!]"
	_quest_badge.visible = false
	add_child(_quest_badge)

func _apply_profile() -> void:
	if npc_profile == null:
		return
	if _char_visual != null and npc_profile.appearance != null:
		_char_visual.apply_appearance(npc_profile.appearance)
		_char_visual.update_locomotion(Vector2.ZERO, Vector2.DOWN, 0.0, 0.0)
	if _name_label != null:
		_name_label.text = npc_profile.full_name
