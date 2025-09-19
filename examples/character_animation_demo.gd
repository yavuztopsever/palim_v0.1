extends Node

# Example script demonstrating the new modular character animation system
# Attach this to any scene to test character animations

@export var test_character: Node3D

var animation_controller: AnimationController

func _ready():
	if test_character:
		animation_controller = test_character.get_node_or_null("AnimationController")
		if animation_controller:
			print("Animation Demo Ready! Press keys to test animations:")
			print("1 - Idle, 2 - Walk, 3 - Run, 4 - Jump")
			print("5 - Attack, 6 - Defend, 7 - Talk, 8 - Wave")
			print("9 - Dance, 0 - Test All Animations")

func _input(event):
	if not animation_controller or not event.pressed:
		return
	
	if event is InputEventKey:
		match event.keycode:
			KEY_1:
				animation_controller.idle()
				print("Playing: Idle")
			KEY_2:
				animation_controller.walk()
				print("Playing: Walk")
			KEY_3:
				animation_controller.run()
				print("Playing: Run")
			KEY_4:
				animation_controller.jump()
				print("Playing: Jump")
			KEY_5:
				animation_controller.attack()
				print("Playing: Attack")
			KEY_6:
				animation_controller.defend()
				print("Playing: Defend")
			KEY_7:
				animation_controller.talk()
				print("Playing: Talk")
			KEY_8:
				animation_controller.wave()
				print("Playing: Wave")
			KEY_9:
				animation_controller.dance()
				print("Playing: Dance")
			KEY_0:
				print("Testing all animations...")
				animation_controller.test_all_animations()

# Example of creating characters with different configurations
func create_example_characters():
	# Create a guard
	var guard = CharacterFactory.create_npc(CharacterFactory.CharacterType.GUARD)
	guard.global_position = Vector3(0, 0, 0)
	add_child(guard)
	
	# Create a colorful merchant
	var merchant = CharacterFactory.create_colored_merchant(Color.PURPLE, Color.GOLD)
	merchant.global_position = Vector3(3, 0, 0)
	add_child(merchant)
	
	# Create a custom character
	var config = CharacterConfig.new()
	config.character_name = "Village Elder"
	config.scale_multiplier = Vector3(1.2, 1.2, 1.2)
	config.animation_speed = 0.7
	config.set_color_tint("robe", Color.DARK_BLUE)
	
	var elder = CharacterFactory.create_custom_npc(config)
	elder.global_position = Vector3(-3, 0, 0)
	add_child(elder)

# Example of animation sequences
func demonstrate_animation_sequences():
	if not animation_controller:
		return
	
	print("Demonstrating animation sequences...")
	
	# Greeting sequence
	await animation_controller.greet_sequence()
	await get_tree().create_timer(1.0).timeout
	
	# Combat sequence
	await animation_controller.combat_sequence()
	await get_tree().create_timer(1.0).timeout
	
	# Celebration sequence
	await animation_controller.celebration_sequence()
	
	print("Animation sequence demonstration complete!")