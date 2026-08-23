# Dungeon Union Title Screen and Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a playable, accessible title screen with generated key art, refine the workplace case file, and preserve the current Bone & Pick simulation flow.

**Architecture:** `TitleScreen` is a focused presentation component that emits player intent while `AppRoot` retains ownership of boot, save-path resolution, and workplace configuration. The existing `WorkplaceHUD` remains behaviorally unchanged; its change is limited to the case-file visual hierarchy.

**Tech Stack:** Godot 4.7, GDScript, PNG key art generated with built-in ImageGen, existing custom acceptance runner.

**Spec:** `docs/superpowers/specs/2026-08-22-title-screen-and-interface-design.md`

## Global Constraints

- Preserve Apple Silicon MacBook compatibility with Godot `gl_compatibility` rendering.
- Keep essential title copy as accessible live Godot text; the key art contains no essential baked-in text.
- Keep WorkplaceView commands, save/load behavior, and keyboard accessibility intact.
- Missing image or campaign data must degrade to a usable fresh-shift route.
- Use the shared `AccessibilitySettings` resource for both title and workplace presentation.

---

### Task 1: Version title key art and test its contract

**Files:**
- Create: `assets/title/dungeon-union-bone-and-pick-key-art-v1.png`
- Modify: `tests/acceptance/test_title_screen.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `res://assets/title/dungeon-union-bone-and-pick-key-art-v1.png`, a readable title-screen PNG.
- Consumes: `TestCase.check(condition: bool, message: String)`.

- [ ] **Step 1: Write the failing asset contract test**

```gdscript
static func _title_key_art_is_versioned(t: TestCase) -> void:
    var image := Image.load_from_file("res://assets/title/dungeon-union-bone-and-pick-key-art-v1.png")
    t.check(not image.is_empty(), "title key art is a readable PNG")
    if not image.is_empty():
        t.check(image.get_width() > image.get_height(), "title key art is landscape")
```

- [ ] **Step 2: Run the acceptance suite to verify the test fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: failure reporting the missing title key art.

- [ ] **Step 3: Copy the selected generated key art into the versioned asset path**

```sh
mkdir -p assets/title
cp /Users/spkoehl/.codex/generated_images/01a02a5a-90d0-7b63-8e84-743c7fd31ef5/exec-a19a1442-ddab-46ab-9e5d-65fe4b6b03f8.png assets/title/dungeon-union-bone-and-pick-key-art-v1.png
```

- [ ] **Step 4: Run the suite to verify the asset contract passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: exit code 0.

- [ ] **Step 5: Commit the asset contract**

```sh
git add assets/title/dungeon-union-bone-and-pick-key-art-v1.png tests/acceptance/test_title_screen.gd tests/test_runner.gd
git commit -m "art: add Dungeon Union title key art"
```

### Task 2: Build the title presentation component

**Files:**
- Create: `src/ui/title_screen.gd`
- Create: `src/ui/title_screen.tscn`
- Modify: `tests/acceptance/test_title_screen.gd`

**Interfaces:**
- Produces: `class_name TitleScreen`, signals `continue_requested`, `new_shift_requested`, and `accessibility_changed(settings: AccessibilitySettings)`.
- Consumes: `AccessibilitySettings` and `set_accessibility(settings: AccessibilitySettings)`.

- [ ] **Step 1: Write the failing title interaction test**

```gdscript
static func _title_actions_are_focusable_and_semantic(t: TestCase) -> void:
    var title: TitleScreen = load("res://src/ui/title_screen.tscn").instantiate()
    t.check(title.has_node("ContinueShift"), "title exposes Continue Shift")
    t.check(title.has_node("NewShift"), "title exposes New Shift")
    t.check(title.has_node("Accessibility"), "title exposes Accessibility")
    t.equal(title.get_node("NewShift").focus_mode, Control.FOCUS_ALL, "New Shift supports keyboard focus")
    title.free()
```

- [ ] **Step 2: Run the suite to verify the title test fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: failure loading the missing title scene.

- [ ] **Step 3: Implement the minimal title UI**

```gdscript
class_name TitleScreen
extends Control

signal continue_requested
signal new_shift_requested
signal accessibility_changed(settings: AccessibilitySettings)

func set_accessibility(settings: AccessibilitySettings) -> void:
    # Apply the supplied scale and selected accessible font to each title control.
    scale = Vector2.ONE
```

Use a full-rect `TextureRect` for `res://assets/title/dungeon-union-bone-and-pick-key-art-v1.png`, a coal `ColorRect` scrim, live title labels, focusable `ContinueShift`, `NewShift`, and `Accessibility` buttons, and a compact accessibility drawer that edits a duplicated `AccessibilitySettings` instance.

- [ ] **Step 4: Run the suite to verify title interactions pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: exit code 0.

- [ ] **Step 5: Commit the title component**

```sh
git add src/ui/title_screen.gd src/ui/title_screen.tscn tests/acceptance/test_title_screen.gd
git commit -m "feat: add accessible title screen"
```

### Task 3: Route AppRoot from title actions into the existing workplace

**Files:**
- Modify: `src/app/app_root.gd`
- Modify: `src/app/app_root.tscn`
- Modify: `tests/acceptance/test_title_screen.gd`

**Interfaces:**
- Consumes: `TitleScreen.continue_requested`, `TitleScreen.new_shift_requested`, `TitleScreen.accessibility_changed(settings)`.
- Produces: `AppRoot.begin_shift(recover_campaign: bool)` and title-first boot behavior.

- [ ] **Step 1: Write the failing routing test**

```gdscript
static func _app_root_waits_for_title_action_before_workplace(t: TestCase) -> void:
    var app: AppRoot = load("res://src/app/app_root.tscn").instantiate()
    t.equal(app.current_mode, &"title", "app opens at the title screen")
    app.begin_shift(false)
    t.equal(app.current_mode, &"workplace", "New Shift enters the workplace")
    app.free()
```

- [ ] **Step 2: Run the suite to verify routing fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: failure because AppRoot currently enters workplace during `_ready()`.

- [ ] **Step 3: Implement title-first AppRoot routing**

```gdscript
func begin_shift(recover_campaign: bool) -> void:
    $TitleScreen.hide()
    $WorkplaceView.configure(self, active_catalog, event_seed, _resolved_save_path(), recover_campaign)
    $WorkplaceView.show()
    change_mode(&"workplace")
```

Move existing save-path resolution into `_resolved_save_path()`. On ready, boot, show title, connect title signals, and defer workplace configuration until `begin_shift`. Apply emitted accessibility settings to the title and workplace view.

- [ ] **Step 4: Run the suite to verify title-to-workplace routing passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: exit code 0 and the original workplace tests still pass.

- [ ] **Step 5: Commit routing**

```sh
git add src/app/app_root.gd src/app/app_root.tscn tests/acceptance/test_title_screen.gd
git commit -m "feat: route app through title screen"
```

### Task 4: Refine the workplace case-file presentation

**Files:**
- Modify: `src/ui/workplace_hud.gd`
- Modify: `tests/acceptance/test_scene_accessibility.gd`

**Interfaces:**
- Consumes: existing case labels in `WorkplaceHUD._labels`.
- Produces: a visual-only `CaseFileTexture` layer that stays below readable title, body, grievance, and action controls.

- [ ] **Step 1: Write the failing case-file visual hierarchy test**

```gdscript
static func _case_file_texture_stays_below_readable_copy(t: TestCase) -> void:
    var hud: WorkplaceHUD = load("res://src/ui/workplace_hud.tscn").instantiate()
    var texture: TextureRect = hud.get_node("CaseFileTexture")
    t.check(texture.mouse_filter == Control.MOUSE_FILTER_IGNORE, "case-file texture cannot block controls")
    t.check(texture.z_index < hud.get_node("CaseTitle").z_index, "case-file texture stays behind title copy")
    hud.free()
```

- [ ] **Step 2: Run the suite to verify the hierarchy test fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: failure because `CaseFileTexture` does not yet exist.

- [ ] **Step 3: Add the paper-and-ink case-file layer**

```gdscript
var case_texture := TextureRect.new()
case_texture.name = "CaseFileTexture"
case_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
case_texture.z_index = -1
case_texture.modulate = Color(1, 1, 1, 0.18)
```

Use the existing union pamphlet texture as a quiet, low-opacity backdrop within the right docket bounds. Keep title, narrative, evidence, action, forecast, and button nodes above it; do not change their command signals, text values, focus behavior, or action enablement.

- [ ] **Step 4: Run the suite to verify HUD refinement passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: exit code 0.

- [ ] **Step 5: Commit HUD refinement**

```sh
git add src/ui/workplace_hud.gd tests/acceptance/test_scene_accessibility.gd
git commit -m "style: refine workplace case file"
```

### Task 5: Final verification and publication

**Files:**
- Verify: all title, app, workplace, and asset files above.

**Interfaces:**
- Consumes: complete title flow and existing Godot test runner.
- Produces: a pushed `feature/bone-and-pick-vertical-slice` branch.

- [ ] **Step 1: Run complete test suite**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

Expected: exit code 0.

- [ ] **Step 2: Inspect repository state**

Run: `git status --short && git log --oneline -6`

Expected: all intended files committed and no unexpected worktree changes.

- [ ] **Step 3: Push the feature branch**

Run: `git push origin feature/bone-and-pick-vertical-slice`

Expected: remote branch advances with all local commits.
