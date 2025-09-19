# AI-Assisted Asset Production Pipeline

This document lays out a lean, repeatable workflow for generating every Palim art deliverable with AI image/3D models and Blender CLI tooling. It complements `docs/asset_checklist.md` by showing how to actually produce those assets at scale.

---

## 1. Goals & Principles
- **Consistency with Lore:** Prompts, styles, and palettes derive from `docs/lore/**` and district palettes defined in the checklist.
- **Automation First:** Every repeatable step executes via scripted tools (ComfyUI/InvokeAI flows + Blender headless scripts + Python glue).
- **Separation of Concerns:** Concept generation → texture synthesis → material assembly → export each handled by discrete modules with shared config.
- **Non-destructive Iteration:** Store source prompts, seeds, intermediate outputs for reproducibility and revision.
- **Asset-First Naming:** Outputs automatically land in the `res://` structure required by Godot, while source files live in `art/source/**`.

---

## 2. Tool Stack Overview
| Layer | Tooling | Purpose |
| --- | --- | --- |
| Prompt Orchestration | YAML prompt library + Jinja templates | Keep lore-driven descriptions consistent |
| Image Generation | ComfyUI/InvokeAI pipelines (SDXL, ControlNet, LCMS) | Concept art, masks, albedo bases |
| Texture Derivation | AI-based normal/roughness generators (e.g. NormalBaker, Height2Normal) + Blender Baking | Produce complete PBR sets |
| 3D Assistance | TripoSR/DreamGaussian (optional) for meshes; mainly rely on base rig files | Speed up hero sculpt block-ins |
| Blender Automation | Blender CLI (`blender -b -P`) scripts under `tools/blender/` | Apply textures, set up materials, generate LOD/collision, export `.glb/.tscn` |
| QA Utilities | Godot CLI preview scripts, image diffs, metadata validators | Ensure compliance with asset checklist |

---

## 3. Prompt & Reference Management
1. **Prompt Library** (`art/prompts/`):
   - `districts/*.yml` – palette, motifs, architecture adjectives.
   - `characters/*.yml` – appearance, clothing, prop notes, emotional states.
   - `props/*.yml` – size references, wear level, cultural stamps.
2. **Template Engine:** Render final prompt strings using Jinja2 (`tools/prompt_render.py`). Example keys: `{{district.palette}}`, `{{npc.visual_traits}}`.
3. **Reference Boards:** Generate and store moodboards in `art/reference/{category}/` using the same prompts, so human review aligns with automated outputs.
4. **Seed Tracking:** Log seeds and negative prompts in metadata JSON per output to make variants reproducible.

---

## 4. High-Level Pipeline (per asset request)
1. **Ingest:** Designer fills out `asset_request.yml` (ID, type, lore refs, required outputs).
2. **Prompt Render:** `./tools/prompt_render.py asset_request.yml` generates final prompt bundle + negative prompts.
3. **AI Synthesis:** `./tools/run_comfy.py bundle.yml` calls ComfyUI API, stores raw images in `art/source/generated/{asset_id}/concept/`.
4. **Post-process:** Python scripts convert concept art into texture-ready assets (seam removal, tiling) using e.g. `seamless.py`, `tileable_diffusion`.
5. **Texture Set Generation:**
   - Diffusion output → Height map via `normalizer.py` → Normal map.
   - Roughness/Metallic via ML predictors or Blender baking.
   - Pack channels per checklist.
6. **Blender Assembly:** Headless Blender script ingests base mesh/rig, applies new materials, adjusts shaders, bakes combined maps, exports `.glb/.tscn` to target directory.
7. **Validation:** Run `./tools/validate_assets.py --asset asset_id` to ensure textures, naming, and directories match checklists.
8. **Version Commit:** Store generated files + metadata; push to repo and asset tracker.

---

## 5. Asset-Type Pipelines

### 5.1 Characters (Base Rig + Skins)
1. **Base Inputs:** `res://assets/characters/base/palim_humanoid.glb`, UV templates, clothing meshes.
2. **Skin Texture Generation:**
   - Render prompts referencing character sheet (e.g. `characters/celeste.yml`).
   - Generate albedo variants (body, face, hands) with diffusion + ControlNet using UV layout guides.
   - Create secondary masks (freckles, grime) via `canny` or segment anything models.
3. **Clothing & Accessory Textures:**
   - Generate fabric patterns per district -> tileable using `tile_resize.py`.
   - Produce emissive and normal variants using procedural passes in Blender.
4. **Blender CLI Script** (`tools/blender/apply_character_skin.py`):
   - Arguments: `--character celeste --skin version_01`.
   - Steps: load base rig, duplicate material slots, assign generated texture set, hook up custom shader (`palim_character.gdshader`), bake AO & curvature, write `.glb` to `res://assets/characters/npcs/celeste/celeste_v01.glb`, update `.tscn` wrappers.
   - Export portrait renders (headshot) via Eevee render in headless mode (use `--render-output` and `--render-frame`).
5. **Animation Compatibility:** Ensure generated clothing weights follow base rig by auto-binding (Blender script `auto_weight.py`) or copying weights from template garments.
6. **Metadata:** Save `character_skin.json` (prompt, seed, textures used, date). 

### 5.2 Environment Modular Kits
1. **Prompt components:** District + asset category (e.g. `inner_bureaucracy` + `wall_segment`).
2. **Concept Tiles:** Generate front, side, detail sheets.
3. **Texture Synthesis:** Create seamless albedo/roughness via diffusion; fit to 2×2 m tile.
4. **Geometry:** Use existing modular mesh templates (`art/source/geometry/modular/*.blend`). Scripts adjust displacement from height maps via `apply_displacement.py`.
5. **Blender CLI** (`tools/blender/build_modular_asset.py`):
   - Input: template `.blend`, texture set paths, asset ID.
   - Process: load template, assign textures, run low/high bake, generate collision (simplify mesh), add `WallHidingSystem` node if flagged, pack to `.glb` + `.tscn` under `res://addons/scene_generator/assets/...`.
6. **Variant Generation:** Use prompt seeds to produce 3–5 variations per tile. Scripts randomize but enforce palette constraints.

### 5.3 Hero Environment Pieces
1. Generate high-detail concept images per major location using multi-prompt sequences (overview, material close-ups).
2. For large structures, optionally run DreamGaussian/TripoSR from concept depth maps to block in geometry, then refine in Blender.
3. Blender CLI script `hero_scene_builder.py` assembles modules, applies generated textures, sets up lighting referencing environment presets, exports to `res://assets/environment/hero/{location}/`.

### 5.4 Props & Interactive Objects
1. Prompt uses prop YAML (size, material, district). Generate orthographic concept set.
2. For flat assets (forms, posters) keep in 2D; for 3D, feed to `prop_builder.py` which:
   - Loads primitive template,
   - Applies albedo+normal,
   - Generates simple collision,
   - Exports `.glb` & `.tscn` with animation tracks if specified.
3. Additional script `paper_animation.py` adds shader-based animation for floating documents.

### 5.5 VFX & Shaders
1. Generate sprite sheets (e.g. language glyphs) via tiled diffusion with transparent backgrounds.
2. Use Blender compositor or custom Python to create flipbooks.
3. Package into `.tres` with GPUParticles via `build_vfx.py`.
4. Store shader code templates in `assets/shaders/templates/`. Use prompts to synthesize noise textures or gradient ramps.

### 5.6 UI & 2D Assets
1. Prompt templates reference Bureau design language (stamps, forms). Generate frame elements with alpha.
2. Vectorize via `vectorizer.py` (e.g. Diffusion → SVG) when needed.
3. Compose UI atlases using automated Figma API export or `compose_ui.py` (PIL-based).
4. Export to `res://ui/assets/` (+ `.theme` updates).

---

## 6. Automation Architecture

### 6.1 Configuration
- `pipeline_config.yml` lists tools paths (ComfyUI server URL, Blender binary, output roots) and per-asset overrides.
- Job runner `manage_assets.py` reads config + asset request queue.

### 6.2 Job Queue
- Accepts JSON payload: `{id, type, district, prompt_template, output_targets}`.
- Spawns stages sequentially but allows parallelism for generation vs Blender steps.
- Stores job logs in `art/logs/{asset_id}.log`.

### 6.3 Blender CLI Scripts
All under `tools/blender/` and share utility module `blender_pipeline_utils.py`.
- Invoke as `blender -b base_scene.blend -P tools/blender/apply_character_skin.py -- --character celeste ...`.
- Scripts handle material creation, UV mapping tweaks, shader graph wiring, light setup, baking, LOD creation, export (`bpy.ops.export_scene.gltf`), and saving `.tscn` via Godot exporter if installed.

### 6.4 Godot Integration
- After Blender export, run `./tools/godot_reimport.py asset_id` to call Godot CLI and refresh `.import` files.
- Optional screenshot via `godot --headless --run screenshot.gd` for quick previews.

---

## 7. Directory Conventions
```
art/
  prompts/
  reference/
  source/
    generated/{asset_id}/(concept|texture|geometry)
    blender/{asset_id}/.blend
  logs/
res://assets/
  characters/
  environment/
  props/
  shaders/
  vfx/
  textures/
  ui/
res://addons/scene_generator/assets/
```
- `art/source/**`: Raw AI outputs + editable files (not shipped in game).
- `res://assets/**`: Clean runtime assets.
- Metadata JSON/YAML accompanies every generated asset with prompt, seed, scripts used.

---

## 8. Quality Assurance & Iteration
1. **Automated Checks** (`validate_assets.py`):
   - File naming, directory compliance.
   - Texture channel verification (normal map format, RG packing).
   - Polycount thresholds, collision presence.
   - Shader parameter defaults (no NaNs).
2. **Visual Diff:** Compare new renders to previous versions to spot regressions.
3. **Lore Alignment Review:** Quick manual pass referencing source doc links stored in metadata.
4. **Feedback Loop:** Designer updates `asset_request.yml` with notes; pipeline reruns from desired stage (support `--skip-generation`, `--only-blender`).

---

## 9. Scheduling & Scalability
- Batch assets per district to reuse prompts and reduce context switching.
- Use nightly runs for heavy Blender baking jobs; keep GPU hours for AI generation during off-peak times.
- Maintain library of reusable outputs (tileable textures, props) to seed future generations.
- Integrate with project management tool (e.g. Linear/Jira) via `manage_assets.py --post-status` to auto-update tickets.

---

## 10. Immediate Next Steps
1. **Implement Prompt Library:** Stub YAML files for key districts/characters; write `prompt_render.py`.
2. **Set Up ComfyUI Workflow:** Create and save node graph for tileable texture + figure render; expose API endpoints.
3. **Author Blender Utilities:** Scaffold `tools/blender/apply_character_skin.py` and shared utils.
4. **Test Character Skin Pipeline:** Run end-to-end for Celeste (albedo → Blender → Godot import).
5. **Expand Modular Asset Scripts:** Start with Inner Bureau floor/wall kit, then replicate for other districts.
6. **Document Usage:** Create README in `tools/` describing command invocations for each script.

This pipeline keeps AI generation, Blender automation, and Godot integration tightly aligned with the asset checklist so the entire content load can be produced systematically.
