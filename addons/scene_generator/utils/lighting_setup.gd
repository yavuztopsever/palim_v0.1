class_name LightingSetup
extends RefCounted

## Lighting setup utility for generated scenes
## Handles ambient lighting, light placement, and area-specific lighting configurations

# Lighting configuration constants
const AMBIENT_LIGHT_ENERGY = 0.3
const DIRECTIONAL_LIGHT_ENERGY = 1.0
const POINT_LIGHT_ENERGY = 1.5
const SPOT_LIGHT_ENERGY = 2.0

# Area-specific lighting configurations
const LIGHTING_CONFIGS = {
	"residential": {
		"ambient_color": Color(1.0, 0.95, 0.8),  # Warm white
		"ambient_energy": 0.4,
		"light_color": Color(1.0, 0.9, 0.7),     # Warm yellow
		"light_energy": 1.2,
		"light_temperature": 3000  # Warm temperature
	},
	"commercial": {
		"ambient_color": Color(0.95, 0.98, 1.0), # Cool white
		"ambient_energy": 0.5,
		"light_color": Color(0.9, 0.95, 1.0),    # Bright cool white
		"light_energy": 2.0,
		"light_temperature": 5000  # Neutral temperature
	},
	"administrative": {
		"ambient_color": Color(0.9, 0.95, 1.0),  # Cool blue-white
		"ambient_energy": 0.3,
		"light_color": Color(0.85, 0.9, 1.0),    # Cool efficient white
		"light_energy": 1.8,
		"light_temperature": 6500  # Cool temperature
	},
	"mixed": {
		"ambient_color": Color(0.95, 0.95, 0.95), # Neutral white
		"ambient_energy": 0.35,
		"light_color": Color(0.95, 0.95, 0.95),   # Neutral white
		"light_energy": 1.5,
		"light_temperature": 4000  # Neutral temperature
	}
}

## Sets up basic lighting for a generated scene
static func setup_scene_lighting(root: Node3D, params: GenerationParams) -> void:
	# Set up world environment with appropriate settings
	_setup_world_environment(root, params)
	
	# Add directional lighting for outdoor scenes or general illumination
	_setup_directional_lighting(root, params)
	
	# Configure SDFGI if available for global illumination
	_setup_global_illumination(root, params)

## Sets up world environment with area-specific ambient lighting
static func _setup_world_environment(root: Node3D, params: GenerationParams) -> void:
	var world_env = _find_or_create_world_environment(root)
	var environment = world_env.environment
	
	if not environment:
		environment = Environment.new()
		world_env.environment = environment
	
	var config = LIGHTING_CONFIGS.get(params.area_type, LIGHTING_CONFIGS["mixed"])
	
	# Configure background and ambient lighting
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = config.ambient_color
	environment.ambient_light_energy = config.ambient_energy
	
	# Enable SSAO for better depth perception in isometric view
	environment.ssao_enabled = true
	environment.ssao_radius = 0.5
	environment.ssao_intensity = 1.0
	
	# Configure tone mapping for better visual quality
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0

## Sets up directional lighting (sun/main light source)
static func _setup_directional_lighting(root: Node3D, params: GenerationParams) -> void:
	# Check if directional light already exists
	if _find_node_of_type(root, DirectionalLight3D):
		return
	
	var directional_light = DirectionalLight3D.new()
	directional_light.name = "MainDirectionalLight"
	
	var config = LIGHTING_CONFIGS.get(params.area_type, LIGHTING_CONFIGS["mixed"])
	
	# Configure light properties
	directional_light.light_color = config.light_color
	directional_light.light_energy = DIRECTIONAL_LIGHT_ENERGY
	
	# Position for isometric view - angled from top-right
	directional_light.rotation_degrees = Vector3(-45, 45, 0)
	
	# Enable shadows for better depth perception
	directional_light.shadow_enabled = true
	directional_light.shadow_bias = 0.1
	directional_light.shadow_normal_bias = 1.0
	
	root.add_child(directional_light)

## Configures SDFGI for global illumination if supported
static func _setup_global_illumination(root: Node3D, params: GenerationParams) -> void:
	var world_env = _find_node_of_type(root, WorldEnvironment) as WorldEnvironment
	if not world_env or not world_env.environment:
		return
	
	var environment = world_env.environment
	
	# Enable SDFGI for realistic light bouncing
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_bounce_feedback = 0.1
	environment.sdfgi_normal_bias = 1.1
	
	# Configure for isometric scenes
	environment.sdfgi_probe_bias = 1.1
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT

## Places point lights in interior spaces (rooms and corridors)
static func place_interior_lights(root: Node3D, layout: SceneLayout, params: GenerationParams) -> void:
	if not params.interior_spaces:
		return
	
	var config = LIGHTING_CONFIGS.get(params.area_type, LIGHTING_CONFIGS["mixed"])
	var light_positions = _calculate_light_positions(layout)
	
	for pos in light_positions:
		var light = _create_point_light(config, pos)
		root.add_child(light)

## Places spot lights for specific areas (corridors, entrances)
static func place_corridor_lights(root: Node3D, layout: SceneLayout, params: GenerationParams) -> void:
	var config = LIGHTING_CONFIGS.get(params.area_type, LIGHTING_CONFIGS["mixed"])
	var corridor_positions = _find_corridor_positions(layout)
	
	for pos in corridor_positions:
		var light = _create_spot_light(config, pos)
		root.add_child(light)

## Calculates optimal light positions based on layout
static func _calculate_light_positions(layout: SceneLayout) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var grid_size = layout.grid_size
	
	# Place lights in a grid pattern, avoiding walls
	for x in range(2, grid_size.x, 4):  # Every 4 grid units (8 meters)
		for y in range(2, grid_size.y, 4):
			var grid_pos = Vector2i(x, y)
			var cell = layout.get_cell_at(grid_pos)
			
			# Only place lights in floor areas
			if cell and cell.cell_type == "floor":
				var world_pos = BaseGenerator.grid_to_world(grid_pos)
				world_pos.y = 3.0  # 3 meters high
				positions.append(world_pos)
	
	return positions

## Finds corridor positions for targeted lighting
static func _find_corridor_positions(layout: SceneLayout) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	# Look for narrow floor areas that might be corridors
	for cell in layout.cells:
		if cell.cell_type == "floor":
			var grid_pos = Vector2i(cell.position.x, cell.position.y)
			if _is_corridor_position(layout, grid_pos):
				var world_pos = BaseGenerator.grid_to_world(grid_pos)
				world_pos.y = 2.5  # Slightly lower for corridors
				positions.append(world_pos)
	
	return positions

## Determines if a position is likely a corridor
static func _is_corridor_position(layout: SceneLayout, grid_pos: Vector2i) -> bool:
	# Simple heuristic: check if surrounded by walls on two opposite sides
	var left = layout.get_cell_at(Vector2i(grid_pos.x - 1, grid_pos.y))
	var right = layout.get_cell_at(Vector2i(grid_pos.x + 1, grid_pos.y))
	var up = layout.get_cell_at(Vector2i(grid_pos.x, grid_pos.y - 1))
	var down = layout.get_cell_at(Vector2i(grid_pos.x, grid_pos.y + 1))
	
	var horizontal_corridor = (left and left.cell_type == "wall") and (right and right.cell_type == "wall")
	var vertical_corridor = (up and up.cell_type == "wall") and (down and down.cell_type == "wall")
	
	return horizontal_corridor or vertical_corridor

## Creates a point light with area-specific configuration
static func _create_point_light(config: Dictionary, position: Vector3) -> OmniLight3D:
	var light = OmniLight3D.new()
	light.name = "InteriorLight"
	light.position = position
	
	# Configure light properties
	light.light_color = config.light_color
	light.light_energy = config.light_energy
	light.omni_range = 8.0  # 8 meter range
	light.omni_attenuation = 2.0  # Realistic falloff
	
	# Enable shadows for some lights (performance consideration)
	light.shadow_enabled = true
	light.shadow_bias = 0.1
	
	return light

## Creates a spot light for corridors and specific areas
static func _create_spot_light(config: Dictionary, position: Vector3) -> SpotLight3D:
	var light = SpotLight3D.new()
	light.name = "CorridorLight"
	light.position = position
	
	# Configure light properties
	light.light_color = config.light_color
	light.light_energy = SPOT_LIGHT_ENERGY
	light.spot_range = 6.0
	light.spot_angle = 45.0
	light.spot_attenuation = 1.5
	
	# Point downward for corridor lighting
	light.rotation_degrees = Vector3(-90, 0, 0)
	
	# Enable shadows
	light.shadow_enabled = true
	light.shadow_bias = 0.1
	
	return light

## Finds or creates a WorldEnvironment node
static func _find_or_create_world_environment(root: Node3D) -> WorldEnvironment:
	var world_env = _find_node_of_type(root, WorldEnvironment) as WorldEnvironment
	
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		root.add_child(world_env)
	
	return world_env

## Recursively finds a node of the specified type
static func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

## Adjusts lighting for isometric camera view
static func optimize_for_isometric_view(root: Node3D) -> void:
	# Find all lights and adjust their properties for isometric view
	var lights = _find_all_lights(root)
	
	for light in lights:
		if light is DirectionalLight3D:
			# Ensure directional light angle works well with isometric view
			var dir_light = light as DirectionalLight3D
			dir_light.rotation_degrees = Vector3(-45, 45, 0)
		
		elif light is OmniLight3D:
			# Adjust point light range for isometric visibility
			var omni_light = light as OmniLight3D
			omni_light.omni_range = min(omni_light.omni_range, 10.0)
		
		elif light is SpotLight3D:
			# Adjust spot light angles for better coverage
			var spot_light = light as SpotLight3D
			spot_light.spot_angle = min(spot_light.spot_angle, 60.0)

## Finds all light nodes in the scene
static func _find_all_lights(node: Node) -> Array[Light3D]:
	var lights: Array[Light3D] = []
	
	if node is Light3D:
		lights.append(node as Light3D)
	
	for child in node.get_children():
		lights.append_array(_find_all_lights(child))
	
	return lights