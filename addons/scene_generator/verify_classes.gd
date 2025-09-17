@tool
extends RefCounted

## Simple verification script for FurniturePlacer and PropPlacementRules
## Can be run without editor context

static func verify_classes():
	print("=== Verifying FurniturePlacer and PropPlacementRules ===")
	
	# Test that classes can be instantiated
	var asset_library = AssetLibrary.new()
	var furniture_placer = FurniturePlacer.new(asset_library, 12345)
	
	print("✓ FurniturePlacer instantiated successfully")
	
	# Test PropPlacementRules static methods
	var residential_rules = PropPlacementRules.get_rules_for_area_type("residential")
	assert(residential_rules.has("max_props_per_room"), "Residential rules should have max_props_per_room")
	print("✓ PropPlacementRules.get_rules_for_area_type() works")
	
	var bed_rule = PropPlacementRules.get_prop_placement_rule("residential", "bed")
	assert(bed_rule.has("location"), "Bed rule should specify location")
	print("✓ PropPlacementRules.get_prop_placement_rule() works")
	
	var max_props = PropPlacementRules.calculate_max_props_for_room(16, "residential")
	assert(max_props > 0, "Should calculate positive max props")
	print("✓ PropPlacementRules.calculate_max_props_for_room() works")
	
	assert(PropPlacementRules.is_preferred_location("residential", "corner"), "Corners should be preferred for residential")
	print("✓ PropPlacementRules.is_preferred_location() works")
	
	var weighted_props = PropPlacementRules.get_weighted_prop_selection("commercial")
	assert(weighted_props.size() > 0, "Should return weighted props")
	print("✓ PropPlacementRules.get_weighted_prop_selection() works")
	
	# Test basic layout creation and room identification
	var layout = SceneLayout.new(Vector2i(6, 6))
	
	# Create a simple 3x3 room
	for x in range(2, 5):
		for y in range(2, 5):
			var floor_cell = CellData.new(Vector2i(x, y), "floor")
			floor_cell.asset_id = "floor_tile"
			layout.set_cell(Vector2i(x, y), floor_cell)
	
	var room_areas = furniture_placer._identify_room_areas(layout)
	assert(room_areas.size() > 0, "Should identify at least one room")
	print("✓ Room identification works")
	
	# Test placement suggestions
	var main_room = room_areas[0]
	var suggestions = PropPlacementRules.generate_placement_suggestions(layout, main_room, "residential")
	print("✓ Generated %d placement suggestions for room" % suggestions.size())
	
	# Test validation
	if suggestions.size() > 0:
		var first_suggestion = suggestions[0]
		var validation = PropPlacementRules.validate_prop_placement(
			layout, 
			first_suggestion.position, 
			first_suggestion.prop_id, 
			"residential"
		)
		assert(validation.has("valid"), "Validation should return valid field")
		print("✓ Prop placement validation works")
	
	# Test statistics
	var stats = PropPlacementRules.get_prop_placement_stats(layout, "residential")
	assert(stats.has("total_props"), "Stats should include total props")
	print("✓ Statistics generation works")
	
	# Verify lighting system
	var lighting_verification = preload("res://addons/scene_generator/verify_lighting.gd")
	if not lighting_verification.verify_lighting_system():
		print("✗ Lighting system verification failed")
		return false
	
	# Verify scene integration
	var integration_validation = preload("res://addons/scene_generator/validate_integration.gd")
	if not integration_validation.validate_scene_integration():
		print("✗ Scene integration validation failed")
		return false
	
	print("=== All verifications passed! ===")
	return true

# Auto-run verification when loaded
func _init():
	verify_classes()