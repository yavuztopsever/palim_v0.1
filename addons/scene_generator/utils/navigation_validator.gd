class_name NavigationValidator
extends RefCounted

## Utility class for validating navigation mesh connectivity and coverage
## Provides comprehensive testing and debugging visualization for navigation systems

# Validation constants
const MIN_SUCCESS_RATE: float = 0.8  # 80% pathfinding success rate required
const MAX_WALL_VIOLATIONS: int = 5   # Maximum allowed navigation mesh vertices in walls
const MIN_COVERAGE_RATIO: float = 0.7  # Minimum ratio of walkable cells covered by navmesh
const MAX_TEST_PAIRS: int = 20       # Maximum number of pathfinding tests to perform

## Comprehensive validation of navigation mesh for a layout
static func validate_navigation_system(nav_region: NavigationRegion3D, layout: SceneLayout) -> Dictionary:
	var results = {
		"overall_valid": true,
		"connectivity_valid": false,
		"boundary_valid": false,
		"coverage_valid": false,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	if not nav_region or not nav_region.navigation_mesh:
		results.errors.append("Invalid navigation region or missing navigation mesh")
		results.overall_valid = false
		return results
	
	if not layout or not layout.validate_layout():
		results.errors.append("Invalid layout provided for validation")
		results.overall_valid = false
		return results
	
	# Test connectivity
	var connectivity_result = test_navigation_connectivity(nav_region, layout)
	results.connectivity_valid = connectivity_result.valid
	if not connectivity_result.valid:
		results.errors.append_array(connectivity_result.errors)
	results.warnings.append_array(connectivity_result.warnings)
	results.stats["connectivity"] = connectivity_result.stats
	
	# Test boundaries
	var boundary_result = test_navigation_boundaries(nav_region, layout)
	results.boundary_valid = boundary_result.valid
	if not boundary_result.valid:
		results.errors.append_array(boundary_result.errors)
	results.warnings.append_array(boundary_result.warnings)
	results.stats["boundaries"] = boundary_result.stats
	
	# Test coverage
	var coverage_result = test_navigation_coverage(nav_region, layout)
	results.coverage_valid = coverage_result.valid
	if not coverage_result.valid:
		results.errors.append_array(coverage_result.errors)
	results.warnings.append_array(coverage_result.warnings)
	results.stats["coverage"] = coverage_result.stats
	
	# Overall validation
	results.overall_valid = results.connectivity_valid and results.boundary_valid and results.coverage_valid
	
	return results

## Tests that all rooms are reachable via navigation mesh
static func test_navigation_connectivity(nav_region: NavigationRegion3D, layout: SceneLayout) -> Dictionary:
	var result = {
		"valid": false,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	var walkable_cells = layout.get_walkable_cells()
	if walkable_cells.size() < 2:
		result.valid = true
		result.stats["walkable_cells"] = walkable_cells.size()
		result.warnings.append("Less than 2 walkable cells - connectivity trivially valid")
		return result
	
	# Test pathfinding between random pairs of walkable cells
	var test_pairs = min(MAX_TEST_PAIRS, walkable_cells.size() / 2)
	var successful_paths = 0
	var failed_paths = []
	
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
			failed_paths.append([start_cell.position, end_cell.position])
	
	var success_rate = float(successful_paths) / float(test_pairs) if test_pairs > 0 else 1.0
	
	result.stats["test_pairs"] = test_pairs
	result.stats["successful_paths"] = successful_paths
	result.stats["success_rate"] = success_rate
	result.stats["failed_paths"] = failed_paths.size()
	
	if success_rate < MIN_SUCCESS_RATE:
		result.errors.append("Navigation connectivity failed: %.1f%% success rate (minimum %.1f%% required)" % [success_rate * 100, MIN_SUCCESS_RATE * 100])
		
		# Add details about failed paths
		for failed_path in failed_paths.slice(0, 5):  # Show first 5 failures
			result.errors.append("No path found from %s to %s" % [failed_path[0], failed_path[1]])
		
		if failed_paths.size() > 5:
			result.errors.append("... and %d more failed paths" % (failed_paths.size() - 5))
	else:
		result.valid = true
		if success_rate < 1.0:
			result.warnings.append("Navigation connectivity passed with %.1f%% success rate" % (success_rate * 100))
	
	return result

## Tests that navigation mesh doesn't extend through walls
static func test_navigation_boundaries(nav_region: NavigationRegion3D, layout: SceneLayout) -> Dictionary:
	var result = {
		"valid": false,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	var nav_mesh = nav_region.navigation_mesh
	var wall_cells = layout.get_cells_of_type("wall")
	
	# Get navigation mesh vertices
	var vertices = nav_mesh.get_vertices()
	if vertices.is_empty():
		result.warnings.append("Navigation mesh has no vertices")
		result.valid = true
		result.stats["vertices"] = 0
		result.stats["wall_violations"] = 0
		return result
	
	# Check if any navigation mesh vertices are inside wall areas
	var violations = 0
	var violation_details = []
	
	for vertex in vertices:
		var grid_pos = BaseGenerator.world_to_grid(vertex)
		
		# Check if this vertex is inside a wall cell
		for wall_cell in wall_cells:
			if wall_cell.position == grid_pos:
				violations += 1
				violation_details.append({
					"vertex": vertex,
					"wall_position": wall_cell.position
				})
				break
	
	result.stats["vertices"] = vertices.size() / 3
	result.stats["wall_cells"] = wall_cells.size()
	result.stats["wall_violations"] = violations
	
	if violations > MAX_WALL_VIOLATIONS:
		result.errors.append("Navigation mesh boundary validation failed: %d vertices overlap with walls (maximum %d allowed)" % [violations, MAX_WALL_VIOLATIONS])
		
		# Add details about violations
		for detail in violation_details.slice(0, 3):  # Show first 3 violations
			result.errors.append("Navigation vertex at %s overlaps with wall at %s" % [detail.vertex, detail.wall_position])
		
		if violation_details.size() > 3:
			result.errors.append("... and %d more violations" % (violation_details.size() - 3))
	else:
		result.valid = true
		if violations > 0:
			result.warnings.append("Navigation mesh boundary validation passed with %d minor violations" % violations)
	
	return result

## Tests navigation mesh coverage of walkable areas
static func test_navigation_coverage(nav_region: NavigationRegion3D, layout: SceneLayout) -> Dictionary:
	var result = {
		"valid": false,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	var walkable_cells = layout.get_walkable_cells()
	if walkable_cells.is_empty():
		result.valid = true
		result.warnings.append("No walkable cells to test coverage")
		result.stats["walkable_cells"] = 0
		result.stats["covered_cells"] = 0
		result.stats["coverage_ratio"] = 1.0
		return result
	
	# Test how many walkable cells are covered by the navigation mesh
	var covered_cells = 0
	var uncovered_positions = []
	
	for cell in walkable_cells:
		var world_pos = BaseGenerator.grid_to_world(cell.position)
		
		# Check if this position is on the navigation mesh
		var closest_point = NavigationServer3D.map_get_closest_point(
			nav_region.get_navigation_map(),
			world_pos
		)
		
		# If the closest point is reasonably close, consider it covered
		var distance = world_pos.distance_to(closest_point)
		if distance <= BaseGenerator.GRID_SIZE:  # Within one grid cell
			covered_cells += 1
		else:
			uncovered_positions.append(cell.position)
	
	var coverage_ratio = float(covered_cells) / float(walkable_cells.size())
	
	result.stats["walkable_cells"] = walkable_cells.size()
	result.stats["covered_cells"] = covered_cells
	result.stats["uncovered_cells"] = uncovered_positions.size()
	result.stats["coverage_ratio"] = coverage_ratio
	
	if coverage_ratio < MIN_COVERAGE_RATIO:
		result.errors.append("Navigation mesh coverage insufficient: %.1f%% coverage (minimum %.1f%% required)" % [coverage_ratio * 100, MIN_COVERAGE_RATIO * 100])
		
		# Add details about uncovered areas
		for pos in uncovered_positions.slice(0, 5):  # Show first 5 uncovered positions
			result.errors.append("Walkable cell at %s not covered by navigation mesh" % pos)
		
		if uncovered_positions.size() > 5:
			result.errors.append("... and %d more uncovered positions" % (uncovered_positions.size() - 5))
	else:
		result.valid = true
		if coverage_ratio < 1.0:
			result.warnings.append("Navigation mesh coverage: %.1f%%" % (coverage_ratio * 100))
	
	return result

## Tests navigation between specific room areas
static func test_room_connectivity(nav_region: NavigationRegion3D, layout: SceneLayout) -> Dictionary:
	var result = {
		"valid": false,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	# Identify room areas
	var room_areas = _identify_room_areas(layout)
	
	if room_areas.size() <= 1:
		result.valid = true
		result.warnings.append("Single room or no rooms - room connectivity trivially valid")
		result.stats["room_count"] = room_areas.size()
		return result
	
	# Test connectivity between all room pairs
	var connected_pairs = 0
	var total_pairs = 0
	var disconnected_pairs = []
	
	for i in range(room_areas.size()):
		for j in range(i + 1, room_areas.size()):
			total_pairs += 1
			
			var room1 = room_areas[i]
			var room2 = room_areas[j]
			
			# Test path between room centers
			var room1_center = _get_room_center(room1)
			var room2_center = _get_room_center(room2)
			
			var path = NavigationServer3D.map_get_path(
				nav_region.get_navigation_map(),
				room1_center,
				room2_center,
				true
			)
			
			if not path.is_empty():
				connected_pairs += 1
			else:
				disconnected_pairs.append([i, j])
	
	var connectivity_ratio = float(connected_pairs) / float(total_pairs) if total_pairs > 0 else 1.0
	
	result.stats["room_count"] = room_areas.size()
	result.stats["total_pairs"] = total_pairs
	result.stats["connected_pairs"] = connected_pairs
	result.stats["connectivity_ratio"] = connectivity_ratio
	
	if connectivity_ratio < 1.0:
		result.errors.append("Room connectivity failed: %d/%d room pairs connected" % [connected_pairs, total_pairs])
		
		for pair in disconnected_pairs.slice(0, 3):  # Show first 3 disconnected pairs
			result.errors.append("No path between room %d and room %d" % [pair[0], pair[1]])
		
		if disconnected_pairs.size() > 3:
			result.errors.append("... and %d more disconnected room pairs" % (disconnected_pairs.size() - 3))
	else:
		result.valid = true
	
	return result

## Identifies distinct room areas from layout
static func _identify_room_areas(layout: SceneLayout) -> Array[Array]:
	var floor_cells = layout.get_cells_of_type("floor")
	var visited: Dictionary = {}
	var room_areas: Array[Array] = []
	
	for cell in floor_cells:
		if not cell.position in visited:
			var room_area: Array[Vector2i] = []
			_flood_fill_room_area(cell.position, layout, visited, room_area)
			if room_area.size() >= 4:  # Minimum size to be considered a room
				room_areas.append(room_area)
	
	return room_areas

## Flood fill to identify a room area
static func _flood_fill_room_area(pos: Vector2i, layout: SceneLayout, visited: Dictionary, room_area: Array[Vector2i]) -> void:
	if pos in visited or not layout.is_valid_position(pos):
		return
	
	var cell = layout.get_cell(pos)
	if not cell or cell.cell_type != "floor":
		return
	
	visited[pos] = true
	room_area.append(pos)
	
	# Only expand to adjacent floor cells
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "floor":
			_flood_fill_room_area(neighbor_pos, layout, visited, room_area)

## Gets the center position of a room area
static func _get_room_center(room_area: Array[Vector2i]) -> Vector3:
	if room_area.is_empty():
		return Vector3.ZERO
	
	var sum = Vector2i.ZERO
	for pos in room_area:
		sum += pos
	
	var center_grid = Vector2i(sum.x / room_area.size(), sum.y / room_area.size())
	return BaseGenerator.grid_to_world(center_grid)

## Creates comprehensive debug visualization for navigation validation
static func create_validation_debug_visualization(parent: Node3D, nav_region: NavigationRegion3D, layout: SceneLayout, validation_results: Dictionary) -> Node3D:
	var debug_parent = Node3D.new()
	debug_parent.name = "NavigationValidationDebug"
	parent.add_child(debug_parent)
	
	# Add navigation mesh visualization
	_add_navigation_mesh_debug(debug_parent, nav_region)
	
	# Add connectivity debug visualization
	if "connectivity" in validation_results.stats:
		_add_connectivity_debug(debug_parent, nav_region, layout, validation_results.stats.connectivity)
	
	# Add boundary violation debug visualization
	if "boundaries" in validation_results.stats:
		_add_boundary_debug(debug_parent, nav_region, layout, validation_results.stats.boundaries)
	
	# Add coverage debug visualization
	if "coverage" in validation_results.stats:
		_add_coverage_debug(debug_parent, nav_region, layout, validation_results.stats.coverage)
	
	return debug_parent

## Adds navigation mesh debug visualization
static func _add_navigation_mesh_debug(parent: Node3D, nav_region: NavigationRegion3D) -> void:
	var nav_debug = NavigationBuilder.add_navigation_debug_visualization(parent, nav_region)
	if nav_debug:
		nav_debug.name = "NavigationMeshDebug"

## Adds connectivity debug visualization
static func _add_connectivity_debug(parent: Node3D, nav_region: NavigationRegion3D, layout: SceneLayout, connectivity_stats: Dictionary) -> void:
	var connectivity_parent = Node3D.new()
	connectivity_parent.name = "ConnectivityDebug"
	parent.add_child(connectivity_parent)
	
	# Visualize failed paths if any
	if "failed_paths" in connectivity_stats and connectivity_stats.failed_paths > 0:
		# This could be expanded to show actual failed path attempts
		connectivity_parent.set_meta("failed_paths", connectivity_stats.failed_paths)
		connectivity_parent.set_meta("success_rate", connectivity_stats.get("success_rate", 0.0))

## Adds boundary violation debug visualization
static func _add_boundary_debug(parent: Node3D, nav_region: NavigationRegion3D, layout: SceneLayout, boundary_stats: Dictionary) -> void:
	var boundary_parent = Node3D.new()
	boundary_parent.name = "BoundaryDebug"
	parent.add_child(boundary_parent)
	
	# Store violation count as metadata
	boundary_parent.set_meta("wall_violations", boundary_stats.get("wall_violations", 0))
	
	# Could add visual markers for violation points
	if boundary_stats.get("wall_violations", 0) > 0:
		# Add warning indicator
		var warning_node = Node3D.new()
		warning_node.name = "BoundaryViolationWarning"
		boundary_parent.add_child(warning_node)

## Adds coverage debug visualization
static func _add_coverage_debug(parent: Node3D, nav_region: NavigationRegion3D, layout: SceneLayout, coverage_stats: Dictionary) -> void:
	var coverage_parent = Node3D.new()
	coverage_parent.name = "CoverageDebug"
	parent.add_child(coverage_parent)
	
	# Store coverage statistics as metadata
	coverage_parent.set_meta("coverage_ratio", coverage_stats.get("coverage_ratio", 0.0))
	coverage_parent.set_meta("uncovered_cells", coverage_stats.get("uncovered_cells", 0))
	
	# Could add visual markers for uncovered areas
	var coverage_ratio = coverage_stats.get("coverage_ratio", 0.0)
	if coverage_ratio < 1.0:
		var coverage_indicator = Node3D.new()
		coverage_indicator.name = "CoverageIndicator"
		coverage_parent.add_child(coverage_indicator)

## Prints comprehensive validation results
static func print_validation_results(validation_results: Dictionary) -> void:
	print("=== Navigation Validation Results ===")
	print("Overall Valid: %s" % ("PASS" if validation_results.overall_valid else "FAIL"))
	print("Connectivity: %s" % ("PASS" if validation_results.connectivity_valid else "FAIL"))
	print("Boundaries: %s" % ("PASS" if validation_results.boundary_valid else "FAIL"))
	print("Coverage: %s" % ("PASS" if validation_results.coverage_valid else "FAIL"))
	
	if not validation_results.errors.is_empty():
		print("\nErrors:")
		for error in validation_results.errors:
			print("  - %s" % error)
	
	if not validation_results.warnings.is_empty():
		print("\nWarnings:")
		for warning in validation_results.warnings:
			print("  - %s" % warning)
	
	if "stats" in validation_results:
		print("\nStatistics:")
		var stats = validation_results.stats
		
		if "connectivity" in stats:
			var conn_stats = stats.connectivity
			print("  Connectivity: %.1f%% success rate (%d/%d paths)" % [
				conn_stats.get("success_rate", 0.0) * 100,
				conn_stats.get("successful_paths", 0),
				conn_stats.get("test_pairs", 0)
			])
		
		if "boundaries" in stats:
			var bound_stats = stats.boundaries
			print("  Boundaries: %d violations out of %d vertices" % [
				bound_stats.get("wall_violations", 0),
				bound_stats.get("vertices", 0)
			])
		
		if "coverage" in stats:
			var cov_stats = stats.coverage
			print("  Coverage: %.1f%% (%d/%d walkable cells)" % [
				cov_stats.get("coverage_ratio", 0.0) * 100,
				cov_stats.get("covered_cells", 0),
				cov_stats.get("walkable_cells", 0)
			])

## Quick validation check for basic navigation functionality
static func quick_validation_check(nav_region: NavigationRegion3D, layout: SceneLayout) -> bool:
	if not nav_region or not nav_region.navigation_mesh:
		return false
	
	if not layout or not layout.validate_layout():
		return false
	
	var walkable_cells = layout.get_walkable_cells()
	if walkable_cells.size() < 2:
		return true  # Trivially valid
	
	# Test a few random paths
	var test_count = min(5, walkable_cells.size() / 2)
	var successful_paths = 0
	
	for i in range(test_count):
		var start_cell = walkable_cells[randi() % walkable_cells.size()]
		var end_cell = walkable_cells[randi() % walkable_cells.size()]
		
		if start_cell == end_cell:
			continue
		
		var start_pos = BaseGenerator.grid_to_world(start_cell.position)
		var end_pos = BaseGenerator.grid_to_world(end_cell.position)
		
		var path = NavigationServer3D.map_get_path(
			nav_region.get_navigation_map(),
			start_pos,
			end_pos,
			true
		)
		
		if not path.is_empty():
			successful_paths += 1
	
	var success_rate = float(successful_paths) / float(test_count) if test_count > 0 else 1.0
	return success_rate >= 0.6  # Lower threshold for quick check