# Bone & Pick Visual Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Bone & Pick mine greybox with reproducible Blender-rendered isometric environment layers that assemble safely in the existing Godot workplace.

**Architecture:** Blender 5.2 LTS generates a versioned `.blend`, four transparent PNG layers, and a JSON manifest from a deterministic Python build script. A typed Godot loader validates the contract and `WorkplaceMineView` displays the layers beneath existing workers, selection rings, hazard hatching, and incident markers; absent or malformed art preserves the procedural fallback.

**Tech Stack:** Blender 5.2 LTS CLI and Python API; Godot 4.x, typed GDScript, PNG, JSON.

**Spec:** `docs/superpowers/specs/2026-08-22-bone-and-pick-visual-pipeline-design.md`

## Global Constraints

- Keep Godot 4.x and statically typed GDScript. Do not introduce runtime 3D, camera rotation, or dependencies.
- The existing 2:1 fixed isometric grid, worker anchors, selection rings, incident markers, keyboard controls, and non-color accessibility cues remain authoritative.
- Use Blender 5.2 LTS through `blender --background --python`; source lives in `art/blender/` and game assets in `assets/environment/bone_and_pick/`.
- Render transparent PNGs named `ground.png`, `midground.png`, `structure.png`, and `foreground.png` from the same 2048 × 2048 canvas and world origin.
- Invalid, absent, or incomplete visual assets must leave the playable procedural fallback intact.

## File Structure

| File | Responsibility |
| :--- | :--- |
| `art/blender/scripts/build_bone_and_pick.py` | Builds named modular mine collections, renders four layers, writes the manifest, and saves the `.blend`. |
| `art/blender/bone_and_pick_environment.blend` | Generated editable source scene with locked camera, lighting, and props. |
| `assets/environment/bone_and_pick/*` | Game-ready PNG layers plus the manifest. |
| `src/workplace/environment_art_manifest.gd` | Parses and validates the art contract before nodes are created. |
| `src/workplace/workplace_mine_view.gd` | Assembles sprites beneath gameplay presentation and retains fallback drawing. |
| `tests/acceptance/test_environment_art.gd` | Verifies manifest, source, rendering contract, layer order, and fallback. |

## Interfaces

`EnvironmentArtManifest` has `REQUIRED_LAYER_IDS = [&"ground", &"midground", &"structure", &"foreground"]`, `canvas_size: Vector2i`, `world_anchor: Vector2`, `layers: Array[Dictionary]`, `errors: PackedStringArray`, static `load_from_path(path: String) -> EnvironmentArtManifest`, and `is_valid() -> bool`.

Every layer dictionary contains `id: StringName`, `file: String`, `z_index: int`, `anchor: Vector2`, and `size: Vector2i`. `WorkplaceMineView` adds `environment_art_loaded() -> bool` and `environment_art_layer_names() -> PackedStringArray` for black-box acceptance checks.

---

### Task 1: Validate the environment-art contract

**Files:**
- Create: `src/workplace/environment_art_manifest.gd`
- Create: `tests/acceptance/test_environment_art.gd`
- Create: `tests/fixtures/missing-environment-manifest.json`
- Modify: `tests/test_runner.gd`

**Consumes:** Godot `FileAccess`, `JSON`, `Image`, and the four-layer contract.

**Produces:** A typed manifest parser and registered acceptance suite.

- [ ] **Step 1: Write the failing tests**

Create `test_environment_art.gd` with `run(t: TestCase)`. Load `res://assets/environment/bone_and_pick/manifest.json`; assert `manifest.is_valid()`, the exact required layer order, each `Image.load_from_file("res://assets/environment/bone_and_pick/%s" % layer.file)` is non-empty, each image equals `manifest.canvas_size`, and each image `has_alpha()`. Load the empty `{}` fixture and assert it is invalid without crashing. Add the test to `tests/test_runner.gd`.

- [ ] **Step 2: Run the test to verify it fails**

Run `godot --headless --path . --script res://tests/test_runner.gd`.

Expected: fail because the parser and required generated assets do not exist.

- [ ] **Step 3: Implement the minimal parser**

Create `environment_art_manifest.gd`. `load_from_path` uses `FileAccess.file_exists`, `FileAccess.get_file_as_string`, `JSON.new().parse`, and rejects a non-dictionary root. Require `schema_version == 1`, positive `[width, height]` canvas values, two-number `world_anchor`, exactly four ordered IDs, nonempty `file`, integer `z_index`, and an existing PNG next to the manifest. Append human-readable strings to `errors` rather than throwing.

- [ ] **Step 4: Re-run the test**

Run `godot --headless --path . --script res://tests/test_runner.gd`.

Expected: the malformed fixture passes its failure-path assertion; valid asset assertions remain red until Task 2.

- [ ] **Step 5: Commit**

Run `git add src/workplace/environment_art_manifest.gd tests/acceptance/test_environment_art.gd tests/fixtures/missing-environment-manifest.json tests/test_runner.gd && git commit -m "feat: validate environment art manifests"`.

### Task 2: Generate the Blender environment kit

**Files:**
- Create: `art/blender/scripts/build_bone_and_pick.py`
- Create: `art/blender/bone_and_pick_environment.blend`
- Create: `assets/environment/bone_and_pick/ground.png`
- Create: `assets/environment/bone_and_pick/midground.png`
- Create: `assets/environment/bone_and_pick/structure.png`
- Create: `assets/environment/bone_and_pick/foreground.png`
- Create: `assets/environment/bone_and_pick/manifest.json`
- Modify: `tests/acceptance/test_environment_art.gd`

**Consumes:** The manifest contract from Task 1.

**Produces:** A reproducible source scene and four 2048×2048 alpha PNGs.

- [ ] **Step 1: Extend tests for source assets**

Add assertions that `FileAccess.file_exists("res://art/blender/scripts/build_bone_and_pick.py")` and `FileAccess.file_exists("res://art/blender/bone_and_pick_environment.blend")` are true. Run the full suite and confirm the expected failure.

- [ ] **Step 2: Build the deterministic Blender script**

Create the Python script using only `bpy`, `math`, `json`, and `pathlib`. Clear the scene; create `GROUND`, `MIDGROUND`, `STRUCTURE`, and `FOREGROUND` collections. Build a 7×5 diamond floor, rock faces, four timber braces, rail, cart, three lanterns, alarm post, rubble, workbench, fume decal, cave-in rubble, and three foreground occluders from low-poly primitives. Use coal `#0B1114`, slate `#16242B`, paper `#E8D9B5`, brass `#D2A75C`, union red `#A54138`, safety teal `#79B7B0`, and ember `#E98B3A`.

Create `DungeonUnionIsoCamera` at `(14, -18, 16)`, aim it at `(0, 0, 0)`, set an orthographic scale in the script, and add one sun plus warm practical point lights. Render one collection at a time to the four exact PNG names with 2048×2048 RGBA output. Write manifest schema `1`, canvas `[2048, 2048]`, anchor `[0, 0]`, and layer z-indexes `-40`, `-30`, `-20`, `-10`. Save the `.blend` at the exact path.

- [ ] **Step 3: Run Blender and inspect artifacts**

Run `blender --background --python art/blender/scripts/build_bone_and_pick.py` followed by `file assets/environment/bone_and_pick/ground.png assets/environment/bone_and_pick/midground.png assets/environment/bone_and_pick/structure.png assets/environment/bone_and_pick/foreground.png`.

Expected: Blender exits 0, all assets report 2048×2048 RGBA PNG image data, manifest and `.blend` exist.

- [ ] **Step 4: Run the Godot suite**

Run `godot --headless --path . --script res://tests/test_runner.gd`.

Expected: all Task 1 and Task 2 asset assertions pass.

- [ ] **Step 5: Commit**

Run `git add art/blender assets/environment tests/acceptance/test_environment_art.gd && git commit -m "feat: add Bone and Pick Blender environment kit"`.

### Task 3: Assemble art layers in the mine view

**Files:**
- Modify: `src/workplace/workplace_mine_view.gd`
- Modify: `tests/acceptance/test_environment_art.gd`

**Consumes:** Validated manifest and generated PNG layers.

**Produces:** A contained `EnvironmentArt` sprite group below workers with safe fallback.

- [ ] **Step 1: Write failing assembly tests**

Instantiate `WorkplaceMineView`, call `configure(load("res://content/bone_and_pick/catalog.tres"))`, and assert `environment_art_loaded()`; assert names equal `["ground", "midground", "structure", "foreground"]`; assert `EnvironmentArt/foreground` has a lower z-index than `Worker_nib`. Add a second test setting `environment_manifest_path` to the malformed fixture; assert art is not loaded and `Worker_nib` still exists. Run the suite and confirm these tests fail.

- [ ] **Step 2: Implement isolated assembly**

Add exported `environment_manifest_path := "res://assets/environment/bone_and_pick/manifest.json"`, `_environment_loaded`, and `_environment_layer_names` to the mine view. At the start of `configure`, clear/build only an `EnvironmentArt` Node2D, parse the manifest, load each texture, construct a named `Sprite2D`, assign anchor/z-index, and retain order. On manifest or texture error, issue `push_warning`, keep `_environment_loaded` false, and do not disturb worker construction. Wrap procedural floor/wall/rail/alarm drawing in `if not _environment_loaded`; always draw accessible fume hatching and incident markers.

- [ ] **Step 3: Run visual/runtime regression checks**

Run `godot --headless --path . --script res://tests/test_runner.gd` and `godot --headless --path . --quit-after 2`.

Expected: both exit 0 without parse/resource errors.

- [ ] **Step 4: Commit**

Run `git add src/workplace/workplace_mine_view.gd tests/acceptance/test_environment_art.gd && git commit -m "feat: render Bone and Pick environment layers"`.

### Task 4: Add art-production and accessibility gates

**Files:**
- Modify: `README.md`
- Modify: `docs/PLAYTEST.md`
- Modify: `tests/acceptance/test_environment_art.gd`

**Consumes:** Complete art assembly and the existing accessibility test surface.

**Produces:** Documented pipeline and tests proving the art never hides playable feedback.

- [ ] **Step 1: Write failing accessibility/ordering tests**

For `AccessibilitySettings` at `0.75`, `1.0`, `1.5`, and `2.0`, configure a mine view and assert art stays loaded, all twelve `Worker_*` nodes are present, and `EnvironmentArt` remains below worker/selection/incident presentation. Run the suite and confirm any missing public inspection fails.

- [ ] **Step 2: Add only needed inspection API**

Implement `environment_art_loaded()` and `environment_art_layer_names()` if not finished in Task 3; do not add production-only accessibility branches. Keep all decorative assets below authoritative overlays.

- [ ] **Step 3: Document production**

Add an `Art pipeline` section to README with the exact Blender command and source/output locations. Add a `Visual environment check` in `docs/PLAYTEST.md`: at normal zoom and 2× UI scale, players identify the cart, fumes, alarm post, and selected worker.

- [ ] **Step 4: Run release checks**

Run `blender --background --python art/blender/scripts/build_bone_and_pick.py`, `godot --headless --path . --script res://tests/test_runner.gd`, `godot --headless --path . --script res://tests/performance/workplace_stress.gd`, and `git diff --check`.

Expected: Blender exits 0 and recreates source/renders; both Godot suites exit 0; stress reports zero backlog; diff is clean.

- [ ] **Step 5: Commit**

Run `git add README.md docs/PLAYTEST.md tests/acceptance/test_environment_art.gd src/workplace/workplace_mine_view.gd && git commit -m "docs: add Bone and Pick art pipeline checks"`.

## Final verification checklist

- [ ] The Blender command recreates the `.blend`, manifest, and four 2048×2048 alpha layers.
- [ ] Full tests, startup smoke test, and 30-agent stress test exit 0.
- [ ] Procedural fallback remains functional with a missing manifest.
- [ ] Visual review confirms workers, focus rings, accessible hatching, and incident markers are not obscured at normal and 2× UI scale.
- [ ] `git diff --check` and `git status --short` are clean after final commit.
