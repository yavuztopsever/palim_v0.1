@tool
extends EditorScript

## Simple test script for LayoutGenerator
## Run this from the Editor -> Run Script menu to test layout generation

func _run():
	print("=== Testing LayoutGenerator ===")
	
	# Test interior layout generation
	test_interior_layout()
	
	# Test outdoor layout generation  
	test_outdoor_layout()
	
	# Test validation and connectivity
	test_validation_and_connectivity()
	
	print("=== LayoutGenerator tests completed ===")

func test_interior_layout():
	print("\n--- Testing Interior Layout ---")
	
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(12, 10)
	params.interior_spaces = true
	params.seed = 12345
	
	var generator = LayoutGenerator.new()
	var layout = generator.generate_layout(params)
	
	print("Generated interior layout: %s" % layout.to_string())
	layout.print_layout_stats()
	
	# Validate the layout
	var is_valid = layout.validate_layout()
	var is_connected = layout.check_connectivity()
	
	print("Layout valid: %s" % is_valid)
	print("Layout connected: %s" % is_connected)
	
	# Check for expected elements
	var floor_cells = layout.get_cells_of_type("floor")
	var wall_cells = layout.get_cells_of_type("wall")
	
	print("Floor cells: %d" % floor_cells.size())
	print("Wall cells: %d" % wall_cells.size())
	
	test_assert(floor_cells.size() > 0, "Interior layout should have floor cells")
	test_assert(wall_cells.size() > 0, "Interior layout should have wall cells")

func test_outdoor_layout():
	print("\n--- Testing Outdoor Layout ---")
	
	var params = GenerationParams.new()
	params.area_type = "commercial"
	params.size = Vector2i(15, 15)
	params.interior_spaces = false
	params.seed = 54321
	
	var generator = LayoutGenerator.new()
	var layout = generator.generate_layout(params)
	
	print("Generated outdoor layout: %s" % layout.to_string())
	layout.print_layout_stats()
	
	# Validate the layout
	var is_valid = layout.validate_layout()
	var is_connected = layout.check_connectivity()
	
	print("Layout valid: %s" % is_valid)
	print("Layout connected: %s" % is_connected)
	
	# Check for expected elements
	var floor_cells = layout.get_cells_of_type("floor")
	
	print("Floor cells: %d" % floor_cells.size())
	
	test_assert(floor_cells.size() > 0, "Outdoor layout should have floor cells")

func test_validation_and_connectivity():
	print("\n--- Testing Validation and Connectivity ---")
	
	# Test with very small size
	var small_params = GenerationParams.new()
	small_params.size = Vector2i(3, 3)
	small_params.interior_spaces = true
	
	var generator = LayoutGenerator.new()
	var small_layout = generator.generate_layout(small_params)
	
	print("Small layout validation: %s" % small_layout.validate_layout())
	print("Small layout connectivity: %s" % small_layout.check_connectivity())
	
	# Test connectivity fixing
	var disconnected_layout = SceneLayout.new(Vector2i(10, 10))
	
	# Create two separate floor areas
	for x in range(2, 4):
		for y in range(2, 4):
			var cell = CellData.new(Vector2i(x, y), "floor")
			disconnected_layout.set_cell(Vector2i(x, y), cell)
	
	for x in range(6, 8):
		for y in range(6, 8):
			var cell = CellData.new(Vector2i(x, y), "floor")
			disconnected_layout.set_cell(Vector2i(x, y), cell)
	
	print("Disconnected layout connectivity (before): %s" % disconnected_layout.check_connectivity())
	
	# Try to fix connectivity
	var fixed = disconnected_layout.ensure_connectivity()
	print("Connectivity fix successful: %s" % fixed)
	print("Disconnected layout connectivity (after): %s" % disconnected_layout.check_connectivity())
	
	test_assert(disconnected_layout.check_connectivity(), "Connectivity should be fixed")

func test_assert(condition: bool, message: String):
	if not condition:
		push_error("ASSERTION FAILED: %s" % message)
	else:
		print("✓ %s" % message)