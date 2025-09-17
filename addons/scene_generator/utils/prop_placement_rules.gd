class_name PropPlacementRules
extends Resource

## Prop placement rules system for scene generation
## Defines furniture sets for different area types
## Implements logic to avoid overcrowding spaces with too many props
## Ensures props are placed against walls or in logical positions

# Prop placement rules by area type
const PROP_RULES = {
	"residential": {
		"max_props_per_room": 8,
		"density_factor": 0.6,
		"preferred_locations": ["corner", "wall", "center"],
		"avoid_locations": ["doorway", "window"],
		"prop_categories": {
			"furniture": {
				"weight": 0.7,
				"items": ["bed", "table", "chair", "cabinet", "shelf"],
				"placement_rules": {
					"bed": {"location": "corner", "clearance": 1.0, "max_per_room": 2},
					"table": {"location": "center", "clearance": 1.2, "max_per_room": 2},
					"chair": {"location": "near_table", "clearance": 0.8, "max_per_room": 6},
					"cabinet": {"location": "wall", "clearance": 0.5, "max_per_room": 3},
					"shelf": {"location": "wall", "clearance": 0.3, "max_per_room": 4}
				}
			},
			"lighting": {
				"weight": 0.2,
				"items": ["lamp", "torch"],
				"placement_rules": {
					"lamp": {"location": "corner", "clearance": 0.5, "max_per_room": 2},
					"torch": {"location": "wall", "clearance": 0.3, "max_per_room": 4}
				}
			},
			"decorative": {
				"weight": 0.1,
				"items": ["barrel", "crate"],
				"placement_rules": {
					"barrel": {"location": "corner", "clearance": 0.6, "max_per_room": 2},
					"crate": {"location": "wall", "clearance": 0.4, "max_per_room": 3}
				}
			}
		}
	},
	"commercial": {
		"max_props_per_room": 12,
		"density_factor": 0.8,
		"preferred_locations": ["wall", "center", "display"],
		"avoid_locations": ["doorway", "traffic_path"],
		"prop_categories": {
			"furniture": {
				"weight": 0.6,
				"items": ["table", "chair", "cabinet", "shelf"],
				"placement_rules": {
					"table": {"location": "center", "clearance": 1.5, "max_per_room": 4},
					"chair": {"location": "near_table", "clearance": 0.8, "max_per_room": 8},
					"cabinet": {"location": "wall", "clearance": 0.5, "max_per_room": 4},
					"shelf": {"location": "wall", "clearance": 0.3, "max_per_room": 6}
				}
			},
			"display": {
				"weight": 0.3,
				"items": ["barrel", "crate"],
				"placement_rules": {
					"barrel": {"location": "display", "clearance": 0.8, "max_per_room": 4},
					"crate": {"location": "display", "clearance": 0.6, "max_per_room": 6}
				}
			},
			"lighting": {
				"weight": 0.1,
				"items": ["lamp_post", "torch"],
				"placement_rules": {
					"lamp_post": {"location": "corner", "clearance": 0.8, "max_per_room": 2},
					"torch": {"location": "wall", "clearance": 0.4, "max_per_room": 4}
				}
			}
		}
	},
	"administrative": {
		"max_props_per_room": 10,
		"density_factor": 0.7,
		"preferred_locations": ["wall", "organized"],
		"avoid_locations": ["doorway", "center"],
		"prop_categories": {
			"furniture": {
				"weight": 0.8,
				"items": ["table", "chair", "cabinet", "shelf"],
				"placement_rules": {
					"table": {"location": "organized", "clearance": 1.2, "max_per_room": 3},
					"chair": {"location": "near_table", "clearance": 0.8, "max_per_room": 6},
					"cabinet": {"location": "wall", "clearance": 0.5, "max_per_room": 4},
					"shelf": {"location": "wall", "clearance": 0.3, "max_per_room": 5}
				}
			},
			"storage": {
				"weight": 0.15,
				"items": ["crate"],
				"placement_rules": {
					"crate": {"location": "corner", "clearance": 0.5, "max_per_room": 3}
				}
			},
			"lighting": {
				"weight": 0.05,
				"items": ["lamp"],
				"placement_rules": {
					"lamp": {"location": "organized", "clearance": 0.5, "max_per_room": 2}
				}
			}
		}
	},
	"mixed": {
		"max_props_per_room": 10,
		"density_factor": 0.65,
		"preferred_locations": ["wall", "corner", "center"],
		"avoid_locations": ["doorway"],
		"prop_categories": {
			"furniture": {
				"weight": 0.6,
				"items": ["table", "chair", "cabinet", "shelf", "bed"],
				"placement_rules": {
					"table": {"location": "center", "clearance": 1.2, "max_per_room": 3},
					"chair": {"location": "near_table", "clearance": 0.8, "max_per_room": 6},
					"cabinet": {"location": "wall", "clearance": 0.5, "max_per_room": 3},
					"shelf": {"location": "wall", "clearance": 0.3, "max_per_room": 4},
					"bed": {"location": "corner", "clearance": 1.0, "max_per_room": 1}
				}
			},
			"decorative": {
				"weight": 0.25,
				"items": ["barrel", "crate"],
				"placement_rules": {
					"barrel": {"location": "corner", "clearance": 0.6, "max_per_room": 2},
					"crate": {"location": "wall", "clearance": 0.4, "max_per_room": 3}
				}
			},
			"lighting": {
				"weight": 0.15,
				"items": ["lamp", "torch"],
				"placement_rules": {
					"lamp": {"location": "corner", "clearance": 0.5, "max_per_room": 2},
					"torch": {"location": "wall", "clearance": 0.3, "max_per_room": 3}
				}
			}
		}
	}
}

# Location type definitions
const LOCATION_TYPES = {
	"corner": "Position in room corners, away from traffic",
	"wall": "Position against walls with clearance",
	"center": "Position in central areas of rooms",
	"near_table": "Position adjacent to existing tables",
	"display": "Position for commercial display purposes",
	"organized": "Position in organized, formal arrangements",
	"doorway": "Near room entrances (usually avoided)",
	"window": "Near windows (context dependent)",
	"traffic_path": "Main walking paths through rooms"
}

# Overcrowding prevention settings
const OVERCROWDING_RULES = {
	"min_clearance_between_props": 1.0,
	"max_props_per_grid_cell": 1,
	"traffic_path_width": 2.0,
	"doorway_clearance_radius": 1.5,
	"window_clearance": 0.8,
	"room_edge_clearance": 0.5
}

## Gets prop placement rules for a specific area type
static func get_rules_for_area_type(area_type: String) -> Dictionary:
	return PROP_RULES.get(area_type, PROP_RULES["mixed"])

## Gets placement rules for a specific prop item
static func get_prop_placement_rule(area_type: String, prop_id: String) -> Dictionary:
	var area_rules = get_rules_for_area_type(area_type)
	
	for category_name in area_rules.prop_categories:
		var category = area_rules.prop_categories[category_name]
		if prop_id in category.placement_rules:
			return category.placement_rules[prop_id]
	
	# Return default rule if not found
	return {
		"location": "wall",
		"clearance": 0.5,
		"max_per_room": 2
	}

## Calculates maximum props allowed in a room based on size and area type
static func calculate_max_props_for_room(room_size: int, area_type: String) -> int:
	var rules = get_rules_for_area_type(area_type)
	var base_max = rules.max_props_per_room
	var density = rules.density_factor
	
	# Scale based on room size
	var size_factor = float(room_size) / 16.0  # Normalize to 4x4 room
	var calculated_max = int(base_max * density * size_factor)
	
	# Ensure reasonable bounds
	return clamp(calculated_max, 1, base_max * 2)

## Checks if a location type is preferred for an area type
static func is_preferred_location(area_type: String, location_type: String) -> bool:
	var rules = get_rules_for_area_type(area_type)
	return location_type in rules.preferred_locations

## Checks if a location type should be avoided for an area type
static func should_avoid_location(area_type: String, location_type: String) -> bool:
	var rules = get_rules_for_area_type(area_type)
	return location_type in rules.avoid_locations

## Gets weighted prop selection for an area type
static func get_weighted_prop_selection(area_type: String) -> Array[Dictionary]:
	var rules = get_rules_for_area_type(area_type)
	var weighted_props: Array[Dictionary] = []
	
	for category_name in rules.prop_categories:
		var category = rules.prop_categories[category_name]
		var weight = category.weight
		
		for prop_id in category.items:
			weighted_props.append({
				"prop_id": prop_id,
				"category": category_name,
				"weight": weight,
				"placement_rule": category.placement_rules.get(prop_id, {})
			})
	
	return weighted_props

## Validates prop placement against overcrowding rules
static func validate_prop_placement(layout: SceneLayout, pos: Vector2i, prop_id: String, area_type: String) -> Dictionary:
	var validation_result = {
		"valid": true,
		"warnings": [],
		"errors": []
	}
	
	# Check minimum clearance between props
	if not _check_prop_clearance(layout, pos, prop_id, area_type):
		validation_result.valid = false
		validation_result.errors.append("Insufficient clearance between props")
	
	# Check doorway clearance
	if _is_too_close_to_doorway(layout, pos):
		validation_result.valid = false
		validation_result.errors.append("Too close to doorway")
	
	# Check traffic path interference
	if _blocks_traffic_path(layout, pos):
		validation_result.valid = false
		validation_result.errors.append("Blocks main traffic path")
	
	# Check room edge clearance
	if not _has_room_edge_clearance(layout, pos):
		validation_result.warnings.append("Very close to room edge")
	
	# Check prop count limits
	var room_area = _get_room_area_for_position(layout, pos)
	if room_area.size() > 0:
		var prop_count = _count_props_in_room(layout, room_area, prop_id)
		var max_allowed = get_prop_placement_rule(area_type, prop_id).get("max_per_room", 2)
		
		if prop_count >= max_allowed:
			validation_result.valid = false
			validation_result.errors.append("Maximum %s count reached for room" % prop_id)
	
	return validation_result

## Checks if there's sufficient clearance between props
static func _check_prop_clearance(layout: SceneLayout, pos: Vector2i, prop_id: String, area_type: String) -> bool:
	var placement_rule = get_prop_placement_rule(area_type, prop_id)
	var required_clearance = placement_rule.get("clearance", 0.5)
	var clearance_cells = int(required_clearance / BaseGenerator.GRID_SIZE) + 1
	
	for x in range(-clearance_cells, clearance_cells + 1):
		for y in range(-clearance_cells, clearance_cells + 1):
			if x == 0 and y == 0:
				continue
			
			var check_pos = pos + Vector2i(x, y)
			var cell = layout.get_cell(check_pos)
			if cell and (cell.cell_type == "furniture" or cell.cell_type == "prop"):
				var distance = (check_pos - pos).length() * BaseGenerator.GRID_SIZE
				if distance < required_clearance:
					return false
	
	return true

## Checks if position is too close to a doorway
static func _is_too_close_to_doorway(layout: SceneLayout, pos: Vector2i) -> bool:
	var clearance_radius = int(OVERCROWDING_RULES.doorway_clearance_radius / BaseGenerator.GRID_SIZE)
	
	for x in range(-clearance_radius, clearance_radius + 1):
		for y in range(-clearance_radius, clearance_radius + 1):
			var check_pos = pos + Vector2i(x, y)
			var cell = layout.get_cell(check_pos)
			if cell and cell.cell_type == "door":
				return true
	
	return false

## Checks if position blocks main traffic paths
static func _blocks_traffic_path(layout: SceneLayout, pos: Vector2i) -> bool:
	# Simple heuristic: check if position is in a corridor-like area
	var walkable_neighbors = 0
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			walkable_neighbors += 1
	
	# If surrounded by walkable cells, might be a traffic path
	return walkable_neighbors >= 3

## Checks if position has adequate clearance from room edges
static func _has_room_edge_clearance(layout: SceneLayout, pos: Vector2i) -> bool:
	var clearance = int(OVERCROWDING_RULES.room_edge_clearance / BaseGenerator.GRID_SIZE)
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var check_pos = pos + direction * clearance
		if not layout.is_valid_position(check_pos):
			return false
		
		var cell = layout.get_cell(check_pos)
		if not cell or cell.cell_type == "wall":
			return false
	
	return true

## Gets the room area that contains a specific position
static func _get_room_area_for_position(layout: SceneLayout, pos: Vector2i) -> Array[Vector2i]:
	var room_area: Array[Vector2i] = []
	var visited: Dictionary = {}
	
	_flood_fill_room_area(pos, layout, visited, room_area)
	return room_area

## Flood fill to identify room area containing a position
static func _flood_fill_room_area(pos: Vector2i, layout: SceneLayout, visited: Dictionary, room_area: Array[Vector2i]) -> void:
	if pos in visited or not layout.is_valid_position(pos):
		return
	
	var cell = layout.get_cell(pos)
	if not cell or not cell.is_walkable():
		return
	
	visited[pos] = true
	room_area.append(pos)
	
	# Expand to adjacent walkable cells
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.is_walkable():
			_flood_fill_room_area(neighbor_pos, layout, visited, room_area)

## Counts existing props of a specific type in a room
static func _count_props_in_room(layout: SceneLayout, room_area: Array[Vector2i], prop_id: String) -> int:
	var count = 0
	
	for pos in room_area:
		var cell = layout.get_cell(pos)
		if cell and (cell.cell_type == "furniture" or cell.cell_type == "prop"):
			if cell.asset_id == prop_id:
				count += 1
	
	return count

## Generates prop placement suggestions for a room
static func generate_placement_suggestions(layout: SceneLayout, room_area: Array[Vector2i], area_type: String) -> Array[Dictionary]:
	var suggestions: Array[Dictionary] = []
	var weighted_props = get_weighted_prop_selection(area_type)
	var max_props = calculate_max_props_for_room(room_area.size(), area_type)
	
	# Sort props by weight (highest first)
	weighted_props.sort_custom(func(a, b): return a.weight > b.weight)
	
	var placed_props = 0
	for prop_data in weighted_props:
		if placed_props >= max_props:
			break
		
		var prop_id = prop_data.prop_id
		var placement_rule = prop_data.placement_rule
		var max_per_room = placement_rule.get("max_per_room", 2)
		
		# Check current count
		var current_count = _count_props_in_room(layout, room_area, prop_id)
		if current_count >= max_per_room:
			continue
		
		# Find suitable positions
		var suitable_positions = _find_suitable_positions_for_prop(layout, room_area, prop_id, area_type)
		
		for pos in suitable_positions:
			if placed_props >= max_props:
				break
			
			suggestions.append({
				"position": pos,
				"prop_id": prop_id,
				"category": prop_data.category,
				"priority": prop_data.weight,
				"placement_rule": placement_rule
			})
			placed_props += 1
			
			# Don't place too many of the same prop
			if suggestions.filter(func(s): return s.prop_id == prop_id).size() >= max_per_room:
				break
	
	return suggestions

## Finds suitable positions for a specific prop in a room
static func _find_suitable_positions_for_prop(layout: SceneLayout, room_area: Array[Vector2i], prop_id: String, area_type: String) -> Array[Vector2i]:
	var suitable_positions: Array[Vector2i] = []
	var placement_rule = get_prop_placement_rule(area_type, prop_id)
	var preferred_location = placement_rule.get("location", "wall")
	
	for pos in room_area:
		# Check if position is already occupied
		var cell = layout.get_cell(pos)
		if cell and cell.cell_type != "floor":
			continue
		
		# Check if position matches preferred location type
		if not _position_matches_location_type(layout, pos, preferred_location):
			continue
		
		# Validate placement
		var validation = validate_prop_placement(layout, pos, prop_id, area_type)
		if validation.valid:
			suitable_positions.append(pos)
	
	return suitable_positions

## Checks if a position matches a specific location type
static func _position_matches_location_type(layout: SceneLayout, pos: Vector2i, location_type: String) -> bool:
	match location_type:
		"corner":
			return _is_corner_position(layout, pos)
		"wall":
			return _is_near_wall(layout, pos)
		"center":
			return _is_central_position(layout, pos)
		"near_table":
			return _is_near_table(layout, pos)
		"display":
			return _is_display_position(layout, pos)
		"organized":
			return _is_organized_position(layout, pos)
		_:
			return true

## Checks if position is in a corner
static func _is_corner_position(layout: SceneLayout, pos: Vector2i) -> bool:
	var wall_neighbors = 0
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "wall":
			wall_neighbors += 1
	
	return wall_neighbors >= 2

## Checks if position is near a wall
static func _is_near_wall(layout: SceneLayout, pos: Vector2i) -> bool:
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		var neighbor_cell = layout.get_cell(neighbor_pos)
		if neighbor_cell and neighbor_cell.cell_type == "wall":
			return true
	
	return false

## Checks if position is central in the room
static func _is_central_position(layout: SceneLayout, pos: Vector2i) -> bool:
	# Not adjacent to walls
	return not _is_near_wall(layout, pos)

## Checks if position is near an existing table
static func _is_near_table(layout: SceneLayout, pos: Vector2i) -> bool:
	var search_radius = 2
	
	for x in range(-search_radius, search_radius + 1):
		for y in range(-search_radius, search_radius + 1):
			if x == 0 and y == 0:
				continue
			
			var check_pos = pos + Vector2i(x, y)
			var cell = layout.get_cell(check_pos)
			if cell and (cell.cell_type == "furniture" or cell.cell_type == "prop"):
				if cell.asset_id == "table":
					return true
	
	return false

## Checks if position is suitable for display purposes
static func _is_display_position(layout: SceneLayout, pos: Vector2i) -> bool:
	# Display positions are near walls but not in corners
	return _is_near_wall(layout, pos) and not _is_corner_position(layout, pos)

## Checks if position fits organized placement patterns
static func _is_organized_position(layout: SceneLayout, pos: Vector2i) -> bool:
	# Organized positions follow grid patterns and avoid random placement
	# Simple heuristic: positions that align with room geometry
	return (pos.x % 2 == 0) or (pos.y % 2 == 0)

## Gets overcrowding prevention rules
static func get_overcrowding_rules() -> Dictionary:
	return OVERCROWDING_RULES

## Checks if a room is overcrowded with props
static func is_room_overcrowded(layout: SceneLayout, room_area: Array[Vector2i], area_type: String) -> bool:
	var prop_count = 0
	
	for pos in room_area:
		var cell = layout.get_cell(pos)
		if cell and (cell.cell_type == "furniture" or cell.cell_type == "prop"):
			prop_count += 1
	
	var max_allowed = calculate_max_props_for_room(room_area.size(), area_type)
	return prop_count > max_allowed

## Gets prop placement statistics for a layout
static func get_prop_placement_stats(layout: SceneLayout, area_type: String) -> Dictionary:
	var stats = {
		"total_props": 0,
		"props_by_category": {},
		"rooms_analyzed": 0,
		"overcrowded_rooms": 0,
		"average_props_per_room": 0.0
	}
	
	var all_props = layout.get_cells_of_type("furniture") + layout.get_cells_of_type("prop")
	stats.total_props = all_props.size()
	
	# Count by category
	var weighted_props = get_weighted_prop_selection(area_type)
	for prop_data in weighted_props:
		var category = prop_data.category
		if not category in stats.props_by_category:
			stats.props_by_category[category] = 0
		
		for cell in all_props:
			if cell.asset_id == prop_data.prop_id:
				stats.props_by_category[category] += 1
	
	# Analyze rooms
	var room_areas = _get_all_room_areas(layout)
	stats.rooms_analyzed = room_areas.size()
	
	var total_room_props = 0
	for room_area in room_areas:
		var room_prop_count = 0
		for pos in room_area:
			var cell = layout.get_cell(pos)
			if cell and (cell.cell_type == "furniture" or cell.cell_type == "prop"):
				room_prop_count += 1
		
		total_room_props += room_prop_count
		
		if is_room_overcrowded(layout, room_area, area_type):
			stats.overcrowded_rooms += 1
	
	if stats.rooms_analyzed > 0:
		stats.average_props_per_room = float(total_room_props) / float(stats.rooms_analyzed)
	
	return stats

## Gets all room areas in a layout
static func _get_all_room_areas(layout: SceneLayout) -> Array[Array]:
	var floor_cells = layout.get_cells_of_type("floor")
	var visited: Dictionary = {}
	var room_areas: Array[Array] = []
	
	for cell in floor_cells:
		if not cell.position in visited:
			var room_area: Array[Vector2i] = []
			_flood_fill_room_area(cell.position, layout, visited, room_area)
			if room_area.size() >= 4:  # Minimum room size
				room_areas.append(room_area)
	
	return room_areas