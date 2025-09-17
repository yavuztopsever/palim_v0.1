extends Camera3D

# Static isometric camera that automatically fits and centers the entire scene

func _ready():
	# Set orthographic projection for isometric look
	projection = PROJECTION_ORTHOGONAL

	# Setup static isometric view
	setup_static_view()

func setup_static_view():
	# Standard isometric angle for games
	rotation_degrees = Vector3(-30, 45, 0)

	# Scene bounds (walls are at ±10, so total width is 20)
	var scene_width = 20.0
	var scene_depth = 20.0

	# For isometric view, we need to account for diagonal viewing
	# The diagonal of the scene is what we need to fit
	var scene_diagonal = sqrt(scene_width * scene_width + scene_depth * scene_depth)

	# Orthographic size should be enough to see everything
	# Using diagonal as base with some extra margin
	size = scene_diagonal * 0.8  # This should frame the scene nicely

	# Center of the scene (should be at origin)
	var scene_center = Vector3(0, 0, 0)

	# For proper isometric view, camera needs to be positioned correctly
	# Using standard isometric camera positioning
	var camera_distance = 30.0  # Fixed distance for consistent view
	var camera_height = 25.0    # Height above scene

	# Calculate camera position for 45-degree rotation
	# This positions the camera to look from the south-east corner
	var cam_offset = Vector3(
		camera_distance,
		camera_height,
		camera_distance
	)

	# Set camera position
	global_position = scene_center + cam_offset

	# Look at the center of the scene
	look_at(scene_center, Vector3.UP)

	# Override with proper isometric rotation
	# This ensures consistent isometric angle
	rotation_degrees = Vector3(-30, 45, 0)

	print("Camera centered on scene")
	print("Scene center: ", scene_center)
	print("Camera size: ", size)
	print("Camera position: ", global_position)
	print("Camera rotation: ", rotation_degrees)
