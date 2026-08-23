# Dungeon Union Title Screen and Interface Refinement

## Purpose

Introduce a premium, playable front door for Dungeon Union without disrupting the existing Bone & Pick workplace simulation. The title screen uses authored key art as its background and makes the next action immediately legible.

## Player flow

1. AppRoot validates content, then shows a new `TitleScreen` instead of immediately configuring the workplace.
2. **Continue Shift** restores the existing campaign when one is available, otherwise begins a new shift.
3. **New Shift** begins the current Bone & Pick vertical slice with a fresh simulation state.
4. **Accessibility** opens a compact title-screen panel for reduced motion, high contrast, dyslexia-friendly font, and UI scale; it shares the existing `AccessibilitySettings` resource with the workplace.
5. Beginning a shift hides the title UI, configures the existing `WorkplaceView`, and switches AppRoot to `workplace`. The workplace's existing save/load actions remain authoritative.

## Visual direction

The generated 16:9 mine key art lives at `assets/title/dungeon-union-bone-and-pick-key-art-v1.png`. It remains text-free. Godot supplies live, accessible text: a cream serif `DUNGEON UNION` masthead, a small data-font subtitle, and deliberately square paper-and-ink action buttons. A coal scrim protects contrast without obscuring the scene.

The workplace HUD receives a matching case-file refinement: the right docket gains a subdued paper texture and clearer separation between the incident heading, evidence copy, and actions. Existing text, focus order, high-contrast behavior, and keyboard support must remain intact.

## Components

- `TitleScreen` (`Control`) owns background art, title typography, action buttons, and the accessibility drawer. It emits semantic action signals only.
- `AppRoot` owns transition and save-state decisions. It never moves simulation logic into the title UI.
- `WorkplaceHUD` remains the owner of workplace layout; its refinement is visual and does not alter commands or simulation state.

## Error handling

- Missing key art falls back to the coal backdrop and live title text.
- Missing/corrupt save data leaves Continue Shift visible but routes to a fresh shift, avoiding a dead-end button.
- Accessibility settings are applied before the title is shown and again when entering the workplace.

## Acceptance checks

- App boot lands on the title screen and does not configure the workplace until a shift action is selected.
- Continue Shift and New Shift both reach the existing playable workplace.
- Accessibility controls update the shared settings and remain keyboard focusable.
- The title asset is versioned, readable, and does not contain essential baked-in text.
- Existing Godot acceptance tests continue to pass; new tests cover title actions and accessibility propagation.
