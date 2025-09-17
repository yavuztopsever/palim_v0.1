@tool
extends RefCounted

## Simple verification script for lighting system
## Verifies that lighting configurations are properly defined

static func verify_lighting_system() -> bool:
	print("=== Verifying Lighting System ===")
	
	var success = true
	
	# Verify lighting configurations exist
	if not _verify_lighting_configs():
		success = false
	
	# Verify LightingSetup class methods exist
	if not _verify_lighting_methods():
		success = false
	
	if success:
		print("✓ Lighting system verification passed")
	else:
		print("✗ Lighting system verification failed")
	
	return success

static func _verify_lighting_configs() -> bool:
	print("\n--- Verifying Lighting Configurations ---")
	
	var required_area_types = ["residential", "commercial", "administrative", "mixed"]
	var required_config_keys = ["ambient_color", "ambient_energy", "light_color", "light_energy", "light_temperature"]
	
	for area_type in required_area_types:
		if not area_type in LightingSetup.LIGHTING_CONFIGS:
			print("✗ Missing lighting config for area type: %s" % area_type)
			return false
		
		var config = LightingSetup.LIGHTING_CONFIGS[area_type]
		for key in required_config_keys:
			if not key in config:
				print("✗ Missing config key '%s' for area type: %s" % [key, area_type])
				return false
		
		print("✓ Lighting config verified for %s" % area_type)
	
	# Verify color properties
	var residential_config = LightingSetup.LIGHTING_CONFIGS["residential"]
	var commercial_config = LightingSetup.LIGHTING_CONFIGS["commercial"]
	var admin_config = LightingSetup.LIGHTING_CONFIGS["administrative"]
	
	# Residential should be warm (more red than blue)
	var res_color = residential_config["ambient_color"] as Color
	if res_color.r <= res_color.b:
		print("✗ Residential lighting should be warm (more red than blue)")
		return false
	print("✓ Residential lighting is warm")
	
	# Commercial should be bright (high energy)
	var com_energy = commercial_config["ambient_energy"] as float
	if com_energy < 0.5:
		print("✗ Commercial lighting should be bright (energy >= 0.5)")
		return false
	print("✓ Commercial lighting is bright")
	
	# Administrative should be cool (more blue than red)
	var admin_color = admin_config["ambient_color"] as Color
	if admin_color.b <= admin_color.r:
		print("✗ Administrative lighting should be cool (more blue than red)")
		return false
	print("✓ Administrative lighting is cool")
	
	return true

static func _verify_lighting_methods() -> bool:
	print("\n--- Verifying Lighting Methods ---")
	
	# Simple verification that the LightingSetup class exists and can be referenced
	# We can't easily check static methods without instantiation, so we'll just verify
	# the class exists and has the expected constants
	
	if not LightingSetup:
		print("✗ LightingSetup class not found")
		return false
	
	# Check that constants exist by trying to access them
	var configs = LightingSetup.LIGHTING_CONFIGS
	if not configs:
		print("✗ LIGHTING_CONFIGS constant not found")
		return false
	
	var ambient_energy = LightingSetup.AMBIENT_LIGHT_ENERGY
	if ambient_energy == null:
		print("✗ AMBIENT_LIGHT_ENERGY constant not found")
		return false
	
	print("✓ LightingSetup class structure verified")
	return true

static func print_lighting_configs():
	print("\n=== Lighting Configurations ===")
	
	for area_type in LightingSetup.LIGHTING_CONFIGS:
		var config = LightingSetup.LIGHTING_CONFIGS[area_type]
		print("\n%s:" % area_type.to_upper())
		print("  Ambient Color: %s" % config["ambient_color"])
		print("  Ambient Energy: %f" % config["ambient_energy"])
		print("  Light Color: %s" % config["light_color"])
		print("  Light Energy: %f" % config["light_energy"])
		print("  Light Temperature: %dK" % config["light_temperature"])