extends StaticBody3D

# Modular NPC class with integrated BaseCharacter functionality
# Handles NPC-specific interaction and dialogue

@export var npc_name: String = "NPC"
@export var dialogue_text: String = "Hello there!"
@export var dialogue_resource: DialogueResource
@export var npc_config: CharacterConfig

signal interaction_started(npc_name, dialogue, dialogue_resource, npc)

var player_nearby = false
var interaction_active = false

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
	add_to_group("npcs")
	set_process_input(true)
	
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
	
	# Apply NPC configuration
	if npc_config:
		apply_character_config(npc_config)
		# Update NPC properties from config
		npc_name = npc_config.character_name
		dialogue_text = npc_config.default_dialogue
		if npc_config.dialogue_resource:
			dialogue_resource = npc_config.dialogue_resource
	
	print("NPC character setup complete. Available animations: ", animation_player.get_animation_list())
	play_animation("idle")

func _search_for_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _search_for_animation_player(child)
		if result:
			return result
	return null

func _input(event):
	if player_nearby and event.is_action_pressed("interact"):
		start_interaction()

func start_interaction():
	if not interaction_active:
		interaction_active = true
		interaction_started.emit(npc_name, dialogue_text, dialogue_resource, self)
		print(npc_name + ": " + dialogue_text)

		# Face the player
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			# Face the player by looking at their position
			face_position(player.global_position)
			if player.has_method("stop_movement"):
				player.stop_movement()

		# Play talk animation
		if not play_animation("talk"):
			play_animation("idle")

func end_interaction():
	interaction_active = false

	# Return to idle animation
	play_animation("idle")

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		print("Press E to interact with " + npc_name)

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		end_interaction()

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
				print("NPC ", npc_name, " playing animation: ", name_variant)
				return true
			return true
	
	print("NPC ", npc_name, " animation not found: ", anim_name, " (tried: ", animation_variants, ")")
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

# Character customization methods
func set_character_config(config: CharacterConfig):
	npc_config = config
	character_config = config
	if config:
		apply_character_config(config)
		# Update NPC properties from config
		npc_name = config.character_name
		dialogue_text = config.default_dialogue
		if config.dialogue_resource:
			dialogue_resource = config.dialogue_resource

func get_character_config() -> CharacterConfig:
	return npc_config

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

func get_available_animations() -> PackedStringArray:
	if animation_player:
		return animation_player.get_animation_list()
	return PackedStringArray()

# Utility function for facing a position
func face_position(target_pos: Vector3, turn_speed: float = 8.0):
	var look_pos = target_pos
	look_pos.y = global_position.y
	var direction = (look_pos - global_position).normalized()
	
	if direction.length() > 0.001:
		var desired_yaw = atan2(-direction.x, -direction.z) + PI
		rotation.y = lerp_angle(rotation.y, desired_yaw, turn_speed * get_process_delta_time())
