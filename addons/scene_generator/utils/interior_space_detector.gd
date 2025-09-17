class_name InteriorSpaceDetector
extends RefCounted

## Interior space detection system for generated layouts
## Automatically identifies interior vs exterior areas and prevents roof generation
## Ensures proper wall hiding behavior for interior rooms

# Detection parameters
const MIN_ENCLOSED_AREA: int = 4  # Minimum cells to consider a space interior
const WALL_THRESHOLD: float = 0.6  # Ratio of walls to consider space enclosed

## Analyzes layout and marks interior/exterior spaces
static func detect_interior_spaces(layout: SceneLayout) -> Dictionary:
	var space_info = {
		"interior_rooms": [],
		"exterior_areas": [],
		"mixed_areas": [],
		"room_boundaries": {}
	}
	
	# Find all connected floor regions
	var floor_regions = _find_connected_floor_regions(layout)
	
	# Analyze each region to determine if it's interior or exterior
	for region in floor_regions:
		var region_info = _analyze_region(region, layout)
		
		match region_info.space_type:
			"interior":
				space_info.interior_rooms.append(region_info)
			"exterior":
				space_info.exterior_areas.append(region_info)
			"mixed":
				space_info.mixed_areas.append(region_info)
		
		# Store room boundaries
		space_info.room_boundaries[region_info.room_id] = region_info.boundary_cells
	
	return space_info

## Finds connected regions of floor cells
static func _find_connected_floor_regions(layout: SceneLayout) -> Array[Array]:
	var floor_cells = layout.get_cells_of_type("floor")
	var visited: Array[Vector2i] = []
	var regions: Array[Array] = []
	
	for cell in floor_cells:
		if cell.position not in visited:
			var region = _flood_fill_region(cell.position, layout, visited)
			if region.size() >= MIN_ENCLOSED_AREA:
				regions.append(region)
	
	return regions

## Flood fill to find connected floor cells
static func _flood_fill_region(start_pos: Vector2i, layout: SceneLayout, visited: Array[Vector2i]) -> Array[Vector2i]:
	var region: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start_pos]
	
	while queue.size() > 0:
		var current_pos = queue.pop_front()
		
		if current_pos in visited:
			continue
		
		var current_cell = layout.get_cell(current_pos)
		if not current_cell or not current_cell.is_walkable():
			continue
		
		visited.append(current_pos)
		region.append(current_pos)
		
		# Add neighbors to queue
		var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		for direction in directions:
			var neighbor_pos = current_pos + direction
			if neighbor_pos not in visited:
				queue.append(neighbor_pos)
	
	return region

## Analyzes a region to determine if it's interior, exterior, or mixed
static func _analyze_region(region: Array[Vector2i], layout: SceneLayout) -> Dictionary:
	var region_info = {
		"room_id": "room_%s" % region[0],
		"cells": region,
		"space_type": "exterior",
		"enclosure_ratio": 0.0,
		"boundary_cells": [],
		"has_exterior_connection": false,
		"wall_count": 0,
		"perimeter_length": 0
	}
	
	# Find boundary cells and analyze enclosure
	var boundary_analysis = _analyze_region_boundary(region, layout)
	region_info.boundary_cells = boundary_analysis.boundary_cells
	region_info.wall_count = boundary_analysis.wall_count
	region_info.perimeter_length = boundary_analysis.perimeter_length
	region_info.has_exterior_connection = boundary_analysis.has_exterior_connection
	
	# Calculate enclosure ratio
	if region_info.perimeter_length > 0:
		region_info.enclosure_ratio = float(region_info.wall_count) / float(region_info.perimeter_length)
	
	# Determine space type based on analysis
	region_info.space_type = _determine_space_type(region_info)
	
	return region_info

## Analyzes the boundary of a region
static func _analyze_region_boundary(region: Array[Vector2i], layout: SceneLayout) -> Dictionary:
	var boundary_info = {
		"boundary_cells": [],
		"wall_count": 0,
		"perimeter_length": 0,
		"has_exterior_connection": false
	}
	
	var region_set = {}
	for pos in region:
		region_set[pos] = true
	
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	var boundary_positions = {}
	
	# Find all boundary positions
	for pos in region:
		for direction in directions:
			var neighbor_pos = pos + direction
			
			if neighbor_pos not in region_set:
				boundary_positions[neighbor_pos] = true
				boundary_info.perimeter_length += 1
				
				# Check what's at the boundary
				var boundary_cell = layout.get_cell(neighbor_pos)
				
				if boundary_cell:
					if boundary_cell.cell_type == "wall":
						boundary_info.wall_count += 1
					elif boundary_cell.is_walkable():
						boundary_info.has_exterior_connection = true
				else:
					# No cell means edge of layout (exterior)
					boundary_info.has_exterior_connection = true
	
	# Convert boundary positions to array
	for pos in boundary_positions:
		boundary_info.boundary_cells.append(pos)
	
	return boundary_info

## Determines space type based on region analysis
static func _determine_space_type(region_info: Dictionary) -> String:
	var enclosure_ratio = region_info.enclosure_ratio
	var has_exterior_connection = region_info.has_exterior_connection
	var region_size = region_info.cells.size()
	
	# Large areas with exterior connections are likely exterior
	if region_size > 50 and has_exterior_connection:
		return "exterior"
	
	# High enclosure ratio indicates interior space
	if enclosure_ratio >= WALL_THRESHOLD:
		return "interior"
	
	# Medium enclosure with no exterior connection might be interior
	if enclosure_ratio >= 0.4 and not has_exterior_connection:
		return "interior"
	
	# Low enclosure or exterior connections indicate exterior
	if enclosure_ratio < 0.3 or has_exterior_connection:
		return "exterior"
	
	# Ambiguous cases are mixed
	return "mixed"

## Updates layout cells with interior/exterior information
static func apply_space_detection_to_layout(layout: SceneLayout, space_info: Dictionary) -> void:
	# Mark interior room cells
	for room_info in space_info.interior_rooms:
		_mark_cells_as_interior(layout, room_info.cells, room_info.room_id)
	
	# Mark exterior area cells
	for area_info in space_info.exterior_areas:
		_mark_cells_as_exterior(layout, area_info.cells, area_info.room_id)
	
	# Mark mixed area cells
	for area_info in space_info.mixed_areas:
		_mark_cells_as_mixed(layout, area_info.cells, area_info.room_id)

## Marks cells as interior
static func _mark_cells_as_interior(layout: SceneLayout, cells: Array[Vector2i], room_id: String) -> void:
	for pos in cells:
		var cell = layout.get_cell(pos)
		if cell:
			cell.properties["is_interior"] = true
			cell.properties["space_type"] = "interior"
			cell.properties["room_id"] = room_id

## Marks cells as exterior
static func _mark_cells_as_exterior(layout: SceneLayout, cells: Array[Vector2i], room_id: String) -> void:
	for pos in cells:
		var cell = layout.get_cell(pos)
		if cell:
			cell.properties["is_interior"] = false
			cell.properties["space_type"] = "exterior"
			cell.properties["room_id"] = room_id

## Marks cells as mixed
static func _mark_cells_as_mixed(layout: SceneLayout, cells: Array[Vector2i], room_id: String) -> void:
	for pos in cells:
		var cell = layout.get_cell(pos)
		if cell:
			cell.properties["is_interior"] = false  # Default to exterior for mixed
			cell.properties["space_type"] = "mixed"
			cell.properties["room_id"] = room_id

## Prevents roof generation for interior spaces
static func configure_roof_generation(layout: SceneLayout, space_info: Dictionary) -> void:
	# Mark all cells in interior rooms to prevent roof generation
	for room_info in space_info.interior_rooms:
		for pos in room_info.cells:
			var cell = layout.get_cell(pos)
			if cell:
				cell.properties["generate_roof"] = false
				cell.properties["roof_excluded"] = true
	
	# Allow roof generation for exterior areas
	for area_info in space_info.exterior_areas:
		for pos in area_info.cells:
			var cell = layout.get_cell(pos)
			if cell:
				cell.properties["generate_roof"] = true
				cell.properties["roof_excluded"] = false
	
	# Mixed areas default to no roof (safer for isometric view)
	for area_info in space_info.mixed_areas:
		for pos in area_info.cells:
			var cell = layout.get_cell(pos)
			if cell:
				cell.properties["generate_roof"] = false
				cell.properties["roof_excluded"] = true

## Configures wall hiding behavior for interior rooms
static func configure_wall_hiding_behavior(layout: SceneLayout, space_info: Dictionary) -> void:
	# Configure walls around interior rooms for proper hiding
	for room_info in space_info.interior_rooms:
		_configure_interior_room_walls(layout, room_info)
	
	# Configure walls around exterior areas
	for area_info in space_info.exterior_areas:
		_configure_exterior_area_walls(layout, area_info)

## Configures walls around an interior room
static func _configure_interior_room_walls(layout: SceneLayout, room_info: Dictionary) -> void:
	var room_id = room_info.room_id
	var boundary_cells = room_info.boundary_cells
	
	# Find wall cells adjacent to this room
	for boundary_pos in boundary_cells:
		var wall_cell = layout.get_cell(boundary_pos)
		if wall_cell and wall_cell.cell_type == "wall":
			# Configure wall for interior room hiding
			wall_cell.properties["is_interior_wall"] = true
			wall_cell.properties["adjacent_room_id"] = room_id
			wall_cell.properties["hide_when_behind"] = true
			wall_cell.properties["transparency_fade"] = 0.3

## Configures walls around an exterior area
static func _configure_exterior_area_walls(layout: SceneLayout, area_info: Dictionary) -> void:
	var area_id = area_info.room_id
	var boundary_cells = area_info.boundary_cells
	
	# Find wall cells adjacent to this area
	for boundary_pos in boundary_cells:
		var wall_cell = layout.get_cell(boundary_pos)
		if wall_cell and wall_cell.cell_type == "wall":
			# Configure wall for exterior area (less aggressive hiding)
			wall_cell.properties["is_interior_wall"] = false
			wall_cell.properties["adjacent_room_id"] = area_id
			wall_cell.properties["hide_when_behind"] = false
			wall_cell.properties["transparency_fade"] = 0.1

## Gets debug information about space detection
static func get_debug_info(space_info: Dictionary) -> String:
	var debug_text = "Interior Space Detection Results:\n"
	
	debug_text += "Interior Rooms: %d\n" % space_info.interior_rooms.size()
	for room_info in space_info.interior_rooms:
		debug_text += "  - %s: %d cells, %.2f enclosure\n" % [
			room_info.room_id, room_info.cells.size(), room_info.enclosure_ratio
		]
	
	debug_text += "Exterior Areas: %d\n" % space_info.exterior_areas.size()
	for area_info in space_info.exterior_areas:
		debug_text += "  - %s: %d cells, %.2f enclosure\n" % [
			area_info.room_id, area_info.cells.size(), area_info.enclosure_ratio
		]
	
	debug_text += "Mixed Areas: %d\n" % space_info.mixed_areas.size()
	for area_info in space_info.mixed_areas:
		debug_text += "  - %s: %d cells, %.2f enclosure\n" % [
			area_info.room_id, area_info.cells.size(), area_info.enclosure_ratio
		]
	
	return debug_text

## Creates debug visualization for space detection
static func create_debug_visualization(root: Node3D, layout: SceneLayout, space_info: Dictionary) -> void:
	if not OS.is_debug_build():
		return
	
	var debug_parent = Node3D.new()
	debug_parent.name = "SpaceDetectionDebug"
	root.add_child(debug_parent)
	
	# Visualize interior rooms in green
	for room_info in space_info.interior_rooms:
		_create_room_debug_visualization(debug_parent, room_info, Color.GREEN, "Interior")
	
	# Visualize exterior areas in blue
	for area_info in space_info.exterior_areas:
		_create_room_debug_visualization(debug_parent, area_info, Color.BLUE, "Exterior")
	
	# Visualize mixed areas in yellow
	for area_info in space_info.mixed_areas:
		_create_room_debug_visualization(debug_parent, area_info, Color.YELLOW, "Mixed")

## Creates debug visualization for a single room/area
static func _create_room_debug_visualization(parent: Node3D, room_info: Dictionary, color: Color, type: String) -> void:
	var room_debug = Node3D.new()
	room_debug.name = "%s_%s" % [type, room_info.room_id]
	parent.add_child(room_debug)
	
	# Create a marker at the center of the room
	var center_pos = _calculate_room_center(room_info.cells)
	var world_center = BaseGenerator.grid_to_world(center_pos)
	
	var marker = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	marker.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission = color * 0.3
	marker.material_override = material
	
	marker.position = world_center + Vector3(0, 2, 0)  # Above ground
	room_debug.add_child(marker)
	
	# Add label
	var label = Label3D.new()
	label.text = "%s\n%s\nCells: %d\nEnclosure: %.2f" % [
		type, room_info.room_id, room_info.cells.size(), room_info.enclosure_ratio
	]
	label.position = world_center + Vector3(0, 3, 0)
	room_debug.add_child(label)

## Calculates the center position of a room
static func _calculate_room_center(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	
	var sum_x = 0
	var sum_y = 0
	
	for pos in cells:
		sum_x += pos.x
		sum_y += pos.y
	
	return Vector2i(sum_x / cells.size(), sum_y / cells.size())