@tool
extends EditorScript

## Test script for AssetPlacer functionality
## Run this script in the Godot editor to test asset placement

func _run():
	print("=== Testing AssetPlacer ===")
	
	# Create a simple test layout
	var layout = SceneLayout.new(Vector2i(5, 5))
	
	# Add some floor cells
	for x in range(1, 4):
		for y in range(1, 4):
			var pos = Vector2i(x, y)
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "floor_tile"
			layout.set_cell(pos, cell)
	
	# Add some walls around the floor
	var wall_positions = [
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),  # Left wall
		Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3),  # Right wall
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),  # Top wall
		Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)   # Bottom wall
	]
	
	for pos in wall_positions:
		var cell = CellData.new(pos, "wall")
		cell.asset_id = "wall_segment"
		layout.set_cell(pos, cell)
	
	# Add a door
	var door_cell = CellData.new(Vector2i(2, 4), "door")
	door_cell.asset_id = "door_frame"
	layout.set_cell(Vector2i(2, 4), door_cell)
	
	# Validate the layout
	if not layout.validate_layout():
		print("ERROR: Test layout validation failed")
		return
	
	print("Test layout created successfully")
	layout.print_layout_stats()
	
	# Test AssetLibrary
	print("\n=== Testing AssetLibrary ===")
	var asset_library = AssetLibrary.new()
	asset_library.print_asset_stats()
	
	# Create placeholder assets for missing files
	asset_library.create_placeholder_assets()
	
	# Test AssetPlacer
	print("\n=== Testing AssetPlacer ===")
	var asset_placer = AssetPlacer.new(asset_library)
	
	# Create a test scene
	var test_scene = Node3D.new()
	test_scene.name = "AssetPlacerTest"
	
	# Place assets
	asset_placer.place_assets_from_layout(test_scene, layout)
	
	# Add to current scene for inspection
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene:
		current_scene.add_child(test_scene)
		test_scene.owner = current_scene
		
		# Set ownership for all children so they save with the scene
		_set_owner_recursive(test_scene, current_scene)
		
		print("Test scene added to current scene. Check the scene tree!")
	else:
		print("No current scene to add test to")
	
	print("=== AssetPlacer Test Complete ===")

func _set_owner_recursive(node: Node, owner: Node):
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)