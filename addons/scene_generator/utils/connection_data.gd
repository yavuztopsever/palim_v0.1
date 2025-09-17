class_name ConnectionData
extends Resource

## Represents a connection between two cells in the scene layout
## Used for doors, corridors, or other linking elements

@export var from_position: Vector2i
@export var to_position: Vector2i
@export var connection_type: String = "door"
@export var properties: Dictionary = {}

# Valid connection types
const VALID_CONNECTION_TYPES = [
	"door",
	"corridor", 
	"window",
	"passage",
	"stairs"
]

func _init(from_pos: Vector2i = Vector2i.ZERO, to_pos: Vector2i = Vector2i.ZERO, type: String = "door"):
	from_position = from_pos
	to_position = to_pos
	set_connection_type(type)

func set_connection_type(type: String) -> void:
	if type in VALID_CONNECTION_TYPES:
		connection_type = type
	else:
		push_warning("Invalid connection_type: %s. Using 'door' instead." % type)
		connection_type = "door"

func get_direction() -> Vector2i:
	return to_position - from_position

func get_distance() -> float:
	var diff = to_position - from_position
	return sqrt(diff.x * diff.x + diff.y * diff.y)

func is_adjacent() -> bool:
	var diff = to_position - from_position
	return abs(diff.x) + abs(diff.y) == 1  # Manhattan distance of 1

func is_horizontal() -> bool:
	return from_position.y == to_position.y

func is_vertical() -> bool:
	return from_position.x == to_position.x

func has_property(key: String) -> bool:
	return key in properties

func get_property(key: String, default_value = null):
	return properties.get(key, default_value)

func set_property(key: String, value) -> void:
	properties[key] = value

func validate() -> bool:
	var is_valid = true
	
	if not connection_type in VALID_CONNECTION_TYPES:
		push_error("Invalid connection_type: %s" % connection_type)
		is_valid = false
	
	if from_position == to_position:
		push_error("Connection from and to positions are the same: %s" % from_position)
		is_valid = false
	
	return is_valid

func to_string() -> String:
	return "ConnectionData(%s -> %s, %s)" % [from_position, to_position, connection_type]