extends Node

# Game manager handles overall game state and logic
# Scene setup is done in Main.tscn

var dialogue_ui: DialogueUI

func _ready():
	print("=== Palim 0.1 ===")
	print("Click to move, E to interact with NPCs, W to toggle wall visibility")
	print("")

	# Connect to any NPCs in the scene
	await get_tree().process_frame
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and not dialogue_ui.is_connected("dialogue_finished", Callable(self, "_on_dialogue_finished")):
		dialogue_ui.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	connect_npcs()

func connect_npcs():
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.has_signal("interaction_started"):
			if not npc.is_connected("interaction_started", _on_npc_interaction):
				npc.connect("interaction_started", _on_npc_interaction)

func _on_npc_interaction(npc_name: String, dialogue: String, dialogue_resource: DialogueResource, npc: Node):
	if dialogue_ui:
		_set_player_movement_enabled(false)
		dialogue_ui.start_dialogue(npc_name, dialogue_resource, dialogue, npc)
	else:
		print("\n[", npc_name, "]: ", dialogue, "\n")
		if npc and npc.has_method("end_interaction"):
			npc.end_interaction()
		# With no UI available, just print dialogue in console.

func _on_dialogue_finished(npc: Node):
	_set_player_movement_enabled(true)
	if npc and npc.has_method("end_interaction"):
		npc.end_interaction()

func _set_player_movement_enabled(enabled: bool):
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_method("set_movement_enabled"):
			player.set_movement_enabled(enabled)
