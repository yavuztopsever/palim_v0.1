@tool
extends RefCounted

## Simple lighting system test that can be run without editor context

static func test_lighting_configs():
	print("=== Testing Lighting Configurations ===")
	
	# Test that all required area types have configurations
	var required_types = ["residential", "commercial", "administrative", "mixed"]
	
	for area_type in required_types:
		if area_type in LightingSetup.LIGHTING_CONFIGS:
			var config = LightingSetup.LIGHTING_CONFIGS[area_type]
			print("✓ %s lighting config found" % area_type)
			
			# Check required keys
			var required_keys = ["ambient_color", "ambient_energy", "light_color", "light_energy"]
			for key in required_keys:
				if key in config:
					print("  ✓ %s: %s" % [key, config[key]])
				else:
					print("  ✗ Missing key: %s" % key)
		else:
			print("✗ Missing config for: %s" % area_type)
	
	# Test lighting characteristics
	var residential = LightingSetup.LIGHTING_CONFIGS["residential"]
	var commercial = LightingSetup.LIGHTING_CONFIGS["commercial"]
	var administrative = LightingSetup.LIGHTING_CONFIGS["administrative"]
	
	print("\n=== Lighting Characteristics ===")
	
	# Residential should be warm
	var res_color = residential["ambient_color"] as Color
	if res_color.r > res_color.b:
		print("✓ Residential lighting is warm (R:%.2f > B:%.2f)" % [res_color.r, res_color.b])
	else:
		print("✗ Residential lighting should be warmer")
	
	# Commercial should be bright
	var com_energy = commercial["ambient_energy"] as float
	if com_energy >= 0.5:
		print("✓ Commercial lighting is bright (energy: %.2f)" % com_energy)
	else:
		print("✗ Commercial lighting should be brighter")
	
	# Administrative should be cool
	var admin_color = administrative["ambient_color"] as Color
	if admin_color.b > admin_color.r:
		print("✓ Administrative lighting is cool (B:%.2f > R:%.2f)" % [admin_color.b, admin_color.r])
	else:
		print("✗ Administrative lighting should be cooler")
	
	print("\n=== Lighting Test Complete ===")

# Auto-run when script is loaded
func _init():
	test_lighting_configs()