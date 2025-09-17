@tool
extends RefCounted

## Scene integration validation utility
## Validates that generated scenes work properly with existing systems

static func validate_scene_integration() -> bool:
	print("=== Scene Integration Validation ===")
	
	var success = true
	
	# Test basic scene generation
	if not _test_basic_scene_generation():
		success = false
	
	# Test camera system compatibility
	if not _test_camera_compatibility():
		success = false
	
	# Test navigation system
	if not _test_navigation_system():
		success = false
	
	# Test collision system
	if not _test_collision_system():
		success = false
	
	# Test lighting integration
	if not _test_lighting_integration():
		success = false
	
	if success:
		print("✓ All integration tests passed")
	else:
		print("✗ Some integration tests failed")
	
	return success

static func _test_basic_scene_generation() -> bool:
	print("\n--- Testing Basic Scene Generation ---")
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(6, 6)
	params.interior_spaces = true
	params.seed = 12345
	
	# Generate scene
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	# Validate basic components
	var has_world_env = _find_node_of_type(test_scene, WorldEnvironment) != null
	var has_light = _find_node_of_type(test_scene, DirectionalLight3D) != null
	var has_navigation = _find_node_of_type(test_scene, NavigationRegion3D) != null
	var has_meshes = _find_all_nodes_of_type(test_scene, MeshInstance3D).size() > 0
	var has_collision = _find_all_nodes_of_type(test_scene, StaticBody3D).size() > 0
	
	var success = true
	
	if not has_world_env:
		print("✗ Missing WorldEnvironment")
		success = false
	else:
		print("✓ WorldEnvironment found")
	
	if not has_light:
		print("✗ Missing DirectionalLight3D")
		success = false
	else:
		print("✓ DirectionalLight3D found")
	
	if not has_navigation:
		print("⚠ NavigationRegion3D not found")
	else:
		print("✓ NavigationRegion3D found")
	
	if not has_meshes:
		print("✗ No MeshInstance3D nodes found")
		success = false
	else:
		print("✓ MeshInstance3D nodes found")
	
	if not has_collision:
		print("✗ No StaticBody3D nodes found")
		success = false
	else:
		print("✓ StaticBody3D nodes found")
	
	# Cleanup
	test_scene.queue_free()
	
	return success

static func _test_camera_compatibility() -> bool:
	print("\n--- Testing Camera System Compatibility ---")
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "commercial"
	params.size = Vector2i(8, 8)
	params.interior_spaces = true
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	var success = true
	
	# Check for wall hiding metadata
	var walls_with_metadata = 0
	var total_walls = 0
	
	var static_bodies = _find_all_nodes_of_type(test_scene, StaticBody3D)
	for body in static_bodies:
		if body.name.contains("Wall"):
			total_walls += 1
			if body.has_meta("wall_layer") or body.has_meta("room_id"):
				walls_with_metadata += 1
	
	if total_walls > 0:
		var coverage = float(walls_with_metadata) / float(total_walls) * 100.0
		print("✓ Wall hiding metadata coverage: %.1f%% (%d/%d)" % [coverage, walls_with_metadata, total_walls])
		if coverage < 50.0:
			print("⚠ Low wall hiding coverage")
	else:
		print("⚠ No walls found to test")
	
	# Check lighting optimization for isometric view
	var directional_light = _find_node_of_type(test_scene, DirectionalLight3D)
	if directional_light:
		var rotation = directional_light.rotation_degrees
		var is_optimized = abs(rotation.x + 45) < 15 and abs(rotation.y - 45) < 15
		if is_optimized:
			print("✓ Directional light optimized for isometric view")
		else:
			print("⚠ Directional light may not be optimized for isometric view")
	
	# Check for interior space detection
	var mesh_instances = _find_all_nodes_of_type(test_scene, MeshInstance3D)
	var roof_count = 0
	for mesh in mesh_instances:
		if mesh.name.to_lower().contains("roof") or mesh.name.to_lower().contains("ceiling"):
			roof_count += 1
	
	if params.interior_spaces and roof_count == 0:
		print("✓ No roofs found in interior scene (good for isometric view)")
	elif params.interior_spaces and roof_count > 0:
		print("⚠ Found %d roof elements in interior scene" % roof_count)
	
	test_scene.queue_free()
	return success

static func _test_navigation_system() -> bool:
	print("\n--- Testing Navigation System ---")
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "administrative"
	params.size = Vector2i(10, 10)
	params.interior_spaces = true
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	var success = true
	
	# Check for navigation region
	var nav_region = _find_node_of_type(test_scene, NavigationRegion3D)
	if not nav_region:
		print("✗ NavigationRegion3D not found")
		success = false
		test_scene.queue_free()
		return success
	
	print("✓ NavigationRegion3D found")
	
	# Check navigation mesh
	if not nav_region.navigation_mesh:
		print("✗ NavigationRegion3D has no navigation mesh")
		success = false
	else:
		var nav_mesh = nav_region.navigation_mesh
		var polygon_count = nav_mesh.get_polygon_count()
		if polygon_count > 0:
			print("✓ Navigation mesh has %d polygons" % polygon_count)
		else:
			print("✗ Navigation mesh has no polygons")
			success = false
	
	test_scene.queue_free()
	return success

static func _test_collision_system() -> bool:
	print("\n--- Testing Collision System ---")
	
	# Create test scene
	var test_scene = Node3D.new()
	var params = GenerationParams.new()
	params.area_type = "mixed"
	params.size = Vector2i(8, 8)
	
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	var success = true
	
	# Count collision bodies and shapes
	var static_bodies = _find_all_nodes_of_type(test_scene, StaticBody3D)
	var total_shapes = 0
	var bodies_with_shapes = 0
	
	for body in static_bodies:
		var shapes = _find_all_nodes_of_type(body, CollisionShape3D)
		if shapes.size() > 0:
			bodies_with_shapes += 1
			total_shapes += shapes.size()
	
	if static_bodies.size() == 0:
		print("✗ No StaticBody3D nodes found")
		success = false
	else:
		print("✓ Found %d StaticBody3D nodes" % static_bodies.size())
		
		var coverage = float(bodies_with_shapes) / float(static_bodies.size()) * 100.0
		print("✓ Collision shape coverage: %.1f%% (%d shapes total)" % [coverage, total_shapes])
		
		if coverage < 90.0:
			print("⚠ Low collision shape coverage")
	
	test_scene.queue_free()
	return success

static func _test_lighting_integration() -> bool:
	print("\n--- Testing Lighting Integration ---")
	
	var success = true
	
	# Test each area type
	for area_type in ["residential", "commercial", "administrative"]:
		var test_scene = Node3D.new()
		var params = GenerationParams.new()
		params.area_type = area_type
		params.size = Vector2i(6, 6)
		params.interior_spaces = true
		
		var generator = LayoutGenerator.new()
		generator.generate_scene(test_scene, params)
		
		# Check lighting characteristics
		var world_env = _find_node_of_type(test_scene, WorldEnvironment)
		if world_env and world_env.environment:
			var ambient_color = world_env.environment.ambient_light_color
			var ambient_energy = world_env.environment.ambient_light_energy
			
			match area_type:
				"residential":
					if ambient_color.r > ambient_color.b:
						print("✓ %s lighting is warm" % area_type)
					else:
						print("⚠ %s lighting should be warmer" % area_type)
				
				"commercial":
					if ambient_energy >= 0.5:
						print("✓ %s lighting is bright" % area_type)
					else:
						print("⚠ %s lighting should be brighter" % area_type)
				
				"administrative":
					if ambient_color.b > ambient_color.r:
						print("✓ %s lighting is cool" % area_type)
					else:
						print("⚠ %s lighting should be cooler" % area_type)
		else:
			print("✗ %s scene missing lighting environment" % area_type)
			success = false
		
		# Check for interior lights
		var point_lights = _find_all_nodes_of_type(test_scene, OmniLight3D)
		var spot_lights = _find_all_nodes_of_type(test_scene, SpotLight3D)
		var total_interior_lights = point_lights.size() + spot_lights.size()
		
		if total_interior_lights > 0:
			print("✓ %s scene has %d interior lights" % [area_type, total_interior_lights])
		else:
			print("⚠ %s scene has no interior lights" % area_type)
		
		test_scene.queue_free()
	
	return success

## Helper methods

static func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

static func _find_all_nodes_of_type(node: Node, type: Variant) -> Array[Node]:
	var nodes: Array[Node] = []
	
	if is_instance_of(node, type):
		nodes.append(node)
	
	for child in node.get_children():
		nodes.append_array(_find_all_nodes_of_type(child, type))
	
	return nodes