extends Node
class_name LocationManager

# Manages location loading and transitions
# This can be expanded with save/load, transition effects, etc.

signal location_changed(location_name: String)

var locations = {
	"test_room": "res://scenes/locations/TestRoom.tscn",
	"town_square": "res://scenes/locations/TownSquare.tscn",
	"player_house": "res://scenes/locations/PlayerHouse.tscn"
}

var current_location_name: String = ""
var current_location_node: Node3D
var location_container: Node3D

func initialize(container: Node3D):
	location_container = container

func load_location_by_name(location_name: String):
	if location_name in locations:
		var path = locations[location_name]
		return load_location(path, location_name)
	else:
		print("Location not found: ", location_name)
		return false

func load_location(location_path: String, location_name: String = ""):
	print("Loading location: ", location_path)
	
	# Remove current location if it exists
	if current_location_node:
		current_location_node.queue_free()
		current_location_node = null
	
	# Load and instantiate new location
	var location_scene = load(location_path)
	if location_scene:
		current_location_node = location_scene.instantiate()
		location_container.add_child(current_location_node)
		
		current_location_name = location_name if location_name != "" else location_path.get_file().get_basename()
		
		# Emit signal for other systems to respond
		location_changed.emit(current_location_name)
		
		print("Location loaded successfully: ", current_location_name)
		return true
	else:
		print("Failed to load location: ", location_path)
		return false

func get_current_location_name() -> String:
	return current_location_name

func get_current_location_node() -> Node3D:
	return current_location_node