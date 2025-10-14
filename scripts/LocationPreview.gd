extends Node3D

@export var location_type: String = "indoor_small"
@export var player_scene: PackedScene = preload("res://scenes/characters/ModularPlayer.tscn")
@export var camera_scene: PackedScene = preload("res://scenes/util/PreviewCamera.tscn")

func _ready():
	if Engine.is_editor_hint():
		return
	# Skip preview spawning if the game already injected a player (e.g., via GameManager).
	if get_tree().get_first_node_in_group("player"):
		return
	var spawn_point := find_child("PlayerSpawn", true, false)
	_spawn_player(spawn_point)
	_spawn_camera(spawn_point)

func _spawn_player(spawn_point: Node):
	if not player_scene:
		return
	var player = player_scene.instantiate()
	player.name = "PreviewPlayer"
	add_child(player)
	if spawn_point and spawn_point is Node3D:
		player.global_transform = (spawn_point as Node3D).global_transform
	if player.has_method("stop_movement"):
		player.stop_movement()

func _spawn_camera(spawn_point: Node):
	if get_tree().get_first_node_in_group("camera"):
		return
	if not camera_scene:
		return
	var camera = camera_scene.instantiate()
	camera.name = "PreviewCamera"
	add_child(camera)
	var center := Vector3.ZERO
	if spawn_point and spawn_point is Node3D:
		center = (spawn_point as Node3D).global_transform.origin
	if camera.has_method("configure_for_location_type"):
		camera.configure_for_location_type(location_type, center)
