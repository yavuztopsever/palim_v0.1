# Palim 0.1 - Project Overview

## Gameplay Snapshot
- **Core loop:** click-to-move exploration inside instanced locations with lightweight NPC conversations.
- **Player controls:** left-click movement, double-click to sprint, `E` to interact, mouse wheel for zoom. Walls that face the camera fade automatically.
- **Current content:** two locations (`PlayerHouse`, `TownSquare`) demonstrating indoor/outdoor setups, one guard NPC with placeholder dialogue, and UI for dialogue + zoom feedback.

## Scenes
| Category | Path | Purpose |
| -------- | ---- | ------- |
| Root | `scenes/Main.tscn` | Persistent systems (camera, managers, UI, wall cutaway) and the `LocationContainer` placeholder. |
| Characters | `scenes/characters/ModularPlayer.tscn` | Player prefab with animation controller + click-to-move logic. |
| Characters | `scenes/characters/ModularNPC.tscn` | NPC prefab with interaction signals and shared animation stack. |
| Locations | `scenes/locations/PlayerHouse.tscn` | Interior example with cutaway-ready walls and furniture obstacles. |
| Locations | `scenes/locations/TownSquare.tscn` | Exterior example with simple buildings and a guard NPC. |
| UI | `ui/DialogueUI.tscn` | Dialogue presentation. |
| UI | `ui/ZoomIndicator.tscn` | HUD element showing the current zoom ratio. |

## Scripts
| Path | Role | Notes |
| ---- | ---- | ----- |
| `scripts/GameManager.gd` | Bootstraps the game, loads the startup location, manages dialogue state, and pauses player movement during conversations. |
| `scripts/LocationManager.gd` | Streams location scenes into `LocationContainer`, keeps track of current location, emits `location_changed`. |
| `scripts/CameraController.gd` | Provides orthographic framing and zoom controls. |
| `scripts/WallCutaway.gd` | Auto-hides camera-facing walls whenever the camera or location changes. |
| `scripts/ModularPlayer.gd` | Handles click-to-move navigation, movement state, and animation playback for the player character. |
| `scripts/ModularNPC.gd` | Manages proximity checks, interaction signalling, and animation playback for NPCs. |
| `scripts/CharacterAnimator.gd` | Minimal helper that maps action names (idle, walk, run, etc.) to available animation clips. |
| `scripts/CharacterConfig.gd` | Resource definition for naming, animation speed/overrides, and behaviour tuning for characters. |
| `scripts/dialogue/dialogue_resource.gd` | Stores an array of `DialogueLine` resources. |
| `scripts/dialogue/dialogue_line.gd` | Individual speaker/text entries. |
| `ui/DialogueUI.gd` | Drives the conversation UI flow. |
| `ui/ZoomIndicator.gd` | Watches the camera zoom level and fades the HUD label. |

Helper scripts inside `scripts/*.py` support doc maintenance (link checking, lore tidying) and are not part of the runtime.

## Assets & Data
- `assets/characters/AnimationLibrary_Godot_Standard.glb` - shared skeletal mesh + animation clips for both characters.
- `data/dialogue/celeste_dialogue.tres` - sample dialogue resource (not wired into the current locations, but available for reuse).
- `data/characters/` - new home for authored `CharacterConfig` resources (create as needed).

## Systems Interplay
1. **Startup:** `Main.tscn` loads, `GameManager` instantiates `LocationManager` and listens for `location_changed`.
2. **Location load:** `LocationManager` adds the requested location scene under `LocationContainer`, emits the change signal.
3. **Post-load wiring:** `GameManager` connects all `ModularNPC` instances, configures the camera, and ensures UI references are valid.
4. **Interaction flow:** Player walks into an NPC's `InteractionArea`, presses `E`, `ModularNPC` emits `interaction_started`, `DialogueUI` opens, player movement pauses, and resumes on `dialogue_finished`.
5. **Wall/Camera helpers:** `WallCutaway` constantly syncs wall visibility with the active camera while `ZoomIndicator` tracks zoom level.

## Known Gaps & Next Steps
1. Author new `CharacterConfig` resources to give NPCs unique names, outfits, and dialogue resources (store under `data/characters/`).
2. Populate `LocationManager.gd` with additional scenes as they are produced and extend the camera configuration match for new environment types.
3. Replace placeholder console messages with proper UI feedback (e.g., tooltip prompts, mission log).
4. Consider wiring `data/dialogue/celeste_dialogue.tres` into an NPC to demonstrate multi-line conversations inside the current locations.
5. Add automated tests or in-editor tools if the lore/documentation maintenance scripts (`check_links.py`, `normalize_related.py`) continue to be useful.
