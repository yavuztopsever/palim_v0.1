@tool
extends EditorScript

## Simple test to verify AssetPlacer functionality

func _run():
	print("=== Simple AssetPlacer Test ===")
	
	# Test AssetLibrary creation
	var asset_library = AssetLibrary.new()
	print("AssetLibrary created successfully")
	
	# Create placeholder assets
	asset_library.create_placeholder_assets()
	print("Placeholder assets created")
	
	# Test AssetPlacer creation
	var asset_placer = AssetPlacer.new(asset_library)
	print("AssetPlacer created successfully")
	
	# Create a simple layout
	var layout = SceneLayout.new(Vector2i(3, 3))
	
	# Add a floor cell
	var floor_cell = CellData.new(Vector2i(1, 1), "floor")
	floor_cell.asset_id = "floor_tile"
	layout.set_cell(Vector2i(1, 1), floor_cell)
	
	# Add a wall cell
	var wall_cell = CellData.new(Vector2i(0, 1), "wall")
	wall_cell.asset_id = "wall_segment"
	layout.set_cell(Vector2i(0, 1), wall_cell)
	
	print("Test layout created with %d cells" % layout.cells.size())
	
	# Create test scene
	var test_scene = Node3D.new()
	test_scene.name = "SimpleAssetTest"
	
	# Place assets
	asset_placer.place_assets_from_layout(test_scene, layout)
	print("Assets placed successfully")
	
	# Add to current scene
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene:
		current_scene.add_child(test_scene)
		test_scene.owner = current_scene
		print("Test scene added to current scene")
	else:
		print("No current scene available")
	
	print("=== Simple Test Complete ===")