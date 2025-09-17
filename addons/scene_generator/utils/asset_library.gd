class_name AssetLibrary
extends Resource

## Asset library that loads and manages building block scenes from resources
## Provides asset instantiation with proper positioning and rotation
## Includes error handling for missing or invalid assets

# Asset categories
enum AssetCategory {
	FLOOR,
	WALL,
	DOOR,
	WINDOW,
	FURNITURE,
	PROP,
	LIGHTING
}

# Asset storage
var _assets: Dictionary = {}
var _asset_paths: Dictionary = {}
var _fallback_assets: Dictionary = {}

# Asset loading settings
var auto_load_on_init: bool = true
var asset_base_path: String = "res://addons/scene_generator/assets/"

func _init():
	_initialize_asset_paths()
	# Don't auto-load assets to avoid file not found errors
	# if auto_load_on_init:
	#	_load_default_assets()

## Initializes the default asset paths for each category
func _initialize_asset_paths() -> void:
	_asset_paths = {
		"floor_tile": "building_blocks/floors/floor_tile.tscn",
		"grass_tile": "building_blocks/floors/grass_tile.tscn",
		"path_tile": "building_blocks/floors/path_tile.tscn",
		"market_tile": "building_blocks/floors/market_tile.tscn",
		"formal_path_tile": "building_blocks/floors/formal_path_tile.tscn",
		"corridor_tile": "building_blocks/floors/corridor_tile.tscn",
		"mixed_tile": "building_blocks/floors/mixed_tile.tscn",
		
		"wall_segment": "building_blocks/walls/wall_segment.tscn",
		"corner_wall": "building_blocks/walls/corner_wall.tscn",
		"wall_with_window": "building_blocks/walls/wall_with_window.tscn",
		
		"door_frame": "building_blocks/doors/door_frame.tscn",
		"wooden_door": "building_blocks/doors/wooden_door.tscn",
		"metal_door": "building_blocks/doors/metal_door.tscn",
		
		"window_frame": "building_blocks/windows/window_frame.tscn",
		"glass_window": "building_blocks/windows/glass_window.tscn",
		"shuttered_window": "building_blocks/windows/shuttered_window.tscn",
		
		"table": "furniture/tables/table.tscn",
		"chair": "furniture/chairs/chair.tscn",
		"cabinet": "furniture/storage/cabinet.tscn",
		"shelf": "furniture/storage/shelf.tscn",
		"bed": "furniture/beds/bed.tscn",
		
		"barrel": "props/containers/barrel.tscn",
		"crate": "props/containers/crate.tscn",
		"lamp_post": "props/lighting/lamp_post.tscn",
		"torch": "props/lighting/torch.tscn",
		
		"default_prop": "props/default/default_prop.tscn"
	}

## Loads default assets from the asset paths
func _load_default_assets() -> void:
	for asset_id in _asset_paths:
		var asset_path = asset_base_path + _asset_paths[asset_id]
		_load_asset(asset_id, asset_path)

## Loads a single asset from a file path
func _load_asset(asset_id: String, asset_path: String) -> bool:
	if not ResourceLoader.exists(asset_path):
		push_warning("Asset file not found: %s for asset_id: %s" % [asset_path, asset_id])
		return false
	
	var resource = load(asset_path)
	if not resource:
		push_error("Failed to load asset: %s" % asset_path)
		return false
	
	if not resource is PackedScene:
		push_error("Asset is not a PackedScene: %s" % asset_path)
		return false
	
	_assets[asset_id] = resource
	
	if OS.is_debug_build():
		print("Loaded asset: %s from %s" % [asset_id, asset_path])
	
	return true

## Gets an asset by ID, with optional fallback
func get_asset(asset_id: String, fallback_id: String = "") -> PackedScene:
	# Try to get the requested asset
	if asset_id in _assets:
		return _assets[asset_id]
	
	# Try to load the asset if it's not loaded but path exists
	if asset_id in _asset_paths:
		var asset_path = asset_base_path + _asset_paths[asset_id]
		if _load_asset(asset_id, asset_path):
			return _assets[asset_id]
	
	# Try fallback asset
	if fallback_id != "" and fallback_id in _assets:
		push_warning("Using fallback asset '%s' for missing asset '%s'" % [fallback_id, asset_id])
		return _assets[fallback_id]
	
	# Try category fallback
	var category_fallback = _get_category_fallback(asset_id)
	if category_fallback and category_fallback in _assets:
		push_warning("Using category fallback '%s' for missing asset '%s'" % [category_fallback, asset_id])
		return _assets[category_fallback]
	
	# Asset not found
	push_error("Asset not found: %s (fallback: %s)" % [asset_id, fallback_id])
	return null

## Gets a fallback asset based on asset category
func _get_category_fallback(asset_id: String) -> String:
	# Determine category from asset_id and return appropriate fallback
	if "floor" in asset_id or "tile" in asset_id:
		return "floor_tile"
	elif "wall" in asset_id:
		return "wall_segment"
	elif "door" in asset_id:
		return "door_frame"
	elif "window" in asset_id:
		return "window_frame"
	elif "furniture" in asset_id or "table" in asset_id or "chair" in asset_id:
		return "table"
	else:
		return "default_prop"

## Registers a new asset with the library
func register_asset(asset_id: String, asset_scene: PackedScene) -> void:
	if not asset_scene:
		push_error("Cannot register null asset: %s" % asset_id)
		return
	
	_assets[asset_id] = asset_scene
	
	if OS.is_debug_build():
		print("Registered asset: %s" % asset_id)

## Registers an asset from a file path
func register_asset_from_path(asset_id: String, asset_path: String) -> bool:
	return _load_asset(asset_id, asset_path)

## Unregisters an asset from the library
func unregister_asset(asset_id: String) -> bool:
	if asset_id in _assets:
		_assets.erase(asset_id)
		if OS.is_debug_build():
			print("Unregistered asset: %s" % asset_id)
		return true
	
	return false

## Checks if an asset is available
func has_asset(asset_id: String) -> bool:
	return asset_id in _assets or asset_id in _asset_paths

## Gets all available asset IDs
func get_available_assets() -> Array[String]:
	var available: Array[String] = []
	
	# Add loaded assets
	for asset_id in _assets:
		available.append(asset_id)
	
	# Add unloaded but available assets
	for asset_id in _asset_paths:
		if not asset_id in _assets:
			available.append(asset_id)
	
	return available

## Gets assets by category
func get_assets_by_category(category: AssetCategory) -> Array[String]:
	var category_assets: Array[String] = []
	var available_assets = get_available_assets()
	
	for asset_id in available_assets:
		if _asset_belongs_to_category(asset_id, category):
			category_assets.append(asset_id)
	
	return category_assets

## Checks if an asset belongs to a specific category
func _asset_belongs_to_category(asset_id: String, category: AssetCategory) -> bool:
	match category:
		AssetCategory.FLOOR:
			return "floor" in asset_id or "tile" in asset_id
		AssetCategory.WALL:
			return "wall" in asset_id
		AssetCategory.DOOR:
			return "door" in asset_id
		AssetCategory.WINDOW:
			return "window" in asset_id
		AssetCategory.FURNITURE:
			return "table" in asset_id or "chair" in asset_id or "bed" in asset_id or "cabinet" in asset_id or "shelf" in asset_id
		AssetCategory.PROP:
			return "barrel" in asset_id or "crate" in asset_id or "prop" in asset_id
		AssetCategory.LIGHTING:
			return "lamp" in asset_id or "torch" in asset_id or "light" in asset_id
		_:
			return false

## Instantiates an asset with proper error handling
func instantiate_asset(asset_id: String, fallback_id: String = "") -> Node3D:
	var asset_scene = get_asset(asset_id, fallback_id)
	if not asset_scene:
		push_error("Cannot instantiate asset: %s" % asset_id)
		return null
	
	var instance = asset_scene.instantiate()
	if not instance:
		push_error("Failed to instantiate asset: %s" % asset_id)
		return null
	
	if not instance is Node3D:
		push_error("Asset is not a Node3D: %s" % asset_id)
		instance.queue_free()
		return null
	
	return instance as Node3D

## Instantiates an asset at a specific grid position
func instantiate_asset_at_grid(asset_id: String, grid_pos: Vector2i, fallback_id: String = "") -> Node3D:
	var instance = instantiate_asset(asset_id, fallback_id)
	if instance:
		instance.position = BaseGenerator.grid_to_world(grid_pos)
	
	return instance

## Instantiates an asset with rotation
func instantiate_asset_with_rotation(asset_id: String, rotation_degrees: float, fallback_id: String = "") -> Node3D:
	var instance = instantiate_asset(asset_id, fallback_id)
	if instance:
		instance.rotation_degrees.y = rotation_degrees
	
	return instance

## Preloads all assets to avoid runtime loading delays
func preload_all_assets() -> void:
	var total_assets = _asset_paths.size()
	var loaded_count = 0
	
	print("Preloading %d assets..." % total_assets)
	
	for asset_id in _asset_paths:
		if not asset_id in _assets:
			var asset_path = asset_base_path + _asset_paths[asset_id]
			if _load_asset(asset_id, asset_path):
				loaded_count += 1
	
	print("Preloaded %d/%d assets successfully" % [loaded_count, total_assets])

## Validates all registered assets
func validate_assets() -> bool:
	var is_valid = true
	var invalid_assets: Array[String] = []
	
	for asset_id in _assets:
		var asset = _assets[asset_id]
		if not asset or not asset is PackedScene:
			invalid_assets.append(asset_id)
			is_valid = false
	
	if not invalid_assets.is_empty():
		push_error("Invalid assets found: %s" % invalid_assets)
	
	return is_valid

## Clears all loaded assets from memory
func clear_assets() -> void:
	_assets.clear()
	print("Cleared all loaded assets from memory")

## Gets asset loading statistics
func get_asset_stats() -> Dictionary:
	var stats = {}
	stats["total_registered_paths"] = _asset_paths.size()
	stats["loaded_assets"] = _assets.size()
	stats["unloaded_assets"] = _asset_paths.size() - _assets.size()
	
	# Category breakdown
	var category_counts = {}
	for category in AssetCategory.values():
		var category_name = AssetCategory.keys()[category]
		category_counts[category_name] = get_assets_by_category(category).size()
	stats["category_breakdown"] = category_counts
	
	return stats

## Prints asset loading statistics
func print_asset_stats() -> void:
	var stats = get_asset_stats()
	print("=== Asset Library Statistics ===")
	print("Total registered paths: %d" % stats["total_registered_paths"])
	print("Loaded assets: %d" % stats["loaded_assets"])
	print("Unloaded assets: %d" % stats["unloaded_assets"])
	
	print("Category breakdown:")
	var category_breakdown = stats["category_breakdown"]
	for category_name in category_breakdown:
		print("  %s: %d" % [category_name, category_breakdown[category_name]])

## Sets a custom base path for assets
func set_asset_base_path(path: String) -> void:
	asset_base_path = path
	if not asset_base_path.ends_with("/"):
		asset_base_path += "/"
	
	print("Asset base path set to: %s" % asset_base_path)

## Adds a custom asset path mapping
func add_asset_path(asset_id: String, relative_path: String) -> void:
	_asset_paths[asset_id] = relative_path
	
	if OS.is_debug_build():
		print("Added asset path: %s -> %s" % [asset_id, relative_path])

## Removes an asset path mapping
func remove_asset_path(asset_id: String) -> bool:
	if asset_id in _asset_paths:
		_asset_paths.erase(asset_id)
		return true
	
	return false

## Creates placeholder assets for missing files
func create_placeholder_assets() -> void:
	print("Creating placeholder assets for missing files...")
	
	var placeholders_created = 0
	
	for asset_id in _asset_paths:
		if not asset_id in _assets:
			var asset_path = asset_base_path + _asset_paths[asset_id]
			if not ResourceLoader.exists(asset_path):
				var placeholder = _create_placeholder_scene(asset_id)
				if placeholder:
					_assets[asset_id] = placeholder
					placeholders_created += 1
	
	print("Created %d placeholder assets" % placeholders_created)

## Creates a placeholder scene for a missing asset
func _create_placeholder_scene(asset_id: String) -> PackedScene:
	var scene = PackedScene.new()
	var root = Node3D.new()
	root.name = "Placeholder_%s" % asset_id
	
	# Create a simple colored cube as placeholder
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 1.0)
	mesh_instance.mesh = box_mesh
	
	# Color based on asset type
	var material = StandardMaterial3D.new()
	if "floor" in asset_id:
		material.albedo_color = Color.BROWN
	elif "wall" in asset_id:
		material.albedo_color = Color.GRAY
	elif "door" in asset_id:
		material.albedo_color = Color.BLUE
	elif "window" in asset_id:
		material.albedo_color = Color.CYAN
	else:
		material.albedo_color = Color.MAGENTA  # Obvious placeholder color
	
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	
	scene.pack(root)
	return scene