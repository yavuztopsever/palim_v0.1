Development Plan for Rule‑Based Scene Generation plugin in Godot
Overview: Procedural vs. Rule‑Based Generation
Procedural content generation (PCG) ranges from completely random or noise-driven methods to structured, rule-driven techniques. In a rule-based approach, we define explicit rules or a mini “design language” that shapes how content is created, rather than relying on purely random noise. This method ensures generated scenes follow a consistent style and meet design constraints. For example, the indie game Unexplored uses a custom graph grammar (PhantomGrammar) to generate Zelda-like dungeons via graph rewriting, a formal rule-based technique
boristhebrave.com
. Similarly, tools like CityEngine use a shape grammar (CGA rules) – essentially a scripting language for architecture – to generate entire cities by applying rules to base shapes
doc.arcgis.com
. These examples show that rule-based generation can produce sophisticated, repeatable level layouts governed by design constraints rather than pure randomness. Adopting such practices in Godot will give us fine-grained control over the scenes we generate.
Best Practices in Generative Design: Successful rule-based generation systems often share common best practices. They use modular rules (e.g. grammar productions or algorithmic steps) that can be tweaked without rewriting everything. They ensure determinism with seeds for reproducibility, and allow designer input at a high level (for theme, size, etc.). A key principle is to incrementally build complexity: start from a simple layout and refine it with more rules. For instance, CityEngine’s CGA rules are authored incrementally – you don’t write a 500-line rule file in one go; you add rules step by step and test outcomes
doc.arcgis.com
. We will apply these practices by breaking down our generation process into clear steps and rules, enabling controlled, theme-consistent results.
Designing a Code‑Based Design Language for Scenes
To meet the requirement of a code-based design language, we will create a system where we can specify high-level design parameters (shape of the scene, placement of structures, themes, etc.) and translate those into a Godot scene. Essentially, we’ll implement a simplified procedural grammar for game environments. This could be a custom DSL (domain-specific language) or simply a well-structured GDScript API that designers can use. For example, we might define rules or functions like add_building(type, position, size) or split_area(area, rule) that carry out predefined generation logic.
A proven approach for such design languages is using shape grammars – rule sets that iteratively replace or subdivide shapes. Shape grammars are well-suited for architectural and regular structures (e.g. buildings)
courses.cs.ut.ee
. We could represent our scene as an initial "shape" (or abstract layout), then apply successive rules to flesh it out. For instance, a rule might subdivide a block into smaller blocks (lots for buildings or rooms), another rule might replace a block with a building of a certain style, and so on. CityEngine’s CGA rules follow this pattern: e.g., start with a building footprint, then extrude to a building mass, then split that mass into floors and facades
doc.arcgis.com
doc.arcgis.com
. We can mirror this concept in GDScript.
Rule Definition Structure: We will create data structures or classes to hold generation rules. Each rule might have a trigger condition and an action. For example:
Rule object: contains a condition (e.g. "if area is larger than X and marked as 'city_block'") and an action (e.g. "split area into grid of roads and lots").
We’ll have a Generator class that keeps a list of such rules and applies them sequentially or recursively to an initial scene layout description.
Alternatively, we could implement a simpler grammar using strings or JSON where the designer writes something like:
Start -> TownCenter(size=100)  
TownCenter -> RoadGrid(spacing=10) + Buildings(style="medieval")  
Building -> { House | Shop | Apartment }  
This is just a sketch, but it illustrates defining high-level components and their sub-components. The code would parse this and instantiate corresponding Godot nodes and scenes.
Parameters and Themes: Our design language will allow parameters like theme (e.g. “medieval town” vs “modern city”), density (how many structures), size of the area, etc. Internally, different parameter sets can select different rule sets or content modules. For example, a “seaside” theme might include rules to place a water plane and beach props, whereas a “basement” theme might use dungeon-like room generation. By changing parameters, the same generator can scale from a small indoor room to a full outdoor level, maintaining flexibility.
Implementing Generation for Various Environments
To ensure we can generate rooms, outdoors, streets, town centers, seasides, basements, apartments, and full levels, our system will be modular. We will likely implement different algorithms or rule sets for indoor versus outdoor environments, all under the same framework.
Indoor Environments (Rooms, Dungeons, Apartments)
Indoor scenes like rooms, basements, and building interiors benefit from space-partitioning algorithms combined with rules for room contents. A classic technique is Binary Space Partitioning (BSP) to subdivide a region into rooms or areas. BSP uses a recursive tree structure to split space into smaller rooms
jonoshields.com
. We can use BSP to carve out a floor plan within a building or dungeon, then apply rules to those rooms (e.g. designate some as hallways, others as chambers).
Example of a procedurally generated dungeon layout using BSP partitioning (rooms in pink) connected by corridors (green)
jonoshields.com
. This demonstrates a rule-based algorithm splitting space into rooms and hallways, which can be controlled via parameters like room size range.
Using BSP as a rule: we could have a high-level rule “SubdivideInterior” that triggers BSP splitting on a rectangular area meant to be an interior. The algorithm can be guided by parameters (e.g. desired number of rooms, minimum/maximum room size). The result is a set of room rectangles. We then place actual room instances: for each partition, instantiate a Room scene (a pre-designed scene with walls/doors) at the corresponding location. Corridors or doorways are created to connect adjacent partitions
jonoshields.com
. This gives us a connected layout. The rule-based aspect comes from controlling how splits occur (for example, rules to avoid too narrow rooms by checking aspect ratio before choosing horizontal vs vertical split
jonoshields.com
jonoshields.com
).
For apartments or multi-story buildings, we can incorporate vertical splitting rules. A shape grammar approach is useful: for instance, start with a block for the whole building, then apply a rule to split it into multiple floor slices, and within each floor slice apply another rule to partition into individual apartments. This is analogous to how a shape grammar can split a building mass into floors and then rooms. CityEngine’s grammar, for example, allows splitting a building mass vertically by a floor height attribute
doc.arcgis.com
. In our Godot code, we might do something like:
# Pseudo-code for splitting a building volume into floors and apartments
func generate_building(base_size, floor_count, apartments_per_floor):
    for floor_index in range(floor_count):
        var floor_y = floor_index * FLOOR_HEIGHT
        for apt_index in range(apartments_per_floor):
            # Determine apartment area by splitting base_size.x by number of apartments
            var apt_width = base_size.x / apartments_per_floor
            var apt_position = Vector3(apt_index * apt_width, floor_y, 0)
            var apartment_scene = ApartmentRoom.instance()
            apartment_scene.position = apt_position
            apartment_scene.size = Vector3(apt_width, FLOOR_HEIGHT, base_size.z)
            add_child(apartment_scene)
In practice, the above logic would be wrapped in rule-checks (only split further if apartment size > min, etc.). The key is that by encoding these rules in code, designers can specify “an apartment building with 5 floors and 4 apartments each” and the system will create the nodes accordingly. This rule-driven approach yields predictable, scalable indoor layouts.
We should also include content placement rules: e.g. a rule for furnishing rooms (if room type is “basement”, place certain props; if “treasure room”, place loot). These can be simple if-else in scripts or part of the grammar data (e.g. Room -> {Spawn(Barrel) Spawn(Crate) ...} depending on theme).
Outdoor Environments (Streets, Towns, Terrain)
Outdoor scenes like town centers, city streets, or seaside towns require a different set of generation rules focusing on roads, terrain, and building placement. A rule-based system here might involve multiple layers:
Terrain Generation: If needed, create a base terrain heightmap or use a preset terrain. We can apply rules like “if seaside theme, flatten an area for the shore and add a water plane; if town, ensure a relatively flat area for building placement”. Terrain can be generated with noise or predefined heightmaps, but rule-based adjustments ensure the terrain suits the scene (e.g. no steep hills in the town center area).
Road Network Generation: Roads can be generated with algorithmic patterns or grammars. One approach is using an L-system (Lindenmayer system) or graph grammar to grow roads. For example, an L-system can recursively create street patterns (this was historically used to model cities with fractal-like road layouts). Another approach is to use a population density map and connect key points – an advanced technique described in Citygen research. In that approach, you generate a population density map (higher values where building concentration should be) and pick cluster centers (e.g. via k-means clustering), then connect those centers with roads
doingmyprogramming.wordpress.com
. The roads are laid out using heuristics (following gentle slopes, going through high-density areas, etc.)
doingmyprogramming.wordpress.com
. While complex, this rule-based method yields realistic road networks: main roads between population centers and secondary roads branching off in populated zones.
In our plan, for simplicity, we might start with a grid or radial road layout (e.g. a grid for a city, or a ring road for a town center). The rule language can allow selecting a road pattern: for instance, RoadPattern("grid", spacing=20) vs RoadPattern("radial", spokes=5). The generator script then creates path nodes or StaticMesh instances for roads accordingly. We must ensure roads align with terrain (if using heightmap) by sampling heights or flattening where roads go.
Building Placement: Once roads are in place (or if we skip explicit roads for simpler villages), we place buildings. This can be rule-driven by zone: e.g. along each road segment, place a row of buildings set back by a few units. We could have a rule like “For each lot in the town, if near main road and size > X, place a building of type Y”. Using theme parameters, the generator chooses building style (medieval cottages vs modern skyscrapers). We’ll likely prepare a set of building scene templates (e.g. HouseSmall.tscn, HouseLarge.tscn, Shop.tscn, etc.). The generation code then instantiates these scenes at positions determined by the layout.
For organic layouts (like a seaside village), a rule might scatter small houses with some randomness but still follow rules like “houses cluster near the shore” or “leave open space for a town center plaza”. These can be implemented by checking distance constraints in the script as it places objects.
Scaling Up to Full Levels: By combining the above, we can generate full game levels. A full level might include terrain + a town + surrounding areas. We can orchestrate the generation with a top-level rule sequence. Example sequence for a “town level”:
Terrain Rule: Generate or load terrain, flatten an area for town center.
Town Center Rule: Carve out a town center (plaza or main square).
Road Rule: Lay out roads emanating from the center (grid or radial pattern).
Zone Rules: Define zones along roads – e.g. residential, commercial – based on distance from center or random assignment.
Building Rules: Place buildings appropriate to each zone. For each lot or grid cell, choose a building template that fits the zone and instantiate it.
Decoration Rules: Add props, lights, NPC spawners, etc. For example, along a seaside, add boats or piers; in basements/dungeons, add torches and monsters.
Each step is governed by parameters. For instance, “size=large” might generate more road branches and buildings; a higher “density” parameter might pack buildings closer with smaller gaps, etc. The system’s rule definitions make it easy to tweak these without altering core code – e.g., a designer can change the road pattern or building styles via the rule config.
By keeping indoor and outdoor generation somewhat separate (different rule sets or modules), we maintain flexibility. We can even nest them: for example, generating a town with several buildings, and if a building is enterable, use the indoor generator to create its interior layout when needed.
Godot Implementation – Scripting & Plugin Architecture
We will implement the above system entirely in Godot (no external dependencies), using GDScript for flexibility. The plan is to create an Editor Plugin in Godot that provides a user-friendly interface to input parameters and generate the scene.
Editor Plugin Setup: Godot allows extending the editor with custom plugins. We’ll create a plugin script (extends EditorPlugin) marked as tool script (so it runs in the editor). The plugin will add, for example, a new dock panel or a menu option for “Procedural Scene Generator”. This panel will have fields for all the parameters we care about (scene type, theme, size, seed, etc.) and a “Generate” button. According to Godot’s plugin requirements, our plugin script must inherit EditorPlugin and be a tool script to function
docs.godotengine.org
. We can use Godot’s Editor UI nodes (like OptionButton, LineEdit, CheckBox, etc.) to make the interface.
When the user hits Generate, the plugin will run our generation code. This code can either create a new scene or populate the current scene. For example, we might have a root Node (like an empty Spatial if 3D) in the scene, and the generator script will add children (roads, buildings, etc.) to it. Using GDScript, we can instantiate scenes with PackedScene.instance() or create MeshInstances/Nodes via Node.new() and then use add_child() to attach them to the scene tree. For instance, creating a grid of streets might look like:
func generate_grid_city(root: Node, city_size: int, spacing: float):
    for x in range(city_size):
        for y in range(city_size):
            if is_road_position(x, y):
                var road_segment = RoadSegmentScene.instance()
                road_segment.position = Vector3(x * spacing, 0, y * spacing)
                root.add_child(road_segment)
(where is_road_position implements the pattern of roads). After roads, we’d place buildings similarly at non-road positions.
No External Dependencies: All generation will use Godot’s capabilities. If we need to create custom meshes (for unique building shapes), we can use Godot’s SurfaceTool or Mesh API to construct geometry at runtime, but we’ll try to leverage pre-made scene templates for most structures to keep things simple. Using Blender via scripting is not in the main plan, since we want to avoid dependencies, but we might use it in asset creation stage (e.g. modeling a set of building parts). The runtime combination and layout, however, will be done in Godot script.
Saving and Iteration: The plugin can allow the user to preview generated scenes and, if satisfied, save them as a reusable scene. Godot’s editor plugin can call EditorInterface.get_scene() to get the current scene and then save it. We can either generate directly in the current scene (allowing the user to manually adjust after generation) or generate in a new scene resource. A good workflow is: user creates an empty scene, uses the generator to populate it, then manually tweaks if needed, then saves.
Example: Putting It All Together
To illustrate, consider a user story: “As a designer, I want to generate a seaside town level with a harbor, a market square, and a few surrounding houses.” Using our system, the designer would open the Procedural Scene Generator plugin in Godot, set Scene Type = “Seaside Town”, Size = “Small”, Theme = “Medieval Harbor”, and click Generate.
Behind the scenes, our code will:
Create a Terrain and mark an area near one edge as “water” (placing an Ocean node or water plane).
Flatten an area next to the water for the harbor and market (town center).
Lay out a main road along the waterfront and a couple of branching streets forming a small grid around the market square.
Place a dock and market stalls in the town center (because theme = harbor, we have specific rules to add these).
Place houses (chosen from a set of medieval house scenes) along the streets and near the harbor. Maybe one larger warehouse near the dock.
Add decorative props: boats in the water, crates on the dock, street lamps, etc., according to theme rules.
All these are created as Godot nodes (Spatial nodes, MeshInstances, etc.) with appropriate transforms, ready in the scene tree.
The result is a playable scene generated by rules but following the high-level description the designer gave. If the designer changes the theme to “Modern Port”, the same layout rules might apply but swap medieval houses with modern buildings, and wooden piers with concrete docks, etc., demonstrating the flexibility of the rule-based system.
Throughout development, we’ll maintain scripts and example scenes for each type of environment to validate our approach. For instance, we’ll write a GDScript for dungeon generation (indoor test), one for city block generation (outdoor test), and so on, then integrate them under one plugin UI. By researching and leveraging known procedural generation techniques (like BSP for indoors and rule-based road generation for outdoors), our development plan ensures we use proven practices. The end goal is a Godot plugin that acts as a robust foundation/skeleton for level generation – extensible with new rules and content as our game grows, while keeping everything self-contained in Godot (no external engines or libraries needed).
With this plan, we combine the power of rule-based design (grammars, partitioning algorithms, and parameterized rules) with Godot’s scripting and editor extensibility to create an easy-to-use procedural scene generator. The result will allow us to generate diverse environments (from a cramped basement to a sprawling seaside town) at the push of a button, with consistent design language and the ability to tweak rules to achieve the desired look and feel for our game levels.
Sources:
Boris the Brave, Graph Rewriting for Procedural Level Generation – discusses using graph grammars (PhantomGrammar) in Unexplored
boristhebrave.com
boristhebrave.com
.
ArcGIS CityEngine Documentation: Illustrates shape grammar (CGA rules) for rule-based 3D city modeling
doc.arcgis.com
doc.arcgis.com
.
Mathias Plans, Shape Grammar Editor (2023) – Master’s thesis tool for rule-based 3D building generation
courses.cs.ut.ee
courses.cs.ut.ee
.
Jono Shields, Procedural Dungeon Generation in Godot – explains using BSP to split space into rooms and corridors
jonoshields.com
jonoshields.com
.
Procedural Moonbase Blog (2016) – demonstrates using density maps and clustering for road network generation
doingmyprogramming.wordpress.com
doingmyprogramming.wordpress.com
.
Godot Engine Documentation – guidelines on making EditorPlugins (tool scripts) for extending the editor
docs.godotengine.org
.