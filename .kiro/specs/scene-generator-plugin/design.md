# Design Document

## Overview

The Scene Generator Plugin is a Godot editor plugin that provides rule-based procedural generation of 3D isometric environments. The plugin uses modular asset systems, built-in Godot physics and navigation, and follows industry best practices for level generation. It generates complete game-ready scenes with proper collision, navigation meshes, and lighting optimized for animated character gameplay.

## Architecture

### Plugin Structure
```
addons/scene_generator/
├── plugin.cfg                 # Plugin configuration
├── plugin.gd                  # Main plugin entry point
├── dock/
│   ├── generator_dock.gd      # UI dock panel script
│   └── generator_dock.tscn    # UI dock panel scene
├── generators/
│   ├── base_generator.gd      # Abstract base generator class
│   ├── layout_generator.gd    # Creates basic spatial layouts using BSP or grid
│   ├── asset_placer.gd        # Places walls, floors, doors based on layout
│   ├── furniture_placer.gd    # Adds furniture and props to rooms
│   ├── navigation_builder.gd  # Generates navigation meshes
│   └── lighting_setup.gd      # Adds basic lighting to scenes
├── assets/
│   ├── building_blocks/      # Core modular pieces
│   │   ├── walls/           # Basic wall segments
│   │   ├── floors/          # Floor tiles and surfaces
│   │   ├── doors/           # Door frames and doors
│   │   ├── windows/         # Window frames and glass
│   │   └── stairs/          # Stairways and ramps
│   ├── furniture/           # Basic props and furniture
│   │   ├── tables/          # Various table types
│   │   ├── chairs/          # Seating options
│   │   ├── storage/         # Cabinets, shelves, boxes
│   │   └── decorative/      # Basic decorative items
│   └── lighting/            # Basic lighting elements
│       ├── lamps/           # Various lamp types
│       ├── fixtures/        # Ceiling and wall fixtures
│       └── ambient/         # Environmental lighting setups
└── utils/
    ├── grid_system.gd        # Grid alignment utilities
    ├── collision_builder.gd  # Collision shape generation
    ├── nav_mesh_builder.gd   # Navigation mesh utilities
    └── lighting_setup.gd     # Lighting configuration
```

### Core Components

#### 1. Generator System
- **BaseGenerator**: Abstract class defining the generation interface
- **Layout Generator**: Creates basic spatial layouts (rooms, corridors, outdoor areas)
- **Asset Placement System**: Places modular building pieces based on layout
- **Navigation Builder**: Generates navigation meshes for character movement

#### 2. UI System
- **Generator Dock**: Main interface panel in Godot editor
- **Basic Controls**: Area type, size, interior/exterior toggle
- **Generation Button**: Trigger scene generation with current parameters

#### 3. Asset System
- **Modular Building Pieces**: Grid-aligned walls, floors, doors, windows
- **Basic Furniture/Props**: Simple objects to populate spaces
- **Navigation Elements**: Stairs, ramps, passages for multi-level areas

## Components and Interfaces

### BaseGenerator Class
```gdscript
class_name BaseGenerator
extends RefCounted

# Core generation interface
func generate_scene(root: Node3D, params: GenerationParams) -> void:
    pass

# Setup basic scene structure
func setup_scene_foundation(root: Node3D, params: GenerationParams) -> void:
    # Add WorldEnvironment, lighting, camera
    pass

# Apply theme-specific assets
func apply_theme(root: Node3D, theme: String) -> void:
    pass
```

### GenerationParams Class
```gdscript
class_name GenerationParams
extends Resource

# Basic Layout
@export var area_type: String = "mixed"    # residential, commercial, administrative, industrial, mixed
@export var size: Vector2i = Vector2i(10, 10)  # Grid dimensions in 2-meter cells
@export var seed: int = 0                  # Random seed for reproducibility
@export var interior_spaces: bool = true   # Generate interior rooms vs exterior areas
```

### GridSystem Utility
```gdscript
class_name GridSystem
extends RefCounted

const GRID_SIZE: float = 2.0  # 2 meter grid cells

static func snap_to_grid(position: Vector3) -> Vector3:
    # Snap position to nearest grid point
    pass

static func get_grid_bounds(size: Vector2i) -> AABB:
    # Calculate world bounds for grid size
    pass
```

## Data Models

### Scene Layout Data
The plugin uses a hierarchical data model to represent scene layouts before instantiation:

```gdscript
class_name SceneLayout
extends Resource

@export var grid_size: Vector2i
@export var cells: Array[CellData] = []
@export var connections: Array[ConnectionData] = []

class_name CellData
extends Resource

@export var position: Vector2i
@export var cell_type: String  # floor, wall, door, prop
@export var asset_id: String   # Specific asset to place
@export var rotation: int = 0  # 0, 90, 180, 270 degrees
```



## Error Handling

### Generation Validation
- **Parameter Validation**: Check size limits, valid theme names, seed ranges
- **Asset Availability**: Verify required assets exist before generation
- **Memory Limits**: Monitor node count and prevent excessive generation
- **Collision Validation**: Ensure generated collision shapes are valid

### Error Recovery
- **Graceful Degradation**: Fall back to default assets if theme assets missing
- **Partial Generation**: Allow completion even if some elements fail
- **User Feedback**: Clear error messages in Godot's output panel
- **Cleanup**: Remove partially generated content on critical failures

## Testing Strategy

### Unit Testing
- **Generator Logic**: Test each generator type with known parameters
- **Grid System**: Verify alignment and snapping calculations
- **Asset Loading**: Test theme switching and asset instantiation
- **Navigation Mesh**: Validate generated navmesh connectivity

### Integration Testing
- **Full Scene Generation**: Test complete generation pipeline
- **Character Navigation**: Verify characters can navigate generated scenes
- **Performance Testing**: Measure generation time and memory usage
- **Visual Validation**: Screenshot comparison for consistent output

### Manual Testing
- **UI Workflow**: Test complete user workflow in Godot editor
- **Theme Consistency**: Visual inspection of different themes
- **Isometric View**: Verify scenes look correct from isometric camera
- **Asset Alignment**: Check for gaps, overlaps, or misalignments

## Performance Considerations

### Generation Optimization
- **Batch Operations**: Group similar operations to reduce overhead
- **Asset Instancing**: Use Godot's instancing for repeated elements
- **LOD System**: Generate simplified versions for distant objects
- **Streaming**: Generate large scenes in chunks if needed

### Memory Management
- **Asset Pooling**: Reuse common assets across generations
- **Cleanup**: Properly free unused resources after generation
- **Limits**: Set reasonable limits on scene complexity
- **Monitoring**: Track memory usage during generation

### Runtime Performance
- **Static Batching**: Combine static meshes where possible
- **Occlusion Culling**: Organize scenes for efficient culling
- **Collision Optimization**: Use simple shapes for collision detection
- **Navigation Efficiency**: Generate clean, optimized navigation meshes

## Camera Integration & Wall Hiding

### Isometric Camera Compatibility
- **Wall Layering System**: Generated walls are organized in layers based on camera-facing direction
- **Occlusion Groups**: Walls are grouped by their relationship to camera view (front-facing, side-facing, etc.)
- **Transparency Zones**: Areas that should become transparent when camera looks "through" them
- **Room Detection**: Automatic detection of interior vs exterior spaces for selective hiding
- **Roof Management**: Interior spaces automatically exclude roofs for clear isometric visibility

### Wall Hiding Implementation
```gdscript
class_name WallHidingSystem
extends Node3D

# Automatically applied to generated walls
@export var wall_layer: int = 0           # Layer for camera occlusion
@export var hide_when_behind: bool = true # Hide when camera is behind this wall
@export var transparency_fade: float = 0.3 # How transparent when hiding (0.0-1.0)
@export var room_id: String = ""          # Which room this wall belongs to
@export var is_interior: bool = false     # Interior spaces don't generate roofs
@export var space_type: String = "exterior" # exterior, interior, mixed
```

### Integration with Existing Systems
- **Compatible with existing WallCutaway.gd**: Generated walls automatically work with current wall hiding
- **Maintains Performance**: Uses same occlusion culling systems as existing scenes
- **Preserves Functionality**: Wall hiding doesn't break collision or navigation
- **Seamless Integration**: Generated scenes work identically to hand-built scenes
- **Smart Roof Generation**: Only generates roofs for exterior buildings, leaves interiors open for isometric view

## Implementation Notes

### Godot Integration
- Uses `EditorPlugin` class for editor integration
- Leverages `PackedScene` for asset management
- Utilizes `StaticBody3D` and `CollisionShape3D` for physics
- Employs `NavigationRegion3D` for pathfinding
- Integrates with Godot's material and lighting systems
- **Compatible with existing camera and wall hiding systems**

### Modular Design
- Each generator type is independent and swappable
- Aesthetic system allows flexible visual combinations
- Rule-based approach enables fine-tuning without code changes
- Asset system supports both built-in and custom content
- **Wall pieces designed for camera occlusion compatibility**

### Extensibility
- Plugin architecture allows adding new generator types
- Aesthetic profiles support custom visual combinations
- Rule definitions can be externalized to data files
- API designed for potential scripting by advanced users
- **Camera integration designed to work with future camera improvements**