@tool
extends EditorScript

## Test script for wall hiding system
## Run this in the editor to test the wall hiding functionality

func _run():
	print("Testing Wall Hiding System...")
	
	# Test WallHidingSystem component
	test_wall_hiding_component()
	
	# Test InteriorSpaceDetector
	test_interior_space_detector()
	
	print("Wall hiding system tests completed!")

func test_wall_hiding_component():
	print("\n=== Testing WallHidingSystem Component ===")
	
	# Create a test wall node
	var wall_node = Node3D.new()
	wall_node.name = "TestWall"
	
	# Add a mesh to the wall
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 3, 0.2)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GRAY
	mesh_instance.material_override = material
	
	wall_node.add_child(mesh_instance)
	
	# Add WallHidingSystem component
	var wall_hiding = preload("res://addons/scene_generator/utils/wall_hiding_system.gd").new()
	wall_hiding.wall_direction = Vector3.FORWARD
	wall_hiding.is_interior = true
	wall_hiding.room_id = "test_room"
	wall_hiding.transparency_fade = 0.5
	
	wall_node.add_child(wall_hiding)
	
	print("✓ WallHidingSystem component created successfully")
	print("  - Wall direction: %s" % wall_hiding.wall_direction)
	print("  - Is interior: %s" % wall_hiding.is_interior)
	print("  - Room ID: %s" % wall_hiding.room_id)
	print("  - Transparency fade: %s" % wall_hiding.transparency_fade)
	
	# Test visibility methods
	wall_hiding.set_wall_visibility(false)
	print("  - Wall hidden: %s" % (not wall_node.visible))
	
	wall_hiding.set_wall_visibility(true)
	print("  - Wall shown: %s" % wall_node.visible)
	
	# Test transparency
	wall_hiding.set_wall_transparency(true)
	print("  - Transparency applied: %s" % wall_hiding.is_currently_transparent)
	
	wall_hiding.set_wall_transparency(false)
	print("  - Transparency removed: %s" % (not wall_hiding.is_currently_transparent))
	
	# Clean up
	wall_node.queue_free()

func test_interior_space_detector():
	print("\n=== Testing InteriorSpaceDetector ===")
	
	# Create a test layout
	var layout = SceneLayout.new()
	layout.grid_size = Vector2i(10, 10)
	
	# Create a simple room layout
	# Floor cells forming a 3x3 room
	for x in range(2, 5):
		for y in range(2, 5):
			var floor_cell = CellData.new()
			floor_cell.position = Vector2i(x, y)
			floor_cell.cell_type = "floor"
			layout.add_cell(floor_cell)
	
	# Wall cells around the room
	var wall_positions = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1),
		Vector2i(1, 2), Vector2i(5, 2),
		Vector2i(1, 3), Vector2i(5, 3),
		Vector2i(1, 4), Vector2i(5, 4),
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)
	]
	
	for pos in wall_positions:
		var wall_cell = CellData.new()
		wall_cell.position = pos
		wall_cell.cell_type = "wall"
		layout.add_cell(wall_cell)
	
	print("✓ Test layout created with %d cells" % layout.cells.size())
	
	# Test space detection
	var InteriorSpaceDetector = preload("res://addons/scene_generator/utils/interior_space_detector.gd")
	var space_info = InteriorSpaceDetector.detect_interior_spaces(layout)
	
	print("✓ Space detection completed")
	print("  - Interior rooms: %d" % space_info.interior_rooms.size())
	print("  - Exterior areas: %d" % space_info.exterior_areas.size())
	print("  - Mixed areas: %d" % space_info.mixed_areas.size())
	
	# Test space detection application
	InteriorSpaceDetector.apply_space_detection_to_layout(layout, space_info)
	print("✓ Space detection applied to layout")
	
	# Test roof generation configuration
	InteriorSpaceDetector.configure_roof_generation(layout, space_info)
	print("✓ Roof generation configured")
	
	# Test wall hiding configuration
	InteriorSpaceDetector.configure_wall_hiding_behavior(layout, space_info)
	print("✓ Wall hiding behavior configured")
	
	# Check results
	var floor_cells = layout.get_cells_of_type("floor")
	if floor_cells.size() > 0:
		var sample_floor = floor_cells[0]
		print("  - Sample floor cell properties:")
		print("    - Is interior: %s" % sample_floor.properties.get("is_interior", "not set"))
		print("    - Space type: %s" % sample_floor.properties.get("space_type", "not set"))
		print("    - Room ID: %s" % sample_floor.properties.get("room_id", "not set"))
		print("    - Generate roof: %s" % sample_floor.properties.get("generate_roof", "not set"))
	
	var wall_cells = layout.get_cells_of_type("wall")
	if wall_cells.size() > 0:
		var sample_wall = wall_cells[0]
		print("  - Sample wall cell properties:")
		print("    - Is interior wall: %s" % sample_wall.properties.get("is_interior_wall", "not set"))
		print("    - Adjacent room ID: %s" % sample_wall.properties.get("adjacent_room_id", "not set"))
		print("    - Hide when behind: %s" % sample_wall.properties.get("hide_when_behind", "not set"))
	
	print("✓ Interior space detection test completed successfully")