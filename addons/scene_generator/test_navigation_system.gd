@tool
extends EditorScript

## Test script for navigation system functionality
## Run this script in the Godot editor to test navigation mesh generation and validation

func _run():
	print("=== Testing Navigation System ===")
	
	# Create a test scene
	var test_scene = Node3D.new()
	test_scene.name = "NavigationTestScene"
	
	# Create test layout
	var layout = SceneLayout.new(Vector2i(8, 8))
	_create_test_layout(layout)
	
	print("Created test layout with %d cells" % layout.cells.size())
	
	# Generate navigation region
	var nav_region = NavigationBuilder.generate_navigation_region_for_layout(test_scene, layout)
	
	if not nav_region:
		print("ERROR: Failed to generate navigation region")
		return
	
	print("Generated navigation region successfully")
	
	# Validate navigation system
	var validation_results = NavigationValidator.validate_navigation_system(nav_region, layout)
	
	print("\n=== Validation Results ===")
	NavigationValidator.print_validation_results(validation_results)
	
	# Test quick validation
	var quick_check = NavigationValidator.quick_validation_check(nav_region, layout)
	print("\nQuick validation check: %s" % ("PASS" if quick_check else "FAIL"))
	
	# Test room connectivity if multiple rooms exist
	var room_connectivity = NavigationValidator.test_room_connectivity(nav_region, layout)
	print("\n=== Room Connectivity ===")
	print("Room connectivity valid: %s" % ("PASS" if room_connectivity.valid else "FAIL"))
	if "stats" in room_connectivity:
		var stats = room_connectivity.stats
		print("Rooms found: %d" % stats.get("room_count", 0))
		if stats.get("room_count", 0) > 1:
			print("Connected room pairs: %d/%d" % [stats.get("connected_pairs", 0), stats.get("total_pairs", 0)])
	
	# Print navigation mesh statistics
	if nav_region.navigation_mesh:
		print("\n=== Navigation Mesh Statistics ===")
		NavigationBuilder.print_navigation_mesh_stats(nav_region.navigation_mesh)
	
	# Add to current scene for inspection
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene:
		current_scene.add_child(test_scene)
		test_scene.owner = current_scene
		
		# Set ownership for all children
		_set_owner_recursive(test_scene, current_scene)
		
		print("\nTest scene added to current scene for inspection")
	else:
		print("\nNo current scene - test scene not added")
	
	print("\n=== Navigation System Test Complete ===")

## Creates a test layout with rooms and corridors
func _create_test_layout(layout: SceneLayout) -> void:
	# Create a simple layout with two rooms connected by a corridor
	
	# Room 1 (top-left)
	for x in range(1, 4):
		for y in range(1, 4):
			var pos = Vector2i(x, y)
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "floor_tile"
			layout.set_cell(pos, cell)
	
	# Room 2 (bottom-right)
	for x in range(5, 8):
		for y in range(5, 8):
			var pos = Vector2i(x, y)
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "floor_tile"
			layout.set_cell(pos, cell)
	
	# Corridor connecting the rooms
	var corridor_positions = [
		Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)
	]
	
	for pos in corridor_positions:
		var cell = CellData.new(pos, "floor")
		cell.asset_id = "corridor_tile"
		layout.set_cell(pos, cell)
	
	# Add walls around the rooms
	_add_walls_around_floors(layout)
	
	# Add a door in the corridor
	var door_pos = Vector2i(4, 3)
	var door_cell = CellData.new(door_pos, "door")
	door_cell.asset_id = "door_frame"
	layout.set_cell(door_pos, door_cell)

## Adds walls around floor areas
func _add_walls_around_floors(layout: SceneLayout) -> void:
	var wall_positions: Array[Vector2i] = []
	
	# Find all positions that should have walls (adjacent to floors but not floors themselves)
	for x in range(layout.grid_size.x):
		for y in range(layout.grid_size.y):
			var pos = Vector2i(x, y)
			var cell = layout.get_cell(pos)
			
			# If this position is empty, check if it should be a wall
			if not cell or cell.cell_type == "empty":
				if _should_be_wall(layout, pos):
					wall_positions.append(pos)
	
	# Place walls
	for wall_pos in wall_positions:
		var wall_cell = CellData.new(wall_pos, "wall")
		wall_cell.asset_id = "wall_segment"
		layout.set_cell(wall_pos, wall_cell)

## Checks if a position should be a wall (adjacent to floor)
func _should_be_wall(layout: SceneLayout, pos: Vector2i) -> bool:
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			return true
	
	return false

## Sets owner recursively for all children
func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)