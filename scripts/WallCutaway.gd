extends Node3D

@export var cutaway_mode: int = 1  # 0 = walls up, 1 = cutaway, 2 = walls down

var current_walls: Array[Node3D] = []
var location_manager: LocationManager

func _ready():
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Get reference to location manager
	var game_manager = get_parent().get_node_or_null("GameManager")
	if game_manager and game_manager.location_manager:
		location_manager = game_manager.location_manager
		location_manager.location_changed.connect(_on_location_changed)
	
	# Find walls in current scene
	find_walls_in_current_location()

func _on_location_changed(location_name: String):
	# Wait for new location to be ready
	await get_tree().process_frame
	find_walls_in_current_location()

func find_walls_in_current_location():
	current_walls.clear()
	
	# Search for walls in the entire scene tree
	var all_walls = find_all_walls(get_tree().root)
	
	if all_walls.size() > 0:
		current_walls = all_walls
		print("Found ", current_walls.size(), " walls in current location")
		apply_cutaway_mode()
	else:
		print("No walls found in current location")

func find_all_walls(node: Node) -> Array[Node3D]:
	var walls: Array[Node3D] = []
	
	# Check if this node is a wall (has wall_direction metadata or is named like a wall)
	if node is CSGBox3D:
		var is_wall = false
		
		# Check for wall_direction metadata
		if node.has_meta("wall_direction"):
			is_wall = true
		# Check for wall-like names
		elif node.name.to_lower().contains("wall"):
			is_wall = true
		
		if is_wall:
			walls.append(node as Node3D)
	
	# Recursively search children
	for child in node.get_children():
		walls.append_array(find_all_walls(child))
	
	return walls

func _input(event):
	if event.is_action_pressed("toggle_walls"):
		cycle_cutaway_mode()

func cycle_cutaway_mode():
	cutaway_mode = (cutaway_mode + 1) % 3
	apply_cutaway_mode()

	match cutaway_mode:
		0:
			print("Wall mode: Walls Up (all visible)")
		1:
			print("Wall mode: Cutaway (south/east hidden)")
		2:
			print("Wall mode: Walls Down (all hidden)")

func apply_cutaway_mode():
	if current_walls.is_empty():
		return

	match cutaway_mode:
		0:  # Walls up - all visible
			for wall in current_walls:
				set_wall_visibility(wall, true)
		1:  # Cutaway - hide south and east walls
			for wall in current_walls:
				var wall_direction = get_wall_direction(wall)
				var should_be_visible = wall_direction != "south" and wall_direction != "east"
				set_wall_visibility(wall, should_be_visible)
		2:  # Walls down - all hidden
			for wall in current_walls:
				set_wall_visibility(wall, false)

func get_wall_direction(wall: Node3D) -> String:
	# Check metadata first
	if wall.has_meta("wall_direction"):
		return wall.get_meta("wall_direction")
	
	# Try to determine from name
	var name_lower = wall.name.to_lower()
	if "north" in name_lower:
		return "north"
	elif "south" in name_lower:
		return "south"
	elif "east" in name_lower:
		return "east"
	elif "west" in name_lower:
		return "west"
	
	# Default to visible (treat as north)
	return "north"

func set_wall_visibility(wall: Node3D, visible: bool):
	if wall:
		wall.visible = visible
