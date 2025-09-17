extends Node

# Game manager handles overall game state and logic
# Scene setup is done in Main.tscn

func _ready():
	print("=== Palim 0.1 ===")
	print("Click to move, E to interact with NPCs, W to toggle wall visibility")
	print("")

	# Connect to any NPCs in the scene
	await get_tree().process_frame
	connect_npcs()

func connect_npcs():
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.has_signal("interaction_started"):
			if not npc.is_connected("interaction_started", _on_npc_interaction):
				npc.connect("interaction_started", _on_npc_interaction)

func _on_npc_interaction(npc_name: String, dialogue: String):
	print("\n[", npc_name, "]: ", dialogue, "\n")
	# Here you could show a dialogue UI, trigger events, etc.
