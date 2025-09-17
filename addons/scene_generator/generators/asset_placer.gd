class_name AssetPlacer
extends RefCounted

## Asset placement system that converts layout data into 3D scene nodes
## Handles wall placement, floor tiles, doors, and windows based on layout boundaries
## Includes navigation mesh generation and validation

# Required imports
const WallHidingSystem = preload("res://addons/scene_generator/utils/wall_hiding_system.gd")
const InteriorSpaceDetector = preload("res://addons/scene_generator/utils/interior_space_detector.gd")

# Asset placement constants
const WALL_HEIGHT: float = 3.0
const FLOOR_THICKNESS: float = 0.1
const DOOR_HEIGHT: float = 2.5
const WINDOW_HEIGHT: float = 1.5
const WINDOW_OFFSET_Y: float = 1.0

# Asset library reference
var asset_library: AssetLibrary

func _init(library: AssetLibrary = null):
	asset_library = library if library else AssetLibrary.new()

## Places all assets from a layout into the scene
func place_assets_from_layout(root: Node3D, layout: SceneLayout) -> void:
	if not layout or not layout.validate_layout():
		push_error("Invalid layout provided to AssetPlacer")
		return
	
	# Detect interior/exterior spaces before placing assets
	var space_info = InteriorSpaceDetector.detect_interior_spaces(layout)
	
	# Apply space detection results to layout
	InteriorSpaceDetector.apply_space_detection_to_layout(layout, space_info)
	
	# Configure roof generation (prevent roofs for interior spaces)
	InteriorSpaceDetector.configure_roof_generation(layout, space_info)
	
	# Configure wall hiding behavior for interior rooms
	InteriorSpaceDetector.configure_wall_hiding_behavior(layout, space_info)
	
	# Create parent nodes for organization
	var floor_parent = _create_parent_node(root, "Floors")
	var wall_parent = _create_parent_node(root, "Walls")
	var door_parent = _create_parent_node(root, "Doors")
	var window_parent = _create_parent_node(root, "Windows")
	var prop_parent = _create_parent_node(root, "Props")
	
	# Place assets by type
	_place_floor_tiles(floor_parent, layout)
	_place_walls(wall_parent, layout)
	_place_doors(door_parent, layout)
	_place_windows(window_parent, layout)
	_place_props(prop_parent, layout)
	
	# Set up collision for all generated assets
	CollisionBuilder.generate_static_bodies_for_layout(root, layout)
	
	# Generate navigation mesh for character movement
	var nav_region = NavigationBuilder.generate_navigation_region_for_layout(root, layout)
	
	# Validate navigation system
	if nav_region:
		var validation_results = NavigationValidator.validate_navigation_system(nav_region, layout)
		
		if not validation_results.overall_valid:
			push_warning("Navigation validation failed for generated layout")
			if OS.is_debug_build():
				NavigationValidator.print_validation_results(validation_results)
		elif OS.is_debug_build():
			print("Navigation system validated successfully")
			NavigationValidator.print_validation_results(validation_results)
		
		# Add debug visualization in debug builds
		if OS.is_debug_build():
			NavigationValidator.create_validation_debug_visualization(root, nav_region, layout, validation_results)
	
	# Add space detection debug visualization
	if OS.is_debug_build():
		print("Interior Space Detection Results:")
		print(InteriorSpaceDetector.get_debug_info(space_info))
		InteriorSpaceDetector.create_debug_visualization(root, layout, space_info)

## Places floor tiles for all walkable areas
func _place_floor_tiles(parent: Node3D, layout: SceneLayout) -> void:
	var floor_cells = layout.get_cells_of_type("floor")
	
	for cell in floor_cells:
		var floor_node = _create_floor_tile(cell)
		if floor_node:
			parent.add_child(floor_node)

## Creates a floor tile node from cell data
func _create_floor_tile(cell: CellData) -> Node3D:
	var floor_scene = asset_library.get_asset(cell.asset_id, "floor_tile")
	if not floor_scene:
		# Create default floor tile
		floor_scene = _create_default_floor_tile()
	
	var floor_node = floor_scene.instantiate() if floor_scene else _create_default_floor_tile()
	floor_node.name = "Floor_%s" % cell.position
	floor_node.position = BaseGenerator.grid_to_world(cell.position)
	
	# Apply rotation
	if cell.rotation != 0:
		floor_node.rotation_degrees.y = cell.rotation
	
	# Apply any custom properties
	_apply_cell_properties(floor_node, cell)
	
	return floor_node

## Creates a default floor tile when no asset is available
func _create_default_floor_tile() -> Node3D:
	var floor_node = Node3D.new()
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(BaseGenerator.GRID_SIZE - 0.1, FLOOR_THICKNESS, BaseGenerator.GRID_SIZE - 0.1)
	mesh_instance.mesh = box_mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown floor
	mesh_instance.material_override = material
	
	# Position mesh slightly below grid level
	mesh_instance.position.y = -FLOOR_THICKNESS / 2
	
	floor_node.add_child(mesh_instance)
	return floor_node

## Places walls that follow layout boundaries
func _place_walls(parent: Node3D, layout: SceneLayout) -> void:
	var wall_cells = layout.get_cells_of_type("wall")
	
	for cell in wall_cells:
		var wall_node = _create_wall_segment(cell, layout)
		if wall_node:
			parent.add_child(wall_node)

## Creates a wall segment node from cell data
func _create_wall_segment(cell: CellData, layout: SceneLayout) -> Node3D:
	var wall_scene = asset_library.get_asset(cell.asset_id, "wall_segment")
	if not wall_scene:
		# Create default wall segment
		wall_scene = _create_default_wall_segment(cell, layout)
	
	var wall_node = wall_scene.instantiate() if wall_scene else _create_default_wall_segment(cell, layout)
	wall_node.name = "Wall_%s" % cell.position
	wall_node.position = BaseGenerator.grid_to_world(cell.position)
	
	# Apply rotation based on wall orientation
	var wall_rotation = _determine_wall_rotation(cell, layout)
	wall_node.rotation_degrees.y = wall_rotation
	
	# Add WallHidingSystem component for camera integration
	_add_wall_hiding_system(wall_node, cell, layout, wall_rotation)
	
	# Apply any custom properties
	_apply_cell_properties(wall_node, cell)
	
	return wall_node

## Determines the rotation for a wall based on its neighbors
func _determine_wall_rotation(cell: CellData, layout: SceneLayout) -> float:
	var neighbors = layout.get_neighbors(cell.position, false)
	var floor_neighbors: Array[Vector2i] = []
	
	# Find floor neighbors to determine wall orientation
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for i in range(directions.size()):
		var neighbor_pos = cell.position + directions[i]
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			floor_neighbors.append(directions[i])
	
	# Determine rotation based on floor neighbor pattern
	if floor_neighbors.size() == 0:
		return 0  # Default orientation
	
	# If floor is to the north or south, wall should be horizontal (0° or 180°)
	# If floor is to the east or west, wall should be vertical (90° or 270°)
	var primary_direction = floor_neighbors[0]
	
	if primary_direction.y != 0:  # North or South
		return 0  # Horizontal wall
	else:  # East or West
		return 90  # Vertical wall

## Creates a default wall segment when no asset is available
func _create_default_wall_segment(cell: CellData, layout: SceneLayout) -> Node3D:
	var wall_node = Node3D.new()
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(BaseGenerator.GRID_SIZE, WALL_HEIGHT, 0.2)
	mesh_instance.mesh = box_mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.7)  # Gray wall
	mesh_instance.material_override = material
	
	# Position mesh at proper height
	mesh_instance.position.y = WALL_HEIGHT / 2
	
	wall_node.add_child(mesh_instance)
	return wall_node

## Adds WallHidingSystem component to a wall node
func _add_wall_hiding_system(wall_node: Node3D, cell: CellData, layout: SceneLayout, wall_rotation: float) -> void:
	# Create WallHidingSystem component
	var wall_hiding = WallHidingSystem.new()
	wall_hiding.name = "WallHidingSystem"
	
	# Set wall direction based on rotation
	var wall_direction = Vector3.FORWARD
	match int(wall_rotation):
		90, -270:
			wall_direction = Vector3.RIGHT
		180, -180:
			wall_direction = Vector3.BACK
		270, -90:
			wall_direction = Vector3.LEFT
		_:
			wall_direction = Vector3.FORWARD
	
	wall_hiding.wall_direction = wall_direction
	
	# Use detected interior space information
	var is_interior_wall = cell.properties.get("is_interior_wall", false)
	var space_type = cell.properties.get("space_type", "exterior")
	var room_id = cell.properties.get("adjacent_room_id", "room_%s" % cell.position)
	
	wall_hiding.is_interior = is_interior_wall
	wall_hiding.space_type = space_type
	wall_hiding.room_id = room_id
	
	# Configure hiding behavior based on detected properties
	wall_hiding.hide_when_behind = cell.properties.get("hide_when_behind", true)
	wall_hiding.transparency_fade = cell.properties.get("transparency_fade", 0.3)
	
	# Add component to wall
	wall_node.add_child(wall_hiding)

## Determines if a wall is interior based on surrounding cells
func _is_interior_wall(cell: CellData, layout: SceneLayout) -> bool:
	# Check if wall is surrounded by floor cells (indicating interior)
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	var floor_neighbors = 0
	var total_neighbors = 0
	
	for direction in directions:
		var neighbor_pos = cell.position + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		
		if neighbor_cell:
			total_neighbors += 1
			if neighbor_cell.is_walkable():
				floor_neighbors += 1
	
	# If most neighbors are floors, this is likely an interior wall
	return total_neighbors > 0 and float(floor_neighbors) / float(total_neighbors) > 0.5

## Checks if roof generation should be prevented for a cell
func _should_generate_roof(cell: CellData) -> bool:
	# Check if roof generation is explicitly disabled
	if cell.properties.has("generate_roof"):
		return cell.properties.generate_roof
	
	# Check if roof is excluded (interior spaces)
	if cell.properties.has("roof_excluded"):
		return not cell.properties.roof_excluded
	
	# Check if this is an interior space
	if cell.properties.get("is_interior", false):
		return false
	
	# Default to allowing roof generation for exterior spaces
	return cell.properties.get("space_type", "exterior") == "exterior"

## Places doors at room connections
func _place_doors(parent: Node3D, layout: SceneLayout) -> void:
	var door_cells = layout.get_cells_of_type("door")
	
	for cell in door_cells:
		var door_node = _create_door(cell, layout)
		if door_node:
			parent.add_child(door_node)

## Creates a door node from cell data
func _create_door(cell: CellData, layout: SceneLayout) -> Node3D:
	var door_scene = asset_library.get_asset(cell.asset_id, "door_frame")
	if not door_scene:
		# Create default door
		door_scene = _create_default_door()
	
	var door_node = door_scene.instantiate() if door_scene else _create_default_door()
	door_node.name = "Door_%s" % cell.position
	door_node.position = BaseGenerator.grid_to_world(cell.position)
	
	# Apply rotation based on door orientation
	var door_rotation = _determine_door_rotation(cell, layout)
	door_node.rotation_degrees.y = door_rotation
	
	# Apply any custom properties
	_apply_cell_properties(door_node, cell)
	
	return door_node

## Determines the rotation for a door based on adjacent walkable areas
func _determine_door_rotation(cell: CellData, layout: SceneLayout) -> float:
	# Similar to wall rotation but for door orientation
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	var walkable_directions: Array[Vector2i] = []
	
	for direction in directions:
		var neighbor_pos = cell.position + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			walkable_directions.append(direction)
	
	# Door should be oriented perpendicular to the connection
	if walkable_directions.size() >= 2:
		var first_dir = walkable_directions[0]
		var second_dir = walkable_directions[1]
		
		# If connecting north-south, door should be horizontal (0°)
		# If connecting east-west, door should be vertical (90°)
		if (first_dir.y != 0 and second_dir.y != 0) or (first_dir.x != 0 and second_dir.x != 0):
			return 0  # Same axis connection
		else:
			return 90 if first_dir.y != 0 else 0  # Perpendicular connection
	
	return 0  # Default orientation

## Creates a default door when no asset is available
func _create_default_door() -> Node3D:
	var door_node = Node3D.new()
	
	# Create door frame
	var frame_instance = MeshInstance3D.new()
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(BaseGenerator.GRID_SIZE, DOOR_HEIGHT, 0.2)
	frame_instance.mesh = frame_mesh
	
	var frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.4, 0.2, 0.1)  # Brown door frame
	frame_instance.material_override = frame_material
	
	frame_instance.position.y = DOOR_HEIGHT / 2
	door_node.add_child(frame_instance)
	
	# Create door panel (slightly smaller)
	var panel_instance = MeshInstance3D.new()
	var panel_mesh = BoxMesh.new()
	panel_mesh.size = Vector3(BaseGenerator.GRID_SIZE - 0.2, DOOR_HEIGHT - 0.2, 0.1)
	panel_instance.mesh = panel_mesh
	
	var panel_material = StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.3, 0.15, 0.05)  # Darker brown door panel
	panel_instance.material_override = panel_material
	
	panel_instance.position.y = DOOR_HEIGHT / 2
	panel_instance.position.z = 0.05  # Slightly forward
	door_node.add_child(panel_instance)
	
	return door_node

## Places windows at appropriate wall locations
func _place_windows(parent: Node3D, layout: SceneLayout) -> void:
	var window_cells = layout.get_cells_of_type("window")
	
	for cell in window_cells:
		var window_node = _create_window(cell, layout)
		if window_node:
			parent.add_child(window_node)

## Creates a window node from cell data
func _create_window(cell: CellData, layout: SceneLayout) -> Node3D:
	var window_scene = asset_library.get_asset(cell.asset_id, "window_frame")
	if not window_scene:
		# Create default window
		window_scene = _create_default_window()
	
	var window_node = window_scene.instantiate() if window_scene else _create_default_window()
	window_node.name = "Window_%s" % cell.position
	window_node.position = BaseGenerator.grid_to_world(cell.position)
	
	# Apply rotation similar to walls
	var window_rotation = _determine_wall_rotation(cell, layout)
	window_node.rotation_degrees.y = window_rotation
	
	# Apply any custom properties
	_apply_cell_properties(window_node, cell)
	
	return window_node

## Creates a default window when no asset is available
func _create_default_window() -> Node3D:
	var window_node = Node3D.new()
	
	# Create window frame
	var frame_instance = MeshInstance3D.new()
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(BaseGenerator.GRID_SIZE - 0.4, WINDOW_HEIGHT, 0.2)
	frame_instance.mesh = frame_mesh
	
	var frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.8, 0.8, 0.8)  # Light gray frame
	frame_instance.material_override = frame_material
	
	frame_instance.position.y = WINDOW_OFFSET_Y + WINDOW_HEIGHT / 2
	window_node.add_child(frame_instance)
	
	# Create glass pane
	var glass_instance = MeshInstance3D.new()
	var glass_mesh = BoxMesh.new()
	glass_mesh.size = Vector3(BaseGenerator.GRID_SIZE - 0.6, WINDOW_HEIGHT - 0.2, 0.05)
	glass_instance.mesh = glass_mesh
	
	var glass_material = StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.7, 0.9, 1.0, 0.3)  # Transparent blue glass
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_instance.material_override = glass_material
	
	glass_instance.position.y = WINDOW_OFFSET_Y + WINDOW_HEIGHT / 2
	window_node.add_child(glass_instance)
	
	return window_node

## Places props and furniture
func _place_props(parent: Node3D, layout: SceneLayout) -> void:
	var prop_cells = layout.get_cells_of_type("prop")
	var furniture_cells = layout.get_cells_of_type("furniture")
	
	# Combine prop and furniture cells
	var all_prop_cells = prop_cells + furniture_cells
	
	for cell in all_prop_cells:
		var prop_node = _create_prop(cell)
		if prop_node:
			parent.add_child(prop_node)

## Creates a prop node from cell data
func _create_prop(cell: CellData) -> Node3D:
	var prop_scene = asset_library.get_asset(cell.asset_id, "default_prop")
	if not prop_scene:
		# Create default prop
		prop_scene = _create_default_prop()
	
	var prop_node = prop_scene.instantiate() if prop_scene else _create_default_prop()
	prop_node.name = "%s_%s" % [cell.cell_type.capitalize(), cell.position]
	prop_node.position = BaseGenerator.grid_to_world(cell.position)
	
	# Apply rotation
	if cell.rotation != 0:
		prop_node.rotation_degrees.y = cell.rotation
	
	# Apply any custom properties
	_apply_cell_properties(prop_node, cell)
	
	return prop_node

## Creates a default prop when no asset is available
func _create_default_prop() -> Node3D:
	var prop_node = Node3D.new()
	
	# Create simple box prop
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.8, 1.0, 0.8)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.3, 0.2)  # Brown prop
	mesh_instance.material_override = material
	
	mesh_instance.position.y = 0.5  # Half height above ground
	prop_node.add_child(mesh_instance)
	
	return prop_node

## Creates a parent node for organizing assets
func _create_parent_node(root: Node3D, name: String) -> Node3D:
	var parent = Node3D.new()
	parent.name = name
	root.add_child(parent)
	return parent

## Applies custom properties from cell data to the node
func _apply_cell_properties(node: Node3D, cell: CellData) -> void:
	# Apply any custom properties stored in the cell
	for property_name in cell.properties:
		var property_value = cell.properties[property_name]
		
		# Handle common properties
		match property_name:
			"scale":
				if property_value is Vector3:
					node.scale = property_value
				elif property_value is float:
					node.scale = Vector3.ONE * property_value
			"material_color":
				if property_value is Color:
					_apply_material_color(node, property_value)
			"visible":
				if property_value is bool:
					node.visible = property_value
			_:
				# Store custom properties as metadata
				node.set_meta(property_name, property_value)

## Applies a material color to all MeshInstance3D children
func _apply_material_color(node: Node3D, color: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance = child as MeshInstance3D
			if mesh_instance.material_override:
				if mesh_instance.material_override is StandardMaterial3D:
					var material = mesh_instance.material_override as StandardMaterial3D
					material.albedo_color = color
		
		# Recursively apply to children
		if child is Node3D:
			_apply_material_color(child, color)

## Sets up collision shapes for all nodes under a parent
func _setup_collision_for_parent(parent: Node3D, collision_type: String) -> void:
	for child in parent.get_children():
		_setup_collision_for_node(child, collision_type)

## Sets up collision for a single node based on its type
func _setup_collision_for_node(node: Node3D, collision_type: String) -> void:
	# Skip collision setup for now to avoid complexity
	# This will be implemented in a later task (task 5)
	pass

## Creates collision shape for floor tiles
func _create_floor_collision_shape() -> Shape3D:
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(BaseGenerator.GRID_SIZE, FLOOR_THICKNESS, BaseGenerator.GRID_SIZE)
	return box_shape

## Creates collision shape for walls
func _create_wall_collision_shape() -> Shape3D:
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(BaseGenerator.GRID_SIZE, WALL_HEIGHT, 0.2)
	return box_shape

## Creates default collision shape
func _create_default_collision_shape() -> Shape3D:
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	return box_shape