# Asset Checklist – Palim 0.1

## 1. Purpose & Scope
- Consolidates every asset deliverable needed to realize the Palim campaign as described in `docs/lore` and implemented in the Godot prototype (`scenes/Main.tscn` and supporting scripts).
- Covers 3D models, textures, shaders, VFX, UI, and systemic content required by both handcrafted scenes and the procedural generators under `addons/scene_generator`.
- Specifies target file formats, directory placement (`res://` paths), scale guidelines, and narrative references so that art, tech-art, and design teams can work from a single authoritative backlog.

## 2. Production Conventions
| Item | Specification | Notes |
| --- | --- | --- |
| Engine Units | 1 Godot unit = 1 meter | `BaseGenerator.GRID_SIZE = 2.0`; modular kits must snap to a 2 m grid. |
| Axis Conventions | +Y up, +Z forward, +X right | Align export axes to Godot defaults; root pivots at world origin. |
| 3D Geometry Formats | `.glb` (preferred), `.dae` acceptable; deliver instanced scenes as `.tscn` | Place raw meshes in `res://assets/**/models/`; create wrapper scenes for placement. |
| Texture Formats | 16-bit `.png` (BaseColor, Roughness, AO), `.exr` (Normal, Height), `.png` (Mask) | Name maps `asset_map.png` (e.g. `bureau_wall_albedo.png`). |
| Material Workflow | Metallic/Roughness PBR | Keep albedo in sRGB, others linear. |
| Shader Assets | `.gdshader` or `.tres` | Store in `res://assets/shaders/`; expose shader params for WallCutaway/WallHidingSystem integration. |
| Animation Clips | Godot AnimationPlayer tracks (`.tscn`) or imported `.glb` actions | Must include `Idle`, `Walk`, `Run`, `Talk`, `Gesture`, and quest-specific poses. |
| Naming | snake_case for files, PascalCase node names | Match asset IDs used by `AssetLibrary` (`floor_tile`, `door_frame`, etc.). |
| LOD & Collision | Provide low/med poly variants where possible; include simple collision meshes or let `CollisionBuilder` generate boxes | Large hero props require hand-authored collision for nav precision. |
| Version Control | Store source files (blend/zpr) under `art/source/` (outside runtime) | Runtime assets remain under `res://`. |

## 3. Shared Technical Foundations

### 3.1 Directory Layout Targets
| Path | Purpose | Key Assets |
| --- | --- | --- |
| `res://assets/characters/` | Character meshes, rigs, materials | Player + NPC `.glb`, costume materials, face textures |
| `res://assets/environment/modular/` | Snap-to-grid kits for generators | Floor tiles, wall segments, door/window frames, stair modules |
| `res://assets/environment/hero/` | Unique location meshes | Hall of Stamps altar, Weeping Cathedral nave, Memory Well |
| `res://assets/props/` | Portable & interactive props | Form packets, pneumatic capsules, memory bottles, musical instruments |
| `res://assets/shaders/` | Custom shaders | Bureau fluorescent flicker, Fog Quarter volumetric blend, Wall transparency |
| `res://assets/vfx/` | Particle, GPUParticles, visual effects scenes | Temporal tide distortion, language storm glyphs, administrative recursion |
| `res://assets/textures/palettes/` | Swatch textures / gradient ramps | District palette LUTs for post-processing |
| `res://ui/assets/` | Fonts, textures for widgets | Bureau seal icons, dialogue frame atlas, choice button skins |
| `res://addons/scene_generator/assets/` | Generator-ready `.tscn` prefabs | `building_blocks/floors/floor_tile.tscn`, etc. (see §5.1) |
| `res://navigation/` | Nav meshes and baked data | `MainNavigationMesh.tres` plus per-scene nav for interiors |

### 3.2 Character & Animation Pipeline
- Replace `assets/characters/AnimationLibrary_Godot_Standard.glb` with Palim-specific humanoid rig (`palim_humanoid.glb`). Requirements:
  - 1.8 m tall neutral A-pose; 55–65 bones, Humanoid naming (`hips`, `spine`, `neck`, etc.).
  - Blendshape channels: `blink`, `jaw_open`, `brow_raise`, `mouth_funnel` for expressive dialogue; optional phoneme visemes.
  - Export animation sets as separate actions (Idle, Walk, Run, Talk, Gesture, Panic, Exhausted, Write, Stamp).
  - Provide AnimationPlayer scene `res://assets/characters/animation/palim_humanoid_library.tscn` with retarget-compatible tracks.
- Cloth & accessory sockets: `backpack_socket`, `shoulder_socket_l/r`, `hand_socket_l/r` for courier bags, stampers, lanterns.
- Provide standardized `SkeletonProfileHumanoid` to enable Godot retargeting for crowd variants.

### 3.3 Material & Texture Standards
- Each material ships as `.tres` referencing texture set in `res://assets/textures/**`.
- Required texture channels per set:
  - `*_albedo.png`, `*_normal.exr`, `*_roughness.png`, `*_metallic.png` (pack metallic in R, AO in G, height in B if desired), `*_emission.png` for lit signage.
  - Resolution targets: Hero assets 4K, modular kits 2K, props 1K.
- District palette LUTs (512×16 ramp) for color grading: `inner_bureau_lut.png`, `docklands_lut.png`, etc.
- Use vertex colors for grime/age variation where possible to reduce texture count.

### 3.4 Lighting & Atmosphere Baseline
- HDR skyboxes per district (`.exr`, 8K) to replace procedural default: `inner_bureau_fluoro.exr`, `docklands_mist.exr`, `fog_quarter_twilight.exr`, `market_sprawl_neon.exr`, `theater_district_amber.exr`.
- Volumetric fog profiles stored as `Environment` resources (e.g. `res://assets/environment/fog/fog_quarter_env.tres`).
- Omni/spot light prefabs for generator use (`res://assets/vfx/lights/warm_lantern.tscn`, etc.).

## 4. Characters & Costuming

### 4.1 Player Character
| Deliverable | Specification | Target Path |
| --- | --- | --- |
| Player base mesh | Neutral, androgynous body with swappable heads; 50k tris | `res://assets/characters/player/player_base.glb` |
| Clothing set – Bureau new hire | Layered tunic + stamped sash, muted blues; cloth sim-ready | `res://assets/characters/player/outfits/bureau_intake.glb` |
| Clothing set – Civilian | Weathered coat, layered scarves, neutral earth tones | `.../outfits/civilian_survivor.glb` |
| Texture variants | Diverse skin tones (4×2K), grime overlays, freckles | `res://assets/textures/characters/player/` |
| Portrait textures | UI bust renders (512px) for dialogue | `res://ui/assets/portraits/player/` |

### 4.2 Major NPCs (from `docs/lore/characters/major_npcs`)
| NPC | Visual Keys | Required Assets | Target Path |
| --- | --- | --- | --- |
| Celeste Amélie Durand | Petite, wire-rim glasses, neat bun with vintage pins, leather portfolio | Unique head mesh + hair cards; Archive clerk uniform (deep Bureau blue, silver trim); glass shader for lenses; prop: stamped leather folio | `res://assets/characters/npcs/celeste/` |
| Joran Micah Krenke | Thin, graying hair, thick-rimmed glasses, rumpled brown cardigan, satchel | Outfit with layered cardigan + rolled sleeves; satchel prop with paper animation; expression morphs for sardonic smirk; desk clutter kit (notes, coded forms) | `res://assets/characters/npcs/joran/` |
| Marcel Théodore Valmont | Gaunt, hollow-eyed, loose Bureau attire, ring on chain | Emaciated body morph; disheveled Bureau clerk suit (gray/white); hero prop: wedding ring necklace (close-up); texture morph for sunken cheeks | `res://assets/characters/npcs/marcel/` |
| Ishan Ravi Patel | Oil-stained coveralls, heavy tool belt, short hair | Maintenance uniform with grime masks; tool belt with animated wrench set; rigged shadow duplicate mesh (see §4.4); hand decals (grease) | `res://assets/characters/npcs/ishan/` |
| Nia Solange Reyes | Athletic, braided hair with brass bells, weathered courier jacket, messenger bag | Courier outfit with modular layers (rain cape, gloves); bicycle-ready boots; braided hair asset with bell jingles (attachable); messenger bag with swappable form bundles | `res://assets/characters/npcs/nia/` |

Each hero NPC requires:
- 4K texture set (body, outfit, accessories), 1K detail masks.
- Blendshape/animation library aligned to base rig.
- Idle interaction animations (Idle, Talk, Emphatic gesture, Despair, Determined).
- Portrait renders for UI.

### 4.3 Faction & Social Group Variants
| Group | Visual Direction (doc reference) | Assets |
| --- | --- | --- |
| Bureau High Clerks (`inner_bureaucracy.md`) | White coats, silver stamps, bureaucratic sashes with mini seals | High clerk outfit set (male/female), stamp prop variations, headwear; color palette: Fluorescent white, deep bureau blue, stamp red |
| Processing Clerks | Color-coded badges, layered aprons | Badge decal library, stack of forms, desk props |
| Filing Assistants | Gray uniforms, carrying crates of documents | Backpack crate rig, simple uniform with adjustable sleeves |
| Form Supplicants | Civilian attire with queue tokens | Token prop, queue signage |
| Docklands Harbor Masters (`docklands.md`) | Weathered coats, nautical insignia, rope belts | Heavy coat kit, barnacle shader overlay |
| Sea-Touched | Bioluminescent tattoos, waterproof cloaks | Emissive body decals, translucent rain capes |
| Fog Quarter Care Workers (`fog_quarter.md`) | Damp shawls, layered wraps, candles | Fabric simulation shawls, candle props with volumetric glow |
| Flow Architects Enforcers (`factions/flow_architects.md`) | Sterile white tactical gear, syringe launchers | Armored suit, medical suppression tools |
| Rememberer Scholars (`organizations/rememberers.md`) | Archive yellow robes, hidden pockets | Robe kit with document stash, ring binder prop |
| Theater District Artists (`locations/districts/theater_district.md`) | Expressionist attire, paint-stained garments | Bohemian outfit set, dramatic masks |

Deliver each group as modular wardrobe pieces compatible with base rig, with shared 2K textures and color variants.

### 4.4 Non-Humanoid & Metaphysical Entities
| Entity | Description | Assets |
| --- | --- | --- |
| Ishan's Shadow-Self (`ishan_maintenance_worker.md`) | Semi-translucent humanoid silhouette, smoky tendrils | Animated shader (`ishan_shadow.gdshader`), volumetric particle trail, alternate rig with inverse lighting |
| Administrative Recursion (`inner_bureaucracy.md`) | Floating forms, stamping apparitions | GPUParticles with sheet sprites; animated stamp meshes with emissive logos |
| Temporal Tide Echoes (`docklands.md`) | Ghostly fish/boats phasing through water | Semi-transparent mesh set with distortion shader; triggered by timeline events |
| Memory Fog Apparitions (`fog_quarter.md`) | Liminal figures inside fog | Sprite-based volumetric impostors, cross-faded textures |
| Language Storm Glyphs (`docklands.md`) | Letters materializing in air | Procedural mesh ribbons with scrolling glyph texture, spawn logic |

### 4.5 Animation Library Additions
- Shared loops: Queue fidget, desk stamping, writing, carrying crate, exhaustion slump.
- Cinematics: Marcel collapse, Celeste stamping frenzy, Joran investigative gesture, Nia bike mount/dismount, Ishan shadow confrontation.
- Cloth simulation caches for hero scenes (Hall of Stamps banners, Docklands sails).

## 5. Environment Modules & Scenes

### 5.1 Procedural Kit Assets (`addons/scene_generator/assets`)
| Asset ID (matches `AssetLibrary`) | Scene Requirement | Geometry Spec | Notes |
| --- | --- | --- | --- |
| `building_blocks/floors/floor_tile.tscn` | Base neutral floor | 2×2 m tile, 0.05 m thick | Default beige tile; includes baked AO |
| `.../grass_tile.tscn` | Exterior greenspace | 2×2 m, displacement-ready | Blend for Market parks |
| `.../path_tile.tscn` | Outdoor path | 2×2 m, stone atlas | Docklands boardwalk variant |
| `.../market_tile.tscn` | Market Sprawl interior | 2×2 m, patterned tile | Include vertex color for grime |
| `.../formal_path_tile.tscn` | Bureau corridors | 2×2 m, polished granite | Reflective shader, decal sockets |
| `.../corridor_tile.tscn` | Narrow corridors | 2×2 m, includes baseboard meshes | Align to 2 m grid |
| `.../mixed_tile.tscn` | Mixed-use | Multi-material | Variation mask |
| `building_blocks/walls/wall_segment.tscn` | Straight wall | 2 m length, 3 m height | Slot for `WallHidingSystem`; UV for signage |
| `.../corner_wall.tscn` | L-shaped corner | 2 m legs | Align pivot at inner corner |
| `.../wall_with_window.tscn` | Window opening | 2 m width | Replace glass via shader |
| `building_blocks/doors/door_frame.tscn` | Doorway | 1 m width, 2.5 m height | include collision + open anim |
| `.../wooden_door.tscn` | Docklands interior | Distressed wood texture | Hinged, interacts |
| `.../metal_door.tscn` | Bureau secure | Brushed metal, stamp decals | Supports keycard prop |
| `building_blocks/windows/window_frame.tscn` | Default window | 1.5 m width | Transparent shader slot |
| `.../glass_window.tscn` | Bureau double glazing | Include parallax interior card |
| `.../shuttered_window.tscn` | Docklands | Animated shutters |
| `furniture/tables/table.tscn` | Generic table | 1.6×0.8×0.75 m | Variation textures per district |
| `furniture/chairs/chair.tscn` | Chair | 0.45 seat height | Idle animation for NPC |
| `furniture/storage/cabinet.tscn` | Filing cabinet | 0.9×0.5×1.5 m | Drawer open animation |
| `furniture/storage/shelf.tscn` | Shelving | 2 m tall | Parameterized clutter sockets |
| `furniture/beds/bed.tscn` | Residential | 2×1 m | Fog Quarter blankets |
| `props/containers/barrel.tscn` | Docklands barrel | 1 m height | Vertex paint for algae |
| `props/containers/crate.tscn` | Market crate | Stackable |
| `props/lighting/lamp_post.tscn` | Street lamp | 4 m tall | Warm emission |
| `props/lighting/torch.tscn` | Wall torch | Particle flame |
| `props/default/default_prop.tscn` | Placeholder | 1×1×1 m cube | Magenta placeholder |

Ensure each `.tscn` contains:
- `MeshInstance3D`, optional `StaticBody3D` or rely on `CollisionBuilder`.
- `WallHidingSystem` child where relevant.
- Material overrides referencing `res://assets/materials/**`.

### 5.2 District Environment Kits

#### Inner Bureaucracy
- **Palette:** Institutional Gray (#6B7B8C), Fluorescent White (#F5F5F0), Deep Bureau Blue (#1E3A5F), Stamp Red (#CC0000).
- **Modular Set:** Brutalist wall modules (straight, inset niche, relief sculpture), vaulted ceiling panels, pneumatic tube bundles, desk banks, queue stanchions.
- **Hero Locations:**
  | Location (`establishments/inner_bureaucracy`) | Required Assets |
  | --- | --- |
  | Central Registry | Endless vertical archive shafts, moving lift platforms, holographic ledger displays |
  | Hall of Stamps | Shrine pedestals with high-res stamp props, glass cases, ambient particle motes |
  | Pneumatic Hub | Animated tube network, spinning valve wheels, document capsules |
  | Memory Processing Center | Form shredders, memory eddy VFX, identity verification booths |
  | Form 47 Processing Center | Queue amphitheater modules, bureaucracy altar |
- **VFX:** Floating forms (administrative recursion), time-stamped light shafts, fluorescent flicker shader.
- **Audio triggers (reference):** Typewriter, pneumatic hiss (assets may be delegated later).

#### Docklands
- **Palette:** Deep Ocean Blues (#1B365D), Salt-Stained White (#F0F4F7), Rust Orange (#CC6600), Seaweed Green (#4F7942), Amber Gold (#FFC649).
- **Modular Set:** Weathered plank floors, leaning building facades with adjustable skew, rope railing kit, boat hull segments, floating market pontoons.
- **Hero Locations:**
  | Location | Assets |
  | --- | --- |
  | Anchor Repair Cooperative | Dry-dock scaffold, rope pulley animations, barnacle shader plane |
  | Temporal Cargo Processing | Conveyor belts with time-echo VFX, cargo crate variants |
  | Tide & Anchor Tavern | Circular stew hearth, communal benches, accordion stage |
  | Sailors' Archive (concept) | Shipping container stacks, hidden interior with contraband |
- **VFX:** Temporal tide surface shader (scrolling normals, color shift), language storm glyph particles, emotional weather rain (shader blending).
- **Water:** Planar water material with support for time offsets; foam decals.

#### Fog Quarter
- **Palette:** Pearl Gray (#E5E5E5), Charcoal (#36454F), Faded Blue (#6699CC), Dusty Rose (#BC8F8F), Amber Gold (#FFBF00).
- **Modular Set:** Sagging wall meshes (blend shapes for droop), fog volume cubes, damp cobblestone decals, ornate but worn window trims.
- **Hero Locations:**
  | Location | Assets |
  | --- | --- |
  | Weeping Cathedral | Dripping wall shader, pews with water stains, stained glass gloom |
  | Silence Gardens | Low shrub meshes with fog overlay, sound-dampening VFX |
  | Broken Clock Tavern | Clock face with slow pendulum, condensation decals |
  | Forgotten Library | Fading book meshes (alpha-controlled), disappearing text shader |
  | Mercy Clinic | Medical cots, emergency lanterns |
  | Community Support Center | Bulletin boards, support circle chairs |
  | Shadow Market | Pop-up stalls with tarp covers, hidden storage crates |
- **VFX:** Memory fog apparitions, gravitational depression effect (screen-space vignette), dripping particles.

#### Market Sprawl
- **Palette:** Neon oranges, saturated purples, brass, market greens (see `locations/districts/market_sprawl.md`).
- **Modular Set:** Market canopy system, stall tables, signage rig with animated flips, translation tower lattice.
- **Hero Locations:**
  | Location | Assets |
  | --- | --- |
  | Mask Market | Modular mask displays, artisan workbench |
  | Translation Tower | Spiral stair with language glyph projection, translation console |
  | Spice Labyrinth | Maze walls with hanging spice sacks, particle dust |
  | Memory Mart | Bottled memory shelves (glass shader), cold storage units |
  | Probability Bazaar | Probability wheel props, flickering signage |
- **VFX:** Particle spices, chromatic aberration for probability VFX, glowing memory bottles.

#### Theater District
- **Palette:** Warm ambers, crimson drapes, stage lighting blues (`locations/districts/theater_district.md`).
- **Modular Set:** Stage floor pieces, retractable scenery panels, loft catwalks, dressing rooms.
- **Hero Locations:**
  | Location | Assets |
  | --- | --- |
  | Grand Stage | Proscenium arch, stage rigging, curtain simulation |
  | Music Hall | Orchestra seating, acoustic paneling |
  | Memory Stage | Projection surfaces for memory scenes |
  | Artists' Commune | Communal workshops, consciousness amplifier devices |
  | Cinema Paradox | Folding chairs, dual-projection screens |
- **VFX:** Spotlight gobo shader, memory bleed stage fog, animated poster signage.

### 5.3 Exterior Landmarks & Skyline
- City skyline matte mesh with LOD tiers, referencing `world/infrastructure.md`.
- River assets (Bureaucracy River) with bridges, water flow shader.
- Coastal sea mesh for Docklands with tide animation.

## 6. Quest-Specific Set Dressing

### Investigation Chain 1 – The Vanishing Clerk (`campaigns/investigation_quest_chains.md`)
| Scene | Required Assets |
| --- | --- |
| The Empty Desk (Bureau Administration) | Shrinking desk rig (scale animation), fading personal items (coffee mug with dissolve shader), contradictory paperwork stack, NPC cluster with random memory responses |
| Apartment Search | Morphing apartment layout (modular walls with blend shapes), animated lease document (self-editing text shader), hidden diary prop |
| Personnel Records | Auto-editing files (UI overlay), nervous HR clerk with glitching memory VFX, pneumatic tube reroute |
| Archive Voluntary Form | Form 89-A hero prop with temporal text shift, deletion-resistant ink decal, Celeste workstation variant |
| Theater District investigation | Stage dressing with fading presence, seat cushion stash prop |
| Underground Safe House | Reality-shifting interior (tile swap), photo evidence board, Rememberer meeting props |

### Investigation Chain 2 – Memory Merchants
| Scene | Assets |
| --- | --- |
| Support Group | Community center variant (circle of chairs), condensation breath VFX, shared journal prop |
| Probability Bazaar Market | Vendor stalls with bottled memories (unique glass shader), phasing stall mesh |
| Extraction Facility | Hybrid medical/occult rig, consciousness field generator (animated shader), victim rig |
| Memory Restoration | Rememberer facility interior, transformation VFX (environment morph), trauma animation |
| Collector Network | Upper residence kit (luxury materials), memory gallery frames, projection holograms |
| Bureau Medical Department | Temporal overlay (dual time textures), equipment with multi-era appearance |

Include timeline markers for Warps: intensity escalation states require alternate environment textures (Act 1 subtle, Act 3 dramatic).

## 7. Props & Interactive Items
| Category | Examples & Specs | Notes |
| --- | --- | --- |
| Administrative Tools | Form stacks (varied sizes), stampers (animated plunger), typewriters (mechanical rig), pneumatic capsules (open/close anim) | Align with `inner_bureaucracy` palette; high-poly hero versions for cinematics, low-poly for background |
| Identity Artifacts | Existence certificates, identity bracelets, queue tokens, Ministry badges | 512×512 texture atlases for tokens; metallic/enameled materials |
| Memory Preservation | Bottled memories (varied glow colors), Rememberer notebooks, mnemonic devices | Emissive textures, script overlay |
| Maritime Gear | Nets, lanterns, rope coils, boat repair tools | Wetness shader toggles |
| Cultural Items | Masks (Market), musical instruments (accordion, drums, violin), stage props | Provide rigging for animation where needed |
| Medical / Suppression | Flow Architect inhibitor syringes, Continuum monitoring devices | Sterile white materials, emissive displays |
| Everyday Items | Coffee mugs with slogans, coats on hooks, rain umbrellas, personal diaries | Variation textures to indicate existence fading |

Ensure interactive props include Godot `AnimationPlayer` or `Tween` sequences for pickup/investigation.

## 8. UI & 2D Assets
- **Dialogue UI overhaul (`ui/DialogueUI.tscn`):**
  - High-res panel frame referencing Bureau forms (4-slice texture), highlight animations.
  - Speaker nameplate variants (Bureau vs Underground).
  - Typeface assets: Bureau standard (condensed sans), ACT handwriting font, Docklands signage script.
  - Choice button states (default, hover, disabled) with color-coded outcomes (Truth/Order/Integration per campaign paths).
- **HUD & Menus:**
  - Objective tracker with stamp icons, faction reputation meters.
  - Form inventory UI (drag-and-drop), memory archive timeline widget.
- **Iconography:** 64px & 128px icons for actions (Stamp, Record, Recall, Navigate).
- **Post-process overlays:** Vignette textures for reality distortions, fog gradients for Fog Quarter transitions.

## 9. Shaders & VFX
| Effect | Shader Requirements | Placement |
| --- | --- | --- |
| Wall Transparency (existing `WallCutaway.gd`, `WallHidingSystem`) | Material supporting alpha fade & depth prepass; parameter `fade_amount` controlled by script | Attach to wall materials in modular kit |
| Bureau Fluorescent Flicker | Shader animating light intensity + subtle color shift; optional screen-space banding | Inner Bureau lighting fixtures |
| Administrative Recursion | Shader-driven instanced forms with additive glow, random motion | Hall of Stamps, archives |
| Temporal Tide Distortion | Screen-space UV distortion + time offset; secondary water shader | Docklands waterfront |
| Language Storm Glyphs | Vertex animated quads with scrolling glyph texture & fade | Docklands events |
| Memory Fog | Depth-aware particle fog with noise-based dissolves | Fog Quarter | 
| Reality Friction | Post-process glitch shader (UV offset, chromatic aberration) triggered by Warps | Crisis events |
| Lamp & Lantern Bloom | Emissive + bloom mask controlled via shader param | Docklands, Fog Quarter |
| Stage Lighting | Spotlight shader with gobo mask blending | Theater District |
| Document Self-Editing | Shader writes/erases text via mask animation | Investigation scenes |

Store all shaders in `res://assets/shaders/` with preset `.tres` resources for reuse.

## 10. Lighting, Atmosphere & FX Support
- Volumetric fog volumes (Fog Quarter, Docklands mist) using `FogVolume` nodes.
- Particle systems: dust motes (Inner Bureau), sea spray (Docklands), ash flakes (Crisis events), paper scraps (Archive leaks).
- Light probes / GI: Bake `SDFGI` configs per district; add ReflectionProbes for polished interiors.
- Weather toggles: Rain (particle + wetness shader), snow (rare event), sandstorm (Market Sprawl emergency).

## 11. Navigation, Collision & Level Infrastructure
- Update navmesh resources per hero scene (`res://navigation/{scene}_navmesh.tres`). Maintain 0.35 m agent radius to match `PlayerAnimated` capsule.
- Provide invisible blockers for queue control, crowd flow.
- Place `NavigationObstacle3D` nodes inside large props (desks, shelves).
- Create climbable volumes (ladder, stairs) with `NavigationLink3D`.

## 12. Audio Stubs (for coordination)
*(Audio assets to be scoped separately; include references so sound team can align later.)*
- Looping ambiences per district (typewriters, sea gulls, fog drone, bazaar crowd, stage rehearsal).
- One-shot SFX for stamps, pneumatic tubes, temporal warp, reality friction, fog drip.
- Music motifs referencing doc tone (absurdist, melancholic, maritime).

## 13. Outstanding Placeholders & Replacement Targets
| Current Placeholder | Replacement Needed |
| --- | --- |
| `assets/characters/AnimationLibrary_Godot_Standard.glb` | Palim humanoid animation set (`palim_humanoid.glb`) |
| `scenes/Main.tscn` CSG primitives (Ground, Walls, Desk) | Modular environment meshes + hero props consistent with Inner Bureau aesthetic |
| Procedural sky | District-specific HDR skyboxes |
| Generic desk (`Desk` node) | Bureau desk with form trays, stampers, drawer open anim |
| Lack of material diversity | Full PBR material library per district |

## 14. Delivery Roadmap (Suggested Sequencing)
1. **Foundation:** Replace base character rig & animation library; establish material/shader templates.
2. **Environment Kit:** Build modular assets for generator (floor, walls, doors, windows, furniture) to unlock procedural scene production.
3. **Hero Characters:** Sculpt and texture the five major NPCs + player variants.
4. **District Sets:** Tackle Inner Bureau hero spaces first (player starting area), followed by Docklands and Fog Quarter for narrative progression.
5. **Quest Props & VFX:** Implement investigation chain-specific assets and reality distortion shaders.
6. **UI Reskin:** Deliver new dialogue/UI assets in sync with narrative systems.
7. **Polish:** Add crowd variants, ambient props, nav refinements, audio hooks.

---
This checklist links every asset to its narrative or systemic justification, ensuring art production supports the lore depth captured in `docs/lore` and the mechanics implemented in the current Godot prototype.
