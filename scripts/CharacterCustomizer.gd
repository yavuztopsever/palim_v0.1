extends Control
class_name CharacterCustomizer

# Simple character customization tool for the editor

@export var target_character: Node3D
@export var character_config: CharacterConfig

@onready var name_input: LineEdit
@onready var scale_spinbox: SpinBox
@onready var speed_spinbox: SpinBox
@onready var color_picker: ColorPicker

var preview_character: Node3D

func _ready():
	setup_ui()
	if character_config:
		load_config_to_ui()

func setup_ui():
	# This would be connected to actual UI elements in a real implementation
	# For now, it's a placeholder for the customization interface
	pass

func load_config_to_ui():
	if not character_config:
		return
	
	# Load configuration values into UI elements
	# This would populate the actual UI controls
	pass

func apply_changes():
	if not character_config or not target_character:
		return
	
	# Apply the configuration to the target character
	if target_character.has_method("set_character_config"):
		target_character.set_character_config(character_config)

func create_preview():
	# Create a preview character for testing customizations
	if preview_character:
		preview_character.queue_free()
	
	preview_character = CharacterFactory.create_npc(CharacterFactory.CharacterType.CUSTOM, character_config)
	add_child(preview_character)

# Example customization functions
func set_character_name(new_name: String):
	if character_config:
		character_config.character_name = new_name

func set_character_scale(scale: float):
	if character_config:
		character_config.scale_multiplier = Vector3(scale, scale, scale)

func set_movement_speed(speed: float):
	if character_config:
		character_config.movement_speed = speed

func set_primary_color(color: Color):
	if character_config:
		character_config.set_color_tint("primary", color)

func set_secondary_color(color: Color):
	if character_config:
		character_config.set_color_tint("secondary", color)

# Save/Load functions
func save_config_to_file(path: String):
	if character_config:
		ResourceSaver.save(character_config, path)

func load_config_from_file(path: String):
	var loaded_config = load(path)
	if loaded_config is CharacterConfig:
		character_config = loaded_config
		load_config_to_ui()

# Preset functions
func apply_guard_preset():
	character_config = CharacterFactory.get_default_config_for_type(CharacterFactory.CharacterType.GUARD)
	load_config_to_ui()

func apply_merchant_preset():
	character_config = CharacterFactory.get_default_config_for_type(CharacterFactory.CharacterType.MERCHANT)
	load_config_to_ui()

func apply_villager_preset():
	character_config = CharacterFactory.get_default_config_for_type(CharacterFactory.CharacterType.VILLAGER)
	load_config_to_ui()