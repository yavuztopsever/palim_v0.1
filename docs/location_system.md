# Location System Documentation

## Overview
The game now uses a modular location system where different areas are separate scene files that get loaded dynamically into the main scene.

## Structure

### Main Scene (scenes/Main.tscn)
- Contains core persistent systems:
  - Camera3D with CameraController
  - GameManager (handles game state and location loading)
  - WallCutaway system
  - DialogueUI
  - NavigationRegion3D (shared navigation mesh)
  - LocationContainer (empty node where locations are loaded)

### Location Scenes (scenes/locations/)
- **TestRoom.tscn**: The original prototype room with walls, desk, and Celeste NPC
- **TownSquare.tscn**: An outdoor area with buildings, fountain, and Town Guard NPC

## How It Works

### LocationManager Class
- Manages loading and unloading of location scenes
- Maintains a registry of available locations
- Emits signals when locations change
- Handles cleanup of previous locations

### GameManager Integration
- Creates and initializes LocationManager
- Responds to location changes by:
  - Connecting NPCs in the new location
  - Configuring camera for the location size
  - Managing persistent game state

## Controls
- **ENTER**: Load TestRoom location
- **SPACE**: Load TownSquare location  
- **H**: Load PlayerHouse location
- **Click**: Move player
- **E**: Interact with NPCs
- **W**: Toggle wall visibility (universal across all locations)
- **Mouse Wheel**: Zoom in/out (universal camera zoom)
- **Middle Click**: Reset zoom to default

## Adding New Locations

1. Create a new scene file in `scenes/locations/`
2. Add your environment geometry, NPCs, and props
3. Include a NavigationRegion3D for pathfinding
4. Register the location in LocationManager's locations dictionary
5. Optionally add camera configuration in GameManager's `_on_location_changed`

## Benefits of This System

- **Modular**: Each location is independent and manageable
- **Memory Efficient**: Only one location loaded at a time
- **Scalable**: Easy to add new locations
- **Performance**: Can optimize each location separately
- **Team-Friendly**: Multiple developers can work on different locations

## Future Enhancements

- Transition effects between locations
- Save/load system for location state
- Dynamic location parameters (time of day, weather)
- Location-specific music and ambience
- Procedural location generation integration
## Un
iversal Wall Cutaway System

The wall cutaway system now works universally across all locations:

### How It Works
- **WallCutaway** script automatically detects walls in any loaded location
- Searches for CSG nodes with `wall_direction` metadata or wall-like names
- Supports three modes:
  - **Mode 0**: All walls visible
  - **Mode 1**: Cutaway mode (hides south and east walls for isometric view)
  - **Mode 2**: All walls hidden

### Wall Detection
Walls are detected by:
1. **Metadata**: Nodes with `wall_direction` metadata (preferred method)
2. **Naming**: Nodes with "wall" in their name and directional indicators (north, south, east, west)

### Adding Walls to New Locations
To ensure walls work with the cutaway system:
1. Use CSGBox3D nodes for walls
2. Add `wall_direction` metadata with values: "north", "south", "east", "west"
3. Or name walls with direction indicators (e.g., "NorthWall", "SouthWall")

### Example Wall Setup
```gdscript
# In scene file or script:
wall_node.set_meta("wall_direction", "north")
```

This system ensures consistent wall behavior across all locations without requiring location-specific code.
## St
andardized Camera System

The camera system now provides consistent, standardized behavior across all locations:

### Camera Types
- **indoor_small**: For small rooms like PlayerHouse (12x10 units)
- **indoor_medium**: For medium rooms like TestRoom (20x20 units) 
- **outdoor_large**: For large areas like TownSquare (30x30 units)
- **outdoor_huge**: For very large outdoor areas (50x50 units)

### Universal Zoom Features
- **Smooth Zoom**: Mouse wheel scrolling with smooth interpolation
- **Zoom Range**: 0.5x to 3.0x (50% to 300%)
- **Zoom Reset**: Middle-click to return to 100%
- **Zoom Indicator**: Shows current zoom level in top-right corner
- **Auto-fade**: Zoom indicator fades after 2 seconds of no zoom changes

### Camera Configuration
Each location automatically gets the appropriate camera setup:
```gdscript
# In GameManager, locations are configured with standard types:
camera.configure_for_location_type("indoor_medium")  # TestRoom
camera.configure_for_location_type("outdoor_large")  # TownSquare
camera.configure_for_location_type("indoor_small")   # PlayerHouse
```

### Customization
Camera settings can be adjusted in the CameraController inspector:
- **Zoom Speed**: How fast zoom responds to mouse wheel
- **Min/Max Zoom**: Zoom limits (default 0.5x to 3.0x)
- **Zoom Smoothing**: How smooth the zoom interpolation is
- **Base View Padding**: Default camera distance from scene

This ensures consistent camera behavior while allowing per-location optimization and global zoom functionality.