@tool
extends EditorScript

## Test script for the lighting system
## Tests lighting setup for different area types and validates proper configuration

func _run():
	print("=== Testing Lighting System ===")
	
	# Test basic lighting setup
	test_basic_lighting_setup()
	
	# Test area-specific lighting configurations
	test_area_specific_lighting()
	
	# Test light placement
	test_light_placement()
	
	# Test isometric optimization
	test_isometric_optimization()
	
	print("=== Lighting System Tests Complete ===")

func test_basic_lighting_setup():
	print("\n--- Testing Basic Lighting Setup ---")
	
	# Create test scene
	var root = Node3D.new()
	var params = GenerationParams.new()
	
	# Test each area type
	for area_type in ["residential", "commercial", "administrative", "mixed"]:
		print("Testing lighting setup for area type: %s" % area_type)
		params.area_type = area_type
		
		# Clear previous lighting
		for child in root.get_children():
			child.queue_free()
		
		# Setup lighting
		LightingSetup.setup_scene_lighting(root, params)
		
		# Verify WorldEnvironment was created
		var world_env = _find_node_of_type(root, WorldEnvironment)
		assert(world_env != null, "WorldEnvironment should be created")
		assert(world_env.environment != null, "Environment should be set")
		
		# Verify DirectionalLight was created
		var dir_light = _find_node_of_type(root, DirectionalLight3D)
		assert(dir_light != null, "DirectionalLight3D should be created")
		assert(dir_light.shadow_enabled, "Shadows should be enabled")
		
		print("✓ Basic lighting setup successful for %s" % area_type)
	
	root.queue_free()

func test_area_specific_lighting():
	print("\n--- Testing Area-Specific Lighting ---")
	
	var root = Node3D.new()
	var params = GenerationParams.new()
	
	# Test residential lighting (warm)
	params.area_type = "residential"
	LightingSetup.setup_scene_lighting(root, params)
	
	var world_env = _find_node_of_type(root, WorldEnvironment) as WorldEnvironment
	var environment = world_env.environment
	
	# Check ambient light color is warm
	var ambient_color = environment.ambient_light_color
	assert(ambient_color.r >= ambient_color.b, "Residential lighting should be warm (more red than blue)")
	print("✓ Residential lighting is warm: %s" % ambient_color)
	
	# Clear and test commercial lighting (bright, cool)
	for child in root.get_children():
		child.queue_free()
	
	params.area_type = "commercial"
	LightingSetup.setup_scene_lighting(root, params)
	
	world_env = _find_node_of_type(root, WorldEnvironment) as WorldEnvironment
	environment = world_env.environment
	
	# Check ambient light energy is higher for commercial
	assert(environment.ambient_light_energy >= 0.5, "Commercial lighting should be bright")
	print("✓ Commercial lighting is bright: energy = %f" % environment.ambient_light_energy)
	
	# Clear and test administrative lighting (cool, efficient)
	for child in root.get_children():
		child.queue_free()
	
	params.area_type = "administrative"
	LightingSetup.setup_scene_lighting(root, params)
	
	world_env = _find_node_of_type(root, WorldEnvironment) as WorldEnvironment
	environment = world_env.environment
	
	# Check ambient light color is cool
	ambient_color = environment.ambient_light_color
	assert(ambient_color.b >= ambient_color.r, "Administrative lighting should be cool (more blue than red)")
	print("✓ Administrative lighting is cool: %s" % ambient_color)
	
	root.queue_free()

func test_light_placement():
	print("\n--- Testing Light Placement ---")
	
	var root = Node3D.new()
	var params = GenerationParams.new()
	params.interior_spaces = true
	params.size = Vector2i(8, 8)
	
	# Create a simple test layout
	var layout = SceneLayout.new(params.size)
	
	# Add some floor cells
	for x in range(2, 6):
		for y in range(2, 6):
			var cell = CellData.new()
			cell.position = Vector2i(x, y)
			cell.cell_type = "floor"
			layout.set_cell(Vector2i(x, y), cell)
	
	# Add some walls around the floor
	for x in range(1, 7):
		for y in [1, 6]:
			var cell = CellData.new()
			cell.position = Vector2i(x, y)
			cell.cell_type = "wall"
			layout.set_cell(Vector2i(x, y), cell)
	
	for y in range(2, 6):
		for x in [1, 6]:
			var cell = CellData.new()
			cell.position = Vector2i(x, y)
			cell.cell_type = "wall"
			layout.set_cell(Vector2i(x, y), cell)
	
	# Place interior lights
	LightingSetup.place_interior_lights(root, layout, params)
	
	# Check that lights were placed
	var lights = _find_all_lights(root)
	var point_lights = lights.filter(func(light): return light is OmniLight3D)
	
	assert(point_lights.size() > 0, "Interior lights should be placed")
	print("✓ Placed %d interior lights" % point_lights.size())
	
	# Verify light properties
	for light in point_lights:
		var omni_light = light as OmniLight3D
		assert(omni_light.position.y > 0, "Lights should be positioned above ground")
		assert(omni_light.omni_range > 0, "Lights should have positive range")
		print("✓ Light at %s with range %f" % [omni_light.position, omni_light.omni_range])
	
	root.queue_free()

func test_isometric_optimization():
	print("\n--- Testing Isometric Optimization ---")
	
	var root = Node3D.new()
	
	# Create some test lights
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "TestDirectionalLight"
	root.add_child(dir_light)
	
	var omni_light = OmniLight3D.new()
	omni_light.name = "TestOmniLight"
	omni_light.omni_range = 15.0  # Intentionally large
	root.add_child(omni_light)
	
	var spot_light = SpotLight3D.new()
	spot_light.name = "TestSpotLight"
	spot_light.spot_angle = 90.0  # Intentionally wide
	root.add_child(spot_light)
	
	# Apply isometric optimization
	LightingSetup.optimize_for_isometric_view(root)
	
	# Check that directional light has proper angle
	assert(dir_light.rotation_degrees.x == -45, "Directional light should have -45° X rotation")
	assert(dir_light.rotation_degrees.y == 45, "Directional light should have 45° Y rotation")
	print("✓ Directional light optimized for isometric view")
	
	# Check that omni light range was clamped
	assert(omni_light.omni_range <= 10.0, "Omni light range should be clamped for isometric view")
	print("✓ Omni light range optimized: %f" % omni_light.omni_range)
	
	# Check that spot light angle was clamped
	assert(spot_light.spot_angle <= 60.0, "Spot light angle should be clamped for isometric view")
	print("✓ Spot light angle optimized: %f" % spot_light.spot_angle)
	
	root.queue_free()

func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

func _find_all_lights(node: Node) -> Array[Light3D]:
	var lights: Array[Light3D] = []
	
	if node is Light3D:
		lights.append(node as Light3D)
	
	for child in node.get_children():
		lights.append_array(_find_all_lights(child))
	
	return lights