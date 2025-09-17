class_name GenerationParams
extends Resource

## Generation parameters for scene creation
## Defines area type, size, seed, and interior space configuration

@export var area_type: String = "mixed" : set = set_area_type
@export var size: Vector2i = Vector2i(10, 10) : set = set_size
@export var seed: int = 0 : set = set_seed
@export var interior_spaces: bool = true

# Valid area types
const VALID_AREA_TYPES = ["residential", "commercial", "administrative", "mixed"]

# Size constraints
const MIN_SIZE = Vector2i(3, 3)
const MAX_SIZE = Vector2i(50, 50)

# Seed constraints
const MIN_SEED = 0
const MAX_SEED = 2147483647  # Max int32 value

func _init():
	validate_all_params()

func set_area_type(value: String) -> void:
	if value in VALID_AREA_TYPES:
		area_type = value
	else:
		push_warning("Invalid area_type: %s. Using 'mixed' instead." % value)
		area_type = "mixed"

func set_size(value: Vector2i) -> void:
	var clamped_size = Vector2i(
		clamp(value.x, MIN_SIZE.x, MAX_SIZE.x),
		clamp(value.y, MIN_SIZE.y, MAX_SIZE.y)
	)
	
	if clamped_size != value:
		push_warning("Size %s clamped to valid range %s-%s" % [value, MIN_SIZE, MAX_SIZE])
	
	size = clamped_size

func set_seed(value: int) -> void:
	seed = clamp(value, MIN_SEED, MAX_SEED)

func validate_all_params() -> bool:
	var is_valid = true
	
	# Validate area type
	if not area_type in VALID_AREA_TYPES:
		push_error("Invalid area_type: %s" % area_type)
		is_valid = false
	
	# Validate size
	if size.x < MIN_SIZE.x or size.x > MAX_SIZE.x or size.y < MIN_SIZE.y or size.y > MAX_SIZE.y:
		push_error("Invalid size: %s. Must be between %s and %s" % [size, MIN_SIZE, MAX_SIZE])
		is_valid = false
	
	# Validate seed
	if seed < MIN_SEED or seed > MAX_SEED:
		push_error("Invalid seed: %s. Must be between %s and %s" % [seed, MIN_SEED, MAX_SEED])
		is_valid = false
	
	return is_valid

func get_area_description() -> String:
	var interior_desc = "interior" if interior_spaces else "exterior"
	return "%s %s area (%dx%d)" % [area_type, interior_desc, size.x, size.y]