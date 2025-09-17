class_name NavigationBuilder
extends RefCounted

## Utility class for generating navigation meshes and NavigationRegion3D nodes
## Handles navigation mesh creation for character movement and pathfinding

# Navigation mesh constants
const AGENT_HEIGHT: float = 2.0
const AGENT_RADIUS: float = 0.5
const AGENT_MAX_CLIMB: float = 0.5
const AGENT_MAX_SLOPE: float = 45.0
const REGION_MIN_SIZE: float = 2.0
const REGION_MERGE_SIZE: float = 20.0
const DETAIL_SAMPLE_DIST: float = 6.0
const DETAIL_SAMPLE_MAX_ERROR: float = 1.0

## Generates NavigationRegion3D covering all walkable areas
static func generate_navigation_region_for_layout(parent: Node3D, layout: SceneLayout) -> NavigationRegion3D:
	if not layout or not layout.validate_layout():
		push_error("Invalid layout provided to NavigationBuilder")
		return null
	
	# Create navigation region
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion"
	
	# Create and configure navigation mesh
	var nav_mesh = NavigationMesh.new()
	_configure_navigation_mesh(nav_mesh)
	
	# Generate navigation mesh from layout
	_bake_navigation_mesh_from_layout(nav_mesh, layout)
	
	nav_region.navigation_mesh = nav_mesh
	parent.add_child(nav_region)
	
	return nav_region

## Configures navigation mesh parameters for optimal pathfinding
static func _configure_navigation_mesh(nav_mesh: NavigationMesh) -> void:
	# Agent parameters
	nav_mesh.agent_height = AGENT_HEIGHT
	nav_mesh.agent_radius = AGENT_RADIUS
	nav_mesh.agent_max_climb = AGENT_MAX_CLIMB
	nav_mesh.agent_max_slope = AGENT_MAX_SLOPE
	
	# Region parameters
	nav_mesh.region_min_size = REGION_MIN_SIZE
	nav_mesh.region_merge_size = REGION_MERGE_SIZE
	
	# Detail mesh parameters
	nav_mesh.detail_sample_distance = DETAIL_SAMPLE_DIST
	nav_mesh.detail_sample_max_error = DETAIL_SAMPLE_MAX_ERROR
	
	# Cell size (should match grid system)
	nav_mesh.cell_size = BaseGenerator.GRID_SIZE / 4.0  # Higher resolution for better pathfinding
	nav_mesh.cell_height = 0.2

## Bakes navigation mesh from floor collision shapes
static func _bake_navigation_mesh_from_layout(nav_mesh: NavigationMesh, layout: SceneLayout) -> void:
	# Get all walkable cells
	var walkable_cells = layout.get_walkable_cells()
	
	if walkable_cells.is_empty():
		push_warning("No walkable cells found for navigation mesh generation")
		return
	
	# Create source geometry for navigation mesh baking
	var source_geometry = NavigationMeshSourceGeometryData3D.new()
	
	# Add floor surfaces as walkable geometry
	_add_floor_geometry_to_source(source_geometry, walkable_cells)
	
	# Add wall geometry as obstacles
	var wall_cells = layout.get_cells_of_type("wall")
	_add_wall_geometry_to_source(source_geometry, wall_cells)
	
	# Bake the navigation mesh
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geometry)
	
	if OS.is_debug_build():
		print("Navigation mesh baked with %d walkable cells and %d wall obstacles" % [walkable_cells.size(), wall_cells.size()])

## Adds floor geometry to the source geometry data
static func _add_floor_geometry_to_source(source_geometry: NavigationMeshSourceGeometryData3D, walkable_cells: Array[CellData]) -> void:
	# Group adjacent walkable cells for optimized geometry
	var floor_groups = _group_adjacent_walkable_cells(walkable_cells)
	
	for group in floor_groups:
		_add_floor_group_geometry(source_geometry, group)

## Groups adjacent walkable cells for optimized navigation mesh generation
static func _group_adjacent_walkable_cells(walkable_cells: Array[CellData]) -> Array[Array]:
	var groups: Array[Array] = []
	var processed: Dictionary = {}
	
	for cell in walkable_cells:
		if cell.position in processed:
			continue
		
		# Start a new group with this cell
		var group: Array[CellData] = []
		_flood_fill_walkable_group(cell, walkable_cells, processed, group)
		
		if not group.is_empty():
			groups.append(group)
	
	return groups

## Flood fill to group connected walkable cells
static func _flood_fill_walkable_group(start_cell: CellData, all_walkable_cells: Array[CellData], processed: Dictionary, group: Array[CellData]) -> void:
	if start_cell.position in processed:
		return
	
	processed[start_cell.position] = true
	group.append(start_cell)
	
	# Check adjacent positions for more walkable cells
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		var neighbor_pos = start_cell.position + direction
		
		# Find the cell at this position
		var neighbor_cell: CellData = null
		for cell in all_walkable_cells:
			if cell.position == neighbor_pos:
				neighbor_cell = cell
				break
		
		if neighbor_cell and not neighbor_pos in processed:
			_flood_fill_walkable_group(neighbor_cell, all_walkable_cells, processed, group)

## Adds geometry for a group of connected floor cells
static func _add_floor_group_geometry(source_geometry: NavigationMeshSourceGeometryData3D, floor_group: Array[CellData]) -> void:
	if floor_group.is_empty():
		return
	
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
		# Perfect rectangle - create single mesh
		_add_rectangular_floor_mesh(source_geometry, min_pos, max_pos)
	else:
		# Irregular shape - create individual meshes
		_add_individual_floor_meshes(source_geometry, floor_group)

## Adds a single rectangular mesh for a rectangular floor group
static func _add_rectangular_floor_mesh(source_geometry: NavigationMeshSourceGeometryData3D, min_pos: Vector2i, max_pos: Vector2i) -> void:
	# Calculate world positions
	var world_min = BaseGenerator.grid_to_world(min_pos)
	var world_max = BaseGenerator.grid_to_world(max_pos)
	
	# Create vertices for a rectangular floor
	var vertices = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	# Calculate actual bounds (add grid size to max to get the far corner)
	var x_min = world_min.x - BaseGenerator.GRID_SIZE / 2
	var x_max = world_max.x + BaseGenerator.GRID_SIZE / 2
	var z_min = world_min.z - BaseGenerator.GRID_SIZE / 2
	var z_max = world_max.z + BaseGenerator.GRID_SIZE / 2
	var y = 0.0  # Floor level
	
	# Add vertices (counter-clockwise for proper normal)
	vertices.append_array([
		x_min, y, z_min,  # 0: bottom-left
		x_max, y, z_min,  # 1: bottom-right
		x_max, y, z_max,  # 2: top-right
		x_min, y, z_max   # 3: top-left
	])
	
	# Add indices for two triangles (counter-clockwise)
	indices.append_array([
		0, 1, 2,  # First triangle
		0, 2, 3   # Second triangle
	])
	
	# Add to source geometry
	source_geometry.add_faces(vertices, indices)

## Adds individual meshes for irregular floor groups
static func _add_individual_floor_meshes(source_geometry: NavigationMeshSourceGeometryData3D, floor_group: Array[CellData]) -> void:
	for cell in floor_group:
		_add_single_floor_cell_mesh(source_geometry, cell)

## Adds mesh for a single floor cell
static func _add_single_floor_cell_mesh(source_geometry: NavigationMeshSourceGeometryData3D, cell: CellData) -> void:
	var world_pos = BaseGenerator.grid_to_world(cell.position)
	var half_size = BaseGenerator.GRID_SIZE / 2
	
	# Create vertices for a single floor tile
	var vertices = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	var x_min = world_pos.x - half_size
	var x_max = world_pos.x + half_size
	var z_min = world_pos.z - half_size
	var z_max = world_pos.z + half_size
	var y = 0.0  # Floor level
	
	# Add vertices (counter-clockwise for proper normal)
	vertices.append_array([
		x_min, y, z_min,  # 0: bottom-left
		x_max, y, z_min,  # 1: bottom-right
		x_max, y, z_max,  # 2: top-right
		x_min, y, z_max   # 3: top-left
	])
	
	# Add indices for two triangles (counter-clockwise)
	indices.append_array([
		0, 1, 2,  # First triangle
		0, 2, 3   # Second triangle
	])
	
	# Add to source geometry
	source_geometry.add_faces(vertices, indices)

## Adds wall geometry as obstacles to prevent navigation through walls
static func _add_wall_geometry_to_source(source_geometry: NavigationMeshSourceGeometryData3D, wall_cells: Array[CellData]) -> void:
	for cell in wall_cells:
		_add_wall_obstacle_mesh(source_geometry, cell)

## Adds obstacle mesh for a single wall cell
static func _add_wall_obstacle_mesh(source_geometry: NavigationMeshSourceGeometryData3D, cell: CellData) -> void:
	var world_pos = BaseGenerator.grid_to_world(cell.position)
	var half_size = BaseGenerator.GRID_SIZE / 2
	var wall_height = 3.0  # Should match CollisionBuilder.WALL_HEIGHT
	
	# Create a box mesh for the wall obstacle
	var vertices = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	var x_min = world_pos.x - half_size
	var x_max = world_pos.x + half_size
	var z_min = world_pos.z - half_size
	var z_max = world_pos.z + half_size
	var y_min = 0.0
	var y_max = wall_height
	
	# Add vertices for a box (8 vertices)
	vertices.append_array([
		# Bottom face
		x_min, y_min, z_min,  # 0
		x_max, y_min, z_min,  # 1
		x_max, y_min, z_max,  # 2
		x_min, y_min, z_max,  # 3
		# Top face
		x_min, y_max, z_min,  # 4
		x_max, y_max, z_min,  # 5
		x_max, y_max, z_max,  # 6
		x_min, y_max, z_max   # 7
	])
	
	# Add indices for 12 triangles (6 faces * 2 triangles each)
	indices.append_array([
		# Bottom face (y_min)
		0, 2, 1, 0, 3, 2,
		# Top face (y_max)
		4, 5, 6, 4, 6, 7,
		# Front face (z_min)
		0, 1, 5, 0, 5, 4,
		# Back face (z_max)
		2, 3, 7, 2, 7, 6,
		# Left face (x_min)
		0, 4, 7, 0, 7, 3,
		# Right face (x_max)
		1, 2, 6, 1, 6, 5
	])
	
	# Add to source geometry as obstacle
	source_geometry.add_faces(vertices, indices)

## Tests that all rooms are reachable via navigation mesh
static func validate_navigation_connectivity(nav_region: NavigationRegion3D, layout: SceneLayout) -> bool:
	if not nav_region or not nav_region.navigation_mesh:
		push_error("Invalid navigation region for connectivity validation")
		return false
	
	var walkable_cells = layout.get_walkable_cells()
	if walkable_cells.size() < 2:
		return true  # Trivially connected if less than 2 walkable cells
	
	# Test pathfinding between random pairs of walkable cells
	var test_pairs = min(10, walkable_cells.size() / 2)  # Test up to 10 pairs
	var successful_paths = 0
	
	for i in range(test_pairs):
		var start_cell = walkable_cells[randi() % walkable_cells.size()]
		var end_cell = walkable_cells[randi() % walkable_cells.size()]
		
		if start_cell == end_cell:
			continue
		
		var start_pos = BaseGenerator.grid_to_world(start_cell.position)
		var end_pos = BaseGenerator.grid_to_world(end_cell.position)
		
		# Test if path exists using NavigationServer3D
		var path = NavigationServer3D.map_get_path(
			nav_region.get_navigation_map(),
			start_pos,
			end_pos,
			true  # optimize
		)
		
		if not path.is_empty():
			successful_paths += 1
		else:
			if OS.is_debug_build():
				print("No path found from %s to %s" % [start_cell.position, end_cell.position])
	
	var success_rate = float(successful_paths) / float(test_pairs) if test_pairs > 0 else 1.0
	
	if success_rate < 0.8:  # 80% success rate threshold
		push_error("Navigation connectivity validation failed: %.1f%% success rate" % (success_rate * 100))
		return false
	
	if OS.is_debug_build():
		print("Navigation connectivity validated: %.1f%% success rate (%d/%d paths)" % [success_rate * 100, successful_paths, test_pairs])
	
	return true

## Verifies navigation mesh doesn't extend through walls
static func validate_navigation_mesh_boundaries(nav_region: NavigationRegion3D, layout: SceneLayout) -> bool:
	if not nav_region or not nav_region.navigation_mesh:
		push_error("Invalid navigation region for boundary validation")
		return false
	
	var nav_mesh = nav_region.navigation_mesh
	var wall_cells = layout.get_cells_of_type("wall")
	
	# Get navigation mesh vertices
	var vertices = nav_mesh.get_vertices()
	if vertices.is_empty():
		push_warning("Navigation mesh has no vertices")
		return true
	
	# Check if any navigation mesh vertices are inside wall areas
	var violations = 0
	var max_violations = 5  # Allow some tolerance
	
	for vertex in vertices:
		var grid_pos = BaseGenerator.world_to_grid(vertex)
		
		# Check if this vertex is inside a wall cell
		for wall_cell in wall_cells:
			if wall_cell.position == grid_pos:
				violations += 1
				if OS.is_debug_build():
					print("Navigation mesh vertex at %s overlaps with wall at %s" % [vertex, wall_cell.position])
				break
	
	if violations > max_violations:
		push_error("Navigation mesh boundary validation failed: %d vertices overlap with walls" % violations)
		return false
	
	if OS.is_debug_build() and violations > 0:
		print("Navigation mesh boundary validation passed with %d minor violations" % violations)
	
	return true

## Adds debugging visualization for navigation mesh coverage
static func add_navigation_debug_visualization(parent: Node3D, nav_region: NavigationRegion3D) -> Node3D:
	if not nav_region or not nav_region.navigation_mesh:
		push_error("Invalid navigation region for debug visualization")
		return null
	
	var debug_parent = Node3D.new()
	debug_parent.name = "NavigationDebugVisualization"
	parent.add_child(debug_parent)
	
	# Create mesh instance for navigation mesh visualization
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "NavigationMeshVisualization"
	
	# Create a mesh from navigation mesh data
	var nav_mesh = nav_region.navigation_mesh
	var debug_mesh = _create_debug_mesh_from_navigation_mesh(nav_mesh)
	
	if debug_mesh:
		mesh_instance.mesh = debug_mesh
		
		# Create debug material
		var debug_material = StandardMaterial3D.new()
		debug_material.albedo_color = Color(0.0, 1.0, 0.0, 0.3)  # Semi-transparent green
		debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_material.no_depth_test = true
		debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		mesh_instance.material_override = debug_material
		debug_parent.add_child(mesh_instance)
	
	# Add navigation mesh boundary visualization
	_add_navigation_boundary_debug(debug_parent, nav_mesh)
	
	return debug_parent

## Creates a debug mesh from navigation mesh data
static func _create_debug_mesh_from_navigation_mesh(nav_mesh: NavigationMesh) -> ArrayMesh:
	var vertices = nav_mesh.get_vertices()
	if vertices.is_empty():
		return null
	
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Use vertices directly (already Vector3 array)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	# Create indices (assuming triangulated mesh)
	var index_array: PackedInt32Array = []
	for i in range(vertices.size()):
		index_array.append(i)
	
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

## Adds navigation boundary debug visualization
static func _add_navigation_boundary_debug(parent: Node3D, nav_mesh: NavigationMesh) -> void:
	# This could be expanded to show navigation mesh boundaries, agent radius, etc.
	# For now, we'll add a simple wireframe representation
	
	var boundary_node = Node3D.new()
	boundary_node.name = "NavigationBoundaries"
	parent.add_child(boundary_node)
	
	# Add debug info as metadata
	boundary_node.set_meta("agent_height", nav_mesh.agent_height)
	boundary_node.set_meta("agent_radius", nav_mesh.agent_radius)
	boundary_node.set_meta("cell_size", nav_mesh.cell_size)

## Creates a navigation region with custom parameters
static func create_custom_navigation_region(parent: Node3D, walkable_areas: Array[AABB], obstacles: Array[AABB] = []) -> NavigationRegion3D:
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "CustomNavigationRegion"
	
	var nav_mesh = NavigationMesh.new()
	_configure_navigation_mesh(nav_mesh)
	
	# Create source geometry from custom areas
	var source_geometry = NavigationMeshSourceGeometryData3D.new()
	
	# Add walkable areas
	for area in walkable_areas:
		_add_aabb_as_walkable_geometry(source_geometry, area)
	
	# Add obstacles
	for obstacle in obstacles:
		_add_aabb_as_obstacle_geometry(source_geometry, obstacle)
	
	# Bake the navigation mesh
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geometry)
	
	nav_region.navigation_mesh = nav_mesh
	parent.add_child(nav_region)
	
	return nav_region

## Adds an AABB as walkable geometry to source geometry data
static func _add_aabb_as_walkable_geometry(source_geometry: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	var vertices = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	# Create a flat surface at the bottom of the AABB
	var x_min = area.position.x
	var x_max = area.position.x + area.size.x
	var z_min = area.position.z
	var z_max = area.position.z + area.size.z
	var y = area.position.y
	
	# Add vertices (counter-clockwise for proper normal)
	vertices.append_array([
		x_min, y, z_min,  # 0: bottom-left
		x_max, y, z_min,  # 1: bottom-right
		x_max, y, z_max,  # 2: top-right
		x_min, y, z_max   # 3: top-left
	])
	
	# Add indices for two triangles (counter-clockwise)
	indices.append_array([
		0, 1, 2,  # First triangle
		0, 2, 3   # Second triangle
	])
	
	source_geometry.add_faces(vertices, indices)

## Adds an AABB as obstacle geometry to source geometry data
static func _add_aabb_as_obstacle_geometry(source_geometry: NavigationMeshSourceGeometryData3D, obstacle: AABB) -> void:
	var vertices = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	var x_min = obstacle.position.x
	var x_max = obstacle.position.x + obstacle.size.x
	var y_min = obstacle.position.y
	var y_max = obstacle.position.y + obstacle.size.y
	var z_min = obstacle.position.z
	var z_max = obstacle.position.z + obstacle.size.z
	
	# Add vertices for a box (8 vertices)
	vertices.append_array([
		# Bottom face
		x_min, y_min, z_min,  # 0
		x_max, y_min, z_min,  # 1
		x_max, y_min, z_max,  # 2
		x_min, y_min, z_max,  # 3
		# Top face
		x_min, y_max, z_min,  # 4
		x_max, y_max, z_min,  # 5
		x_max, y_max, z_max,  # 6
		x_min, y_max, z_max   # 7
	])
	
	# Add indices for 12 triangles (6 faces * 2 triangles each)
	indices.append_array([
		# Bottom face (y_min)
		0, 2, 1, 0, 3, 2,
		# Top face (y_max)
		4, 5, 6, 4, 6, 7,
		# Front face (z_min)
		0, 1, 5, 0, 5, 4,
		# Back face (z_max)
		2, 3, 7, 2, 7, 6,
		# Left face (x_min)
		0, 4, 7, 0, 7, 3,
		# Right face (x_max)
		1, 2, 6, 1, 6, 5
	])
	
	source_geometry.add_faces(vertices, indices)

## Optimizes navigation mesh for better performance
static func optimize_navigation_mesh(nav_mesh: NavigationMesh) -> void:
	# Adjust parameters for better performance vs quality trade-off
	nav_mesh.region_min_size = max(nav_mesh.region_min_size, 4.0)
	nav_mesh.region_merge_size = max(nav_mesh.region_merge_size, 40.0)
	nav_mesh.detail_sample_distance = max(nav_mesh.detail_sample_distance, 8.0)
	nav_mesh.detail_sample_max_error = min(nav_mesh.detail_sample_max_error, 2.0)

## Gets navigation mesh statistics for debugging
static func get_navigation_mesh_stats(nav_mesh: NavigationMesh) -> Dictionary:
	var stats = {}
	
	if not nav_mesh:
		return stats
	
	var vertices = nav_mesh.get_vertices()
	stats["vertex_count"] = vertices.size() / 3  # 3 floats per vertex
	stats["triangle_count"] = vertices.size() / 9  # 9 floats per triangle (3 vertices * 3 floats)
	
	stats["agent_height"] = nav_mesh.agent_height
	stats["agent_radius"] = nav_mesh.agent_radius
	stats["cell_size"] = nav_mesh.cell_size
	stats["region_min_size"] = nav_mesh.region_min_size
	
	return stats

## Prints navigation mesh statistics for debugging
static func print_navigation_mesh_stats(nav_mesh: NavigationMesh) -> void:
	var stats = get_navigation_mesh_stats(nav_mesh)
	
	print("=== Navigation Mesh Statistics ===")
	print("Vertices: %d" % stats.get("vertex_count", 0))
	print("Triangles: %d" % stats.get("triangle_count", 0))
	print("Agent Height: %.1f" % stats.get("agent_height", 0))
	print("Agent Radius: %.1f" % stats.get("agent_radius", 0))
	print("Cell Size: %.2f" % stats.get("cell_size", 0))
	print("Region Min Size: %.1f" % stats.get("region_min_size", 0))