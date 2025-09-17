@tool
extends EditorScript

## Test script for FurniturePlacer functionality
## Verifies furniture placement logic and prop rules integration

func _run():
	print("=== Testing FurniturePlacer ===")
	
	# Test prop placement rules
	test_prop_placement_rules()
	
	# Test furniture placer integration
	test_furniture_placer_integration()
	
	print("=== FurniturePlacer Tests Complete ===")

func test_prop_placement_rules():
	print("\n--- Testing PropPlacementRules ---")
	
	# Test rule retrieval for different area types
	var residential_rules = PropPlacementRules.get_rules_for_area_type("residential")
	assert(residential_rules.has("max_props_per_room"), "Residential rules should have max_props_per_room")
	assert(residential_rules.has("prop_categories"), "Residential rules should have prop_categories")
	
	var commercial_rules = PropPlacementRules.get_rules_for_area_type("commercial")
	assert(commercial_rules.max_props_per_room > residential_rules.max_props_per_room, "Commercial should allow more props than residential")
	
	# Test prop placement rule retrieval
	var bed_rule = PropPlacementRules.get_prop_placement_rule("residential", "bed")
	assert(bed_rule.has("location"), "Bed rule should specify location")
	assert(bed_rule.has("clearance"), "Bed rule should specify clearance")
	assert(bed_rule.has("max_per_room"), "Bed rule should specify max per room")
	
	# Test max props calculation
	var small_room_max = PropPlacementRules.calculate_max_props_for_room(9, "residential")  # 3x3 room
	var large_room_max = PropPlacementRules.calculate_max_props_for_room(25, "residential")  # 5x5 room
	assert(large_room_max > small_room_max, "Larger rooms should allow more props")
	
	# Test location preferences
	assert(PropPlacementRules.is_preferred_location("residential", "corner"), "Corners should be preferred for residential")
	assert(PropPlacementRules.should_avoid_location("residential", "doorway"), "Doorways should be avoided for residential")
	
	# Test weighted prop selection
	var weighted_props = PropPlacementRules.get_weighted_prop_selection("commercial")
	assert(weighted_props.size() > 0, "Should return weighted props for commercial")
	
	var has_furniture_category = false
	for prop_data in weighted_props:
		if prop_data.category == "furniture":
			has_furniture_category = true
			break
	assert(has_furniture_category, "Commercial should include furniture category")
	
	print("PropPlacementRules tests passed!")

func test_furniture_placer_integration():
	print("\n--- Testing FurniturePlacer Integration ---")
	
	# Create test layout
	var layout = SceneLayout.new(Vector2i(8, 8))
	
	# Create a simple room (4x4 floor area surrounded by walls)
	for x in range(2, 6):
		for y in range(2, 6):
			var floor_cell = CellData.new(Vector2i(x, y), "floor")
			floor_cell.asset_id = "floor_tile"
			layout.set_cell(Vector2i(x, y), floor_cell)
	
	# Add walls around the room
	for x in range(1, 7):
		for y in range(1, 7):
			if x == 1 or x == 6 or y == 1 or y == 6:
				if not layout.has_cell(Vector2i(x, y)):  # Don't overwrite floor
					var wall_cell = CellData.new(Vector2i(x, y), "wall")
					wall_cell.asset_id = "wall_segment"
					layout.set_cell(Vector2i(x, y), wall_cell)
	
	# Add a door
	var door_cell = CellData.new(Vector2i(3, 1), "door")
	door_cell.asset_id = "door_frame"
	layout.set_cell(Vector2i(3, 1), door_cell)
	
	# Validate layout
	assert(layout.validate_layout(), "Test layout should be valid")
	
	# Create furniture placer
	var asset_library = AssetLibrary.new()
	var furniture_placer = FurniturePlacer.new(asset_library, 12345)
	
	# Test room identification
	var room_areas = furniture_placer._identify_room_areas(layout)
	assert(room_areas.size() > 0, "Should identify at least one room")
	
	var main_room = room_areas[0]
	assert(main_room.size() >= 16, "Main room should have at least 16 floor cells")
	
	# Test placement position finding
	var placement_positions = furniture_placer._find_furniture_placement_positions(layout, main_room)
	assert(placement_positions.size() > 0, "Should find placement positions")
	
	# Test validation functions
	for pos in placement_positions:
		assert(furniture_placer._is_valid_furniture_position(layout, pos), "All placement positions should be valid")
	
	# Test prop rules integration
	var placement_suggestions = PropPlacementRules.generate_placement_suggestions(layout, main_room, "residential")
	assert(placement_suggestions.size() > 0, "Should generate placement suggestions")
	
	# Verify suggestions have required fields
	for suggestion in placement_suggestions:
		assert(suggestion.has("position"), "Suggestion should have position")
		assert(suggestion.has("prop_id"), "Suggestion should have prop_id")
		assert(suggestion.has("category"), "Suggestion should have category")
		assert(suggestion.has("priority"), "Suggestion should have priority")
	
	# Test overcrowding detection
	assert(not PropPlacementRules.is_room_overcrowded(layout, main_room, "residential"), "Empty room should not be overcrowded")
	
	# Test validation
	var test_pos = main_room[0]
	var validation = PropPlacementRules.validate_prop_placement(layout, test_pos, "table", "residential")
	assert(validation.has("valid"), "Validation should return valid field")
	assert(validation.has("warnings"), "Validation should return warnings array")
	assert(validation.has("errors"), "Validation should return errors array")
	
	# Test statistics
	var stats = PropPlacementRules.get_prop_placement_stats(layout, "residential")
	assert(stats.has("total_props"), "Stats should include total props")
	assert(stats.has("rooms_analyzed"), "Stats should include rooms analyzed")
	
	print("FurniturePlacer integration tests passed!")

func test_furniture_placement_workflow():
	print("\n--- Testing Complete Furniture Placement Workflow ---")
	
	# Create a test scene
	var test_scene = Node3D.new()
	test_scene.name = "TestScene"
	
	# Create test layout with multiple rooms
	var layout = SceneLayout.new(Vector2i(12, 8))
	
	# Room 1: Residential (3x3)
	for x in range(1, 4):
		for y in range(1, 4):
			var floor_cell = CellData.new(Vector2i(x, y), "floor")
			floor_cell.asset_id = "floor_tile"
			layout.set_cell(Vector2i(x, y), floor_cell)
	
	# Room 2: Commercial (4x3)
	for x in range(6, 10):
		for y in range(1, 4):
			var floor_cell = CellData.new(Vector2i(x, y), "floor")
			floor_cell.asset_id = "floor_tile"
			layout.set_cell(Vector2i(x, y), floor_cell)
	
	# Room 3: Administrative (3x4)
	for x in range(1, 4):
		for y in range(5, 8):
			var floor_cell = CellData.new(Vector2i(x, y), "floor")
			floor_cell.asset_id = "floor_tile"
			layout.set_cell(Vector2i(x, y), floor_cell)
	
	# Add walls and doors (simplified)
	# ... (wall placement logic would go here)
	
	# Test different area types
	var area_types = ["residential", "commercial", "administrative", "mixed"]
	
	for area_type in area_types:
		print("Testing area type: %s" % area_type)
		
		var params = GenerationParams.new()
		params.area_type = area_type
		params.size = Vector2i(12, 8)
		params.seed = 12345
		
		var asset_library = AssetLibrary.new()
		var furniture_placer = FurniturePlacer.new(asset_library, params.seed)
		
		# Test statistics before placement
		var stats_before = furniture_placer.get_furniture_stats(layout, area_type)
		assert(stats_before.total_props == 0, "Should start with no props")
		
		# Test rule-based suggestions
		var room_areas = furniture_placer._identify_room_areas(layout)
		for room_area in room_areas:
			if room_area.size() >= furniture_placer.MIN_ROOM_SIZE:
				var suggestions = PropPlacementRules.generate_placement_suggestions(layout, room_area, area_type)
				print("  Room with %d cells: %d placement suggestions" % [room_area.size(), suggestions.size()])
		
		# Verify area-specific rules
		var area_rules = PropPlacementRules.get_rules_for_area_type(area_type)
		assert(area_rules.has("max_props_per_room"), "Area rules should specify max props per room")
		assert(area_rules.has("prop_categories"), "Area rules should specify prop categories")
		
		print("  Area type %s: max_props_per_room = %d, density_factor = %.2f" % [
			area_type, 
			area_rules.max_props_per_room, 
			area_rules.density_factor
		])
	
	# Cleanup
	test_scene.queue_free()
	
	print("Complete workflow tests passed!")

# Run additional test when script is executed
func _init():
	if Engine.is_editor_hint():
		call_deferred("test_furniture_placement_workflow")