@tool
extends EditorPlugin

const GeneratorDock = preload("res://addons/scene_generator/dock/generator_dock.tscn")
var dock

func _enter_tree():
	# Add the custom dock to the left UL dock
	dock = GeneratorDock.instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	# Clean up
	if dock:
		remove_control_from_docks(dock)
		dock = null