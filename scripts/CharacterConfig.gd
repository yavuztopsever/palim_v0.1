extends Resource
class_name CharacterConfig

# Character configuration resource for customizing appearance and behavior

@export_group("Identity")
@export var character_name: String = "Character"
@export var character_id: String = ""
@export var character_description: String = ""

@export_group("Visual & Animation")
@export var scale_multiplier: Vector3 = Vector3.ONE
@export var animation_speed: float = 1.0
@export var animation_overrides: Dictionary = {} # String action -> String or Array of clip names

@export_group("Character Stats")
@export var movement_speed: float = 5.0
@export var interaction_radius: float = 2.0

@export_group("Dialogue & Behavior")
@export var default_dialogue: String = "Hello there!"
@export var dialogue_resource: DialogueResource
@export var character_personality: String = "friendly" # friendly, hostile, neutral, etc.

# Preset configurations for quick character creation
static func create_guard_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.character_name = "Town Guard"
	config.character_id = "guard_01"
	config.character_description = "A vigilant town guard"
	config.default_dialogue = "Stay safe, citizen."
	config.character_personality = "neutral"
	config.movement_speed = 3.0
	return config

static func create_merchant_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.character_name = "Merchant"
	config.character_id = "merchant_01"
	config.character_description = "A traveling merchant"
	config.default_dialogue = "Welcome! Take a look at my wares!"
	config.character_personality = "friendly"
	config.movement_speed = 4.0
	return config

static func create_player_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.character_name = "Player"
	config.character_id = "player"
	config.character_description = "The main character"
	config.movement_speed = 5.0
	return config

static func create_villager_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.character_name = "Villager"
	config.character_id = "villager_01"
	config.character_description = "A local villager"
	config.default_dialogue = "Good day to you!"
	config.character_personality = "friendly"
	config.movement_speed = 3.5
	return config
