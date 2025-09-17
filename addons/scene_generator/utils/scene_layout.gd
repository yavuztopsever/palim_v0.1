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
	
	return is_valid

func check_connectivity() -> bool:
	# Simple connectivity check - ensure all walkable cells are reachable
	var walkable_cells = get_walkable_cells()
	if walkable_cells.is_empty():
		return true  # No walkable cells, trivially connected
	
	# Use flood fill from first walkable cell
	var visited: Dictionary = {}
	var start_cell = walkable_cells[0]
	_flood_fill_walkable(start_cell.position, visited)
	
	# Check if all walkable cells were visited
	for cell in walkable_cells:
		if not cell.position in visited:
			push_warning("Unreachable walkable cell at %s" % cell.position)
			return false
	
	return true

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

func to_string() -> String:
	return "SceneLayout(%s, %d cells, %d connections)" % [grid_size, cells.size(), connections.size()]