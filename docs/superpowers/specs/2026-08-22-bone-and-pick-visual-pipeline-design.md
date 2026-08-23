# Bone & Pick Visual Pipeline Design

**Date:** 2026-08-22  
**Status:** Approved direction; ready for implementation planning  
**Target:** Dungeon Union's playable Bone & Pick workplace

## Goal

Replace the current procedural mine greybox with a reusable, premium-indie 2.5D environment kit. Blender is the authored source; Godot remains a lightweight 2D runtime with fixed-orientation isometric composition, interaction overlays, and accessible incident presentation.

## Chosen approach

Use Blender 5.2 LTS in headless mode to create modular environment groups and render transparent PNG layers from one locked orthographic camera. Do not convert the Godot game to a real-time 3D world. This retains the existing simulation, fixed 2:1 isometric layout, deterministic input behavior, and low-overhead Apple Silicon target while enabling dimensional lighting, occlusion, and polished materials.

## Art direction

The mine combines fantasy storybook forms with screen-printed labor-pamphlet texture:

- blue-black stone and charcoal shadows;
- worn cream highlights, brass hardware, ember-orange practical light, and union red accents;
- chunky readable silhouettes, painted diffuse materials, selective ink outlines, and restrained grain;
- warm, communal visual signals for union spaces; cold, symmetrical, surveillant motifs for employer-owned spaces.

The result must remain legible at the current camera's minimum and maximum zoom, including when high-contrast and reduced-motion accessibility modes are enabled.

## Deliverable: first environment kit

The first slice contains the following authored environment components:

1. Diamond-grid mine floor and variation decals.
2. Rock face and timber-shoring wall groups.
3. Rail, cart, lantern, alarm post, rubble, hazard-sign, and workbench props.
4. Fume-hazard ground decal and cave-in dressing that sit beneath the existing non-color-only markers.
5. Three foreground occluders to give the mine depth without concealing selected workers or incident UI.
6. Twelve worker-facing anchor points matching the current simulation positions.

This is a single room, not a universal dungeon tileset. Its construction rules and source templates become the basis for later workplaces.

## File and asset contract

```text
art/
  blender/
    bone_and_pick_environment.blend
    scripts/
      build_bone_and_pick.py
  renders/
    bone_and_pick/
      ground.png
      midground.png
      structure.png
      foreground.png
      manifest.json
assets/
  environment/
    bone_and_pick/
      (Godot-imported copies of approved render layers)
```

`art/blender/` holds versioned editable source. The Python script is the sole automated authoring entry point and must run under Blender's `--background --python` CLI. `renders/` holds reproducible review outputs. `assets/` holds the copies consumed by Godot.

Each render layer has a stable native canvas, shared world origin, alpha background, and an entry in `manifest.json` containing its filename, z-layer, world anchor, and native dimensions. Major groups use a 2048 × 2048 canvas; small overlays or isolated props use a 512–1024px canvas only if their world anchor remains exact.

## Geometry and camera rules

- The Godot mine view's 2:1 diamond grid is authoritative.
- The Blender scene contains a matching ground-plane guide and named empty at world origin.
- The Blender camera is orthographic, locked, and never rotated per asset.
- A shared lighting rig bakes the environment's broad illumination. Godot retains selection, hazard, focus, and incident overlays above all art.
- Layers render separately: `ground`, `midground`, `structure`, and `foreground`.
- Foreground art must never cover active worker tokens, nameplates, focus rings, or incident markers.

## Godot integration

`WorkplaceMineView` becomes an assembly surface for the four rendered layers. It preserves its worker-node positions, camera transform, selected-worker ring, authored incident markers, accessible hazard hatching, and keyboard/trackpad behavior. Art layers are loaded from `assets/environment/bone_and_pick/` and positioned by the manifest rather than manually tuned per resolution.

No gameplay command, save format, event definition, or simulation-state interface changes. Missing or invalid art assets degrade safely to the existing procedural drawing so the vertical slice stays playable during art iteration.

## Validation

Implementation adds:

- a headless Blender render command that produces all required layers and manifest;
- a manifest validator checking required names, PNG existence, alpha-capable format, dimensions, anchors, and z-order;
- a Godot smoke test that confirms the art assembly loads without hiding worker/interactivity nodes;
- visual checks at 0.75×, 1×, 1.5×, and 2× interface scale, normal and high-contrast modes;
- a deterministic fallback test for a missing art layer.

The first asset pass is accepted when the playable room has the authored visual kit, workers and markers remain readable, the fallback path works, and the full Godot suite remains green.

## Non-goals

- Runtime 3D camera or free camera rotation.
- Final character rigs, portraits, animation suite, sound, or full campaign art.
- Procedural asset generation at game runtime.
- Replacing non-color accessibility cues with purely decorative art.
