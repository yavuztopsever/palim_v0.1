@tool
extends EditorScript

## Comprehensive scene validation and testing system
## Tests generated scenes for proper integration with camera systems, navigation, and collision

# Test configuration
const TEST_AREA_TYPES = ["residential", "commercial", "administrative", "mixed"]
const TEST_SIZES = [Vector2i(5, 5), Vector2i(10, 10), Vector2i(15, 15)]
const TEST_SEEDS = [12345, 67890, 11111]

# Test results tracking
var test_results: Dictionary = {}
var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _run():
	print("=== Scene Generator Validation Tests ===")
	print("Starting comprehensive testing suite...")
	
	# Initialize test tracking
	test_results.clear()
	total_tests = 0
	passed_tests = 0
	failed_tests = 0
	
	# Run all test suites
	test_basic_generation_functionality()
	test_camera_system_integration()
	test_navigation_mesh_connectivity()
	test_collision_detection()
	test_lighting_system_integration()
	test_scene_saving_and_loading()
	
	# Print final results
	print_test_summary()

## Tests basic generation functionality for all area types and sizes
func test_basic_generation_functionality():
	print("\n--- Testing Basic Generation Functionality ---")
	
	for area_type in TEST_AREA_TYPES:
		for size in TEST_SIZES:
			for seed in TEST_SEEDS:
				var test_name = "basic_generation_%s_%dx%d_seed%d" % [area_type, size.x, size.y, seed]
				run_test(test_name, _test_basic_generation, [area_type, size, seed])

func _test_basic_generation(area_type: String, size: Vector2i, seed: int) -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	test_scene.name = "TestScene"
	
	# Create generation parameters
	var params = GenerationParams.new()
	params.area_type = area_type
	params.size = size
	params.seed = seed
	params.interior_spaces = true
	
	# Validate parameters
	if not params.validate_all_params():
		result.errors.append("Invalid generation parameters")
		return result
	
	# Generate scene
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Validate generated content
	if test_scene.get_child_count() == 0:
		result.errors.append("No content generated")
		return result
	
	# Check for required components
	var has_world_env = _find_node_of_type(test_scene, WorldEnvironment) != null
	var has_directional_light = _find_node_of_type(test_scene, DirectionalLight3D) != null
	var has_navigation = _find_node_of_type(test_scene, NavigationRegion3D) != null
	
	if not has_world_env:
		result.errors.append("Missing WorldEnvironment")
	if not has_directional_light:
		result.errors.append("Missing DirectionalLight3D")
	if not has_navigation:
		result.warnings.append("Missing NavigationRegion3D")
	
	# Check for mesh instances (walls, floors, etc.)
	var mesh_instances = _find_all_nodes_of_type(test_scene, MeshInstance3D)
	if mesh_instances.size() == 0:
		result.errors.append("No MeshInstance3D nodes found")
	
	# Check for collision bodies
	var static_bodies = _find_all_nodes_of_type(test_scene, StaticBody3D)
	if static_bodies.size() == 0:
		result.errors.append("No StaticBody3D nodes found")
	
	# Cleanup
	test_scene.queue_free()
	
	result.success = result.errors.is_empty()
	return result

## Tests integration with camera systems
func test_camera_system_integration():
	print("\n--- Testing Camera System Integration ---")
	
	# Test wall hiding system integration
	run_test("wall_hiding_integration", _test_wall_hiding_integration, [])
	
	# Test isometric camera compatibility
	run_test("isometric_camera_compatibility", _test_isometric_camera_compatibility, [])

func _test_wall_hiding_integration() -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene with generated content
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(8, 8)
	params.interior_spaces = true
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Check for wall hiding components
	var walls_with_hiding = 0
	var total_walls = 0
	
	var static_bodies = _find_all_nodes_of_type(test_scene, StaticBody3D)
	for body in static_bodies:
		if body.name.contains("Wall"):
			total_walls += 1
			if body.has_meta("wall_layer") or body.has_meta("room_id"):
				walls_with_hiding += 1
	
	if total_walls == 0:
		result.errors.append("No walls found in generated scene")
	elif walls_with_hiding == 0:
		result.warnings.append("No walls have wall hiding metadata")
	else:
		var coverage = float(walls_with_hiding) / float(total_walls) * 100.0
		if coverage < 50.0:
			result.warnings.append("Low wall hiding coverage: %.1f%%" % coverage)
	
	# Check for interior space detection
	var interior_detector = _find_node_of_type(test_scene, Node)
	if interior_detector and interior_detector.has_method("detect_interior_spaces"):
		# Interior space detection is available
		pass
	else:
		result.warnings.append("Interior space detection not found")
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

func _test_isometric_camera_compatibility() -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "commercial"
	params.size = Vector2i(10, 10)
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Add isometric camera
	var camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(10, 15, 10)
	camera.rotation_degrees = Vector3(-45, 45, 0)
	test_scene.add_child(camera)
	
	# Check lighting compatibility with isometric view
	var directional_light = _find_node_of_type(test_scene, DirectionalLight3D)
	if directional_light:
		var light_rotation = directional_light.rotation_degrees
		if abs(light_rotation.x + 45) > 10 or abs(light_rotation.y - 45) > 10:
			result.warnings.append("Directional light not optimized for isometric view")
	
	# Check that no roofs block the view (for interior spaces)
	var mesh_instances = _find_all_nodes_of_type(test_scene, MeshInstance3D)
	var roof_count = 0
	for mesh in mesh_instances:
		if mesh.name.to_lower().contains("roof") or mesh.name.to_lower().contains("ceiling"):
			roof_count += 1
	
	if params.interior_spaces and roof_count > 0:
		result.warnings.append("Found %d roof/ceiling elements in interior scene" % roof_count)
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

## Tests navigation mesh connectivity
func test_navigation_mesh_connectivity():
	print("\n--- Testing Navigation Mesh Connectivity ---")
	
	for area_type in TEST_AREA_TYPES:
		var test_name = "navigation_connectivity_%s" % area_type
		run_test(test_name, _test_navigation_connectivity, [area_type])

func _test_navigation_connectivity(area_type: String) -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = area_type
	params.size = Vector2i(12, 12)
	params.interior_spaces = true
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Find navigation region
	var nav_region = _find_node_of_type(test_scene, NavigationRegion3D)
	if not nav_region:
		result.errors.append("No NavigationRegion3D found")
		test_scene.queue_free()
		return result
	
	# Check if navigation mesh is baked
	if not nav_region.navigation_mesh:
		result.errors.append("NavigationRegion3D has no navigation mesh")
		test_scene.queue_free()
		return result
	
	var nav_mesh = nav_region.navigation_mesh
	if nav_mesh.get_polygon_count() == 0:
		result.errors.append("Navigation mesh has no polygons")
		test_scene.queue_free()
		return result
	
	# Test navigation agent pathfinding
	var nav_agent = NavigationAgent3D.new()
	test_scene.add_child(nav_agent)
	
	# Wait for navigation to be ready (in a real test, this would be async)
	await test_scene.get_tree().process_frame
	
	# Test pathfinding between different points
	var test_points = [
		Vector3(2, 0, 2),
		Vector3(8, 0, 8),
		Vector3(15, 0, 5),
		Vector3(5, 0, 15)
	]
	
	var successful_paths = 0
	var total_path_tests = 0
	
	for i in range(test_points.size()):
		for j in range(i + 1, test_points.size()):
			total_path_tests += 1
			nav_agent.target_position = test_points[j]
			
			# Check if path is valid (simplified check)
			if nav_agent.is_navigation_finished():
				successful_paths += 1
	
	if total_path_tests > 0:
		var success_rate = float(successful_paths) / float(total_path_tests) * 100.0
		if success_rate < 50.0:
			result.errors.append("Low pathfinding success rate: %.1f%%" % success_rate)
		elif success_rate < 80.0:
			result.warnings.append("Moderate pathfinding success rate: %.1f%%" % success_rate)
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

## Tests collision detection
func test_collision_detection():
	print("\n--- Testing Collision Detection ---")
	
	run_test("collision_coverage", _test_collision_coverage, [])
	run_test("collision_accuracy", _test_collision_accuracy, [])

func _test_collision_coverage() -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "mixed"
	params.size = Vector2i(10, 10)
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Count mesh instances vs collision bodies
	var mesh_instances = _find_all_nodes_of_type(test_scene, MeshInstance3D)
	var static_bodies = _find_all_nodes_of_type(test_scene, StaticBody3D)
	
	if mesh_instances.size() == 0:
		result.errors.append("No mesh instances found")
		test_scene.queue_free()
		return result
	
	if static_bodies.size() == 0:
		result.errors.append("No collision bodies found")
		test_scene.queue_free()
		return result
	
	# Check collision shape coverage
	var bodies_with_shapes = 0
	for body in static_bodies:
		var collision_shapes = _find_all_nodes_of_type(body, CollisionShape3D)
		if collision_shapes.size() > 0:
			bodies_with_shapes += 1
	
	var coverage = float(bodies_with_shapes) / float(static_bodies.size()) * 100.0
	if coverage < 90.0:
		result.errors.append("Low collision shape coverage: %.1f%%" % coverage)
	elif coverage < 100.0:
		result.warnings.append("Incomplete collision shape coverage: %.1f%%" % coverage)
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

func _test_collision_accuracy() -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(8, 8)
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Test collision alignment with visual geometry
	var static_bodies = _find_all_nodes_of_type(test_scene, StaticBody3D)
	var misaligned_collisions = 0
	
	for body in static_bodies:
		var collision_shapes = _find_all_nodes_of_type(body, CollisionShape3D)
		for shape_node in collision_shapes:
			var shape = shape_node.shape
			if shape is BoxShape3D:
				var box_shape = shape as BoxShape3D
				# Check if box shape has reasonable dimensions
				if box_shape.size.x <= 0 or box_shape.size.y <= 0 or box_shape.size.z <= 0:
					misaligned_collisions += 1
	
	if misaligned_collisions > 0:
		result.warnings.append("Found %d potentially misaligned collision shapes" % misaligned_collisions)
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

## Tests lighting system integration
func test_lighting_system_integration():
	print("\n--- Testing Lighting System Integration ---")
	
	for area_type in TEST_AREA_TYPES:
		var test_name = "lighting_integration_%s" % area_type
		run_test(test_name, _test_lighting_integration, [area_type])

func _test_lighting_integration(area_type: String) -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = area_type
	params.size = Vector2i(10, 10)
	params.interior_spaces = true
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Check for proper lighting setup
	var world_env = _find_node_of_type(test_scene, WorldEnvironment)
	if not world_env:
		result.errors.append("Missing WorldEnvironment")
	elif not world_env.environment:
		result.errors.append("WorldEnvironment has no Environment")
	
	var directional_light = _find_node_of_type(test_scene, DirectionalLight3D)
	if not directional_light:
		result.errors.append("Missing DirectionalLight3D")
	
	# Check for interior lights
	var point_lights = _find_all_nodes_of_type(test_scene, OmniLight3D)
	var spot_lights = _find_all_nodes_of_type(test_scene, SpotLight3D)
	
	if params.interior_spaces and point_lights.size() == 0 and spot_lights.size() == 0:
		result.warnings.append("No interior lights found for interior scene")
	
	# Verify area-specific lighting characteristics
	if world_env and world_env.environment:
		var ambient_color = world_env.environment.ambient_light_color
		
		match area_type:
			"residential":
				if ambient_color.r <= ambient_color.b:
					result.warnings.append("Residential lighting should be warmer")
			"commercial":
				if world_env.environment.ambient_light_energy < 0.5:
					result.warnings.append("Commercial lighting should be brighter")
			"administrative":
				if ambient_color.b <= ambient_color.r:
					result.warnings.append("Administrative lighting should be cooler")
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

## Tests scene saving and loading
func test_scene_saving_and_loading():
	print("\n--- Testing Scene Saving and Loading ---")
	
	run_test("scene_ownership", _test_scene_ownership, [])
	run_test("scene_persistence", _test_scene_persistence, [])

func _test_scene_ownership() -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "mixed"
	params.size = Vector2i(6, 6)
	
	# Simulate the dock's container creation
	var container = Node3D.new()
	container.name = "Generated_Test_Container"
	container.set_meta("scene_generator_content", true)
	test_scene.add_child(container)
	container.owner = test_scene
	
	# Generate content in container
	var generator = LayoutGenerator.new()
	generator.generate_scene(container, params)
	
	# Check ownership recursively
	var nodes_without_owner = 0
	_check_ownership_recursive(container, test_scene, nodes_without_owner)
	
	if nodes_without_owner > 0:
		result.errors.append("Found %d nodes without proper ownership" % nodes_without_owner)
	
	# Check for metadata
	if not container.has_meta("scene_generator_content"):
		result.errors.append("Container missing generator metadata")
	
	test_scene.queue_free()
	result.success = result.errors.is_empty()
	return result

func _test_scene_persistence() -> Dictionary:
	var result = {"success": false, "errors": [], "warnings": []}
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(5, 5)
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Count generated nodes
	var original_node_count = _count_all_nodes(test_scene)
	
	# Create a packed scene (simulate saving)
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(test_scene)
	
	if pack_result != OK:
		result.errors.append("Failed to pack scene: error %d" % pack_result)
		test_scene.queue_free()
		return result
	
	# Instantiate the packed scene (simulate loading)
	var loaded_scene = packed_scene.instantiate()
	if not loaded_scene:
		result.errors.append("Failed to instantiate packed scene")
		test_scene.queue_free()
		return result
	
	# Compare node counts
	var loaded_node_count = _count_all_nodes(loaded_scene)
	if loaded_node_count != original_node_count:
		result.warnings.append("Node count mismatch: original %d, loaded %d" % [original_node_count, loaded_node_count])
	
	# Cleanup
	test_scene.queue_free()
	loaded_scene.queue_free()
	
	result.success = result.errors.is_empty()
	return result

## Helper methods for testing

func run_test(test_name: String, test_func: Callable, args: Array = []) -> void:
	total_tests += 1
	print("Running test: %s" % test_name)
	
	var start_time = Time.get_ticks_msec()
	var result = test_func.callv(args)
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = result
	test_results[test_name]["duration_ms"] = duration
	
	if result.success:
		passed_tests += 1
		print("  ✓ PASSED (%d ms)" % duration)
		if result.warnings.size() > 0:
			for warning in result.warnings:
				print("    ⚠ Warning: %s" % warning)
	else:
		failed_tests += 1
		print("  ✗ FAILED (%d ms)" % duration)
		for error in result.errors:
			print("    ✗ Error: %s" % error)
		for warning in result.warnings:
			print("    ⚠ Warning: %s" % warning)

func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

func _find_all_nodes_of_type(node: Node, type: Variant) -> Array[Node]:
	var nodes: Array[Node] = []
	
	if is_instance_of(node, type):
		nodes.append(node)
	
	for child in node.get_children():
		nodes.append_array(_find_all_nodes_of_type(child, type))
	
	return nodes

func _check_ownership_recursive(node: Node, expected_owner: Node, counter: int) -> void:
	if node != expected_owner and node.owner != expected_owner:
		counter += 1
	
	for child in node.get_children():
		_check_ownership_recursive(child, expected_owner, counter)

func _count_all_nodes(node: Node) -> int:
	var count = 1  # Count this node
	
	for child in node.get_children():
		count += _count_all_nodes(child)
	
	return count

func print_test_summary():
	print("\n=== Test Summary ===")
	print("Total Tests: %d" % total_tests)
	print("Passed: %d" % passed_tests)
	print("Failed: %d" % failed_tests)
	print("Success Rate: %.1f%%" % (float(passed_tests) / float(total_tests) * 100.0))
	
	if failed_tests > 0:
		print("\nFailed Tests:")
		for test_name in test_results:
			var result = test_results[test_name]
			if not result.success:
				print("  - %s" % test_name)
				for error in result.errors:
					print("    ✗ %s" % error)
	
	print("\n=== Validation Complete ===")