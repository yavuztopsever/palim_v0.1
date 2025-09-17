class_name SceneLayout
extends Resource

## Represents the complete layout of a generated scene
## Contains grid of cells and connection data before instantiation

@export var grid_size: Vector2i
@export var cells: Array[CellData] = []
@export var connections: Array[ConnectionData] = []

# Internal grid for fast lookups
var _cell_grid: Array[Array] = []

func _init(size: Vector2i = Vector2i(10, 10)):
	grid_size = size
	_initialize_grid()

func _initialize_grid() -> void:
	_cell_grid.clear()
	_cell_grid.resize(grid_size.x)
	
	for x in range(grid_size.x):
		_cell_grid[x] = []
		_cell_grid[x].resize(grid_size.y)
		
		for y in range(grid_size.y):
			_cell_grid[x][y] = null

func set_cell(pos: Vector2i, cell: CellData) -> void:
	if not is_valid_position(pos):
		push_error("Invalid position: %s for grid size %s" % [pos, grid_size])
		return
	
	# Remove existing cell at this position if any
	remove_cell(pos)
	
	# Set the cell position to match
	cell.position = pos
	
	# Add to arrays
	cells.append(cell)
	_cell_grid[pos.x][pos.y] = cell

func get_cell(pos: Vector2i) -> CellData:
	if not is_valid_position(pos):
		return null
	
	return _cell_grid[pos.x][pos.y]

func get_cell_at(pos: Vector2i) -> CellData:
	return get_cell(pos)

func remove_cell(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	
	var existing_cell = _cell_grid[pos.x][pos.y]
	if existing_cell:
		cells.erase(existing_cell)
		_cell_grid[pos.x][pos.y] = null
		return true
	
	return false

func has_cell(pos: Vector2i) -> bool:
	return get_cell(pos) != null

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func get_cells_of_type(cell_type: String) -> Array[CellData]:
	var result: Array[CellData] = []
	
	for cell in cells:
		if cell.cell_type == cell_type:
			result.append(cell)
	
	return result

func get_neighbors(pos: Vector2i, include_diagonals: bool = false) -> Array[CellData]:
	var neighbors: Array[CellData] = []
	var directions: Array[Vector2i] = []
	
	# Cardinal directions
	directions.append_array([
		Vector2i(0, 1),   # North
		Vector2i(1, 0),   # East
		Vector2i(0, -1),  # South
		Vector2i(-1, 0)   # West
	])
	
	# Diagonal directions
	if include_diagonals:
		directions.append_array([
			Vector2i(1, 1),   # Northeast
			Vector2i(1, -1),  # Southeast
			Vector2i(-1, -1), # Southwest
			Vector2i(-1, 1)   # Northwest
		])
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = get_cell(neighbor_pos)
		if neighbor_cell:
			neighbors.append(neighbor_cell)
	
	return neighbors

func get_empty_positions() -> Array[Vector2i]:
	var empty_positions: Array[Vector2i] = []
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if not has_cell(pos):
				empty_positions.append(pos)
	
	return empty_positions

func add_connection(connection: ConnectionData) -> void:
	connections.append(connection)

func get_connections_from(pos: Vector2i) -> Array[ConnectionData]:
	var result: Array[ConnectionData] = []
	
	for connection in connections:
		if connection.from_position == pos:
			result.append(connection)
	
	return result

func validate_layout() -> bool:
	var is_valid = true
	
	# Validate grid size
	if grid_size.x <= 0 or grid_size.y <= 0:
		push_error("Invalid grid size: %s" % grid_size)
		is_valid = false
	
	# Validate all cells
	for cell in cells:
		if not cell.validate():
			is_valid = false
		
		if not is_valid_position(cell.position):
			push_error("Cell at invalid position: %s" % cell.position)
			is_valid = false
	
	# Validate connections
	for connection in connections:
		if not connection.validate():
			is_valid = false
		
		if not is_valid_position(connection.from_position) or not is_valid_position(connection.to_position):
			push_error("Connection with invalid positions: %s -> %s" % [connection.from_position, connection.to_position])
			is_valid = false
	
	# Validate layout fits within size constraints
	if not _validate_size_constraints():
		is_valid = false
	
	# Validate no isolated areas exist
	if not _validate_no_isolated_areas():
		is_valid = false
	
	return is_valid

## Validates that the layout fits within specified size constraints
func _validate_size_constraints() -> bool:
	var is_valid = true
	
	# Check that all cells are within bounds
	for cell in cells:
		if cell.position.x < 0 or cell.position.x >= grid_size.x or cell.position.y < 0 or cell.position.y >= grid_size.y:
			push_error("Cell at %s is outside grid bounds %s" % [cell.position, grid_size])
			is_valid = false
	
	# Check for reasonable distribution of space
	var floor_cells = get_cells_of_type("floor")
	var total_cells = grid_size.x * grid_size.y
	var floor_ratio = float(floor_cells.size()) / float(total_cells)
	
	# Warn if layout seems unreasonable (too sparse or too dense)
	if floor_ratio < 0.1:
		push_warning("Layout seems very sparse (%.1f%% floor coverage)" % (floor_ratio * 100))
	elif floor_ratio > 0.9:
		push_warning("Layout seems very dense (%.1f%% floor coverage)" % (floor_ratio * 100))
	
	return is_valid

## Validates that no isolated areas exist (all walkable areas are connected)
func _validate_no_isolated_areas() -> bool:
	var walkable_cells = get_walkable_cells()
	if walkable_cells.is_empty():
		return true  # No walkable cells, trivially valid
	
	# Group walkable cells into connected components
	var connected_components = _find_connected_components()
	
	if connected_components.size() > 1:
		push_error("Layout has %d isolated areas. All walkable areas should be connected." % connected_components.size())
		
		# Log details about isolated areas
		for i in range(connected_components.size()):
			var component = connected_components[i]
			push_error("Isolated area %d: %d cells starting at %s" % [i + 1, component.size(), component[0]])
		
		return false
	
	return true

## Finds all connected components of walkable cells
func _find_connected_components() -> Array[Array]:
	var walkable_cells = get_walkable_cells()
	var visited: Dictionary = {}
	var components: Array[Array] = []
	
	for cell in walkable_cells:
		if not cell.position in visited:
			var component: Array[Vector2i] = []
			_flood_fill_component(cell.position, visited, component)
			if not component.is_empty():
				components.append(component)
	
	return components

## Flood fill to find connected component starting from a position
func _flood_fill_component(pos: Vector2i, visited: Dictionary, component: Array[Vector2i]) -> void:
	if pos in visited or not is_valid_position(pos):
		return
	
	var cell = get_cell(pos)
	if not cell or not cell.is_walkable():
		return
	
	visited[pos] = true
	component.append(pos)
	
	# Recursively visit neighbors
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		_flood_fill_component(pos + direction, visited, component)

func check_connectivity() -> bool:
	# Comprehensive connectivity check - ensure all walkable cells are reachable
	var walkable_cells = get_walkable_cells()
	if walkable_cells.is_empty():
		return true  # No walkable cells, trivially connected
	
	# Use flood fill from first walkable cell
	var visited: Dictionary = {}
	var start_cell = walkable_cells[0]
	_flood_fill_walkable(start_cell.position, visited)
	
	# Check if all walkable cells were visited
	var unreachable_cells: Array[Vector2i] = []
	for cell in walkable_cells:
		if not cell.position in visited:
			unreachable_cells.append(cell.position)
	
	if not unreachable_cells.is_empty():
		push_error("Found %d unreachable walkable cells" % unreachable_cells.size())
		for pos in unreachable_cells:
			push_error("Unreachable cell at %s" % pos)
		return false
	
	# Additional connectivity checks
	return _validate_room_accessibility() and _validate_connection_integrity()

## Validates that all rooms are accessible via corridors or doors
func _validate_room_accessibility() -> bool:
	var room_areas = _identify_room_areas()
	if room_areas.size() <= 1:
		return true  # Single room or no rooms, trivially accessible
	
	# Check that each room area is connected to at least one other
	for i in range(room_areas.size()):
		var room = room_areas[i]
		var has_connection = false
		
		# Check if this room connects to any other room
		for j in range(room_areas.size()):
			if i != j:
				var other_room = room_areas[j]
				if _rooms_are_connected(room, other_room):
					has_connection = true
					break
		
		if not has_connection:
			push_error("Room area starting at %s is not connected to other rooms" % room[0])
			return false
	
	return true

## Validates the integrity of explicit connections
func _validate_connection_integrity() -> bool:
	var is_valid = true
	
	for connection in connections:
		# Check that connection endpoints are walkable
		var from_cell = get_cell(connection.from_position)
		var to_cell = get_cell(connection.to_position)
		
		if not from_cell or not from_cell.is_walkable():
			push_error("Connection from non-walkable cell at %s" % connection.from_position)
			is_valid = false
		
		if not to_cell or not to_cell.is_walkable():
			push_error("Connection to non-walkable cell at %s" % connection.to_position)
			is_valid = false
		
		# Check that connection is reasonable (not too long)
		var distance = connection.get_distance()
		if distance > 10:  # Arbitrary reasonable limit
			push_warning("Very long connection (%.1f units) from %s to %s" % [distance, connection.from_position, connection.to_position])
	
	return is_valid

## Identifies distinct room areas (connected floor regions)
func _identify_room_areas() -> Array[Array]:
	var floor_cells = get_cells_of_type("floor")
	var visited: Dictionary = {}
	var room_areas: Array[Array] = []
	
	for cell in floor_cells:
		if not cell.position in visited:
			var room_area: Array[Vector2i] = []
			_flood_fill_room_area(cell.position, visited, room_area)
			if room_area.size() >= 4:  # Minimum size to be considered a room
				room_areas.append(room_area)
	
	return room_areas

## Flood fill to identify a room area
func _flood_fill_room_area(pos: Vector2i, visited: Dictionary, room_area: Array[Vector2i]) -> void:
	if pos in visited or not is_valid_position(pos):
		return
	
	var cell = get_cell(pos)
	if not cell or cell.cell_type != "floor":
		return
	
	visited[pos] = true
	room_area.append(pos)
	
	# Only expand to adjacent floor cells (not through doors/corridors)
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "floor":
			_flood_fill_room_area(neighbor_pos, visited, room_area)

## Checks if two room areas are connected via corridors or doors
func _rooms_are_connected(room1: Array[Vector2i], room2: Array[Vector2i]) -> bool:
	# Check if there's a path between any cell in room1 and any cell in room2
	# This is a simplified check - in practice, we'd use pathfinding
	
	# For now, check if rooms are adjacent or connected via explicit connections
	for pos1 in room1:
		for pos2 in room2:
			# Check if rooms are adjacent
			var diff = pos2 - pos1
			if abs(diff.x) + abs(diff.y) == 1:  # Manhattan distance of 1
				return true
			
			# Check if there's an explicit connection
			for connection in connections:
				if (connection.from_position == pos1 and connection.to_position == pos2) or (connection.from_position == pos2 and connection.to_position == pos1):
					return true
	
	return false

func get_walkable_cells() -> Array[CellData]:
	var walkable: Array[CellData] = []
	
	for cell in cells:
		if cell.is_walkable():
			walkable.append(cell)
	
	return walkable

func _flood_fill_walkable(pos: Vector2i, visited: Dictionary) -> void:
	if pos in visited or not is_valid_position(pos):
		return
	
	var cell = get_cell(pos)
	if not cell or not cell.is_walkable():
		return
	
	visited[pos] = true
	
	# Recursively visit neighbors
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		_flood_fill_walkable(pos + direction, visited)

func clear() -> void:
	cells.clear()
	connections.clear()
	_initialize_grid()

func get_bounds() -> AABB:
	return AABB(Vector3.ZERO, Vector3(grid_size.x * 2.0, 0, grid_size.y * 2.0))

## Ensures all rooms are accessible by adding connections where needed
func ensure_connectivity() -> bool:
	var room_areas = _identify_room_areas()
	if room_areas.size() <= 1:
		return true  # Already connected or no rooms to connect
	
	# Find disconnected room pairs and add connections
	var connected_rooms: Array[int] = [0]  # Start with first room as connected
	var unconnected_rooms: Array[int] = []
	
	for i in range(1, room_areas.size()):
		unconnected_rooms.append(i)
	
	# Connect each unconnected room to the connected group
	while not unconnected_rooms.is_empty():
		var best_connection = _find_best_room_connection(room_areas, connected_rooms, unconnected_rooms)
		
		if best_connection.is_empty():
			push_error("Could not find connection between room areas")
			return false
		
		# Add connection
		var connection = ConnectionData.new(best_connection[0], best_connection[1], "corridor")
		add_connection(connection)
		
		# Move room from unconnected to connected
		var room_index = best_connection[2]
		connected_rooms.append(room_index)
		unconnected_rooms.erase(room_index)
	
	return true

## Finds the best connection between connected and unconnected room groups
func _find_best_room_connection(room_areas: Array[Array], connected_rooms: Array[int], unconnected_rooms: Array[int]) -> Array:
	var best_connection: Array = []
	var best_distance = INF
	
	for connected_idx in connected_rooms:
		var connected_room = room_areas[connected_idx]
		
		for unconnected_idx in unconnected_rooms:
			var unconnected_room = room_areas[unconnected_idx]
			
			# Find closest points between these rooms
			for pos1 in connected_room:
				for pos2 in unconnected_room:
					var distance = (pos2 - pos1).length()
					if distance < best_distance:
						best_distance = distance
						best_connection = [pos1, pos2, unconnected_idx]
	
	return best_connection

## Gets layout statistics for debugging and validation
func get_layout_stats() -> Dictionary:
	var stats = {}
	
	# Basic counts
	stats["total_cells"] = cells.size()
	stats["grid_size"] = grid_size
	stats["connections"] = connections.size()
	
	# Cell type breakdown
	var cell_types = {}
	for cell in cells:
		if cell.cell_type in cell_types:
			cell_types[cell.cell_type] += 1
		else:
			cell_types[cell.cell_type] = 1
	stats["cell_types"] = cell_types
	
	# Connectivity stats
	var walkable_cells = get_walkable_cells()
	stats["walkable_cells"] = walkable_cells.size()
	
	var room_areas = _identify_room_areas()
	stats["room_areas"] = room_areas.size()
	
	var connected_components = _find_connected_components()
	stats["connected_components"] = connected_components.size()
	
	# Coverage stats
	var total_grid_cells = grid_size.x * grid_size.y
	stats["coverage_percent"] = (float(cells.size()) / float(total_grid_cells)) * 100.0
	
	return stats

## Prints layout statistics for debugging
func print_layout_stats() -> void:
	var stats = get_layout_stats()
	print("=== Layout Statistics ===")
	print("Grid Size: %s" % stats["grid_size"])
	print("Total Cells: %d" % stats["total_cells"])
	print("Coverage: %.1f%%" % stats["coverage_percent"])
	print("Walkable Cells: %d" % stats["walkable_cells"])
	print("Room Areas: %d" % stats["room_areas"])
	print("Connected Components: %d" % stats["connected_components"])
	print("Connections: %d" % stats["connections"])
	
	print("Cell Types:")
	var cell_types = stats["cell_types"]
	for cell_type in cell_types:
		print("  %s: %d" % [cell_type, cell_types[cell_type]])

func to_string() -> String:
	return "SceneLayout(%s, %d cells, %d connections)" % [grid_size, cells.size(), connections.size()]