class_name LayoutGenerator
extends BaseGenerator

## Layout generator that creates basic spatial layouts using BSP and grid-based algorithms
## Handles both interior room generation and outdoor area layouts

# BSP parameters for room generation
const MIN_ROOM_SIZE = Vector2i(3, 3)
const MAX_ROOM_SIZE = Vector2i(12, 12)
const MIN_SPLIT_SIZE = Vector2i(6, 6)  # Minimum size before we can split
const CORRIDOR_WIDTH = 1

# Room generation parameters
const ROOM_PADDING = 1  # Space around rooms for walls

# BSP Tree node for recursive space partitioning
class BSPNode:
	var bounds: Rect2i
	var left_child: BSPNode
	var right_child: BSPNode
	var room: Rect2i  # The actual room within this node's bounds
	var is_leaf: bool = false
	
	func _init(rect: Rect2i):
		bounds = rect
	
	func is_leaf_node() -> bool:
		return left_child == null and right_child == null

## Generates a scene layout based on the provided parameters
func generate_scene(root: Node3D, params: GenerationParams) -> void:
	# Set up random seed for reproducible generation
	if params.seed != 0:
		seed(params.seed)
	
	# Create the layout
	var layout = generate_layout(params)
	
	# Validate the layout
	if not layout.validate_layout():
		push_error("Generated layout failed validation")
		return
	
	# Check and ensure connectivity
	if not layout.check_connectivity():
		push_warning("Generated layout has connectivity issues, attempting to fix...")
		if layout.ensure_connectivity():
			push_warning("Connectivity issues resolved")
		else:
			push_error("Could not resolve connectivity issues")
			return
	
	# Final validation after connectivity fixes
	if not layout.validate_layout():
		push_error("Layout validation failed after connectivity fixes")
		return
	
	# Print layout statistics for debugging
	if OS.is_debug_build():
		layout.print_layout_stats()
	
	# Set up basic scene foundation
	setup_scene_foundation(root, params)
	
	# Use AssetPlacer to place actual assets instead of simple visualization
	var asset_placer = AssetPlacer.new()
	asset_placer.place_assets_from_layout(root, layout)
	
	# Add lighting after assets are placed
	LightingSetup.place_interior_lights(root, layout, params)
	LightingSetup.place_corridor_lights(root, layout, params)
	LightingSetup.optimize_for_isometric_view(root)

## Generates a SceneLayout based on parameters
func generate_layout(params: GenerationParams) -> SceneLayout:
	var layout = SceneLayout.new(params.size)
	
	# Validate parameters before generation
	if not _validate_generation_params(params):
		push_error("Invalid generation parameters")
		return layout
	
	if params.interior_spaces:
		_generate_interior_layout(layout, params)
	else:
		_generate_outdoor_layout(layout, params)
	
	# Post-generation validation and fixes
	_post_process_layout(layout, params)
	
	return layout

## Validates generation parameters
func _validate_generation_params(params: GenerationParams) -> bool:
	var is_valid = true
	
	# Check size constraints
	if params.size.x < MIN_ROOM_SIZE.x or params.size.y < MIN_ROOM_SIZE.y:
		push_error("Layout size %s is too small. Minimum size is %s" % [params.size, MIN_ROOM_SIZE])
		is_valid = false
	
	# Check if size is reasonable for the requested area type
	var total_area = params.size.x * params.size.y
	if params.interior_spaces and total_area < 25:  # 5x5 minimum for interior
		push_warning("Very small area (%d cells) for interior generation" % total_area)
	elif not params.interior_spaces and total_area < 100:  # 10x10 minimum for outdoor
		push_warning("Small area (%d cells) for outdoor generation" % total_area)
	
	return is_valid

## Post-processes the layout to fix common issues
func _post_process_layout(layout: SceneLayout, params: GenerationParams) -> void:
	# Remove isolated single cells
	_remove_isolated_cells(layout)
	
	# Ensure minimum connectivity
	if not layout.check_connectivity():
		_fix_connectivity_issues(layout, params)
	
	# Add doors where appropriate
	if params.interior_spaces:
		_add_doors_to_layout(layout)

## Removes isolated single cells that don't contribute to the layout
func _remove_isolated_cells(layout: SceneLayout) -> void:
	var cells_to_remove: Array[Vector2i] = []
	
	for cell in layout.cells:
		if cell.cell_type == "floor":
			var neighbors = layout.get_neighbors(cell.position, false)
			var floor_neighbors = 0
			
			for neighbor in neighbors:
				if neighbor.cell_type == "floor":
					floor_neighbors += 1
			
			# Remove isolated floor cells (no floor neighbors)
			if floor_neighbors == 0:
				cells_to_remove.append(cell.position)
	
	for pos in cells_to_remove:
		layout.remove_cell(pos)
		if OS.is_debug_build():
			print("Removed isolated cell at %s" % pos)

## Attempts to fix connectivity issues in the layout
func _fix_connectivity_issues(layout: SceneLayout, params: GenerationParams) -> void:
	var max_attempts = 3
	var attempt = 0
	
	while attempt < max_attempts and not layout.check_connectivity():
		attempt += 1
		
		if OS.is_debug_build():
			print("Connectivity fix attempt %d/%d" % [attempt, max_attempts])
		
		# Try to connect isolated areas
		if not layout.ensure_connectivity():
			# If automatic connection fails, add manual connections
			_add_manual_connections(layout)
		
		# Remove any new isolated cells created by connections
		_remove_isolated_cells(layout)

## Adds manual connections between disconnected areas
func _add_manual_connections(layout: SceneLayout) -> void:
	var connected_components = layout._find_connected_components()
	
	if connected_components.size() <= 1:
		return
	
	# Connect the largest component to all smaller ones
	var largest_component = connected_components[0]
	var largest_size = largest_component.size()
	var largest_index = 0
	
	for i in range(1, connected_components.size()):
		if connected_components[i].size() > largest_size:
			largest_component = connected_components[i]
			largest_size = connected_components[i].size()
			largest_index = i
	
	# Connect each other component to the largest one
	for i in range(connected_components.size()):
		if i != largest_index:
			var component = connected_components[i]
			_connect_component_to_main(layout, component, largest_component)

## Connects a component to the main connected area
func _connect_component_to_main(layout: SceneLayout, component: Array[Vector2i], main_component: Array[Vector2i]) -> void:
	var best_distance = INF
	var best_start: Vector2i
	var best_end: Vector2i
	
	# Find closest points between components
	for pos1 in component:
		for pos2 in main_component:
			var distance = (pos2 - pos1).length()
			if distance < best_distance:
				best_distance = distance
				best_start = pos1
				best_end = pos2
	
	# Create corridor between closest points
	_create_corridor_between_points(layout, best_start, best_end)

## Adds doors to appropriate locations in interior layouts
func _add_doors_to_layout(layout: SceneLayout) -> void:
	# Find wall positions that could be doors (walls between floor areas)
	var door_candidates: Array[Vector2i] = []
	
	for cell in layout.cells:
		if cell.cell_type == "wall":
			if _should_be_door(layout, cell.position):
				door_candidates.append(cell.position)
	
	# Convert some wall candidates to doors
	var doors_added = 0
	var max_doors = max(1, door_candidates.size() / 4)  # Add doors to 25% of candidates
	
	for i in range(min(max_doors, door_candidates.size())):
		var door_pos = door_candidates[i]
		var door_cell = CellData.new(door_pos, "door")
		door_cell.asset_id = "door_frame"
		layout.set_cell(door_pos, door_cell)
		doors_added += 1
	
	if OS.is_debug_build() and doors_added > 0:
		print("Added %d doors to layout" % doors_added)

## Checks if a wall position should be converted to a door
func _should_be_door(layout: SceneLayout, wall_pos: Vector2i) -> bool:
	var neighbors = layout.get_neighbors(wall_pos, false)
	var floor_neighbors = 0
	
	for neighbor in neighbors:
		if neighbor.cell_type == "floor":
			floor_neighbors += 1
	
	# A wall should be a door if it has exactly 2 floor neighbors (connects two areas)
	return floor_neighbors == 2

## Generates interior layout using BSP algorithm
func _generate_interior_layout(layout: SceneLayout, params: GenerationParams) -> void:
	# Create BSP tree for room generation
	var root_bounds = Rect2i(0, 0, params.size.x, params.size.y)
	var bsp_root = _create_bsp_tree(root_bounds)
	
	# Generate rooms from BSP tree
	var rooms = _extract_rooms_from_bsp(bsp_root)
	
	# Place rooms in layout
	for room in rooms:
		_place_room_in_layout(layout, room)
	
	# Generate corridors to connect rooms
	_generate_corridors(layout, bsp_root)
	
	# Add walls around rooms and corridors
	_add_walls_to_layout(layout)

## Generates outdoor layout using grid-based approach
func _generate_outdoor_layout(layout: SceneLayout, params: GenerationParams) -> void:
	# For outdoor areas, create a more open layout with paths and areas
	
	# Fill most of the area with floor
	for x in range(params.size.x):
		for y in range(params.size.y):
			var pos = Vector2i(x, y)
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "grass_tile"
			layout.set_cell(pos, cell)
	
	# Add some structure based on area type
	match params.area_type:
		"residential":
			_add_residential_outdoor_structure(layout, params)
		"commercial":
			_add_commercial_outdoor_structure(layout, params)
		"administrative":
			_add_administrative_outdoor_structure(layout, params)
		"mixed":
			_add_mixed_outdoor_structure(layout, params)

## Creates BSP tree for room generation
func _create_bsp_tree(bounds: Rect2i) -> BSPNode:
	var node = BSPNode.new(bounds)
	
	# Check if we should stop splitting
	if bounds.size.x < MIN_SPLIT_SIZE.x or bounds.size.y < MIN_SPLIT_SIZE.y:
		node.is_leaf = true
		node.room = _create_room_in_bounds(bounds)
		return node
	
	# Decide split direction - prefer splitting the longer dimension
	var split_horizontal = bounds.size.x > bounds.size.y
	
	# Add some randomness to split direction
	if abs(bounds.size.x - bounds.size.y) < 2:
		split_horizontal = randf() > 0.5
	
	if split_horizontal:
		# Split vertically (horizontal line)
		var split_y = bounds.position.y + randi_range(MIN_SPLIT_SIZE.y, bounds.size.y - MIN_SPLIT_SIZE.y)
		
		var left_bounds = Rect2i(bounds.position.x, bounds.position.y, bounds.size.x, split_y - bounds.position.y)
		var right_bounds = Rect2i(bounds.position.x, split_y, bounds.size.x, bounds.position.y + bounds.size.y - split_y)
		
		node.left_child = _create_bsp_tree(left_bounds)
		node.right_child = _create_bsp_tree(right_bounds)
	else:
		# Split horizontally (vertical line)
		var split_x = bounds.position.x + randi_range(MIN_SPLIT_SIZE.x, bounds.size.x - MIN_SPLIT_SIZE.x)
		
		var left_bounds = Rect2i(bounds.position.x, bounds.position.y, split_x - bounds.position.x, bounds.size.y)
		var right_bounds = Rect2i(split_x, bounds.position.y, bounds.position.x + bounds.size.x - split_x, bounds.size.y)
		
		node.left_child = _create_bsp_tree(left_bounds)
		node.right_child = _create_bsp_tree(right_bounds)
	
	return node

## Creates a room within the given bounds
func _create_room_in_bounds(bounds: Rect2i) -> Rect2i:
	# Leave some padding for walls
	var padded_bounds = Rect2i(
		bounds.position.x + ROOM_PADDING,
		bounds.position.y + ROOM_PADDING,
		bounds.size.x - 2 * ROOM_PADDING,
		bounds.size.y - 2 * ROOM_PADDING
	)
	
	# Ensure minimum room size
	if padded_bounds.size.x < MIN_ROOM_SIZE.x or padded_bounds.size.y < MIN_ROOM_SIZE.y:
		return bounds  # Use full bounds if padding makes it too small
	
	# Add some randomness to room size and position within bounds
	var room_width = randi_range(MIN_ROOM_SIZE.x, min(MAX_ROOM_SIZE.x, padded_bounds.size.x))
	var room_height = randi_range(MIN_ROOM_SIZE.y, min(MAX_ROOM_SIZE.y, padded_bounds.size.y))
	
	var room_x = padded_bounds.position.x + randi_range(0, max(0, padded_bounds.size.x - room_width))
	var room_y = padded_bounds.position.y + randi_range(0, max(0, padded_bounds.size.y - room_height))
	
	return Rect2i(room_x, room_y, room_width, room_height)

## Extracts all rooms from BSP tree
func _extract_rooms_from_bsp(node: BSPNode) -> Array[Rect2i]:
	var rooms: Array[Rect2i] = []
	
	if node.is_leaf_node():
		if node.room.size.x > 0 and node.room.size.y > 0:
			rooms.append(node.room)
	else:
		if node.left_child:
			rooms.append_array(_extract_rooms_from_bsp(node.left_child))
		if node.right_child:
			rooms.append_array(_extract_rooms_from_bsp(node.right_child))
	
	return rooms

## Places a room in the layout
func _place_room_in_layout(layout: SceneLayout, room: Rect2i) -> void:
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			var pos = Vector2i(x, y)
			if layout.is_valid_position(pos):
				var cell = CellData.new(pos, "floor")
				cell.asset_id = "floor_tile"
				layout.set_cell(pos, cell)

## Generates corridors to connect rooms using BSP tree structure
func _generate_corridors(layout: SceneLayout, node: BSPNode) -> void:
	if node.is_leaf_node():
		return
	
	# Recursively generate corridors for children
	if node.left_child:
		_generate_corridors(layout, node.left_child)
	if node.right_child:
		_generate_corridors(layout, node.right_child)
	
	# Connect the two child areas
	if node.left_child and node.right_child:
		_connect_areas(layout, node.left_child, node.right_child)

## Connects two BSP areas with a corridor
func _connect_areas(layout: SceneLayout, left_node: BSPNode, right_node: BSPNode) -> void:
	# Get representative points from each area
	var left_point = _get_connection_point(left_node)
	var right_point = _get_connection_point(right_node)
	
	# Create L-shaped corridor
	_create_corridor_between_points(layout, left_point, right_point)

## Gets a connection point from a BSP node (center of room or area)
func _get_connection_point(node: BSPNode) -> Vector2i:
	if node.is_leaf_node() and node.room.size.x > 0:
		# Use center of room
		return Vector2i(
			node.room.position.x + node.room.size.x / 2,
			node.room.position.y + node.room.size.y / 2
		)
	else:
		# Use center of bounds
		return Vector2i(
			node.bounds.position.x + node.bounds.size.x / 2,
			node.bounds.position.y + node.bounds.size.y / 2
		)

## Creates an L-shaped corridor between two points
func _create_corridor_between_points(layout: SceneLayout, start: Vector2i, end: Vector2i) -> void:
	# Create L-shaped path: horizontal first, then vertical
	var current = start
	
	# Horizontal segment
	var step_x = 1 if end.x > start.x else -1
	while current.x != end.x:
		_place_corridor_cell(layout, current)
		current.x += step_x
	
	# Vertical segment
	var step_y = 1 if end.y > start.y else -1
	while current.y != end.y:
		_place_corridor_cell(layout, current)
		current.y += step_y
	
	# Place final cell
	_place_corridor_cell(layout, current)

## Places a corridor cell in the layout
func _place_corridor_cell(layout: SceneLayout, pos: Vector2i) -> void:
	if layout.is_valid_position(pos):
		var existing_cell = layout.get_cell(pos)
		# Only place corridor if there's no floor already
		if not existing_cell or existing_cell.cell_type != "floor":
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "corridor_tile"
			layout.set_cell(pos, cell)

## Adds walls around rooms and corridors
func _add_walls_to_layout(layout: SceneLayout) -> void:
	var wall_positions: Array[Vector2i] = []
	
	# Find all positions that should have walls (adjacent to floors but not floors themselves)
	for x in range(layout.grid_size.x):
		for y in range(layout.grid_size.y):
			var pos = Vector2i(x, y)
			var cell = layout.get_cell(pos)
			
			# If this position is empty, check if it should be a wall
			if not cell or cell.cell_type == "empty":
				if _should_be_wall(layout, pos):
					wall_positions.append(pos)
	
	# Place walls
	for wall_pos in wall_positions:
		var wall_cell = CellData.new(wall_pos, "wall")
		wall_cell.asset_id = "wall_segment"
		layout.set_cell(wall_pos, wall_cell)

## Checks if a position should be a wall (adjacent to floor)
func _should_be_wall(layout: SceneLayout, pos: Vector2i) -> bool:
	var neighbors = layout.get_neighbors(pos, false)  # Only cardinal directions
	
	for neighbor in neighbors:
		if neighbor.cell_type == "floor":
			return true
	
	return false

## Adds residential outdoor structure (houses, gardens, paths)
func _add_residential_outdoor_structure(layout: SceneLayout, params: GenerationParams) -> void:
	# Add some paths
	var center_x = params.size.x / 2
	var center_y = params.size.y / 2
	
	# Main path through center
	for y in range(params.size.y):
		var pos = Vector2i(center_x, y)
		if layout.is_valid_position(pos):
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "path_tile"
			layout.set_cell(pos, cell)
	
	# Cross path
	for x in range(params.size.x):
		var pos = Vector2i(x, center_y)
		if layout.is_valid_position(pos):
			var cell = CellData.new(pos, "floor")
			cell.asset_id = "path_tile"
			layout.set_cell(pos, cell)

## Adds commercial outdoor structure (market areas, wide spaces)
func _add_commercial_outdoor_structure(layout: SceneLayout, params: GenerationParams) -> void:
	# Create a central market area
	var center = Vector2i(params.size.x / 2, params.size.y / 2)
	var market_size = Vector2i(min(6, params.size.x / 2), min(6, params.size.y / 2))
	
	for x in range(center.x - market_size.x / 2, center.x + market_size.x / 2):
		for y in range(center.y - market_size.y / 2, center.y + market_size.y / 2):
			var pos = Vector2i(x, y)
			if layout.is_valid_position(pos):
				var cell = CellData.new(pos, "floor")
				cell.asset_id = "market_tile"
				layout.set_cell(pos, cell)

## Adds administrative outdoor structure (formal layouts, courtyards)
func _add_administrative_outdoor_structure(layout: SceneLayout, params: GenerationParams) -> void:
	# Create formal courtyard layout
	var border_width = 2
	
	# Create border paths
	for x in range(params.size.x):
		for y in range(params.size.y):
			var pos = Vector2i(x, y)
			if x < border_width or x >= params.size.x - border_width or y < border_width or y >= params.size.y - border_width:
				if layout.is_valid_position(pos):
					var cell = CellData.new(pos, "floor")
					cell.asset_id = "formal_path_tile"
					layout.set_cell(pos, cell)

## Adds mixed outdoor structure (combination of elements)
func _add_mixed_outdoor_structure(layout: SceneLayout, params: GenerationParams) -> void:
	# Combine elements from different types
	_add_residential_outdoor_structure(layout, params)
	
	# Add some commercial elements
	var quarter_x = params.size.x / 4
	var quarter_y = params.size.y / 4
	
	for x in range(quarter_x, quarter_x * 3):
		for y in range(quarter_y, quarter_y * 3):
			var pos = Vector2i(x, y)
			if layout.is_valid_position(pos) and randf() < 0.3:  # 30% chance
				var cell = CellData.new(pos, "floor")
				cell.asset_id = "mixed_tile"
				layout.set_cell(pos, cell)

## Simple visualization of the layout for testing (will be replaced by asset placement)
func _visualize_layout(root: Node3D, layout: SceneLayout) -> void:
	var visualization_parent = Node3D.new()
	visualization_parent.name = "LayoutVisualization"
	root.add_child(visualization_parent)
	
	for cell in layout.cells:
		var mesh_instance = create_mesh_at_grid(cell.position)
		mesh_instance.name = "%s_%s" % [cell.cell_type, cell.position]
		
		# Create simple colored cubes for different cell types
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1.8, 0.2, 1.8)  # Slightly smaller than grid for visibility
		
		var material = StandardMaterial3D.new()
		match cell.cell_type:
			"floor":
				material.albedo_color = Color.BROWN
			"wall":
				material.albedo_color = Color.GRAY
			"door":
				material.albedo_color = Color.BLUE
			_:
				material.albedo_color = Color.WHITE
		
		mesh_instance.mesh = box_mesh
		mesh_instance.material_override = material
		
		visualization_parent.add_child(mesh_instance)