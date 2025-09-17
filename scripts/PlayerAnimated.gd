extends CharacterBody3D

const SPEED = 5.0

var target_position: Vector3
var moving: bool = false
var animation_player: AnimationPlayer
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_enabled: bool = true

func _ready():
	target_position = global_transform.origin
	add_to_group("player")

	await get_tree().process_frame
	_find_animation_player()
	_play_idle_animation()

func _find_animation_player():
	var character_model = $CharacterModel
	animation_player = _search_for_animation_player(character_model)

func _search_for_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _search_for_animation_player(child)
		if result:
			return result
	return null

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0

	if movement_enabled and Input.is_action_just_pressed("click"):
		_set_target_position()

	if moving:
		_move_towards_target()
	else:
		_play_idle_animation()

	move_and_slide()

	if moving:
		var distance = global_transform.origin.distance_to(target_position)
		if distance <= 0.1 or is_on_wall():
			stop_movement()

func _set_target_position():
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var space_state = get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000)
	var result = space_state.intersect_ray(ray_query)

	if result:
		target_position = result.position
		target_position.y = global_transform.origin.y
		moving = true
		_face_towards(target_position)
		_play_walk_animation()

func _move_towards_target():
	var direction = target_position - global_transform.origin
	direction.y = 0
	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		_face_towards(target_position)
		_play_walk_animation()
	else:
		stop_movement()

func _play_walk_animation():
	if animation_player:
		if animation_player.has_animation("Walk"):
			if animation_player.current_animation != "Walk":
				animation_player.play("Walk")
		elif animation_player.has_animation("walk"):
			if animation_player.current_animation != "walk":
				animation_player.play("walk")
		elif animation_player.has_animation("Run"):
			if animation_player.current_animation != "Run":
				animation_player.play("Run")
		elif animation_player.has_animation("run"):
			if animation_player.current_animation != "run":
				animation_player.play("run")

func _play_idle_animation():
	if animation_player:
		if animation_player.has_animation("Idle"):
			if animation_player.current_animation != "Idle":
				animation_player.play("Idle")
		elif animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")

func _face_towards(position: Vector3):
	var look_target = position
	look_target.y = global_transform.origin.y
	look_at(look_target, Vector3.UP)
	rotate_y(PI)

func stop_movement():
	velocity.x = 0
	velocity.z = 0
	moving = false
	target_position = global_transform.origin
	_play_idle_animation()

func set_movement_enabled(value: bool):
	movement_enabled = value
	if not movement_enabled:
		stop_movement()
