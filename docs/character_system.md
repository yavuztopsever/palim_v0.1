# Character System

## Overview
Palim 0.1 ships with a small but functional third-person character stack built around two reusable scenes (`ModularPlayer.tscn` and `ModularNPC.tscn`). The stack focuses on click-to-move exploration, simple NPC interactions, and a shared animation library (imported from `assets/characters/AnimationLibrary_Godot_Standard.glb`). This document summarises the scripts that participate in the system, how they connect at runtime, and how to extend them safely.

## Runtime Characters

### ModularPlayer (`scripts/ModularPlayer.gd`)
- Extends `CharacterBody3D`.
- Handles click-to-move navigation, basic jump/crouch/run toggles, and animation playback.
- Registers itself in the `"player"` group so global systems (e.g. dialogue, wall cutaway) can find it.
- Expects a child node called `CharacterAnimator` (see below) and a `CharacterModel` instance from the animation GLB.
- Supports optional appearance tweaks through `set_character_config(config: CharacterConfig)`.

### ModularNPC (`scripts/ModularNPC.gd`)
- Extends `StaticBody3D`.
- Emits `interaction_started` when a player presses the `interact` action inside its `InteractionArea`.
- Shares the same animation + configuration pipeline as the player, including the dialogue hand-off to the UI.
- Automatically adds itself to the `"npcs"` group so `GameManager.gd` can connect interactions whenever a new location loads.

## Shared Components

| Script | Purpose | Key APIs |
| ------ | ------- | -------- |
| `scripts/CharacterAnimator.gd` | Minimal helper that maps action names to available animation clips. | `play(action, force)`, `stop()`, `set_speed()`, `get_available_clips()`. |
| `scripts/CharacterConfig.gd` | Resource capturing identity, scale, animation speed, stats, and dialogue defaults. | Static helpers such as `create_player_config()`, `create_guard_config()`, etc.  Use `animation_overrides` to point specific actions at custom clip names. |
| `scripts/dialogue/dialogue_resource.gd` & `scripts/dialogue/dialogue_line.gd` | Lightweight resources for authored dialogue. | `DialogueResource.get_entries()` returns dictionaries consumable by the UI. |
| `ui/DialogueUI.gd` | Canvas-layer dialogue box used whenever an NPC interaction starts. | `start_dialogue(npc_name, dialogue_resource, fallback_text, npc)` and the `dialogue_finished` signal. |

## Scene + Data Layout

```
scenes/
 +-- characters/
 |   +-- ModularPlayer.tscn      # Player prefab with CharacterAnimator child
 |   +-- ModularNPC.tscn         # NPC prefab with InteractionArea + CharacterAnimator
 +-- locations/
 |   +-- PlayerHouse.tscn        # Indoor space demonstrating cutaway walls
 |   +-- TownSquare.tscn         # Outdoor plaza with a guard NPC
ui/
 +-- DialogueUI.tscn
 +-- ZoomIndicator.tscn
data/
 +-- dialogue/
     +-- celeste_dialogue.tres   # Example DialogueResource used by earlier prototypes
```

> **Note:** Earlier prototypes relied on a `CharacterFactory` helper. That API was removed during the October 2025 cleanup; create customised characters directly by instancing the scenes above or by authoring `CharacterConfig` resources.

## Working With CharacterConfig

### Authoring a Resource

1. Create a new `CharacterConfig` resource (right-click in the FileSystem dock -> New Resource -> `CharacterConfig`).
2. Fill in identity fields (name, id, description) and adjust movement/animation speeds.
3. (Optional) Populate `animation_overrides` with action-to-clip mappings when a character should use different animations than the defaults.

Save the resource under the new `data/characters/` folder (see below) to keep authored assets organised.

### Applying a Config at Runtime

```gdscript
@onready var npc: Node3D = $ModularNPC
var config: CharacterConfig = load("res://data/characters/merchant_config.tres")

func _ready() -> void:
	if npc.has_method("set_character_config"):
		npc.set_character_config(config)
```

The same API works for the player character if you prefer to preconfigure their look before the scene starts.

### Supplying Dialogue

Assign a `DialogueResource` to an NPC's `npc_config.dialogue_resource` or directly to the NPC's exported `dialogue_resource` property. The dialogue UI will prioritise the resource and fall back to `dialogue_text` whenever the resource is absent.

## Integration Points

- `scripts/GameManager.gd` connects every NPC's `interaction_started` signal when a location loads, pauses player movement during conversations, and resumes control once the UI emits `dialogue_finished`.
- `scripts/WallCutaway.gd` keeps camera-facing walls hidden by scanning location geometry for wall metadata or naming conventions.
- `scripts/CameraController.gd` exposes `configure_for_location_type()`; the game manager calls it so both indoor and outdoor spaces get consistent framing.

## Extending the System

1. **New NPC types** - Duplicate `ModularNPC.tscn`, rename the root node, and adjust the exported defaults or attach a lightweight wrapper script if you need bespoke logic.
2. **Additional emotes** - Add detection for new input actions inside `ModularPlayer.gd::_handle_animation_shortcuts()` or update `CharacterAnimator.gd`'s default map so the new action resolves to an available clip.
3. **Persistent presets** - Serialise `CharacterConfig` resources to disk and reload them before instancing the character scene.

Keep everything under the provided folders (`scenes/characters`, `data/characters`, etc.) so collaborators and automation scripts can rely on a consistent layout.
