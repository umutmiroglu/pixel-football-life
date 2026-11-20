class_name TownPlayer
extends CharacterBody2D

@export var walk_speed: float = 95.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

@onready var char_visual: ProceduralCharacter = $ProceduralCharacter

var controls_locked: bool = false
var facing_dir: Vector2 = Vector2.DOWN

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 3
	add_to_group("town_player")
	if char_visual != null and GameState.player_appearance != null:
		char_visual.apply_appearance(GameState.player_appearance)

func _physics_process(delta: float) -> void:
	if controls_locked:
		velocity = Vector2.ZERO
		if char_visual != null:
			char_visual.update_locomotion(Vector2.ZERO, facing_dir, delta, 0.0)
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		facing_dir = input_dir.normalized()
		velocity = velocity.move_toward(facing_dir * walk_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	if char_visual != null:
		char_visual.update_locomotion(velocity, facing_dir, delta, 0.0)
