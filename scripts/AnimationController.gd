extends Node
class_name AnimationController

# Centralized animation controller for consistent character puppeteering
# Provides high-level animation control for gameplay systems

var character_node: Node

signal animation_started(animation_name: String)
signal animation_completed(animation_name: String)

func _ready():
	# Find character with animation functions in parent
	var parent = get_parent()
	if parent.has_method("play_animation"):
		character_node = parent

func _on_animation_finished(anim_name: String):
	animation_completed.emit(anim_name)

# Core movement animations
func idle() -> bool:
	if character_node and character_node.play_animation("idle"):
		animation_started.emit("idle")
		return true
	return false

func walk() -> bool:
	if character_node and character_node.play_animation("walk"):
		animation_started.emit("walk")
		return true
	return false

func run() -> bool:
	if character_node and character_node.play_animation("run"):
		animation_started.emit("run")
		return true
	return false

func jump() -> bool:
	if character_node and character_node.play_animation("jump"):
		animation_started.emit("jump")
		return true
	return false

# Combat animations
func attack() -> bool:
	if character_node and character_node.play_animation("attack"):
		animation_started.emit("attack")
		return true
	return false

func defend() -> bool:
	if character_node and character_node.play_animation("defend"):
		animation_started.emit("defend")
		return true
	return false

func death() -> bool:
	if character_node and character_node.play_animation("death"):
		animation_started.emit("death")
		return true
	return false

# Social animations
func talk() -> bool:
	if character_node and character_node.play_animation("talk"):
		animation_started.emit("talk")
		return true
	return false

func wave() -> bool:
	if character_node and character_node.play_animation("wave"):
		animation_started.emit("wave")
		return true
	return false

func dance() -> bool:
	if character_node and character_node.play_animation("dance"):
		animation_started.emit("dance")
		return true
	return false

# Utility animations
func sit() -> bool:
	if character_node and character_node.play_animation("sit"):
		animation_started.emit("sit")
		return true
	return false

func sleep() -> bool:
	if character_node and character_node.play_animation("sleep"):
		animation_started.emit("sleep")
		return true
	return false

func pickup() -> bool:
	if character_node and character_node.play_animation("pickup"):
		animation_started.emit("pickup")
		return true
	return false

func throw_item() -> bool:
	if character_node and character_node.play_animation("throw"):
		animation_started.emit("throw")
		return true
	return false

func climb() -> bool:
	if character_node and character_node.play_animation("climb"):
		animation_started.emit("climb")
		return true
	return false

func crouch() -> bool:
	if character_node and character_node.play_animation("crouch"):
		animation_started.emit("crouch")
		return true
	return false

# Animation sequences and combinations
func greet_sequence():
	wave()
	await animation_completed
	idle()

func combat_sequence():
	attack()
	await animation_completed
	defend()
	await animation_completed
	idle()

func celebration_sequence():
	jump()
	await animation_completed
	dance()
	await animation_completed
	wave()
	await animation_completed
	idle()

# Utility functions
func get_available_animations() -> Array[String]:
	if character_node and character_node.has_method("get_available_animations"):
		var animations = character_node.get_available_animations()
		var result: Array[String] = []
		for anim in animations:
			result.append(anim)
		return result
	return []

func is_animation_available(anim_name: String) -> bool:
	return anim_name in get_available_animations()

func play_custom_animation(anim_name: String) -> bool:
	if character_node:
		return character_node.play_animation(anim_name)
	return false

func stop_current_animation():
	if character_node and character_node.has_method("stop_animation"):
		character_node.stop_animation()

func set_animation_speed(speed: float):
	if character_node and "animation_speed" in character_node:
		character_node.animation_speed = speed

func get_current_animation() -> String:
	if character_node and "current_animation" in character_node:
		return character_node.current_animation
	return ""

# Debug functions
func list_all_animations():
	if character_node and character_node.has_method("get_available_animations"):
		var animations = character_node.get_available_animations()
		print("All animations in character: ", animations)

func test_all_animations():
	print("Testing all available animations for character...")
	var available = get_available_animations()
	for anim in available:
		print("Testing: ", anim)
		match anim:
			"idle": idle()
			"walk": walk()
			"run": run()
			"jump": jump()
			"attack": attack()
			"defend": defend()
			"talk": talk()
			"wave": wave()
			"dance": dance()
			"sit": sit()
			"sleep": sleep()
			"pickup": pickup()
			"throw": throw_item()
			"climb": climb()
			"crouch": crouch()
			"death": death()
		
		await get_tree().create_timer(2.0).timeout
	
	idle()
	print("Animation test complete!")