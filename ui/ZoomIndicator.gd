extends Control

@onready var zoom_label: Label = $ZoomLabel
var camera_controller: Camera3D
var fade_timer: float = 0.0
var fade_duration: float = 2.0

func _ready():
	# Find the camera controller
	camera_controller = get_tree().get_first_node_in_group("camera")
	if not camera_controller:
		# Fallback: search for Camera3D with CameraController script
		var cameras = get_tree().get_nodes_in_group("camera")
		for cam in cameras:
			if cam.has_method("get_zoom_level"):
				camera_controller = cam
				break
	
	# Start hidden
	modulate.a = 0.0

func _process(delta):
	if camera_controller and camera_controller.has_method("get_zoom_level"):
		var zoom = camera_controller.get_zoom_level()
		zoom_label.text = "Zoom: %d%%" % (100 / zoom)
		
		# Show indicator when zoom changes
		if abs(zoom - 1.0) > 0.01:  # Not at default zoom
			show_indicator()
		
		# Handle fade out
		if fade_timer > 0:
			fade_timer -= delta
			if fade_timer <= 0:
				fade_out()

func show_indicator():
	modulate.a = 1.0
	fade_timer = fade_duration

func fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			show_indicator()