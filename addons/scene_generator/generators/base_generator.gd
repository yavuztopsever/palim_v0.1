class_name BaseGenerator
extends RefCounted

## Abstract base class for scene generators
## Provides common interface and utilities for all generator types

# Grid system constants
const GRID_SIZE: float = 2.0  # 2-meter grid cells

## Abstract method - must be implemented by subclasses
## Generates a scene based on the provided parameters
func generate_scene(root: Node3D, params: GenerationParams) -> void:
	assert(false, "generate_scene must be implemented by subclass")

## Grid system utilities for 2-meter cell alignment

## Snaps a world position to the nearest grid point
static func snap_to_grid(position: Vector3) -> Vector3:
	return Vector3(
		round(position.x / GRID_SIZE) * GRID_SIZE,
		round(position.y / GRID_SIZE) * GRID_SIZE,
		round(position.z / GRID_SIZE) * GRID_SIZE
	)

## Converts grid coordinates to world position
static func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * GRID_SIZE, 0, grid_pos.y * GRID_SIZE)

## Converts world position to grid coordinates
static func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / GRID_SIZE)),
		int(round(world_pos.z / GRID_SIZE))
	)

## Gets the world bounds for a given grid size
static func get_grid_bounds(grid_size: Vector2i) -> AABB:
	var world_size = Vector3(grid_size.x * GRID_SIZE, 0, grid_size.y * GRID_SIZE)
	return AABB(Vector3.ZERO, world_size)

## Helper methods for node creation and positioning

## Creates a new Node3D and positions it at grid coordinates
func create_node_at_grid(grid_pos: Vector2i, scene_to_instance: PackedScene = null) -> Node3D:
	var node: Node3D
	
	if scene_to_instance:
		node = scene_to_instance.instantiate()
	else:
		node = Node3D.new()
	
	node.position = grid_to_world(grid_pos)
	return node

## Creates a StaticBody3D with collision at the specified grid position
func create_static_body_at_grid(grid_pos: Vector2i, collision_shape: Shape3D = null) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	static_body.position = grid_to_world(grid_pos)
	
	if collision_shape:
		var collision_shape_node = CollisionShape3D.new()
		collision_shape_node.shape = collision_shape
		static_body.add_child(collision_shape_node)
	
	return static_body

## Creates a MeshInstance3D at the specified grid position
func create_mesh_at_grid(grid_pos: Vector2i, mesh: Mesh = null) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.position = grid_to_world(grid_pos)
	
	if mesh:
		mesh_instance.mesh = mesh
	
	return mesh_instance

## Validates that a grid position is within bounds
func is_valid_grid_position(grid_pos: Vector2i, bounds: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < bounds.x and grid_pos.y >= 0 and grid_pos.y < bounds.y

## Gets all grid positions within the specified bounds
func get_all_grid_positions(bounds: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	
	for x in range(bounds.x):
		for y in range(bounds.y):
			positions.append(Vector2i(x, y))
	
	return positions

## Sets up basic scene foundation (lighting, environment)
func setup_scene_foundation(root: Node3D, params: GenerationParams) -> void:
	# Set up comprehensive lighting system
	LightingSetup.setup_scene_lighting(root, params)

## Checks if the scene already has a WorldEnvironment
func _has_world_environment(root: Node3D) -> bool:
	return _find_node_of_type(root, WorldEnvironment) != null

## Recursively finds a node of the specified type
func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null