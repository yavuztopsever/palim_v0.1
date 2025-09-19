extends Camera3D

# Standard camera configuration for isometric view
@export_group("Scene Configuration")
@export var target_center: Vector3 = Vector3.ZERO
@export var target_size: Vector2 = Vector2(20.0, 20.0)

@export_group("Camera Settings")
@export var base_view_padding: float = 1.15
@export var height_multiplier: float = 1.1
@export var distance_multiplier: float = 0.85

@export_group("Zoom Settings")
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_smoothing: float = 10.0

# Internal zoom state
var current_zoom: float = 1.0
var target_zoom: float = 1.0
var base_size: float = 0.0

func _ready():
	projection = PROJECTION_ORTHOGONAL
	setup_static_view()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			reset_zoom()

func _process(delta):
	# Smooth zoom interpolation
	if abs(current_zoom - target_zoom) > 0.01:
		current_zoom = lerp(current_zoom, target_zoom, zoom_smoothing * delta)
		update_zoom()

func zoom_in():
	target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)

func zoom_out():
	target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)

func reset_zoom():
	target_zoom = 1.0

func update_zoom():
	if base_size > 0:
		size = base_size * current_zoom

func configure_for_scene(center: Vector3, width: float, depth: float) -> void:
	target_center = center
	target_size = Vector2(max(width, 1.0), max(depth, 1.0))
	if is_inside_tree():
		call_deferred("setup_static_view")

# Standard camera configurations for different location types
func configure_for_location_type(location_type: String, center: Vector3 = Vector3.ZERO):
	match location_type:
		"indoor_small":  # Like PlayerHouse
			configure_for_scene(center, 12, 10)
		"indoor_medium": # Like TestRoom
			configure_for_scene(center, 20, 20)
		"outdoor_large": # Like TownSquare
			configure_for_scene(center, 30, 30)
		"outdoor_huge":  # For large outdoor areas
			configure_for_scene(center, 50, 50)
		_:  # Default medium indoor
			configure_for_scene(center, 20, 20)

func setup_static_view():
	var scene_width: float = float(max(target_size.x, 1.0))
	var scene_depth: float = float(max(target_size.y, 1.0))
	var diagonal: float = sqrt(scene_width * scene_width + scene_depth * scene_depth)
	
	# Calculate base size (before zoom)
	base_size = diagonal * 0.55 * base_view_padding
	size = base_size * current_zoom
	
	var camera_distance: float = diagonal * distance_multiplier * base_view_padding
	var camera_height: float = float(max(scene_width, scene_depth)) * height_multiplier
	
	var cam_offset: Vector3 = Vector3(camera_distance, camera_height, camera_distance)
	global_position = target_center + cam_offset
	look_at(target_center, Vector3.UP)
	rotation_degrees = Vector3(-30, 45, 0)
	current = true

func set_view_padding(padding: float) -> void:
	base_view_padding = max(0.5, padding)
	if is_inside_tree():
		call_deferred("setup_static_view")

# Get current zoom level (for UI display)
func get_zoom_level() -> float:
	return current_zoom

# Set zoom level directly (for save/load)
func set_zoom_level(zoom: float):
	target_zoom = clamp(zoom, min_zoom, max_zoom)
	current_zoom = target_zoom
	update_zoom()
