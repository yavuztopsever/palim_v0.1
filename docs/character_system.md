# Modular Character System Documentation

## Overview
The modular character system allows you to create diverse characters from a shared base while customizing their appearance, behavior, and properties through configuration resources.

## Architecture

### Core Components

#### 1. BaseCharacter (scripts/BaseCharacter.gd)
- **Purpose**: Handles common character functionality with integrated animation library
- **Features**: 
  - Standardized animation mapping system
  - Puppeteer functions for consistent animation control
  - Texture and material application
  - Scale and visual customization
  - Character identity management
  - Full animation library integration from `res://temp_assets/Animation Library[Standard]-2/`

#### 2. CharacterConfig (scripts/CharacterConfig.gd)
- **Purpose**: Resource-based character configuration
- **Contains**:
  - Identity (name, ID, description)
  - Visual appearance (textures, materials, scale)
  - Animation settings (speed, custom animations)
  - Behavior properties (movement speed, interaction radius)
  - Dialogue and personality traits

#### 3. ModularPlayer (scripts/ModularPlayer.gd)
- **Purpose**: Player-specific functionality with character customization
- **Inherits**: CharacterBody3D + BaseCharacter integration
- **Features**: Click-to-move, input handling, physics

#### 4. ModularNPC (scripts/ModularNPC.gd)
- **Purpose**: NPC-specific functionality with character customization
- **Inherits**: StaticBody3D + BaseCharacter integration
- **Features**: Interaction system, dialogue, facing behavior

#### 5. CharacterFactory (scripts/CharacterFactory.gd)
- **Purpose**: Easy character creation with presets
- **Features**: 
  - Predefined character types (Guard, Merchant, Villager)
  - Color variation system
  - Batch character creation
  - Configuration management

#### 6. AnimationController (scripts/AnimationController.gd)
- **Purpose**: High-level animation control and sequencing
- **Features**:
  - Simplified animation API (idle(), walk(), attack(), etc.)
  - Animation sequences and combinations
  - Event-driven animation system
  - Debug and testing utilities

## Usage Examples

### Creating Characters

#### Basic NPC Creation
```gdscript
# Create a guard with default configuration
var guard = CharacterFactory.create_npc(CharacterFactory.CharacterType.GUARD)
scene.add_child(guard)

# Create a merchant with custom colors
var merchant = CharacterFactory.create_colored_merchant(Color.PURPLE, Color.GOLD)
scene.add_child(merchant)
```

#### Custom Character Configuration
```gdscript
# Create custom character config
var config = CharacterConfig.new()
config.character_name = "Village Elder"
config.character_id = "elder_01"
config.scale_multiplier = Vector3(1.2, 1.2, 1.2)
config.animation_speed = 0.7
config.default_dialogue = "Welcome to our village, traveler."

# Apply color customization
config.set_color_tint("robe", Color.DARK_BLUE)
config.set_color_tint("beard", Color.GRAY)

# Create NPC with custom config
var elder = CharacterFactory.create_custom_npc(config)
```

#### Player Customization
```gdscript
# Load player configuration
var player_config = load("res://data/characters/player_config.tres")
player_config.character_name = "Aria"
player_config.scale_multiplier = Vector3(0.9, 0.9, 0.9)

# Create customized player
var player = CharacterFactory.create_player(player_config)
```

### Character Variations

#### Creating Multiple Guards with Different Colors
```gdscript
# Create 3 guards with different color schemes
var guards = CharacterFactory.create_town_guards(3)
for i in range(guards.size()):
    guards[i].global_position = Vector3(i * 3, 0, 0)
    scene.add_child(guards[i])
```

#### Batch Character Creation
```gdscript
# Create multiple merchants with variations
var color_variations = [
    {"robe": Color.RED, "accent": Color.GOLD},
    {"robe": Color.BLUE, "accent": Color.SILVER},
    {"robe": Color.GREEN, "accent": Color.BRONZE}
]
var merchants = CharacterFactory.create_npc_group(
    CharacterFactory.CharacterType.MERCHANT, 
    3, 
    color_variations
)
```

## Character Configuration Properties

### Identity
- `character_name`: Display name
- `character_id`: Unique identifier
- `character_description`: Flavor text

### Visual Appearance
- `textures`: Dictionary mapping body parts to textures
- `materials`: Dictionary mapping body parts to materials
- `scale_multiplier`: Vector3 for character scaling

### Animation & Movement
- `animation_speed`: Animation playback speed multiplier
- `movement_speed`: Character movement speed
- `custom_animations`: Additional animation libraries

### Behavior
- `interaction_radius`: How close player must be to interact
- `default_dialogue`: Default interaction text
- `character_personality`: Behavior modifier (friendly, hostile, neutral)

## Customization Workflow

### 1. Visual Customization
Characters can be customized through:
- **Texture Replacement**: Swap textures on specific body parts
- **Material Override**: Apply custom materials with colors/properties
- **Scale Adjustment**: Make characters taller, shorter, wider, etc.

### 2. Behavioral Customization
- **Animation Speed**: Make characters move faster/slower
- **Movement Properties**: Adjust speed and interaction ranges
- **Dialogue Integration**: Connect to dialogue resources

### 3. Preset System
Use predefined character types:
- **Guard**: Larger, slower, neutral personality
- **Merchant**: Medium size, friendly, faster animations
- **Villager**: Standard proportions, friendly
- **Custom**: Full control over all properties

## File Structure
```
scripts/
├── BaseCharacter.gd          # Core character functionality
├── CharacterConfig.gd        # Configuration resource
├── ModularPlayer.gd          # Player implementation
├── ModularNPC.gd            # NPC implementation
├── CharacterFactory.gd       # Character creation utilities
└── CharacterCustomizer.gd    # Customization tools

scenes/characters/
├── ModularPlayer.tscn        # Player scene template
└── ModularNPC.tscn          # NPC scene template

data/characters/
├── guard_config.tres         # Guard preset
├── merchant_config.tres      # Merchant preset
└── player_config.tres        # Player preset
```

## Integration with Existing System

### Location Integration
Characters created with the factory can be easily added to any location:

```gdscript
# In a location scene script
func populate_with_npcs():
    var guard = CharacterFactory.create_npc(CharacterFactory.CharacterType.GUARD)
    guard.global_position = Vector3(5, 0, 5)
    add_child(guard)
    
    var merchant = CharacterFactory.create_npc(CharacterFactory.CharacterType.MERCHANT)
    merchant.global_position = Vector3(-5, 0, -5)
    add_child(merchant)
```

### Save/Load System
Character configurations are resources and can be:
- Saved to disk for persistence
- Loaded dynamically for character creation
- Modified at runtime for character progression

## Future Enhancements

### Planned Features
- **Equipment System**: Attach/detach equipment pieces
- **Animation Blending**: Smooth transitions between animations
- **Procedural Variation**: Automatic generation of character variants
- **Character Editor UI**: Visual character customization tool
- **Texture Atlas System**: Efficient texture management for variations

### Advanced Customization
- **Bone Scaling**: Individual bone modifications
- **Facial Expressions**: Dynamic facial animation
- **Clothing Layers**: Stackable clothing/armor pieces
- **Particle Effects**: Character-specific visual effects

This system provides a solid foundation for creating diverse, customizable characters while maintaining consistency and performance across your game.
#
# Integrated Animation System

### Standard Animation Library
The system now includes full integration with the Animation Library[Standard]-2, providing consistent animation control across all characters.

#### Available Standard Animations
- **Movement**: idle, walk, run, jump, climb, crouch
- **Combat**: attack, defend, death
- **Social**: talk, wave, dance
- **Utility**: sit, sleep, pickup, throw

#### Puppeteer Functions
Each character can be controlled through standardized puppeteer functions:

```gdscript
# Direct BaseCharacter control
character.puppet_idle()
character.puppet_walk()
character.puppet_attack()

# High-level AnimationController
animation_controller.idle()
animation_controller.walk()
animation_controller.attack()
```

#### Animation Sequences
Create complex animation sequences easily:

```gdscript
# Greeting sequence
await animation_controller.greet_sequence()  # wave -> idle

# Combat sequence  
await animation_controller.combat_sequence()  # attack -> defend -> idle

# Celebration sequence
await animation_controller.celebration_sequence()  # jump -> dance -> wave -> idle
```

### Animation Mapping System
The BaseCharacter automatically maps standard animation names to available animations in the library:

```gdscript
# These all map to the same animation if available:
character.play_animation("idle")  # -> "Idle", "idle", "T-Pose", etc.
character.play_animation("walk")  # -> "Walk", "walk", "Walking", etc.
```

### Eliminated Redundant Files
The following old character files have been removed and replaced:
- ❌ `scenes/PlayerAnimated.tscn` → ✅ `scenes/characters/ModularPlayer.tscn`
- ❌ `scenes/NPCAnimated.tscn` → ✅ `scenes/characters/ModularNPC.tscn`
- ❌ `scripts/PlayerAnimated.gd` → ✅ `scripts/ModularPlayer.gd`
- ❌ `scripts/NPCAnimated.gd` → ✅ `scripts/ModularNPC.gd`

### Testing Animations
Use the example demo script to test all animations:

```gdscript
# Attach examples/character_animation_demo.gd to test animations
# Press number keys 1-9 to test different animations
# Press 0 to automatically test all available animations
```

This integrated system ensures every character in your game can be consistently puppeteered with the same animation library and control methods.