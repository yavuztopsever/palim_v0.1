extends CharacterBody3D

const SPEED = 5.0

var target_position: Vector3
var moving = false
var animation_player: AnimationPlayer
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	target_position = global_transform.origin
	add_to_group("player")

	# Find AnimationPlayer in the character model
	await get_tree().process_frame
	_find_animation_player()

func _find_animation_player():
	# Search for AnimationPlayer in the character model
	var character_model = $CharacterModel
	animation_player = _search_for_animation_player(character_model)

	if animation_player:
		print("Found AnimationPlayer with animations: ", animation_player.get_animation_list())
		# Play idle animation if available
		if animation_player.has_animation("Idle"):
			animation_player.play("Idle")
		elif animation_player.has_animation("idle"):
			animation_player.play("idle")

func _search_for_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = _search_for_animation_player(child)
		if result:
			return result

	return null

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Reset vertical velocity when on floor to prevent accumulation
		if velocity.y < 0:
			velocity.y = 0

	if Input.is_action_just_pressed("click"):
		_set_target_position()

	if moving:
		_move_to_target(delta)
		_play_walk_animation()
	else:
		_play_idle_animation()

	# Move and check for collisions
	move_and_slide()

	# Check if we hit something while moving
	if moving and is_on_wall():
		# Check if we're close enough to destination or actually blocked
		var distance = global_transform.origin.distance_to(target_position)
		if distance > 0.5:  # Only stop if we're not near the target
			stop_movement()
			print("Hit wall, stopping movement")

func _play_walk_animation():
	if animation_player:
		# Try different walk animation names
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

		# Make character face the target
		var look_target = target_position
		look_target.y = global_transform.origin.y
		look_at(look_target, Vector3.UP)
		# Rotate 180 degrees because the model faces backwards
		rotate_y(PI)

func _move_to_target(_delta):
	var direction = (target_position - global_transform.origin).normalized()
	var distance = global_transform.origin.distance_to(target_position)

	if distance > 0.1:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		stop_movement()

func stop_movement():
	velocity.x = 0
	velocity.z = 0
	moving = false
	target_position = global_transform.origin
	_play_idle_animation()
