@tool
extends Control

# UI References
@onready var area_type_option: OptionButton = $VBoxContainer/AreaTypeOption
@onready var width_spinbox: SpinBox = $VBoxContainer/SizeContainer/WidthSpinBox
@onready var height_spinbox: SpinBox = $VBoxContainer/SizeContainer/HeightSpinBox
@onready var interior_checkbox: CheckBox = $VBoxContainer/InteriorCheckBox
@onready var seed_spinbox: SpinBox = $VBoxContainer/SeedSpinBox
@onready var generate_button: Button = $VBoxContainer/GenerateButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready():
	# Setup area type options
	area_type_option.add_item("Residential")
	area_type_option.add_item("Commercial") 
	area_type_option.add_item("Administrative")
	area_type_option.add_item("Mixed")
	area_type_option.selected = 3  # Default to Mixed
	
	# Connect the generate button
	generate_button.pressed.connect(_on_generate_pressed)
	
	# Set default seed to random value
	seed_spinbox.value = randi() % 100000

func _on_generate_pressed():
	status_label.text = "Generation not implemented yet"
	print("Scene generation requested with parameters:")
	print("  Area Type: ", area_type_option.get_item_text(area_type_option.selected))
	print("  Size: ", width_spinbox.value, "x", height_spinbox.value)
	print("  Interior Spaces: ", interior_checkbox.button_pressed)
	print("  Seed: ", seed_spinbox.value)