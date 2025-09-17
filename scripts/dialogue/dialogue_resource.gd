extends Resource
class_name DialogueResource

@export var lines: Array[DialogueLine] = []

func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for line in lines:
		if line == null:
			continue
		entries.append({
			"speaker": line.speaker,
			"text": line.text
		})
	return entries
