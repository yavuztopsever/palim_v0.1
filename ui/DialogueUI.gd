extends CanvasLayer
class_name DialogueUI

signal dialogue_finished(npc)

var dialogue_entries: Array[Dictionary] = []
var current_index: int = 0
var active_npc: Node = null
var active_npc_name: String = ""

@onready var root_control: Control = $Root
@onready var speaker_label: Label = $Root/Panel/VBoxContainer/SpeakerLabel
@onready var dialogue_text: RichTextLabel = $Root/Panel/VBoxContainer/DialogueText
@onready var choices_container: VBoxContainer = $Root/Panel/VBoxContainer/ChoicesContainer
@onready var continue_button: Button = $Root/Panel/VBoxContainer/ContinueButton

func _ready():
	visible = false
	root_control.visible = false

func start_dialogue(npc_name: String, dialogue_resource: DialogueResource, fallback_text: String, npc: Node) -> void:
	active_npc = npc
	active_npc_name = npc_name
	dialogue_entries = []
	if dialogue_resource:
		dialogue_entries = dialogue_resource.get_entries()

	if dialogue_entries.is_empty():
		dialogue_entries.append({
			"speaker": npc_name,
			"text": fallback_text
		})

	current_index = 0
	visible = true
	root_control.visible = true
	_show_entry()
	continue_button.grab_focus()

func _show_entry() -> void:
	choices_container.hide()
	continue_button.show()

	var entry: Dictionary = dialogue_entries[current_index]
	var speaker: String = entry.get("speaker", "")
	if speaker.is_empty():
		speaker = active_npc_name
	var text: String = entry.get("text", "")

	speaker_label.text = speaker
	dialogue_text.text = text

func _on_continue_button_pressed() -> void:
	if current_index < dialogue_entries.size() - 1:
		current_index += 1
		_show_entry()
	else:
		_end_dialogue()

func _end_dialogue() -> void:
	visible = false
	root_control.visible = false
	dialogue_entries.clear()
	continue_button.release_focus()

	if active_npc:
		emit_signal("dialogue_finished", active_npc)
		active_npc = null
	active_npc_name = ""
