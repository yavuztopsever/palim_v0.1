extends CharacterBody3D

# Modular Player class with integrated BaseCharacter functionality
# Handles player-specific movement and input

const SPEED = 5.0
const TURN_SPEED: float = 8.0

var target_position: Vector3
var moving: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_enabled: bool = true
var desired_direction: Vector3 = Vector3.ZERO

# Character system - integrated BaseCharacter functionality
var animation_player: AnimationPlayer
var character_model: Node3D
var animation_controller: AnimationController
var character_config: CharacterConfig
var current_animation: String = ""
var animation_speed: float = 1.0

# Standard animation mappings for consistent puppeteering
var standard_animations = {
	"idle": ["Idle", "idle", "T-Pose", "t-pose"],
	"walk": ["Walk", "walk", "Walking", "walking"],
	"run": ["Run", "run", "Running", "running", "Jog", "jog"],
	"jump": ["Jump", "jump", "Jumping", "jumping"],
	"attack": ["Attack", "attack", "Punch", "punch", "Strike", "strike"],
	"defend": ["Defend", "defend", "Block", "block", "Guard", "guard"],
	"death": ["Death", "death", "Die", "die", "Dead", "dead"],
	"talk": ["Talk", "talk", "Speaking", "speaking", "Gesture", "gesture"],
	"wave": ["Wave", "wave", "Greeting", "greeting", "Hello", "hello"],
	"dance": ["Dance", "dance", "Dancing", "dancing"],
	"sit": ["Sit", "sit", "Sitting", "sitting"],
	"sleep": ["Sleep", "sleep", "Sleeping", "sleeping", "Rest", "rest"],
	"pickup": ["Pickup", "pickup", "Pick", "pick", "Grab", "grab"],
	"throw": ["Throw", "throw", "Toss", "toss"],
	"climb": ["Climb", "climb", "Climbing", "climbing"],
	"crouch": ["Crouch", "crouch", "Crouching", "crouching", "Sneak", "sneak"]
}

func _ready():
	target_position = global_transform.origin
	add_to_group("player")
	
	# Set up character system
	await get_tree().process_frame
	setup_character_system()

func setup_character_system():
	# Find character components
	character_model = get_node_or_null("CharacterModel")
	animation_controller = get_node_or_null("AnimationController")
	
	if not character_model:
		print("Error: No CharacterModel found in ", name)
		return
	
	# Find AnimationPlayer within the character model
	animation_player = _search_for_animation_player(character_model)
	if not animation_player:
		print("Error: No AnimationPlayer found in character model")
		return
	
	print("Player character setup complete. Available animations: ", animation_player.get_animation_list())
	_play_idle_animation()

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
		_move_towards_target(delta)
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
		desired_direction = (target_position - global_transform.origin)
		desired_direction.y = 0
		if desired_direction.length() > 0.01:
			desired_direction = desired_direction.normalized()
		_play_walk_animation()

func _move_towards_target(delta: float) -> void:
	var direction = target_position - global_transform.origin
	direction.y = 0
	if direction.length() > 0.01:
		desired_direction = direction.normalized()
		velocity.x = desired_direction.x * SPEED
		velocity.z = desired_direction.z * SPEED
		_update_rotation(delta)
		_play_walk_animation()
	else:
		stop_movement()

func _play_walk_animation():
	if not play_animation("walk"):
		play_animation("run")  # Fallback to run if walk not available

func _play_idle_animation():
	play_animation("idle")

# Animation system with standard animation mapping
func play_animation(anim_name: String, force: bool = false) -> bool:
	if not animation_player:
		return false
	
	var normalized_name = anim_name.to_lower()
	var animation_variants = []
	
	# Check if it's a standard animation name
	if normalized_name in standard_animations:
		animation_variants = standard_animations[normalized_name]
	else:
		# Try direct name variants
		animation_variants = [
			anim_name,
			anim_name.capitalize(),
			anim_name.to_upper(),
			anim_name.to_lower()
		]
	
	# Try to find and play the animation
	for name_variant in animation_variants:
		if animation_player.has_animation(name_variant):
			if current_animation != name_variant or force:
				animation_player.speed_scale = animation_speed
				animation_player.play(name_variant)
				current_animation = name_variant
				print("Player playing animation: ", name_variant)
				return true
			return true
	
	print("Player animation not found: ", anim_name, " (tried: ", animation_variants, ")")
	return false

# Puppeteer functions for consistent character control
func puppet_idle():
	return play_animation("idle")

func puppet_walk():
	return play_animation("walk")

func puppet_run():
	return play_animation("run")

func puppet_jump():
	return play_animation("jump")

func puppet_attack():
	return play_animation("attack")

func puppet_talk():
	return play_animation("talk")

func puppet_wave():
	return play_animation("wave")

func puppet_dance():
	return play_animation("dance")

func puppet_sit():
	return play_animation("sit")

func puppet_sleep():
	return play_animation("sleep")

func puppet_pickup():
	return play_animation("pickup")

func puppet_throw():
	return play_animation("throw")

func puppet_climb():
	return play_animation("climb")

func puppet_crouch():
	return play_animation("crouch")

func puppet_defend():
	return play_animation("defend")

func puppet_death():
	return play_animation("death")

func _update_rotation(delta: float) -> void:
	if desired_direction.length() < 0.001:
		return
	var desired_yaw = atan2(-desired_direction.x, -desired_direction.z) + PI
	rotation.y = lerp_angle(rotation.y, desired_yaw, TURN_SPEED * delta)

func stop_movement():
	velocity.x = 0
	velocity.z = 0
	moving = false
	target_position = global_transform.origin
	desired_direction = Vector3.ZERO
	_play_idle_animation()

func set_movement_enabled(value: bool):
	movement_enabled = value
	if not movement_enabled:
		stop_movement()

# Character customization methods
func set_character_config(config: CharacterConfig):
	character_config = config
	if config:
		apply_character_config(config)

func get_character_config() -> CharacterConfig:
	return character_config

func apply_character_config(config: CharacterConfig):
	if not config or not character_model:
		return
	
	# Apply visual customizations
	apply_textures(config.textures)
	apply_materials(config.materials)
	apply_scale(config.scale_multiplier)
	
	# Apply animation settings
	animation_speed = config.animation_speed

func apply_textures(textures: Dictionary):
	if not character_model or textures.is_empty():
		return
	
	# Find all MeshInstance3D nodes and apply textures
	var mesh_instances = _find_all_mesh_instances(character_model)
	for mesh_instance in mesh_instances:
		var mesh_name = mesh_instance.name.to_lower()
		
		# Apply textures based on mesh names
		for texture_key in textures:
			if texture_key.to_lower() in mesh_name:
				var material = mesh_instance.get_surface_override_material(0)
				if not material:
					material = StandardMaterial3D.new()
					mesh_instance.set_surface_override_material(0, material)
				
				if material is StandardMaterial3D:
					material.albedo_texture = textures[texture_key]

func apply_materials(materials: Dictionary):
	if not character_model or materials.is_empty():
		return
	
	var mesh_instances = _find_all_mesh_instances(character_model)
	for mesh_instance in mesh_instances:
		var mesh_name = mesh_instance.name.to_lower()
		
		for material_key in materials:
			if material_key.to_lower() in mesh_name:
				mesh_instance.set_surface_override_material(0, materials[material_key])

func apply_scale(scale_mult: Vector3):
	if character_model:
		character_model.scale = scale_mult

func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		mesh_instances.append_array(_find_all_mesh_instances(child))
	
	return mesh_instances