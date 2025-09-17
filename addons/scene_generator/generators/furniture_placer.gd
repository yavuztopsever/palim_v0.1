class_name FurniturePlacer
extends RefCounted

## Furniture and prop placement system for generated scenes
## Places furniture based on area type (residential, commercial, administrative)
## Ensures furniture doesn't block doorways or navigation paths
## Implements proper furniture scaling and positioning

# Required imports
const PropPlacementRules = preload("res://addons/scene_generator/utils/prop_placement_rules.gd")

# Furniture placement constants
const MIN_ROOM_SIZE: int = 4  # Minimum room size to place furniture
const FURNITURE_CLEARANCE: float = 0.5  # Clearance around furniture
const WALL_OFFSET: float = 0.3  # Distance from walls for furniture placement
const DOORWAY_CLEARANCE: float = 1.5  # Clearance around doorways

# Asset library reference
var asset_library: AssetLibrary
var random_generator: RandomNumberGenerator

func _init(library: AssetLibrary = null, seed: int = 0):
	asset_library = library if library else AssetLibrary.new()
	random_generator = RandomNumberGenerator.new()
	random_generator.seed = seed



## Creates a parent node for organizing furniture
func _create_parent_node(root: Node3D, name: String) -> Node3D:
	var parent = Node3D.new()
	parent.name = name
	root.add_child(parent)
	return parent

## Identifies distinct room areas (connected floor regions)
func _identify_room_areas(layout: SceneLayout) -> Array[Array]:
	var floor_cells = layout.get_cells_of_type("floor")
	var visited: Dictionary = {}
	var room_areas: Array[Array] = []
	
	for cell in floor_cells:
		if not cell.position in visited:
			var room_area: Array[Vector2i] = []
			_flood_fill_room_area(cell.position, layout, visited, room_area)
			if room_area.size() >= MIN_ROOM_SIZE:
				room_areas.append(room_area)
	
	return room_areas

## Flood fill to identify a room area
func _flood_fill_room_area(pos: Vector2i, layout: SceneLayout, visited: Dictionary, room_area: Array[Vector2i]) -> void:
	if pos in visited or not layout.is_valid_position(pos):
		return
	
	var cell = layout.get_cell(pos)
	if not cell or cell.cell_type != "floor":
		return
	
	visited[pos] = true
	room_area.append(pos)
	
	# Expand to adjacent floor cells
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "floor":
			_flood_fill_room_area(neighbor_pos, layout, visited, room_area)

## Places furniture in a specific room area using prop placement rules
func _place_furniture_in_room(parent: Node3D, layout: SceneLayout, room_area: Array[Vector2i], params: GenerationParams) -> void:
	# Use PropPlacementRules to generate placement suggestions
	var placement_suggestions = PropPlacementRules.generate_placement_suggestions(layout, room_area, params.area_type)
	
	# Check for overcrowding before placing
	if PropPlacementRules.is_room_overcrowded(layout, room_area, params.area_type):
		push_warning("Room is already overcrowded, skipping furniture placement")
		return
	
	# Sort suggestions by priority (highest first)
	placement_suggestions.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Place furniture based on suggestions
	var placed_count = 0
	var max_props = PropPlacementRules.calculate_max_props_for_room(room_area.size(), params.area_type)
	
	for suggestion in placement_suggestions:
		if placed_count >= max_props:
			break
		
		var prop_id = suggestion.prop_id
		var position = suggestion.position
		var placement_rule = suggestion.placement_rule
		
		# Validate placement using prop rules
		var validation = PropPlacementRules.validate_prop_placement(layout, position, prop_id, params.area_type)
		
		if validation.valid:
			# Apply random chance based on category
			var place_chance = _get_placement_chance_for_category(suggestion.category)
			if random_generator.randf() < place_chance:
				_place_furniture_piece(parent, layout, position, prop_id)
				placed_count += 1
		elif OS.is_debug_build():
			# Log validation issues in debug builds
			for error in validation.errors:
				push_warning("Furniture placement validation failed at %s: %s" % [position, error])

## Gets placement chance based on prop category
func _get_placement_chance_for_category(category: String) -> float:
	match category:
		"furniture":
			return 0.8  # High chance for essential furniture
		"lighting":
			return 0.6  # Medium chance for lighting
		"decorative":
			return 0.4  # Lower chance for decorative items
		"display":
			return 0.7  # High chance for commercial displays
		"storage":
			return 0.7  # High chance for storage items
		_:
			return 0.5  # Default chance

## Finds suitable positions for furniture placement within a room
func _find_furniture_placement_positions(layout: SceneLayout, room_area: Array[Vector2i]) -> Array[Vector2i]:
	var placement_positions: Array[Vector2i] = []
	
	for pos in room_area:
		if _is_valid_furniture_position(layout, pos):
			placement_positions.append(pos)
	
	return placement_positions

## Checks if a position is valid for furniture placement
func _is_valid_furniture_position(layout: SceneLayout, pos: Vector2i) -> bool:
	# Check if position is clear
	var cell = layout.get_cell(pos)
	if not cell or cell.cell_type != "floor":
		return false
	
	# Check for doorway clearance
	if _is_near_doorway(layout, pos):
		return false
	
	# Check for navigation path clearance
	if _blocks_navigation_path(layout, pos):
		return false
	
	# Prefer positions near walls for furniture placement
	return _is_near_wall(layout, pos)

## Checks if a position is near a doorway
func _is_near_doorway(layout: SceneLayout, pos: Vector2i) -> bool:
	var clearance_radius = int(DOORWAY_CLEARANCE / BaseGenerator.GRID_SIZE)
	
	for x in range(-clearance_radius, clearance_radius + 1):
		for y in range(-clearance_radius, clearance_radius + 1):
			var check_pos = pos + Vector2i(x, y)
			var cell = layout.get_cell(check_pos)
			if cell and cell.cell_type == "door":
				return true
	
	return false

## Checks if placing furniture would block navigation paths
func _blocks_navigation_path(layout: SceneLayout, pos: Vector2i) -> bool:
	# Simple check: ensure at least one adjacent cell remains walkable
	var walkable_neighbors = 0
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			walkable_neighbors += 1
	
	# Need at least 2 walkable neighbors to avoid blocking paths
	return walkable_neighbors < 2

## Checks if a position is near a wall (preferred for furniture)
func _is_near_wall(layout: SceneLayout, pos: Vector2i) -> bool:
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "wall":
			return true
	
	return false

## Finds the best position for a specific furniture piece
func _find_best_position_for_furniture(layout: SceneLayout, room_area: Array[Vector2i], available_positions: Array[Vector2i], furniture_id: String) -> Vector2i:
	if available_positions.is_empty():
		return Vector2i(-1, -1)
	
	# Score positions based on furniture type preferences
	var scored_positions: Array[Dictionary] = []
	
	for pos in available_positions:
		var score = _score_furniture_position(layout, pos, furniture_id)
		scored_positions.append({"position": pos, "score": score})
	
	# Sort by score (highest first)
	scored_positions.sort_custom(func(a, b): return a.score > b.score)
	
	# Return best position
	return scored_positions[0].position

## Scores a position for furniture placement based on furniture type
func _score_furniture_position(layout: SceneLayout, pos: Vector2i, furniture_id: String) -> float:
	var score = 0.0
	
	# Base score for being a valid position
	score += 10.0
	
	# Bonus for being near walls
	if _is_near_wall(layout, pos):
		score += 5.0
	
	# Furniture-specific scoring
	match furniture_id:
		"bed":
			# Beds prefer corners
			if _is_corner_position(layout, pos):
				score += 8.0
		"table":
			# Tables prefer central positions
			if _is_central_position(layout, pos):
				score += 6.0
		"chair":
			# Chairs prefer to be near tables (if any exist)
			score += 3.0
		"cabinet", "shelf":
			# Storage prefers wall positions
			if _is_against_wall(layout, pos):
				score += 7.0
		"lamp", "torch":
			# Lighting prefers corners or central positions
			if _is_corner_position(layout, pos) or _is_central_position(layout, pos):
				score += 5.0
	
	# Small random factor for variety
	score += random_generator.randf() * 2.0
	
	return score

## Checks if a position is in a corner
func _is_corner_position(layout: SceneLayout, pos: Vector2i) -> bool:
	var wall_neighbors = 0
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "wall":
			wall_neighbors += 1
	
	return wall_neighbors >= 2

## Checks if a position is central within the room
func _is_central_position(layout: SceneLayout, pos: Vector2i) -> bool:
	# Simple heuristic: not adjacent to any walls
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "wall":
			return false
	
	return true

## Checks if a position is directly against a wall
func _is_against_wall(layout: SceneLayout, pos: Vector2i) -> bool:
	return _is_near_wall(layout, pos)

## Places a furniture piece at the specified position
func _place_furniture_piece(parent: Node3D, layout: SceneLayout, pos: Vector2i, furniture_id: String) -> void:
	var furniture_node = _create_furniture_node(furniture_id, pos)
	if furniture_node:
		parent.add_child(furniture_node)
		
		# Mark the cell as occupied by furniture
		var cell = CellData.new(pos, "furniture")
		cell.asset_id = furniture_id
		layout.set_cell(pos, cell)

## Creates a furniture node from furniture ID
func _create_furniture_node(furniture_id: String, pos: Vector2i) -> Node3D:
	var furniture_scene = asset_library.get_asset(furniture_id, "default_prop")
	
	var furniture_node: Node3D
	if furniture_scene:
		furniture_node = furniture_scene.instantiate()
	else:
		furniture_node = _create_default_furniture(furniture_id)
	
	furniture_node.name = "Furniture_%s_%s" % [furniture_id, pos]
	furniture_node.position = BaseGenerator.grid_to_world(pos)
	
	# Apply proper scaling and positioning
	_apply_furniture_scaling(furniture_node, furniture_id)
	_apply_furniture_positioning(furniture_node, furniture_id)
	
	return furniture_node

## Creates a default furniture piece when no asset is available
func _create_default_furniture(furniture_id: String) -> Node3D:
	var furniture_node = Node3D.new()
	
	# Create mesh based on furniture type
	var mesh_instance = MeshInstance3D.new()
	var mesh: Mesh
	var color: Color
	var size: Vector3
	
	match furniture_id:
		"table":
			mesh = BoxMesh.new()
			size = Vector3(1.2, 0.8, 0.8)
			color = Color.BROWN
		"chair":
			mesh = BoxMesh.new()
			size = Vector3(0.5, 1.0, 0.5)
			color = Color.SADDLE_BROWN
		"bed":
			mesh = BoxMesh.new()
			size = Vector3(1.0, 0.5, 2.0)
			color = Color.BLUE
		"cabinet":
			mesh = BoxMesh.new()
			size = Vector3(0.8, 1.5, 0.4)
			color = Color.DARK_GRAY
		"shelf":
			mesh = BoxMesh.new()
			size = Vector3(1.0, 1.2, 0.3)
			color = Color.GRAY
		"barrel":
			mesh = CylinderMesh.new()
			size = Vector3(0.6, 1.0, 0.6)
			color = Color.BROWN
		"crate":
			mesh = BoxMesh.new()
			size = Vector3(0.8, 0.8, 0.8)
			color = Color.BURLYWOOD
		_:
			mesh = BoxMesh.new()
			size = Vector3(0.5, 0.5, 0.5)
			color = Color.MAGENTA
	
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var cylinder = mesh as CylinderMesh
		cylinder.top_radius = size.x / 2
		cylinder.bottom_radius = size.x / 2
		cylinder.height = size.y
	
	mesh_instance.mesh = mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	
	furniture_node.add_child(mesh_instance)
	return furniture_node

## Applies proper scaling to furniture based on type
func _apply_furniture_scaling(furniture_node: Node3D, furniture_id: String) -> void:
	# Most furniture should fit within grid cells
	var scale_factor = 1.0
	
	match furniture_id:
		"chair":
			scale_factor = 0.8  # Chairs can be smaller
		"lamp", "torch":
			scale_factor = 0.6  # Lighting fixtures are smaller
		"barrel", "crate":
			scale_factor = 0.7  # Props are smaller
	
	furniture_node.scale = Vector3.ONE * scale_factor

## Applies proper positioning to furniture based on type
func _apply_furniture_positioning(furniture_node: Node3D, furniture_id: String) -> void:
	# Adjust Y position based on furniture type
	match furniture_id:
		"table":
			furniture_node.position.y += 0.4  # Table height
		"chair":
			furniture_node.position.y += 0.5  # Chair height
		"bed":
			furniture_node.position.y += 0.25  # Bed height
		"cabinet", "shelf":
			furniture_node.position.y += 0.75  # Storage height
		"lamp":
			furniture_node.position.y += 1.0  # Lamp height
		"torch":
			furniture_node.position.y += 1.2  # Torch height

## Validates furniture placement doesn't break navigation using prop rules
func validate_furniture_placement(layout: SceneLayout, area_type: String) -> bool:
	var is_valid = true
	var furniture_cells = layout.get_cells_of_type("furniture")
	var prop_cells = layout.get_cells_of_type("prop")
	var all_prop_cells = furniture_cells + prop_cells
	
	for prop_cell in all_prop_cells:
		# Use PropPlacementRules for comprehensive validation
		var validation = PropPlacementRules.validate_prop_placement(layout, prop_cell.position, prop_cell.asset_id, area_type)
		
		if not validation.valid:
			is_valid = false
			for error in validation.errors:
				push_error("Prop validation failed at %s: %s" % [prop_cell.position, error])
		
		# Log warnings in debug builds
		if OS.is_debug_build():
			for warning in validation.warnings:
				push_warning("Prop validation warning at %s: %s" % [prop_cell.position, warning])
	
	# Check for overcrowding at room level
	var room_areas = _identify_room_areas(layout)
	for room_area in room_areas:
		if PropPlacementRules.is_room_overcrowded(layout, room_area, area_type):
			push_warning("Room with %d cells is overcrowded with props" % room_area.size())
			is_valid = false
	
	return is_valid

## Gets furniture placement statistics using prop rules
func get_furniture_stats(layout: SceneLayout, area_type: String) -> Dictionary:
	# Use PropPlacementRules for comprehensive statistics
	var stats = PropPlacementRules.get_prop_placement_stats(layout, area_type)
	
	# Add furniture-specific stats
	var furniture_cells = layout.get_cells_of_type("furniture")
	var prop_cells = layout.get_cells_of_type("prop")
	
	stats["furniture_only"] = furniture_cells.size()
	stats["props_only"] = prop_cells.size()
	
	# Room coverage analysis
	var room_areas = _identify_room_areas(layout)
	stats["rooms_with_furniture"] = 0
	stats["empty_rooms"] = 0
	
	for room_area in room_areas:
		var has_props = false
		for pos in room_area:
			var cell = layout.get_cell(pos)
			if cell and (cell.cell_type == "furniture" or cell.cell_type == "prop"):
				has_props = true
				break
		
		if has_props:
			stats["rooms_with_furniture"] += 1
		else:
			stats["empty_rooms"] += 1
	
	return stats

## Prints comprehensive furniture and prop placement statistics
func print_furniture_stats(layout: SceneLayout, area_type: String) -> void:
	var stats = get_furniture_stats(layout, area_type)
	print("=== Furniture & Prop Placement Statistics ===")
	print("Total Props: %d (Furniture: %d, Props: %d)" % [stats["total_props"], stats["furniture_only"], stats["props_only"]])
	print("Rooms: %d analyzed, %d with props, %d empty, %d overcrowded" % [
		stats["rooms_analyzed"], 
		stats["rooms_with_furniture"], 
		stats["empty_rooms"], 
		stats["overcrowded_rooms"]
	])
	print("Average props per room: %.1f" % stats["average_props_per_room"])
	
	print("Props by Category:")
	var props_by_category = stats["props_by_category"]
	for category in props_by_category:
		print("  %s: %d" % [category, props_by_category[category]])

## Adds comprehensive prop placement validation and statistics
func place_furniture_from_layout(root: Node3D, layout: SceneLayout, params: GenerationParams) -> void:
	if not layout or not layout.validate_layout():
		push_error("Invalid layout provided to FurniturePlacer")
		return
	
	# Create parent node for organization
	var furniture_parent = _create_parent_node(root, "Furniture")
	
	# Identify rooms and place furniture in each
	var room_areas = _identify_room_areas(layout)
	
	for room_area in room_areas:
		if room_area.size() >= MIN_ROOM_SIZE:
			_place_furniture_in_room(furniture_parent, layout, room_area, params)
	
	# Validate final placement
	var validation_passed = validate_furniture_placement(layout, params.area_type)
	
	if OS.is_debug_build():
		if validation_passed:
			print("Furniture placement validation passed")
		else:
			print("Furniture placement validation failed - check warnings above")
		
		# Print comprehensive statistics
		print_furniture_stats(layout, params.area_type)