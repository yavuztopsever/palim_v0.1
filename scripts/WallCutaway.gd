extends Node3D

const CARDINAL_VECTORS := {
	"north": Vector2(0, -1),
	"south": Vector2(0, 1),
	"east": Vector2(1, 0),
	"west": Vector2(-1, 0)
}

@export_range(0.0, 1.0) var camera_alignment_threshold: float = 0.5

var current_walls: Array[Node3D] = []
var location_manager: LocationManager
var camera: Camera3D

var walls_dirty := false
var camera_state_initialized := false
var last_camera_position: Vector3 = Vector3.ZERO
var last_camera_forward: Vector2 = Vector2.ZERO
var last_hidden_directions: Array[String] = []

func _ready():
	await get_tree().process_frame
	_cache_location_manager()
	_refresh_camera()
	find_walls_in_current_location()
	set_process(true)

func _cache_location_manager():
	var game_manager = get_parent().get_node_or_null("GameManager")
	if game_manager and game_manager.location_manager:
		location_manager = game_manager.location_manager
		location_manager.location_changed.connect(_on_location_changed)

func _on_location_changed(_location_name: String):
	await get_tree().process_frame
	find_walls_in_current_location()

func _process(_delta):
	if not is_instance_valid(camera):
		_refresh_camera()
	if current_walls.is_empty() or not is_instance_valid(camera):
		return
	
	var camera_forward = _get_camera_forward_xz()
	var camera_moved = not camera_state_initialized or camera.global_transform.origin.distance_squared_to(last_camera_position) > 0.0001
	var camera_rotated = not camera_state_initialized or camera_forward.distance_squared_to(last_camera_forward) > 0.0001
	
	if camera_moved or camera_rotated or walls_dirty:
		camera_state_initialized = true
		last_camera_position = camera.global_transform.origin
		last_camera_forward = camera_forward
		_apply_camera_facing_rules(camera_forward)
		walls_dirty = false

func find_walls_in_current_location():
	current_walls.clear()
	
	var search_root: Node = null
	if location_manager:
		search_root = location_manager.get_current_location_node()
		if search_root == null:
			search_root = location_manager.get_location_container()
	if search_root == null:
		search_root = get_node_or_null("../LocationContainer")
	if search_root == null:
		return
	
	current_walls = find_all_walls(search_root)
	walls_dirty = true

func find_all_walls(node: Node) -> Array[Node3D]:
	var walls: Array[Node3D] = []
	
	if node is CSGBox3D:
		var is_wall = false
		if node.has_meta("wall_direction"):
			is_wall = true
		elif node.name.to_lower().contains("wall"):
			is_wall = true
		if is_wall:
			walls.append(node as Node3D)
	
	for child in node.get_children():
		walls.append_array(find_all_walls(child))
	
	return walls

func _refresh_camera():
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		camera = cameras[0] as Camera3D
	else:
		camera = get_viewport().get_camera_3d()
	camera_state_initialized = false

func _get_camera_forward_xz() -> Vector2:
	if not is_instance_valid(camera):
		return Vector2.ZERO
	var forward3d = -camera.global_transform.basis.z.normalized()
	var plane_forward = Vector2(forward3d.x, forward3d.z)
	if plane_forward.length_squared() == 0.0:
		return Vector2.ZERO
	return plane_forward.normalized()

func _apply_camera_facing_rules(camera_forward: Vector2):
	var hidden_directions = _compute_hidden_directions(camera_forward)
	last_hidden_directions = hidden_directions
	
	for wall in current_walls:
		if not is_instance_valid(wall):
			continue
		var should_hide := false
		var direction = get_wall_direction(wall)
		if direction != "":
			should_hide = hidden_directions.has(direction)
		else:
			should_hide = _camera_in_front_of_wall(wall)
		set_wall_visibility(wall, not should_hide)

func _compute_hidden_directions(camera_forward: Vector2) -> Array[String]:
	var hidden: Array[String] = []
	if camera_forward.length_squared() == 0.0:
		return hidden
	var scene_to_camera = -camera_forward.normalized()
	for dir_name in CARDINAL_VECTORS.keys():
		var dir_vector: Vector2 = CARDINAL_VECTORS[dir_name]
		if scene_to_camera.dot(dir_vector) >= camera_alignment_threshold:
			hidden.append(dir_name)
	return hidden

func get_wall_direction(wall: Node3D) -> String:
	if wall.has_meta("wall_direction"):
		return str(wall.get_meta("wall_direction")).to_lower()
	var name_lower = wall.name.to_lower()
	for dir_name in CARDINAL_VECTORS.keys():
		if dir_name in name_lower:
			return dir_name
	return ""

func _camera_in_front_of_wall(wall: Node3D) -> bool:
	if not is_instance_valid(camera):
		return false
	var cam_pos = camera.global_transform.origin
	var wall_pos = wall.global_transform.origin
	var delta = cam_pos - wall_pos
	var dir_name = ""
	if abs(delta.x) > abs(delta.z):
		dir_name = "east" if delta.x > 0.0 else "west"
	else:
		dir_name = "south" if delta.z > 0.0 else "north"
	return last_hidden_directions.has(dir_name)

func set_wall_visibility(wall: Node3D, visible: bool):
	if not is_instance_valid(wall):
		return
	if wall.visible == visible:
		return
	wall.visible = visible
