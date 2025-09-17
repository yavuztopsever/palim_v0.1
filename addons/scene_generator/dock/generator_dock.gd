@tool
extends Control

# UI References
@onready var area_type_option: OptionButton = $VBoxContainer/AreaTypeOption
@onready var width_spinbox: SpinBox = $VBoxContainer/SizeContainer/WidthSpinBox
@onready var height_spinbox: SpinBox = $VBoxContainer/SizeContainer/HeightSpinBox
@onready var interior_checkbox: CheckBox = $VBoxContainer/InteriorCheckBox
@onready var seed_spinbox: SpinBox = $VBoxContainer/SeedContainer/SeedSpinBox
@onready var new_seed_button: Button = $VBoxContainer/SeedContainer/NewSeedButton
@onready var generate_button: Button = $VBoxContainer/GenerateButton
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Cleanup UI (created programmatically)
var cleanup_button: Button

# Generation components
var layout_generator: LayoutGenerator

# Area type mapping
const AREA_TYPE_MAP = {
	0: "residential",
	1: "commercial", 
	2: "administrative",
	3: "mixed"
}

func _ready():
	# Setup area type options
	area_type_option.add_item("Residential")
	area_type_option.add_item("Commercial") 
	area_type_option.add_item("Administrative")
	area_type_option.add_item("Mixed")
	area_type_option.selected = 3  # Default to Mixed
	
	# Setup size constraints
	width_spinbox.min_value = GenerationParams.MIN_SIZE.x
	width_spinbox.max_value = GenerationParams.MAX_SIZE.x
	height_spinbox.min_value = GenerationParams.MIN_SIZE.y
	height_spinbox.max_value = GenerationParams.MAX_SIZE.y
	
	# Setup seed constraints
	seed_spinbox.min_value = GenerationParams.MIN_SEED
	seed_spinbox.max_value = GenerationParams.MAX_SEED
	
	# Connect the generate button
	generate_button.pressed.connect(_on_generate_pressed)
	
	# Connect the new seed button
	new_seed_button.pressed.connect(_on_new_seed_pressed)
	
	# Connect input validation
	width_spinbox.value_changed.connect(_on_input_changed)
	height_spinbox.value_changed.connect(_on_input_changed)
	seed_spinbox.value_changed.connect(_on_input_changed)
	area_type_option.item_selected.connect(_on_input_changed)
	interior_checkbox.toggled.connect(_on_input_changed)
	
	# Set default seed to random value
	seed_spinbox.value = randi() % 100000
	
	# Create cleanup button
	_create_cleanup_button()
	
	# Create validation button
	_create_validation_button()
	
	# Initialize generators
	layout_generator = LayoutGenerator.new()
	
	# Update status
	_update_status("Ready")
	
	# Hide progress bar initially
	progress_bar.visible = false

func _on_generate_pressed():
	# Disable generate button during generation
	generate_button.disabled = true
	_update_status("Preparing generation...")
	
	# Create generation parameters from UI
	var params = _create_generation_params()
	if not params:
		generate_button.disabled = false
		return
	
	# Get current scene root
	var scene_root = _get_scene_root()
	if not scene_root:
		_show_error("No scene is currently open. Please create or open a scene first.")
		generate_button.disabled = false
		return
	
	# Start generation process
	await _generate_scene_async(scene_root, params)
	
	# Re-enable generate button
	generate_button.disabled = false

func _create_generation_params() -> GenerationParams:
	var params = GenerationParams.new()
	
	# Set area type
	var area_type_index = area_type_option.selected
	if area_type_index in AREA_TYPE_MAP:
		params.area_type = AREA_TYPE_MAP[area_type_index]
	else:
		params.area_type = "mixed"
	
	# Set size
	params.size = Vector2i(int(width_spinbox.value), int(height_spinbox.value))
	
	# Set interior spaces
	params.interior_spaces = interior_checkbox.button_pressed
	
	# Set seed
	params.seed = int(seed_spinbox.value)
	
	# Validate parameters
	if not params.validate_all_params():
		_show_error("Invalid generation parameters. Please check your inputs.")
		return null
	
	return params

func _get_scene_root() -> Node3D:
	# Get the current scene from the editor
	var editor_selection = EditorInterface.get_selection()
	var selected_nodes = editor_selection.get_selected_nodes()
	
	# If nodes are selected, use the first selected Node3D as root
	if selected_nodes.size() > 0:
		for node in selected_nodes:
			if node is Node3D:
				return node
	
	# Otherwise, try to get the scene root
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene and current_scene is Node3D:
		return current_scene
	
	# If scene root is not Node3D, look for a Node3D child
	if current_scene:
		for child in current_scene.get_children():
			if child is Node3D:
				return child
	
	return null

func _generate_scene_async(root: Node3D, params: GenerationParams) -> void:
	# Show progress bar
	progress_bar.visible = true
	progress_bar.value = 0
	
	# Step 1: Create container for generated content
	_update_status("Preparing scene...")
	_update_progress(10)
	await get_tree().process_frame
	
	var generated_container = _create_generated_container(root, params)
	if not generated_container:
		_show_error("Failed to create container for generated content")
		progress_bar.visible = false
		return
	
	# Step 2: Generate complete scene (layout, assets, furniture, lighting)
	_update_status("Generating scene...")
	_update_progress(25)
	await get_tree().process_frame  # Allow UI to update
	
	if not _safe_generate_step(layout_generator, generated_container, params, "scene generation"):
		return
	
	# Step 3: Finalize and mark as generated content
	_update_progress(90)
	_update_status("Finalizing...")
	await get_tree().process_frame
	
	_finalize_generated_content(generated_container, params)
	
	# Step 4: Complete
	_update_progress(100)
	_update_status("Generation complete! Generated %s" % params.get_area_description())
	
	# Update cleanup button state
	_update_cleanup_button_state()
	
	# Hide progress bar after a short delay
	await get_tree().create_timer(1.0).timeout
	progress_bar.visible = false
	
	# Log success
	print("Scene generation completed successfully:")
	print("  Area Type: ", params.area_type)
	print("  Size: ", params.size)
	print("  Interior Spaces: ", params.interior_spaces)
	print("  Seed: ", params.seed)

func _safe_generate_step(generator: BaseGenerator, root: Node3D, params: GenerationParams, step_name: String) -> bool:
	# GDScript doesn't have try/except, so we'll handle errors through validation
	if not generator or not root or not params:
		var error_msg = "Failed during %s. Invalid parameters." % step_name
		progress_bar.visible = false
		_show_error(error_msg)
		print("Scene generation failed during %s - invalid parameters" % step_name)
		return false
	
	generator.generate_scene(root, params)
	return true

## Creates a container node for generated content
func _create_generated_container(parent: Node3D, params: GenerationParams) -> Node3D:
	# Check if there's already generated content and offer to replace it
	var existing_container = _find_existing_generated_container(parent)
	if existing_container:
		var should_replace = _confirm_replace_existing_content()
		if should_replace:
			existing_container.queue_free()
		else:
			return null  # User cancelled
	
	# Create new container
	var container = Node3D.new()
	container.name = _generate_container_name(params)
	
	# Add metadata to identify this as generated content
	container.set_meta("scene_generator_content", true)
	container.set_meta("generation_params", params)
	container.set_meta("generation_time", Time.get_unix_time_from_system())
	
	parent.add_child(container)
	container.owner = parent.get_tree().edited_scene_root
	
	return container

## Finds existing generated container in the parent node
func _find_existing_generated_container(parent: Node3D) -> Node3D:
	for child in parent.get_children():
		if child.has_meta("scene_generator_content"):
			return child
	return null

## Confirms with user whether to replace existing generated content
func _confirm_replace_existing_content() -> bool:
	# For now, automatically replace. In a full implementation, 
	# this could show a confirmation dialog
	return true

## Generates a descriptive name for the container
func _generate_container_name(params: GenerationParams) -> String:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	return "Generated_%s_%dx%d_%s" % [
		params.area_type.capitalize(),
		params.size.x,
		params.size.y,
		timestamp.split("T")[1].split(".")[0]  # Just the time part
	]

## Finalizes the generated content for proper scene integration
func _finalize_generated_content(container: Node3D, params: GenerationParams) -> void:
	# Ensure all children have proper ownership for saving
	_set_ownership_recursive(container, container.get_tree().edited_scene_root)
	
	# Add a cleanup script component for easy removal
	_add_cleanup_component(container)
	
	# Mark the scene as modified so user knows to save
	EditorInterface.mark_scene_as_unsaved()

## Recursively sets ownership for all nodes to ensure they save properly
func _set_ownership_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	
	for child in node.get_children():
		_set_ownership_recursive(child, owner)

## Adds a cleanup component to generated content for easy removal
func _add_cleanup_component(container: Node3D) -> void:
	# Create a simple script that adds a cleanup method
	var cleanup_script = GDScript.new()
	cleanup_script.source_code = """
extends Node3D

## Generated content cleanup utility
## This node contains procedurally generated content that can be safely removed

func cleanup_generated_content():
	print("Removing generated content: ", name)
	queue_free()

func get_generation_info() -> Dictionary:
	var info = {}
	if has_meta("generation_params"):
		var params = get_meta("generation_params") as GenerationParams
		if params:
			info["area_type"] = params.area_type
			info["size"] = params.size
			info["interior_spaces"] = params.interior_spaces
			info["seed"] = params.seed
	
	if has_meta("generation_time"):
		info["generated_at"] = Time.get_datetime_string_from_unix_time(get_meta("generation_time"))
	
	return info
"""
	
	container.set_script(cleanup_script)

## Creates the cleanup button in the UI
func _create_cleanup_button() -> void:
	cleanup_button = Button.new()
	cleanup_button.text = "Clean Up Generated Content"
	cleanup_button.tooltip_text = "Remove all generated content from the current scene"
	cleanup_button.pressed.connect(_on_cleanup_pressed)
	
	# Add to the VBoxContainer after the status label
	var vbox = $VBoxContainer
	vbox.add_child(cleanup_button)
	vbox.move_child(cleanup_button, vbox.get_child_count() - 1)
	
	# Initially disabled until we detect generated content
	_update_cleanup_button_state()

## Updates the cleanup button state based on whether generated content exists
func _update_cleanup_button_state() -> void:
	if not cleanup_button:
		return
	
	var scene_root = _get_scene_root()
	if scene_root:
		var has_generated_content = _has_generated_content_in_scene(scene_root)
		cleanup_button.disabled = not has_generated_content
		
		if has_generated_content:
			var count = _count_generated_containers(scene_root)
			cleanup_button.text = "Clean Up Generated Content (%d)" % count
		else:
			cleanup_button.text = "Clean Up Generated Content"

## Checks if the scene has any generated content
func _has_generated_content_in_scene(root: Node) -> bool:
	return _find_all_generated_containers(root).size() > 0

## Counts generated containers in the scene
func _count_generated_containers(root: Node) -> int:
	return _find_all_generated_containers(root).size()

## Finds all generated containers in the scene tree
func _find_all_generated_containers(node: Node) -> Array[Node3D]:
	var containers: Array[Node3D] = []
	
	if node.has_meta("scene_generator_content"):
		containers.append(node as Node3D)
	
	for child in node.get_children():
		containers.append_array(_find_all_generated_containers(child))
	
	return containers

## Handles cleanup button press
func _on_cleanup_pressed() -> void:
	var scene_root = _get_scene_root()
	if not scene_root:
		_show_error("No scene root found for cleanup")
		return
	
	var containers = _find_all_generated_containers(scene_root)
	if containers.is_empty():
		_show_error("No generated content found to clean up")
		return
	
	# Show confirmation and info about what will be removed
	var info_text = "Found %d generated content container(s):\n" % containers.size()
	for container in containers:
		var gen_info = container.call("get_generation_info") if container.has_method("get_generation_info") else {}
		var area_type = gen_info.get("area_type", "unknown")
		var size = gen_info.get("size", Vector2i.ZERO)
		info_text += "- %s (%s %dx%d)\n" % [container.name, area_type, size.x, size.y]
	
	print("Cleanup info:\n", info_text)
	
	# Remove all generated containers
	for container in containers:
		print("Removing generated content: ", container.name)
		container.queue_free()
	
	# Mark scene as modified
	EditorInterface.mark_scene_as_unsaved()
	
	# Update UI
	_update_cleanup_button_state()
	_update_status("Cleaned up %d generated content container(s)" % containers.size())

func _update_status(message: String) -> void:
	status_label.text = message
	status_label.modulate = Color.WHITE

func _update_progress(value: float) -> void:
	progress_bar.value = value

func _show_error(message: String) -> void:
	status_label.text = "Error: " + message
	status_label.modulate = Color.RED
	push_error("Scene Generator: " + message)

func _on_input_changed(_value = null) -> void:
	# Validate inputs and update UI state
	var is_valid = _validate_inputs()
	generate_button.disabled = not is_valid or generate_button.disabled
	
	if is_valid:
		var params = _create_generation_params()
		if params:
			_update_status("Ready - " + params.get_area_description())
	else:
		_update_status("Invalid parameters")

func _validate_inputs() -> bool:
	# Check size constraints
	if width_spinbox.value < GenerationParams.MIN_SIZE.x or width_spinbox.value > GenerationParams.MAX_SIZE.x:
		return false
	if height_spinbox.value < GenerationParams.MIN_SIZE.y or height_spinbox.value > GenerationParams.MAX_SIZE.y:
		return false
	
	# Check seed constraints
	if seed_spinbox.value < GenerationParams.MIN_SEED or seed_spinbox.value > GenerationParams.MAX_SEED:
		return false
	
	# Check area type selection
	if area_type_option.selected < 0 or area_type_option.selected >= area_type_option.get_item_count():
		return false
	
	return true

func _on_new_seed_pressed() -> void:
	seed_spinbox.value = randi() % int(GenerationParams.MAX_SEED)

## Called when the dock becomes visible
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Update cleanup button state when dock becomes visible
		call_deferred("_update_cleanup_button_state")

## Handles scene changes in the editor
func _on_scene_changed() -> void:
	_update_cleanup_button_state()

## Creates the validation button in the UI
func _create_validation_button() -> void:
	var validation_button = Button.new()
	validation_button.text = "Run Validation Tests"
	validation_button.tooltip_text = "Run tests to validate plugin functionality"
	validation_button.pressed.connect(_on_validation_pressed)
	
	# Add to the VBoxContainer
	var vbox = $VBoxContainer
	vbox.add_child(validation_button)
	vbox.move_child(validation_button, vbox.get_child_count() - 1)

## Handles validation button press
func _on_validation_pressed() -> void:
	_update_status("Running validation tests...")
	
	# Run basic validation
	var success = _run_basic_validation()
	
	if success:
		_update_status("✓ All validation tests passed")
	else:
		_update_status("✗ Some validation tests failed - check console")

## Runs basic validation tests
func _run_basic_validation() -> bool:
	print("=== Scene Generator Validation ===")
	
	var all_passed = true
	
	# Test 1: Parameter validation
	print("Testing parameter validation...")
	var params = GenerationParams.new()
	params.area_type = "residential"
	params.size = Vector2i(8, 8)
	params.seed = 12345
	
	if not params.validate_all_params():
		print("✗ Parameter validation failed")
		all_passed = false
	else:
		print("✓ Parameter validation passed")
	
	# Test 2: Basic generation
	print("Testing basic generation...")
	var test_scene = Node3D.new()
	var generator = LayoutGenerator.new()
	generator.generate_scene(test_scene, params)
	
	if test_scene.get_child_count() == 0:
		print("✗ No content generated")
		all_passed = false
	else:
		print("✓ Content generated (%d nodes)" % test_scene.get_child_count())
	
	# Test 3: Required components
	print("Testing required components...")
	var has_world_env = _find_node_of_type(test_scene, WorldEnvironment) != null
	var has_light = _find_node_of_type(test_scene, DirectionalLight3D) != null
	var has_meshes = _find_all_nodes_of_type(test_scene, MeshInstance3D).size() > 0
	
	if not has_world_env:
		print("✗ Missing WorldEnvironment")
		all_passed = false
	else:
		print("✓ WorldEnvironment found")
	
	if not has_light:
		print("✗ Missing DirectionalLight3D")
		all_passed = false
	else:
		print("✓ DirectionalLight3D found")
	
	if not has_meshes:
		print("✗ No mesh instances found")
		all_passed = false
	else:
		print("✓ Mesh instances found")
	
	# Test 4: Lighting configuration
	print("Testing lighting configuration...")
	var world_env = _find_node_of_type(test_scene, WorldEnvironment) as WorldEnvironment
	if world_env and world_env.environment:
		var ambient_color = world_env.environment.ambient_light_color
		if ambient_color.r > ambient_color.b:  # Should be warm for residential
			print("✓ Residential lighting is warm")
		else:
			print("⚠ Residential lighting should be warmer")
	
	test_scene.queue_free()
	
	print("=== Validation Complete ===")
	return all_passed

func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

func _find_all_nodes_of_type(node: Node, type: Variant) -> Array[Node]:
	var nodes: Array[Node] = []
	
	if is_instance_of(node, type):
		nodes.append(node)
	
	for child in node.get_children():
		nodes.append_array(_find_all_nodes_of_type(child, type))
	
	return nodes