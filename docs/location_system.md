# Location & Navigation System

## Overview
Palim 0.1 streams self-contained location scenes into the root `Main.tscn` at runtime. The root scene keeps persistent systems alive (camera, UI, managers) while `LocationManager.gd` swaps the environment underneath the player.

## Current Locations

| Name | File | Notes |
| ---- | ---- | ----- |
| `player_house` | `scenes/locations/PlayerHouse.tscn` | Indoor room that demonstrates the wall cutaway system and navigation obstacles. |
| `town_square` | `scenes/locations/TownSquare.tscn` | Outdoor plaza containing the player spawn and a guard NPC. |

Use the built-in shortcuts while the game is running:

- **F5** -> reload `player_house`
- **F6** -> reload `town_square`
- **F7** -> dump current location and animation info to the terminal
- **Click** -> move the player
- **E** (`interact`) -> talk to nearby NPCs
- **Mouse wheel / Middle click** -> adjust or reset zoom

## Main Scene Layout (`scenes/Main.tscn`)

- `Camera3D` + `scripts/CameraController.gd` - orthographic, top-down/three-quarter view with smooth zoom.
- `GameManager` - instantiates `LocationManager`, loads the startup location, connects NPC dialogue, and configures the camera per location type.
- `LocationContainer` - empty `Node3D`; every loaded location scene becomes a child of this node.
- `DialogueUI` & `ZoomIndicator` - UI layers instanced from the `ui/` folder.
- `WallCutaway` - auto-hides walls that face the active camera based on metadata or naming convention.

## LocationManager (`scripts/LocationManager.gd`)

- Holds a dictionary of location names -> scene paths.
- Exposes `load_location_by_name()` (string) and a generic `load_location()` (path) helper.
- Emits `location_changed(location_name)` so other systems can respond.
- Ensures previously loaded scenes are `queue_free()`d before adding the new instance under `LocationContainer`.

When a location finishes loading, `GameManager`:

1. Waits one frame so the scene tree is ready.
2. Reconnects every NPC's `interaction_started` signal.
3. Configures the camera with `CameraController.configure_for_location_type()` (currently `indoor_small` for PlayerHouse and `outdoor_large` for TownSquare).

## Wall Cutaway

The universal wall system (`scripts/WallCutaway.gd`) looks for `CSGBox3D` nodes whose names include "wall" or that provide `wall_direction` metadata. Whenever the camera moves or rotates, the script hides any detected walls that face the camera and reveals the others, keeping interiors readable without manual toggles. Adding `metadata/wall_direction = "north" | "south" | "east" | "west"` in the Inspector ensures consistent detection when your naming scheme varies.

## Adding a New Location

1. Create a scene under `scenes/locations/YourLocation.tscn`.
2. Include a `NavigationRegion3D` with a baked or authored navigation mesh.
3. Drop in one instance of `ModularPlayer.tscn` (spawn point) and any `ModularNPC.tscn` you need, adjusting exports like `npc_name` and `dialogue_text`.
4. Tag walls with metadata or naming if you want cutaway support.
5. Register the scene inside `LocationManager.gd`'s `locations` dictionary.
6. If the camera needs a unique setup, extend the match statement in `GameManager.gd::_on_location_changed()` and call `camera.configure_for_location_type("your_type")`.

Following these steps keeps new content compatible with the existing systems and minimises glue code.
