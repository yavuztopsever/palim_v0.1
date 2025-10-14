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
var character_model: Node3D
var animator: CharacterAnimator
var character_config: CharacterConfig

func _ready():
	add_to_group("npcs")
	set_process_input(true)
	
	# Set up character system
	await get_tree().process_frame
	setup_character_system()

func setup_character_system():
	# Find character components
	character_model = get_node_or_null("CharacterModel")
	animator = get_node_or_null("CharacterAnimator")
	if animator == null:
		animator = get_node_or_null("AnimationController")
	
	if not character_model:
		push_warning("Error: No CharacterModel found in %s" % name)
		return
	
	if not animator:
		push_warning("Error: No CharacterAnimator found in %s" % name)
		return
	
	var overrides := {} if npc_config == null else npc_config.animation_overrides
	var speed := 1.0 if npc_config == null else npc_config.animation_speed
	animator.setup(self, character_model, overrides, speed)
	animator.refresh()
	if npc_config:
		_apply_npc_identity(npc_config)
	print("NPC character setup complete. Available animations: ", animator.get_available_clips())
	play_animation("idle")

func _input(event):
	if player_nearby and event.is_action_pressed("interact"):
		start_interaction()

func start_interaction():
	if not interaction_active:
		interaction_active = true
		var resolved_dialogue := _resolve_dialogue_text()
		interaction_started.emit(npc_name, resolved_dialogue, dialogue_resource, self)
		print("%s: %s" % [npc_name, resolved_dialogue])

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

# Animation system with dynamic animation mapping
func play_animation(anim_name: String, force: bool = false) -> bool:
	if animator:
		return animator.play(anim_name, force)
	return false

# Character customization methods
func set_character_config(config: CharacterConfig):
	npc_config = config
	character_config = config
	if config:
		apply_character_config(config)
		_apply_npc_identity(config)

func get_character_config() -> CharacterConfig:
	return npc_config

func get_available_animations() -> PackedStringArray:
	if animator:
		return animator.get_available_clips()
	return PackedStringArray()

func get_current_animation() -> String:
	if animator:
		return animator.get_current_clip()
	return ""

func _resolve_dialogue_text() -> String:
	if typeof(dialogue_text) == TYPE_STRING:
		var trimmed := dialogue_text.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	if npc_config and typeof(npc_config.default_dialogue) == TYPE_STRING:
		var config_text := npc_config.default_dialogue.strip_edges()
		if not config_text.is_empty():
			return config_text
	return "..."

func apply_character_config(config: CharacterConfig):
	if not config:
		return
	if animator:
		animator.setup(self, character_model, config.animation_overrides, config.animation_speed)
		animator.refresh()

func _apply_npc_identity(config: CharacterConfig) -> void:
	npc_name = config.character_name
	dialogue_text = config.default_dialogue
	if config.dialogue_resource:
		dialogue_resource = config.dialogue_resource

# Utility function for facing a position
func face_position(target_pos: Vector3, turn_speed: float = 8.0):
	var look_pos = target_pos
	look_pos.y = global_position.y
	var direction = (look_pos - global_position).normalized()
	
	if direction.length() > 0.001:
		var desired_yaw = atan2(-direction.x, -direction.z) + PI
		if turn_speed <= 0:
			rotation.y = desired_yaw
			return
		var delta := get_physics_process_delta_time()
		if delta <= 0:
			rotation.y = desired_yaw
		else:
			var t := clamp(turn_speed * delta, 0.0, 1.0)
			rotation.y = lerp_angle(rotation.y, desired_yaw, t)
