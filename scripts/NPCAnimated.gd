extends StaticBody3D

@export var npc_name: String = "Clerk"
@export var dialogue_text: String = "Another form to file... the work never ends."
@export var dialogue_resource: DialogueResource

signal interaction_started(npc_name, dialogue, dialogue_resource, npc)

var player_nearby = false
var interaction_active = false
var animation_player: AnimationPlayer

func _ready():
	add_to_group("npcs")
	set_process_input(true)

	# Find AnimationPlayer in the character model
	await get_tree().process_frame
	_find_animation_player()

func _find_animation_player():
	# Search for AnimationPlayer in the character model
	var character_model = $CharacterModel
	animation_player = _search_for_animation_player(character_model)

	if animation_player:
		print("NPC found AnimationPlayer with animations: ", animation_player.get_animation_list())
		# Play idle animation if available
		if animation_player.has_animation("Idle"):
			animation_player.play("Idle")
		elif animation_player.has_animation("idle"):
			animation_player.play("idle")
		elif animation_player.get_animation_list().size() > 0:
			# Play first available animation
			animation_player.play(animation_player.get_animation_list()[0])

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
			var look_pos = player.global_position
			look_pos.y = global_position.y
			look_at(look_pos, Vector3.UP)
			if player.has_method("stop_movement"):
				player.stop_movement()

		# Play talk animation if available
		if animation_player:
			if animation_player.has_animation("Talk"):
				animation_player.play("Talk")
			elif animation_player.has_animation("talk"):
				animation_player.play("talk")

func end_interaction():
	interaction_active = false

	# Return to idle animation
	if animation_player:
		if animation_player.has_animation("Idle"):
			animation_player.play("Idle")
		elif animation_player.has_animation("idle"):
			animation_player.play("idle")

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		print("Press E to interact with " + npc_name)

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		end_interaction()
