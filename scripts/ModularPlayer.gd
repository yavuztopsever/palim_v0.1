extends CharacterBody3D

# Modular Player class with integrated BaseCharacter functionality
# Handles player-specific movement and input

const WALK_SPEED = 5.0
const RUN_MULTIPLIER = 1.75
const CROUCH_MULTIPLIER = 0.45
const JUMP_VELOCITY = 7.0
const TURN_SPEED: float = 8.0

var target_position: Vector3
var moving: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_enabled: bool = true
var desired_direction: Vector3 = Vector3.ZERO
var base_move_speed: float = WALK_SPEED
var is_running: bool = false
var is_crouching: bool = false

# Character system - integrated BaseCharacter functionality
var character_model: Node3D
var animator: CharacterAnimator
var character_config: CharacterConfig
const ANIMATION_ACTIONS := [
	"attack",
	"defend",
	"talk",
	"wave",
	"dance",
	"sit",
	"sleep",
	"pickup",
	"throw",
	"climb",
	"death"
]

func _ready():
	target_position = global_transform.origin
	add_to_group("player")
	
	# Set up character system
	await get_tree().process_frame
	setup_character_system()

func setup_character_system():
	# Find character components
	character_model = get_node_or_null("CharacterModel")
	animator = get_node_or_null("CharacterAnimator")
	if animator == null:
		# Backward compatibility if the node wasn't renamed in the scene yet
		animator = get_node_or_null("AnimationController")
	
	if not character_model:
		push_warning("Error: No CharacterModel found in %s" % name)
		return
	
	if not animator:
		push_warning("Error: No CharacterAnimator found in %s" % name)
		return
	
	var overrides := {} if character_config == null else character_config.animation_overrides
	var speed := 1.0 if character_config == null else character_config.animation_speed
	animator.setup(self, character_model, overrides, speed)
	if character_config and character_config.movement_speed > 0.0:
		base_move_speed = character_config.movement_speed
	animator.refresh()
	print("Player character setup complete. Available animations: ", animator.get_available_clips())
	_play_idle_animation()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0

	if movement_enabled:
		if Input.is_action_just_pressed("jump"):
			_handle_jump()
		if Input.is_action_just_pressed("crouch"):
			toggle_crouch()
		_handle_animation_shortcuts()

	if moving:
		_move_towards_target(delta)
	else:
		_play_idle_animation()

	move_and_slide()

	if moving:
		var distance = global_transform.origin.distance_to(target_position)
		if distance <= 0.1 or is_on_wall():
			stop_movement()

func _unhandled_input(event):
	if not movement_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click and not is_crouching:
			_set_target_position(true)
		else:
			_set_target_position()

func _set_target_position(run: bool = false):
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
		is_running = run and not is_crouching
		desired_direction = (target_position - global_transform.origin)
		desired_direction.y = 0
		if desired_direction.length() > 0.01:
			desired_direction = desired_direction.normalized()
		_play_movement_animation()

func _move_towards_target(delta: float) -> void:
	var direction = target_position - global_transform.origin
	direction.y = 0
	if direction.length() > 0.01:
		desired_direction = direction.normalized()
		var speed = _get_current_move_speed()
		velocity.x = desired_direction.x * speed
		velocity.z = desired_direction.z * speed
		_update_rotation(delta)
		_play_movement_animation()
	else:
		stop_movement()

func _play_walk_animation():
	if play_animation("walk"):
		return
	play_animation("run")  # Fallback to run if walk not available

func _play_run_animation():
	if play_animation("run"):
		return
	_play_walk_animation()

func _play_crouch_animation():
	play_animation("crouch", true)

func _play_movement_animation():
	if is_crouching:
		_play_crouch_animation()
		return
	if is_running:
		_play_run_animation()
		return
	_play_walk_animation()

func _play_idle_animation():
	if is_crouching:
		_play_crouch_animation()
		return
	if play_animation("idle"):
		return
	play_animation("walk")

# Animation system with dynamic animation mapping
func play_animation(anim_name: String, force: bool = false) -> bool:
	if animator:
		return animator.play(anim_name, force)
	return false

func _update_rotation(delta: float) -> void:
	if desired_direction.length() < 0.001:
		return
	var desired_yaw = atan2(-desired_direction.x, -desired_direction.z) + PI
	rotation.y = lerp_angle(rotation.y, desired_yaw, TURN_SPEED * delta)

func stop_movement():
	velocity.x = 0
	velocity.z = 0
	moving = false
	is_running = false
	target_position = global_transform.origin
	desired_direction = Vector3.ZERO
	_play_idle_animation()

func toggle_crouch():
	is_crouching = not is_crouching
	if is_crouching:
		is_running = false
	stop_movement()

func _handle_jump():
	if not is_on_floor():
		return
	if is_crouching:
		is_crouching = false
	velocity.y = JUMP_VELOCITY
	if animator and animator.play("jump", true):
		return
	play_animation("jump", true)

func _handle_animation_shortcuts():
	for action in ANIMATION_ACTIONS:
		if Input.is_action_just_pressed(action):
			_trigger_animation(action)

func _trigger_animation(animation_name: String):
	stop_movement()
	play_animation(animation_name, true)

func _get_current_move_speed() -> float:
	var speed = base_move_speed
	if is_running:
		speed *= RUN_MULTIPLIER
	if is_crouching:
		speed *= CROUCH_MULTIPLIER
	return speed

func set_movement_enabled(value: bool):
	movement_enabled = value
	if not movement_enabled:
		stop_movement()

func get_available_animations() -> PackedStringArray:
	if animator:
		return animator.get_available_clips()
	return PackedStringArray()

func get_current_animation() -> String:
	if animator:
		return animator.get_current_clip()
	return ""

# Character customization methods
func set_character_config(config: CharacterConfig):
	character_config = config
	if config:
		apply_character_config(config)

func get_character_config() -> CharacterConfig:
	return character_config

func apply_character_config(config: CharacterConfig):
	if not config:
		return
	if animator:
		animator.setup(self, character_model, config.animation_overrides, config.animation_speed)
		animator.refresh()
	if config.movement_speed > 0.0:
		base_move_speed = config.movement_speed
