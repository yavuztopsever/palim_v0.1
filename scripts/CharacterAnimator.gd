extends Node
class_name CharacterAnimator

@export var default_clips: Dictionary = {
	"idle": "Idle_Loop",
	"walk": "Walk_Loop",
	"run": "Sprint_Loop",
	"crouch": "Crouch_Idle_Loop",
	"jump": "Jump_Start",
	"attack": "Sword_Attack",
	"defend": "Pistol_Aim_Neutral",
	"talk": "Idle_Talking_Loop",
	"wave": "Interact",
	"dance": "Dance_Loop",
	"sit": "Sitting_Idle_Loop",
	"sleep": "Sitting_Idle_Loop",
	"pickup": "PickUp_Table",
	"throw": "Spell_Simple_Shoot",
	"death": "Death01"
}

var animation_player: AnimationPlayer
var available_clips: PackedStringArray = PackedStringArray()
var current_clip: String = ""
var _normalized_clip_cache: Dictionary = {}

var _overrides: Dictionary = {}
var _warned_actions: Dictionary = {}
var _owner: Node

func setup(owner: Node, model: Node3D, overrides: Dictionary = {}, speed: float = 1.0) -> void:
	_owner = owner
	animation_player = _find_animation_player(model)
	_overrides = _to_override_map(overrides)
	_warned_actions.clear()
	current_clip = ""
	if animation_player:
		available_clips = animation_player.get_animation_list()
		_rebuild_normalized_cache()
		set_speed(speed)
	else:
		available_clips = PackedStringArray()
		_normalized_clip_cache.clear()

func play(action: String, force: bool = false) -> bool:
	if not animation_player:
		return false
	var clip := _resolve_clip(action)
	if clip == "":
		if not _warned_actions.has(action):
			_warned_actions[action] = true
			push_warning("%s: animation action '%s' could not be resolved" % [_describe_owner(), action])
		return false
	var should_start := force or current_clip != clip or not animation_player.is_playing()
	if should_start:
		animation_player.play(clip)
		current_clip = clip
	return true

func stop() -> void:
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	current_clip = ""

func set_speed(speed: float) -> void:
	if not animation_player:
		return
	animation_player.speed_scale = max(speed, 0.01)

func get_speed() -> float:
	if not animation_player:
		return 0.0
	return animation_player.speed_scale

func get_available_clips() -> PackedStringArray:
	return available_clips

func get_current_clip() -> String:
	return current_clip

func refresh() -> void:
	if animation_player:
		available_clips = animation_player.get_animation_list()
	else:
		available_clips = PackedStringArray()
	_normalized_clip_cache.clear()
	if available_clips.size() > 0:
		_rebuild_normalized_cache()

func _resolve_clip(action: String) -> String:
	if action == "":
		return ""
	var lowered: String = action.to_lower()
	if _overrides.has(lowered):
		var override_value: Variant = _overrides[lowered]
		var override_clip: String = _first_existing_clip(override_value)
		if override_clip != "":
			return override_clip
	if default_clips.has(lowered):
		var default_value: Variant = default_clips[lowered]
		var default_clip: String = ""
		if default_value is String:
			default_clip = default_value
		if default_clip != "" and _clips_has(default_clip):
			return default_clip
		var alt: String = _first_existing_clip(default_value)
		if alt != "":
			return alt
	if _clips_has(action):
		return action
	return _first_existing_clip(action)

func _first_existing_clip(value: Variant) -> String:
	if value is StringName:
		return _find_clip_by_name(String(value))
	if value is String:
		return _find_clip_by_name(value)
	if value is Array:
		for entry in value:
			var clip_name: String = _first_existing_clip(entry)
			if clip_name != "":
				return clip_name
	elif value is PackedStringArray:
		for entry: String in value:
			var clip_name := _find_clip_by_name(entry)
			if clip_name != "":
				return clip_name
	return ""

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _to_override_map(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in raw.keys():
		var normalized := str(key).to_lower()
		result[normalized] = raw[key]
	return result

func _describe_owner() -> String:
	if _owner:
		return _owner.name
	return name

func _find_clip_by_name(raw_name: String) -> String:
	var clip_name := raw_name.strip_edges()
	if clip_name == "":
		return ""
	if _clips_has(clip_name):
		return clip_name
	var lowered_target := clip_name.to_lower()
	var compact_target := _compact_string(lowered_target)
	if _normalized_clip_cache.has(lowered_target):
		return _normalized_clip_cache[lowered_target]
	if compact_target != "" and _normalized_clip_cache.has(compact_target):
		return _normalized_clip_cache[compact_target]
	for candidate in available_clips:
		var match := _clip_matches(candidate, lowered_target, compact_target)
		if match != "":
			_normalized_clip_cache[lowered_target] = match
			if compact_target != "":
				_normalized_clip_cache[compact_target] = match
			return match
	return ""

func _clip_matches(candidate: String, target_lower: String, target_compact: String) -> String:
	var lowered_candidate := candidate.to_lower()
	if lowered_candidate == target_lower:
		return candidate
	if lowered_candidate.ends_with(target_lower):
		return candidate
	var tail := _clip_tail(lowered_candidate)
	if tail == target_lower or (tail != "" and tail.begins_with(target_lower)):
		return candidate
	var compact_candidate := _compact_string(lowered_candidate)
	if compact_candidate == target_compact:
		return candidate
	if target_compact != "" and (compact_candidate.begins_with(target_compact) or compact_candidate.ends_with(target_compact)):
		return candidate
	if target_compact != "":
		var compact_tail := _compact_string(tail)
		if compact_tail == target_compact:
			return candidate
	return ""

func _clip_tail(name: String) -> String:
	var tail := name
	const SEPARATORS := ["/", "\\", "|", ":", ".", "@", "-"]
	for sep in SEPARATORS:
		if tail.contains(sep):
			var parts := tail.rsplit(sep, false, 1)
			if parts.size() > 0:
				tail = parts[parts.size() - 1]
	return tail

func _compact_string(text: String) -> String:
	if text == "":
		return ""
	var result := ""
	var lower_text := text.to_lower()
	var length := lower_text.length()
	for i in length:
		var code := lower_text.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_lower:
			result += String.chr(code)
	return result

func _clips_has(name: String) -> bool:
	if name == "":
		return false
	return available_clips.find(name) != -1

func _rebuild_normalized_cache() -> void:
	_normalized_clip_cache.clear()
	for clip in available_clips:
		var lowered := clip.to_lower()
		if lowered != "" and not _normalized_clip_cache.has(lowered):
			_normalized_clip_cache[lowered] = clip
		var compact := _compact_string(lowered)
		if compact != "" and not _normalized_clip_cache.has(compact):
			_normalized_clip_cache[compact] = clip
		var tail := _clip_tail(lowered)
		if tail != "" and not _normalized_clip_cache.has(tail):
			_normalized_clip_cache[tail] = clip
		var compact_tail := _compact_string(tail)
		if compact_tail != "" and not _normalized_clip_cache.has(compact_tail):
			_normalized_clip_cache[compact_tail] = clip
		var segments := tail.split("_")
		if segments.size() > 1:
			for segment in segments:
				var trimmed_segment := segment.strip_edges()
				if trimmed_segment == "":
					continue
				var segment_lower := trimmed_segment.to_lower()
				if not _normalized_clip_cache.has(segment_lower):
					_normalized_clip_cache[segment_lower] = clip
