extends Node

# Simple test script to verify the character system works

func _ready():
	print("Testing Character System...")
	
	# Test CharacterConfig creation
	var guard_config = CharacterConfig.create_guard_config()
	print("Guard config created: ", guard_config.character_name)
	
	var merchant_config = CharacterConfig.create_merchant_config()
	print("Merchant config created: ", merchant_config.character_name)
	
	var player_config = CharacterConfig.create_player_config()
	print("Player config created: ", player_config.character_name)
	
	print("Character system test complete!")