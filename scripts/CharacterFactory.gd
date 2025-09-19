extends Node
class_name CharacterFactory

# Factory class for creating different character types with configurations

# Preloaded character scenes
const MODULAR_PLAYER_SCENE = preload("res://scenes/characters/ModularPlayer.tscn")
const MODULAR_NPC_SCENE = preload("res://scenes/characters/ModularNPC.tscn")

# Character configurations are created using static functions

enum CharacterType {
	PLAYER,
	GUARD,
	MERCHANT,
	VILLAGER,
	CUSTOM
}

# Create a player character
static func create_player(config: CharacterConfig = null) -> CharacterBody3D:
	var player = MODULAR_PLAYER_SCENE.instantiate()
	
	if not config:
		config = CharacterConfig.create_player_config()
	
	# Apply configuration after the scene is ready
	player.call_deferred("set_character_config", config)
	
	return player

# Create an NPC character
static func create_npc(type: CharacterType, config: CharacterConfig = null) -> StaticBody3D:
	var npc = MODULAR_NPC_SCENE.instantiate()
	
	# Get default config based on type
	if not config:
		config = get_default_config_for_type(type)
	
	# Apply configuration after the scene is ready
	npc.call_deferred("set_character_config", config)
	
	return npc

# Create NPC with custom configuration
static func create_custom_npc(config: CharacterConfig) -> StaticBody3D:
	return create_npc(CharacterType.CUSTOM, config)

# Get default configuration for character type
static func get_default_config_for_type(type: CharacterType) -> CharacterConfig:
	match type:
		CharacterType.GUARD:
			return CharacterConfig.create_guard_config()
		CharacterType.MERCHANT:
			return CharacterConfig.create_merchant_config()
		CharacterType.PLAYER:
			return CharacterConfig.create_player_config()
		CharacterType.VILLAGER:
			return CharacterConfig.create_villager_config()
		_:
			return CharacterConfig.new()

# Create a character configuration with color variations
static func create_color_variant_config(base_config: CharacterConfig, color_scheme: Dictionary) -> CharacterConfig:
	var new_config = base_config.duplicate()
	
	# Apply color scheme to materials
	for part_name in color_scheme:
		new_config.set_color_tint(part_name, color_scheme[part_name])
	
	return new_config

# Create multiple NPCs of the same type with variations
static func create_npc_group(type: CharacterType, count: int, variations: Array = []) -> Array[StaticBody3D]:
	var npcs: Array[StaticBody3D] = []
	
	for i in range(count):
		var config = get_default_config_for_type(type)
		
		# Apply variation if provided
		if i < variations.size() and variations[i] is Dictionary:
			config = create_color_variant_config(config, variations[i])
		
		# Make each NPC unique
		config.character_id = config.character_id + "_" + str(i + 1)
		config.character_name = config.character_name + " " + str(i + 1)
		
		var npc = create_npc(type, config)
		npcs.append(npc)
	
	return npcs

# Helper function to create a guard with custom colors
static func create_colored_guard(armor_color: Color, cloth_color: Color) -> StaticBody3D:
	var color_scheme = {
		"armor": armor_color,
		"cloth": cloth_color,
		"metal": Color.GRAY
	}
	var config = create_color_variant_config(CharacterConfig.create_guard_config(), color_scheme)
	return create_npc(CharacterType.GUARD, config)

# Helper function to create a merchant with custom colors
static func create_colored_merchant(robe_color: Color, accent_color: Color) -> StaticBody3D:
	var color_scheme = {
		"robe": robe_color,
		"accent": accent_color,
		"belt": Color.SADDLE_BROWN
	}
	var config = create_color_variant_config(CharacterConfig.create_merchant_config(), color_scheme)
	return create_npc(CharacterType.MERCHANT, config)

# Example usage functions
static func create_town_guards(count: int = 3) -> Array[StaticBody3D]:
	var color_variations = [
		{"armor": Color.STEEL_BLUE, "cloth": Color.DARK_BLUE},
		{"armor": Color.DIM_GRAY, "cloth": Color.MAROON},
		{"armor": Color.DARK_SLATE_GRAY, "cloth": Color.DARK_GREEN}
	]
	return create_npc_group(CharacterType.GUARD, count, color_variations)

static func create_market_merchants(count: int = 2) -> Array[StaticBody3D]:
	var color_variations = [
		{"robe": Color.PURPLE, "accent": Color.GOLD},
		{"robe": Color.DARK_GREEN, "accent": Color.SILVER}
	]
	return create_npc_group(CharacterType.MERCHANT, count, color_variations)