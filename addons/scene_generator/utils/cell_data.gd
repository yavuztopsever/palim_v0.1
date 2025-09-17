class_name CellData
extends Resource

## Represents data for a single grid cell in the scene layout
## Contains information about what should be placed at this position

@export var position: Vector2i
@export var cell_type: String = "empty"
@export var asset_id: String = ""
@export var rotation: int = 0  # 0, 90, 180, 270 degrees
@export var properties: Dictionary = {}

# Valid cell types
const VALID_CELL_TYPES = [
	"empty",
	"floor", 
	"wall", 
	"door", 
	"window",
	"prop",
	"furniture",
	"light"
]

# Valid rotation values
const VALID_ROTATIONS = [0, 90, 180, 270]

func _init(pos: Vector2i = Vector2i.ZERO, type: String = "empty"):
	position = pos
	set_cell_type(type)

func set_cell_type(type: String) -> void:
	if type in VALID_CELL_TYPES:
		cell_type = type
	else:
		push_warning("Invalid cell_type: %s. Using 'empty' instead." % type)
		cell_type = "empty"

func set_rotation(rot: int) -> void:
	if rot in VALID_ROTATIONS:
		rotation = rot
	else:
		# Normalize rotation to nearest valid value
		var normalized = ((rot % 360) + 360) % 360  # Ensure positive
		var closest = 0
		var min_diff = abs(normalized - 0)
		
		for valid_rot in VALID_ROTATIONS:
			var diff = abs(normalized - valid_rot)
			if diff < min_diff:
				min_diff = diff
				closest = valid_rot
		
		rotation = closest
		if closest != rot:
			push_warning("Invalid rotation: %s. Using %s instead." % [rot, closest])

func get_rotation_radians() -> float:
	return deg_to_rad(rotation)

func is_empty() -> bool:
	return cell_type == "empty"

func is_walkable() -> bool:
	return cell_type in ["empty", "floor", "door"]

func is_solid() -> bool:
	return cell_type in ["wall", "prop", "furniture"]

func has_property(key: String) -> bool:
	return key in properties

func get_property(key: String, default_value = null):
	return properties.get(key, default_value)

func set_property(key: String, value) -> void:
	properties[key] = value

func validate() -> bool:
	var is_valid = true
	
	if not cell_type in VALID_CELL_TYPES:
		push_error("Invalid cell_type: %s" % cell_type)
		is_valid = false
	
	if not rotation in VALID_ROTATIONS:
		push_error("Invalid rotation: %s" % rotation)
		is_valid = false
	
	return is_valid

func to_string() -> String:
	return "CellData(%s, %s, %s, %s°)" % [position, cell_type, asset_id, rotation]