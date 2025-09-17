@tool
extends RefCounted

## Simple test runner for the Scene Generator plugin
## Runs basic functionality tests to ensure the plugin works correctly

static func run_all_tests() -> bool:
	print("=== Scene Generator Plugin Tests ===")
	print("Running comprehensive test suite...")
	
	var all_passed = true
	
	# Test 1: Class verification
	print("\n1. Testing class structure and dependencies...")
	var class_verification = preload("res://addons/scene_generator/verify_classes.gd")
	if not class_verification.verify_classes():
		print("✗ Class verification failed")
		all_passed = false
	else:
		print("✓ Class verification passed")
	
	# Test 2: Basic generation test
	print("\n2. Testing basic scene generation...")
	if not _test_basic_generation():
		print("✗ Basic generation test failed")
		all_passed = false
	else:
		print("✓ Basic generation test passed")
	
	# Test 3: Parameter validation
	print("\n3. Testing parameter validation...")
	if not _test_parameter_validation():
		print("✗ Parameter validation test failed")
		all_passed = false
	else:
		print("✓ Parameter validation test passed")
	
	# Test 4: Asset placement
	print("\n4. Testing asset placement...")
	if not _test_asset_placement():
		print("✗ Asset placement test failed")
		all_passed = false
	else:
		print("✓ Asset placement test passed")
	
	# Test 5: Lighting system
	print("\n5. Testing lighting system...")
	if not _test_lighting_system():
		print("✗ Lighting system test failed")
		all_passed = false
	else:
		print("✓ Lighting system test passed")
	
	# Final result
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All tests passed! Plugin is working correctly.")
	else:
		print("✗ Some tests failed. Please check the output above.")
	
	return all_passed

static func _test_basic_generation() -> bool:
	# Create a simple test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(5, 5)
	params.seed = 12345
	
	# Test generation
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Check that content was generated
	var child_count = test_scene.get_child_count()
	var success = child_count > 0
	
	if success:
		print("  Generated scene with %d child nodes" % child_count)
	else:
		print("  No content generated")
	
	test_scene.queue_free()
	return success

static func _test_parameter_validation() -> bool:
	var success = true
	
	# Test valid parameters
	var valid_params = GenerationParams.new()
	valid_params.area_type = "commercial"
	valid_params.size = Vector2i(10, 10)
	valid_params.seed = 54321
	
	if not valid_params.validate_all_params():
		print("  Valid parameters failed validation")
		success = false
	else:
		print("  Valid parameters passed validation")
	
	# Test invalid parameters
	var invalid_params = GenerationParams.new()
	invalid_params.area_type = "invalid_type"
	invalid_params.size = Vector2i(100, 100)  # Too large
	
	if invalid_params.validate_all_params():
		print("  Invalid parameters incorrectly passed validation")
		success = false
	else:
		print("  Invalid parameters correctly failed validation")
	
	return success

static func _test_asset_placement() -> bool:
	# Create test layout
	var layout = SceneLayout.new(Vector2i(6, 6))
	
	# Add some test cells
	for x in range(2, 5):
		for y in range(2, 5):
			var cell = CellData.new()
			cell.position = Vector2i(x, y)
			cell.cell_type = "floor"
			layout.set_cell(Vector2i(x, y), cell)
	
	# Add walls around the floor
	for x in range(1, 6):
		for y in [1, 5]:
			var cell = CellData.new()
			cell.position = Vector2i(x, y)
			cell.cell_type = "wall"
			layout.set_cell(Vector2i(x, y), cell)
	
	for y in range(2, 5):
		for x in [1, 5]:
			var cell = CellData.new()
			cell.position = Vector2i(x, y)
			cell.cell_type = "wall"
			layout.set_cell(Vector2i(x, y), cell)
	
	# Test layout validation
	var is_valid = layout.validate_layout()
	if is_valid:
		print("  Layout validation passed")
	else:
		print("  Layout validation failed")
	
	# Test asset placement
	var test_scene = Node3D.new()
	var asset_placer = AssetPlacer.new()
	asset_placer.place_assets_from_layout(test_scene, layout)
	
	var assets_placed = test_scene.get_child_count() > 0
	if assets_placed:
		print("  Assets placed successfully")
	else:
		print("  No assets placed")
	
	test_scene.queue_free()
	return is_valid and assets_placed

static func _test_lighting_system() -> bool:
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "administrative"
	params.size = Vector2i(6, 6)
	
	# Test lighting setup
	LightingSetup.setup_scene_lighting(test_scene, params)
	
	# Check for lighting components
	var has_world_env = false
	var has_directional_light = false
	
	for child in test_scene.get_children():
		if child is WorldEnvironment:
			has_world_env = true
		elif child is DirectionalLight3D:
			has_directional_light = true
	
	var success = has_world_env and has_directional_light
	
	if has_world_env:
		print("  WorldEnvironment created")
	else:
		print("  WorldEnvironment missing")
	
	if has_directional_light:
		print("  DirectionalLight3D created")
	else:
		print("  DirectionalLight3D missing")
	
	test_scene.queue_free()
	return success

# Auto-run when script is loaded
func _init():
	run_all_tests()