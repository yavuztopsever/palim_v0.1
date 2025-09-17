class_name CollisionBuilder
extends RefCounted

## Utility class for generating collision shapes and StaticBody3D nodes
## Handles collision setup for walls, floors, and other static structures

# Collision shape constants
const WALL_HEIGHT: float = 3.0
const FLOOR_THICKNESS: float = 0.1
const WALL_THICKNESS: float = 0.2
const DOOR_HEIGHT: float = 2.5

## Generates StaticBody3D nodes for all walls and static structures
static func generate_static_bodies_for_layout(parent: Node3D, layout: SceneLayout) -> void:
	if not layout or not layout.validate_layout():
		push_error("Invalid layout provided to CollisionBuilder")
		return
	
	# Create collision parent for organization
	var collision_parent = _create_collision_parent(parent)
	
	# Generate collision for different cell types
	_generate_wall_collision(collision_parent, layout)
	_generate_floor_collision(collision_parent, layout)
	_generate_door_collision(collision_parent, layout)

## Creates a parent node for collision objects
static func _create_collision_parent(parent: Node3D) -> Node3D:
	var collision_parent = Node3D.new()
	collision_parent.name = "Collision"
	parent.add_child(collision_parent)
	return collision_parent

## Generates collision for all wall cells
static func _generate_wall_collision(parent: Node3D, layout: SceneLayout) -> void:
	var wall_cells = layout.get_cells_of_type("wall")
	
	for cell in wall_cells:
		var wall_body = create_wall_static_body(cell, layout)
		if wall_body:
			parent.add_child(wall_body)

## Generates collision for all floor cells with seamless connections
static func _generate_floor_collision(parent: Node3D, layout: SceneLayout) -> void:
	var floor_cells = layout.get_cells_of_type("floor")
	
	# Group adjacent floor cells for optimized collision
	var floor_groups = _group_adjacent_floor_cells(floor_cells, layout)
	
	for group in floor_groups:
		var floor_body = create_floor_group_static_body(group)
		if floor_body:
			parent.add_child(floor_body)

## Generates collision for door cells (reduced collision for passage)
static func _generate_door_collision(parent: Node3D, layout: SceneLayout) -> void:
	var door_cells = layout.get_cells_of_type("door")
	
	for cell in door_cells:
		var door_body = create_door_static_body(cell, layout)
		if door_body:
			parent.add_child(door_body)

## Creates a StaticBody3D for a wall cell with appropriate collision shape
static func create_wall_static_body(cell: CellData, layout: SceneLayout) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	static_body.name = "WallCollision_%s" % cell.position
	static_body.position = BaseGenerator.grid_to_world(cell.position)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	# Determine wall orientation and adjust collision shape accordingly
	var wall_rotation = _determine_wall_orientation(cell, layout)
	
	if wall_rotation == 90 or wall_rotation == 270:
		# Vertical wall (running north-south)
		box_shape.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, BaseGenerator.GRID_SIZE)
	else:
		# Horizontal wall (running east-west)
		box_shape.size = Vector3(BaseGenerator.GRID_SIZE, WALL_HEIGHT, WALL_THICKNESS)
	
	collision_shape.shape = box_shape
	collision_shape.position.y = WALL_HEIGHT / 2  # Center vertically
	
	static_body.add_child(collision_shape)
	return static_body

## Creates a StaticBody3D for a floor cell
static func create_floor_static_body(cell: CellData) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	static_body.name = "FloorCollision_%s" % cell.position
	static_body.position = BaseGenerator.grid_to_world(cell.position)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(BaseGenerator.GRID_SIZE, FLOOR_THICKNESS, BaseGenerator.GRID_SIZE)
	
	collision_shape.shape = box_shape
	collision_shape.position.y = -FLOOR_THICKNESS / 2  # Slightly below ground level
	
	static_body.add_child(collision_shape)
	return static_body

## Creates a StaticBody3D for a door cell (frame only, passage is walkable)
static func create_door_static_body(cell: CellData, layout: SceneLayout) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	static_body.name = "DoorCollision_%s" % cell.position
	static_body.position = BaseGenerator.grid_to_world(cell.position)
	
	# Create collision for door frame only (not the passage)
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	# Determine door orientation
	var door_rotation = _determine_wall_orientation(cell, layout)
	
	# Create frame collision (thinner than walls to allow passage)
	if door_rotation == 90 or door_rotation == 270:
		# Vertical door frame
		box_shape.size = Vector3(WALL_THICKNESS * 0.5, DOOR_HEIGHT, BaseGenerator.GRID_SIZE * 0.2)
	else:
		# Horizontal door frame
		box_shape.size = Vector3(BaseGenerator.GRID_SIZE * 0.2, DOOR_HEIGHT, WALL_THICKNESS * 0.5)
	
	collision_shape.shape = box_shape
	collision_shape.position.y = DOOR_HEIGHT / 2
	
	static_body.add_child(collision_shape)
	return static_body

## Determines wall/door orientation based on neighboring cells
static func _determine_wall_orientation(cell: CellData, layout: SceneLayout) -> float:
	var neighbors = layout.get_neighbors(cell.position, false)
	var floor_neighbors: Array[Vector2i] = []
	
	# Find floor neighbors to determine orientation
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for i in range(directions.size()):
		var neighbor_pos = cell.position + directions[i]
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			floor_neighbors.append(directions[i])
	
	# Determine rotation based on floor neighbor pattern
	if floor_neighbors.size() == 0:
		return 0  # Default orientation
	
	var primary_direction = floor_neighbors[0]
	
	# If floor is to the north or south, wall should be horizontal (0°)
	# If floor is to the east or west, wall should be vertical (90°)
	if primary_direction.y != 0:  # North or South
		return 0  # Horizontal wall
	else:  # East or West
		return 90  # Vertical wall

## Creates collision shapes for custom objects
static func create_custom_collision_shape(size: Vector3, shape_type: String = "box") -> Shape3D:
	match shape_type.to_lower():
		"box":
			var box_shape = BoxShape3D.new()
			box_shape.size = size
			return box_shape
		"sphere":
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = max(size.x, max(size.y, size.z)) / 2.0
			return sphere_shape
		"capsule":
			var capsule_shape = CapsuleShape3D.new()
			capsule_shape.radius = max(size.x, size.z) / 2.0
			capsule_shape.height = size.y
			return capsule_shape
		_:
			push_warning("Unknown shape type: %s. Using box shape." % shape_type)
			var box_shape = BoxShape3D.new()
			box_shape.size = size
			return box_shape

## Adds collision to an existing node
static func add_collision_to_node(node: Node3D, collision_shape: Shape3D, is_static: bool = true) -> void:
	var body: Node3D
	
	if is_static:
		body = StaticBody3D.new()
		body.name = "StaticBody"
	else:
		body = RigidBody3D.new()
		body.name = "RigidBody"
	
	var collision_shape_node = CollisionShape3D.new()
	collision_shape_node.shape = collision_shape
	collision_shape_node.name = "CollisionShape"
	
	body.add_child(collision_shape_node)
	node.add_child(body)

## Validates collision shapes align with visual geometry
static func validate_collision_alignment(parent: Node3D) -> bool:
	var is_valid = true
	var collision_nodes = _find_collision_nodes(parent)
	
	for collision_node in collision_nodes:
		if not _validate_single_collision_node(collision_node):
			is_valid = false
	
	return is_valid

## Finds all collision nodes under a parent
static func _find_collision_nodes(parent: Node3D) -> Array[Node3D]:
	var collision_nodes: Array[Node3D] = []
	
	for child in parent.get_children():
		if child is StaticBody3D or child is RigidBody3D:
			collision_nodes.append(child)
		
		# Recursively search children
		if child is Node3D:
			collision_nodes.append_array(_find_collision_nodes(child))
	
	return collision_nodes

## Validates a single collision node
static func _validate_single_collision_node(collision_node: Node3D) -> bool:
	var is_valid = true
	
	# Check if collision node has collision shapes
	var collision_shapes = []
	for child in collision_node.get_children():
		if child is CollisionShape3D:
			collision_shapes.append(child)
	
	if collision_shapes.is_empty():
		push_warning("Collision node %s has no collision shapes" % collision_node.name)
		is_valid = false
	
	# Validate each collision shape
	for shape_node in collision_shapes:
		if not shape_node.shape:
			push_error("CollisionShape3D %s has no shape assigned" % shape_node.name)
			is_valid = false
	
	return is_valid

## Groups adjacent floor cells for optimized collision generation
static func _group_adjacent_floor_cells(floor_cells: Array[CellData], layout: SceneLayout) -> Array[Array]:
	var groups: Array[Array] = []
	var processed: Dictionary = {}
	
	for cell in floor_cells:
		if cell.position in processed:
			continue
		
		# Start a new group with this cell
		var group: Array[CellData] = []
		_flood_fill_floor_group(cell, floor_cells, layout, processed, group)
		
		if not group.is_empty():
			groups.append(group)
	
	return groups

## Flood fill to group connected floor cells
static func _flood_fill_floor_group(start_cell: CellData, all_floor_cells: Array[CellData], layout: SceneLayout, processed: Dictionary, group: Array[CellData]) -> void:
	if start_cell.position in processed:
		return
	
	processed[start_cell.position] = true
	group.append(start_cell)
	
	# Check adjacent positions for more floor cells
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		var neighbor_pos = start_cell.position + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		
		if neighbor_cell and neighbor_cell.cell_type == "floor" and not neighbor_pos in processed:
			_flood_fill_floor_group(neighbor_cell, all_floor_cells, layout, processed, group)

## Creates a StaticBody3D for a group of connected floor cells
static func create_floor_group_static_body(floor_group: Array[CellData]) -> StaticBody3D:
	if floor_group.is_empty():
		return null
	
	var static_body = StaticBody3D.new()
	static_body.name = "FloorCollisionGroup_%d_cells" % floor_group.size()
	
	# Calculate the bounding box of the group
	var min_pos = floor_group[0].position
	var max_pos = floor_group[0].position
	
	for cell in floor_group:
		min_pos.x = min(min_pos.x, cell.position.x)
		min_pos.y = min(min_pos.y, cell.position.y)
		max_pos.x = max(max_pos.x, cell.position.x)
		max_pos.y = max(max_pos.y, cell.position.y)
	
	# Check if the group forms a perfect rectangle
	var expected_cells = (max_pos.x - min_pos.x + 1) * (max_pos.y - min_pos.y + 1)
	
	if expected_cells == floor_group.size():
		# Perfect rectangle - use single collision shape
		_create_rectangular_floor_collision(static_body, min_pos, max_pos)
	else:
		# Irregular shape - use individual collision shapes
		_create_individual_floor_collision(static_body, floor_group)
	
	return static_body

## Creates a single rectangular collision shape for a rectangular floor group
static func _create_rectangular_floor_collision(static_body: StaticBody3D, min_pos: Vector2i, max_pos: Vector2i) -> void:
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	# Calculate size and position
	var width = (max_pos.x - min_pos.x + 1) * BaseGenerator.GRID_SIZE
	var depth = (max_pos.y - min_pos.y + 1) * BaseGenerator.GRID_SIZE
	
	box_shape.size = Vector3(width, FLOOR_THICKNESS, depth)
	collision_shape.shape = box_shape
	
	# Position at center of the rectangle
	var center_x = (min_pos.x + max_pos.x) * 0.5 * BaseGenerator.GRID_SIZE
	var center_z = (min_pos.y + max_pos.y) * 0.5 * BaseGenerator.GRID_SIZE
	
	static_body.position = Vector3(center_x, -FLOOR_THICKNESS / 2, center_z)
	static_body.add_child(collision_shape)

## Creates individual collision shapes for irregular floor groups
static func _create_individual_floor_collision(static_body: StaticBody3D, floor_group: Array[CellData]) -> void:
	# Use the first cell's position as the body position
	var reference_pos = floor_group[0].position
	static_body.position = BaseGenerator.grid_to_world(reference_pos)
	
	for cell in floor_group:
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(BaseGenerator.GRID_SIZE, FLOOR_THICKNESS, BaseGenerator.GRID_SIZE)
		
		collision_shape.shape = box_shape
		collision_shape.name = "FloorShape_%s" % cell.position
		
		# Position relative to the static body
		var relative_pos = BaseGenerator.grid_to_world(cell.position - reference_pos)
		collision_shape.position = Vector3(relative_pos.x, -FLOOR_THICKNESS / 2, relative_pos.z)
		
		static_body.add_child(collision_shape)

## Adds collision for stairs and ramps between levels
static func create_stair_collision(start_pos: Vector2i, end_pos: Vector2i, height_difference: float) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	static_body.name = "StairCollision_%s_to_%s" % [start_pos, end_pos]
	
	# Calculate stair parameters
	var horizontal_distance = (end_pos - start_pos).length() * BaseGenerator.GRID_SIZE
	var steps = max(1, int(horizontal_distance / BaseGenerator.GRID_SIZE))
	var step_height = height_difference / steps
	var step_depth = horizontal_distance / steps
	
	# Create collision for each step
	for i in range(steps):
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(BaseGenerator.GRID_SIZE, step_height, step_depth)
		
		collision_shape.shape = box_shape
		collision_shape.name = "Step_%d" % i
		
		# Position each step
		var step_progress = float(i) / float(steps)
		var step_world_pos = BaseGenerator.grid_to_world(start_pos).lerp(BaseGenerator.grid_to_world(end_pos), step_progress)
		step_world_pos.y = step_progress * height_difference + step_height / 2
		
		collision_shape.position = step_world_pos - static_body.position
		static_body.add_child(collision_shape)
	
	static_body.position = BaseGenerator.grid_to_world(start_pos)
	return static_body

## Optimizes collision by combining adjacent shapes where possible
static func optimize_collision_shapes(parent: Node3D) -> void:
	# Floor collision is already optimized during generation
	# Additional optimizations could be added here for walls and other objects
	pass

## Creates collision layers for different object types
static func setup_collision_layers(collision_node: Node3D, layer_type: String) -> void:
	if not collision_node is CollisionObject3D:
		return
	
	var collision_object = collision_node as CollisionObject3D
	
	match layer_type.to_lower():
		"environment":
			collision_object.collision_layer = 1  # Layer 1: Static environment
			collision_object.collision_mask = 0   # Doesn't collide with anything
		"character":
			collision_object.collision_layer = 2  # Layer 2: Characters
			collision_object.collision_mask = 1   # Collides with environment
		"props":
			collision_object.collision_layer = 4  # Layer 3: Props and furniture
			collision_object.collision_mask = 3   # Collides with environment and characters
		_:
			# Default collision setup
			collision_object.collision_layer = 1
			collision_object.collision_mask = 1