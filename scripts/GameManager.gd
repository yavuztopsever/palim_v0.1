extends Node

# Game manager handles overall game state and logic
# Manages location loading and persistent systems

enum StartupLocation {
	TOWN_SQUARE, 
	PLAYER_HOUSE
}

@export var startup_location: StartupLocation = StartupLocation.PLAYER_HOUSE

var dialogue_ui: DialogueUI
var location_manager: LocationManager
var location_container: Node3D
const PLAYER_SCENE := preload("res://scenes/characters/ModularPlayer.tscn")
var player_character: CharacterBody3D

func _ready():
	print("=== Palim 0.1 ===")
	print("Click to move, E to interact with NPCs; walls facing the camera auto-hide")
	print("Mouse wheel to zoom in/out, Middle click to reset zoom")
	print("Characters now use integrated animation library with consistent puppeteering")
	print("Debug hotkeys: F5 -> load player house, F6 -> load town square, F7 -> dump animation state")
	print("Alternate launch: pass --location=<player_house|town_square> on the command line")
	print("")

	# Get references to core systems
	await get_tree().process_frame
	
	# Initialize location manager
	location_manager = LocationManager.new()
	add_child(location_manager)
	location_container = get_node("../LocationContainer")
	location_manager.initialize(location_container)
	location_manager.location_changed.connect(_on_location_changed)
	_ensure_player()
	
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and not dialogue_ui.is_connected("dialogue_finished", Callable(self, "_on_dialogue_finished")):
		dialogue_ui.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	
	# Load initial location (check command line args first)
	var initial_location = get_location_name_from_enum(startup_location)
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--location="):
			var requested_location = arg.split("=")[1]
			if requested_location in location_manager.locations:
				initial_location = requested_location
				print("Loading location from command line: ", requested_location)
			break
	
	location_manager.load_location_by_name(initial_location)
	
	# Debug: Print available locations
	print("Available locations: ", location_manager.locations.keys())

func _ensure_player():
	if player_character:
		return
	player_character = PLAYER_SCENE.instantiate()
	player_character.name = "Player"
	location_container.add_child(player_character)

func get_location_name_from_enum(location_enum: StartupLocation) -> String:
	match location_enum:
		StartupLocation.TOWN_SQUARE:
			return "town_square"
		StartupLocation.PLAYER_HOUSE:
			return "player_house"
		_:
			return "player_house"

func _input(event):
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		Key.KEY_F5:
			location_manager.load_location_by_name("player_house")
			print("[Debug] F5 pressed -> loaded player_house")
		Key.KEY_F6:
			location_manager.load_location_by_name("town_square")
			print("[Debug] F6 pressed -> loaded town_square")
		Key.KEY_F7:
			_print_debug_state()

func _on_location_changed(location_name: String):
	print("Location changed to: ", location_name)
	
	# Wait a frame for the scene to be ready
	await get_tree().process_frame
	
	# Connect NPCs in the new location
	connect_npcs()
	
	# Configure camera for new location using standardized types
	var camera = get_node("../Camera3D")
	if camera and camera.has_method("configure_for_location_type"):
		# Use standardized camera configurations
		match location_name:
			"town_square":
				camera.configure_for_location_type("outdoor_large")
			"player_house":
				camera.configure_for_location_type("indoor_small")
			_:  # Default medium indoor
				camera.configure_for_location_type("indoor_medium")
	_place_player_in_location()



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

func _place_player_in_location():
	if not player_character:
		return
	var spawn := location_manager.get_player_spawn()
	if spawn:
		player_character.global_transform = spawn.global_transform
	else:
		player_character.global_transform = location_container.global_transform
	if player_character.has_method("stop_movement"):
		player_character.stop_movement()

func _print_debug_state():
	print("\n--- Debug State ---")
	if location_manager:
		print("Active location:", location_manager.get_current_location_name())
	else:
		print("Active location: <none>")
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		var player_name = player.name
		if player.has_method("get_current_animation"):
			print(player_name, "current animation:", player.get_current_animation())
		if player.has_method("get_available_animations"):
			print(player_name, "available animations:", player.get_available_animations())
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		var npc_name = npc.npc_name
		if npc.has_method("get_available_animations"):
			print(npc_name, "available animations:", npc.get_available_animations())
	print("--- End Debug State ---\n")
