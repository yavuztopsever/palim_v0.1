class_name WallHidingSystem
extends Node3D

## Wall hiding system component for generated walls
## Provides compatibility with existing WallCutaway.gd system
## Handles transparency, visibility, and room detection for isometric camera views

# Wall layer and room detection properties
@export var wall_layer: int = 0           # Layer for camera occlusion (0=front, 1=side, 2=back)
@export var hide_when_behind: bool = true # Hide when camera is behind this wall
@export var transparency_fade: float = 0.3 # How transparent when hiding (0.0-1.0)
@export var room_id: String = ""          # Which room this wall belongs to
@export var is_interior: bool = false     # Interior spaces don't generate roofs
@export var space_type: String = "exterior" # exterior, interior, mixed

# Wall direction for isometric hiding logic
@export var wall_direction: Vector3 = Vector3.FORWARD # Normal direction of the wall face

# Internal state
var original_materials: Array[Material] = []
var mesh_instances: Array[MeshInstance3D] = []
var is_currently_hidden: bool = false
var is_currently_transparent: bool = false

# Compatibility with existing WallCutaway system
var cutaway_mode: int = 1  # 0 = walls up, 1 = cutaway, 2 = walls down
var wall_name: String = ""  # For compatibility (NorthWall, SouthWall, etc.)

signal wall_visibility_changed(wall: WallHidingSystem, visible: bool)
signal wall_transparency_changed(wall: WallHidingSystem, transparent: bool)

func _ready():
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Initialize the wall hiding system
	_initialize_wall_system()
	
	# Register with any existing WallCutaway systems
	_register_with_cutaway_system()

## Initialize the wall hiding system
func _initialize_wall_system():
	# Find all MeshInstance3D children and store their materials
	_collect_mesh_instances(self)
	
	# Store original materials for restoration
	_store_original_materials()
	
	# Determine wall direction if not set
	if wall_direction == Vector3.ZERO:
		wall_direction = _determine_wall_direction()
	
	# Set wall layer based on direction for isometric view
	if wall_layer == 0:
		wall_layer = _calculate_wall_layer()
	
	# Generate wall name for compatibility
	if wall_name.is_empty():
		wall_name = _generate_wall_name()

## Collect all MeshInstance3D nodes recursively
func _collect_mesh_instances(node: Node):
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)
	
	for child in node.get_children():
		_collect_mesh_instances(child)

## Store original materials for later restoration
func _store_original_materials():
	original_materials.clear()
	
	for mesh_instance in mesh_instances:
		if mesh_instance.material_override:
			original_materials.append(mesh_instance.material_override)
		elif mesh_instance.get_surface_override_material(0):
			original_materials.append(mesh_instance.get_surface_override_material(0))
		else:
			original_materials.append(null)

## Determine wall direction based on geometry or position
func _determine_wall_direction() -> Vector3:
	# Try to determine direction from the wall's orientation
	var transform_basis = global_transform.basis
	
	# Check which axis is most aligned with world directions
	var forward_dot = abs(transform_basis.z.dot(Vector3.FORWARD))
	var right_dot = abs(transform_basis.z.dot(Vector3.RIGHT))
	
	if forward_dot > right_dot:
		return transform_basis.z.normalized()
	else:
		return transform_basis.x.normalized()

## Calculate wall layer for isometric hiding (0=front-facing, 1=side, 2=back-facing)
func _calculate_wall_layer() -> int:
	# For isometric view, determine if wall faces camera
	var camera_direction = Vector3(1, -1, 1).normalized()  # Typical isometric camera direction
	var dot_product = wall_direction.dot(camera_direction)
	
	if dot_product > 0.5:
		return 0  # Front-facing (should be hidden in cutaway mode)
	elif dot_product > -0.5:
		return 1  # Side-facing (partially visible)
	else:
		return 2  # Back-facing (always visible)

## Generate wall name for compatibility with existing system
func _generate_wall_name() -> String:
	# Determine wall name based on direction
	var abs_dir = wall_direction.abs()
	
	if abs_dir.z > abs_dir.x:
		return "NorthWall" if wall_direction.z > 0 else "SouthWall"
	else:
		return "EastWall" if wall_direction.x > 0 else "WestWall"

## Register with existing WallCutaway system if present
func _register_with_cutaway_system():
	# Look for WallCutaway node in the scene
	var cutaway_node = _find_cutaway_node()
	if cutaway_node:
		# Connect to the cutaway system
		_connect_to_cutaway_system(cutaway_node)

## Find WallCutaway node in the scene
func _find_cutaway_node() -> Node:
	# Search up the tree for a WallCutaway node
	var current = get_parent()
	while current:
		for child in current.get_children():
			if child.get_script() and child.get_script().get_global_name() == "WallCutaway":
				return child
		current = current.get_parent()
	
	# Search in the main scene
	var main_scene = get_tree().current_scene
	if main_scene:
		return _find_node_by_script(main_scene, "WallCutaway")
	
	return null

## Find node by script name recursively
func _find_node_by_script(node: Node, script_name: String) -> Node:
	if node.get_script() and node.get_script().get_global_name() == script_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_script(child, script_name)
		if result:
			return result
	
	return null

## Connect to existing WallCutaway system
func _connect_to_cutaway_system(cutaway_node: Node):
	# Add this wall to the cutaway system's wall list
	if cutaway_node.has_method("register_generated_wall"):
		cutaway_node.register_generated_wall(self)
	else:
		# Fallback: monitor cutaway_mode changes
		if cutaway_node.has_signal("cutaway_mode_changed"):
			cutaway_node.cutaway_mode_changed.connect(_on_cutaway_mode_changed)

## Handle cutaway mode changes from the main system
func _on_cutaway_mode_changed(mode: int):
	cutaway_mode = mode
	apply_cutaway_mode()

## Apply cutaway mode (compatible with existing WallCutaway system)
func apply_cutaway_mode():
	match cutaway_mode:
		0:  # Walls up - all visible
			set_wall_visibility(true)
			set_wall_transparency(false)
		1:  # Cutaway - hide front-facing walls
			var should_hide = (wall_layer == 0 and hide_when_behind)
			set_wall_visibility(not should_hide)
			set_wall_transparency(should_hide and transparency_fade > 0)
		2:  # Walls down - all hidden
			set_wall_visibility(false)
			set_wall_transparency(false)

## Set wall visibility (compatible with existing system)
func set_wall_visibility(visible_state: bool):
	if is_currently_hidden == not visible_state:
		return  # No change needed
	
	is_currently_hidden = not visible_state
	self.visible = visible_state
	
	# Emit signal for other systems
	wall_visibility_changed.emit(self, visible_state)

## Set wall transparency
func set_wall_transparency(transparent: bool):
	if is_currently_transparent == transparent:
		return  # No change needed
	
	is_currently_transparent = transparent
	
	if transparent:
		_apply_transparency()
	else:
		_restore_original_materials()
	
	# Emit signal for other systems
	wall_transparency_changed.emit(self, transparent)

## Apply transparency to all materials
func _apply_transparency():
	for i in range(mesh_instances.size()):
		var mesh_instance = mesh_instances[i]
		var original_material = original_materials[i] if i < original_materials.size() else null
		
		if original_material:
			# Create transparent version of the material
			var transparent_material = _create_transparent_material(original_material)
			mesh_instance.material_override = transparent_material
		else:
			# Create default transparent material
			var transparent_material = _create_default_transparent_material()
			mesh_instance.material_override = transparent_material

## Create transparent version of a material
func _create_transparent_material(original: Material) -> Material:
	var transparent_material: StandardMaterial3D
	
	if original is StandardMaterial3D:
		transparent_material = (original as StandardMaterial3D).duplicate()
	else:
		transparent_material = StandardMaterial3D.new()
		if original is BaseMaterial3D:
			var base_mat = original as BaseMaterial3D
			transparent_material.albedo_color = base_mat.albedo_color
	
	# Apply transparency
	transparent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent_material.albedo_color.a = transparency_fade
	
	return transparent_material

## Create default transparent material
func _create_default_transparent_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.7, transparency_fade)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

## Restore original materials
func _restore_original_materials():
	for i in range(mesh_instances.size()):
		var mesh_instance = mesh_instances[i]
		var original_material = original_materials[i] if i < original_materials.size() else null
		
		mesh_instance.material_override = original_material

## Check if wall should be hidden based on camera position
func should_hide_for_camera(camera_position: Vector3) -> bool:
	if not hide_when_behind:
		return false
	
	# Calculate if camera is behind this wall
	var wall_to_camera = (camera_position - global_position).normalized()
	var dot_product = wall_direction.dot(wall_to_camera)
	
	# Hide if camera is behind the wall (negative dot product)
	return dot_product < -0.1

## Check if this wall blocks view to a position
func blocks_view_to_position(camera_position: Vector3, target_position: Vector3) -> bool:
	# Simple check if wall is between camera and target
	var camera_to_target = target_position - camera_position
	var camera_to_wall = global_position - camera_position
	
	# Check if wall is roughly between camera and target
	var projection = camera_to_wall.project(camera_to_target)
	var distance_to_line = (camera_to_wall - projection).length()
	
	# If wall is close to the line of sight, it might block the view
	return distance_to_line < 2.0 and projection.length() < camera_to_target.length()

## Get room information for this wall
func get_room_info() -> Dictionary:
	return {
		"room_id": room_id,
		"is_interior": is_interior,
		"space_type": space_type,
		"wall_layer": wall_layer,
		"wall_direction": wall_direction
	}

## Set room information for this wall
func set_room_info(info: Dictionary):
	if info.has("room_id"):
		room_id = info.room_id
	if info.has("is_interior"):
		is_interior = info.is_interior
	if info.has("space_type"):
		space_type = info.space_type
	if info.has("wall_layer"):
		wall_layer = info.wall_layer
	if info.has("wall_direction"):
		wall_direction = info.wall_direction

## Update wall hiding based on current conditions
func update_wall_hiding():
	# This can be called by external systems to refresh wall state
	apply_cutaway_mode()

## Debug information
func get_debug_info() -> String:
	return "WallHidingSystem: %s, Layer: %d, Direction: %s, Room: %s, Interior: %s" % [
		wall_name, wall_layer, wall_direction, room_id, is_interior
	]