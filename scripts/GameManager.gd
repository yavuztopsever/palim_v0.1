extends Node

# Game manager handles overall game state and logic
# Manages location loading and persistent systems

enum StartupLocation {
	TEST_ROOM,
	TOWN_SQUARE, 
	PLAYER_HOUSE
}

@export var startup_location: StartupLocation = StartupLocation.TEST_ROOM

var dialogue_ui: DialogueUI
var location_manager: LocationManager

func _ready():
	print("=== Palim 0.1 ===")
	print("Click to move, E to interact with NPCs, W to toggle wall visibility")
	print("Mouse wheel to zoom in/out, Middle click to reset zoom")
	print("Press ENTER to load TestRoom, SPACE to load TownSquare, H to load PlayerHouse")
	print("Characters now use integrated animation library with consistent puppeteering")
	print("")

	# Get references to core systems
	await get_tree().process_frame
	
	# Initialize location manager
	location_manager = LocationManager.new()
	add_child(location_manager)
	location_manager.initialize(get_node("../LocationContainer"))
	location_manager.location_changed.connect(_on_location_changed)
	
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

func get_location_name_from_enum(location_enum: StartupLocation) -> String:
	match location_enum:
		StartupLocation.TEST_ROOM:
			return "test_room"
		StartupLocation.TOWN_SQUARE:
			return "town_square"
		StartupLocation.PLAYER_HOUSE:
			return "player_house"
		_:
			return "test_room"

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Enter key
		location_manager.load_location_by_name("test_room")
	elif Input.is_action_just_pressed("ui_select"):  # Space key
		location_manager.load_location_by_name("town_square")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_H:
		location_manager.load_location_by_name("player_house")

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
			"test_room":
				camera.configure_for_location_type("indoor_medium")
			_:  # Default medium indoor
				camera.configure_for_location_type("indoor_medium")



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
