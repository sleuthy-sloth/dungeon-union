# Task 8 Report — Playable Bone & Pick Vertical Slice

## Outcome

Task 8 composes the production simulation, authored event runtime, grievance, organizing, negotiation, campaign-upgrade, save, and presentation boundaries into a boot-playable 1440×900 workplace. `WorkplaceController` is the sole render-frame bridge: every logical tick applies one worker-simulation tick and immediately sends one Task 6 `FixedTickEventCommand` to `AppRoot`. `AppRoot` has no `_process` simulation loop.

The workplace presents all 12 named Bone & Pick workers on a fixed 2:1 isometric floor with Y sorting, bounded pan/zoom, contextual worker/incident inspection, written and patterned hazard cues, pause plus 1×/2×/4×, Tab incident cycling, organizer metrics, grievance documentation, negotiation, and a five-branch union hall. Presentation reads copied snapshots and issues typed commands; it does not reach into service dictionaries.

## Required Review Fix Round

A read-only senior review initially returned **Not Ready** with two Critical findings and six Important findings. The two Critical findings were accepted and fixed under new observed RED tests:

1. **Auto-pause tick loss:** `SimulationClock.advance()` had already consumed a large frame before the controller broke on a major incident. The controller now preserves every unprocessed logical tick in an explicit deferred queue. The acceptance pauses at tick 181, resumes with auto-pause disabled, reaches tick 725, and proves every recorded fixed-tick command is gap-free.
2. **Manufactured negotiation causality:** both controller and fixture previously supplied minimum evidence regardless of workplace play. Negotiation now constructs evidence, resources, participation, trust, and worker priorities solely from public grievance, organizing, and worker views. An unprepared package is rejected; documenting the case improves the safety concession rank and changes the vote to ratification.

Important review fixes also completed:

- A grievance action resolves through `GrievanceService`; repeating it returns a blocker and cannot mint solidarity.
- Documentation is a separate command step. The case file exposes all four slice actions—informal, grievance, petition, and work-to-rule—with ready counts or plain-language blockers from production forecasts.
- Negotiation presentation includes the safety clause, yes/no vote totals, and a qualitative named-worker vote explanation.
- Forecast publication consults the authoritative grievance view, so every action switches to the same terminal blocker after completion instead of advertising stale executable snapshots.
- Active authored incidents now render as patterned floor markers at stable mine locations and cluster at minimum zoom, rather than existing only in the case file.
- UI scale changes font/layout treatment without scaling the fixed canvas beyond its bounds. Dyslexia/high-contrast settings propagate to every HUD text role and the union hall.

The remaining review concerns that require systems or external assets beyond the Task 8 automated gate—manual save-menu UX, final rendered/audio stress, expanded multi-phase save coverage, and target-hardware evidence—remain recorded below rather than being mislabeled complete.

Fix Round 2 added authoritative terminal forecast blockers for all four actions and a resource-stability regression. The reviewer’s final narrow verdict was **APPROVE**, with no remaining Critical or Important Task 8 breakage; append-only incident history remains a non-blocking minor follow-up.

## TDD Evidence

### Initial acceptance RED

Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Observed exit `1` before production integration:

```text
slice has twelve active workers: expected 12, got 0
prepared safety package ratifies
```

The failure came from an inert test-only `BoneAndPickFixture`, so it was a behavioral assertion failure rather than a missing-file or parser error.

The presentation acceptance was then registered and observed RED for every absent runtime scene/script. The 30-agent fixture was separately observed RED with exit `1` because its required public worker-list constructor did not exist.

### Focused follow-up cycles

- Added an acceptance mutation check for continuous Task 6 command delivery. GREEN records commanded ticks exactly as `[1, 2, 3, 4, 5]` while the controller view advances to tick 5.
- Added a RED for resolving the first incident, allowing later authored incidents, and interrupting an accelerated large render frame on auto-pause. Initial behavior dropped the unprocessed portion of the large frame; GREEN preserves and later consumes the deferred ticks without command gaps.
- Added a RED for primary-drag pan and trackpad magnification. GREEN publishes a bounded `Vector2(190, 115)` pan offset and clamps magnification to `1.28`.
- Intentionally inserted a parser fault into the dynamically loaded stress body. The stable stress runner exited `1` and reported `workplace stress fixture has parse errors`; the fault was removed and the fixture returned GREEN.

### GREEN

Fresh full-suite command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd --log-file /tmp/dungeon-union-tests.log
```

Observed exit `0` with no project assertion, script, resource, or parse error. The macOS sandbox still prints its host certificate lookup warning after execution; that warning is outside the project and does not change the exit status.

Stress command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance/workplace_stress.gd --log-file /tmp/dungeon-union-stress-green.log
```

Observed exit `0`:

```text
WORKPLACE_STRESS agents=30 ticks=240 elapsed_ms=5.634 backlog=0.000000
```

This is a deterministic headless backlog/parse gate, not evidence of interactive target-hardware FPS.

## Files

### Production and configuration

- `project.godot` — 1440×900 project remains the logical target; enables ETC2/ASTC import required by arm64 export.
- `export_presets.cfg` — recognized `macOS arm64 Development` preset with `binary_format/architecture="arm64"`.
- `src/app/app_root.gd`, `src/app/app_root.tscn` — boot and explicitly configure the playable workplace scene; no hidden simulation processing.
- `src/workers/workplace_simulation.gd` — public deterministic `create_from_worker_ids` constructor for production-sized/stress compositions.
- `src/accessibility/accessibility_settings.gd` — copied, normalized UI scale, major-event auto-pause, reduced motion, high contrast, and dyslexia-font settings.
- `src/campaign/apply_upgrade_command.gd`, `src/campaign/campaign_state.gd` — typed campaign upgrade command and copied read view.
- `src/workplace/workplace_commands.gd` — typed select, inspect, pause, speed, propose-action, and enter-negotiation commands.
- `src/workplace/workplace_controller.gd` — fixed-tick bridge, command handling, copied view, service composition, keyboard/mouse/trackpad controls.
- `src/workplace/workplace_mine_view.gd`, `src/workplace/workplace_view.tscn` — fixed orientation, 2:1 diamonds, Y-sorted named workers, pattern-coded hazards, bounded camera presentation.
- `src/ui/workplace_hud.gd`, `src/ui/workplace_hud.tscn` — stable top rail, clipped left docket, contextual cut-corner case file, written incident cues, action/time/hall controls.
- `src/ui/union_hall_view.gd`, `src/ui/union_hall_view.tscn` — one command-applied upgrade in each of five branches.

### Tests and documentation

- `tests/fixtures/bone_and_pick_fixture.gd` — required public facade contract and in-memory save round trip, using only production constructors/commands/views.
- `tests/acceptance/test_vertical_slice.gd` — exact end-to-end acceptance flow.
- `tests/acceptance/test_workplace_presentation.gd` — tick-command, copied-view, control, campaign, accessibility, and scene composition contracts.
- `tests/performance/workplace_stress.gd`, `tests/performance/workplace_stress_fixture.gd` — parse-aware runner plus 30-agent zero-backlog body.
- `tests/test_runner.gd` — acceptance registrations.
- `docs/PLAYTEST.md` — three-player gate, exact 0/1/2 observation rubric, intervention rules, accessibility observations, performance/build record, and session template.

## Visual Design Critique

The screen follows the approved six-token palette exactly: Coal Black `#0B1114`, Smelter Slate `#16242B`, Chalk Paper `#E8D9B5`, Lamp Brass `#D2A75C`, Union Red `#A54138`, and Safety Teal `#79B7B0`. Portable `SystemFont` fallbacks assign Palatino-like display, Avenir-like body, and Menlo-like data roles. Controls use zero-radius ink/paper states instead of default rounded cards.

The strongest decision is the restrained union-red organizing thread, drawn above the mine to connect the selected roster entry, patterned floor incident marker, and grievance case file. The hazard area adds diagonal hatching and written pattern keys, while worker species use distinct silhouettes and symbols, so teal/red are never the only information channel. Everything around the thread stays square, disciplined, and docket-like.

The union hall repeats the thread as a literal network linking five stations; this is coherent with the workplace without competing with it. Reduced motion stops worker breathing/bobbing, high contrast changes critical outlines/thread contrast, dyslexia-friendly settings swap the readable font role, UI scale affects HUD/mine labels, keyboard focus is visibly teal, and auto-pause stops remaining logical ticks on a major event.

The main visual limitation is asset fidelity: the mine is a polished procedural illustrated greybox made of Godot polygons and typography, not final hand-painted room art or layered character rigs. That is appropriate for integration but must receive an art-production pass before the vertical slice can be evaluated for final emotional attachment.

## Verification and Gates

| Gate | Result |
|---|---|
| Full registered suite | PASS, exit 0 |
| Main-scene startup, `--quit-after 2` | PASS, exit 0; no project parse/resource/runtime errors |
| 30-agent headless backlog | PASS, 240/240 ticks, backlog 0 |
| Stress parse-failure behavior | PASS, deliberate body parser fault caused exit 1 |
| Acceptance save/restore | PASS, durable snapshot equal after `SaveService` round trip and public-service reconstruction |
| arm64 export preset recognition/config | PASS after enabling ETC2/ASTC |
| arm64 development export | BLOCKED by missing local Godot export template |
| Reproducible viewport screenshot | NOT CAPTURED; normal macOS display process exited 134 in the sandbox and headless uses the dummy renderer with no texture |
| Three-player comprehension gate | EXTERNAL, not run |
| Target Apple Silicon interactive 60 FPS | EXTERNAL, not run |

Export command and exact remaining blocker:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-debug "macOS arm64 Development" "work/export/Dungeon Union.app"
```

```text
No export template found at the expected path:
/Users/spkoehl/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip
```

Godot recognizes the preset and reports no other export configuration error after the ETC2/ASTC project setting was added.

## Intentional Deviations and External Limitations

- The Task 8 integration supplies written visual equivalents but no adaptive music/audio layer because no audio service exists in Tasks 1–7. Therefore the GDD performance scenario's “adaptive music active” load is not represented.
- The procedural mine uses readable illustrated greybox geometry rather than final authored room/prop art and animation rigs.
- Accessibility settings are production resources applied by the workplace, but a complete settings/remapping screen and persistent per-device bindings remain outside this slice task.
- Save/restore is fully exercised through the acceptance facade and production `SaveService`; the playable HUD does not add a separate manual-save menu.
- Controller support remains deferred as allowed by the GDD; mouse, trackpad, and keyboard paths are implemented.
- Incident presentation supports written case files, pattern keys, stable floor markers, minimum-zoom clustering, selection, and cycling. Final authored marker art remains part of the art-production pass.
- External player comprehension and target-hardware interactive profiling cannot be honestly claimed from this environment. `docs/PLAYTEST.md` defines those gates without weakening them into automated substitutes.

## Concerns Before Full Campaign Production

1. Install the Godot 4.7.2 stable macOS export templates and rerun export, launch, save/reload, negotiation, and quit on Apple Silicon.
2. Run the exact three-player rubric. The procedural workers are distinct and named, but only external recall evidence can validate attachment.
3. Profile the true rendered scene with final art/audio at normal and quadruple speed. The headless 5–6 ms fixture proves logical capacity and no backlog, not 60 rendered FPS.
4. Add the full settings/remapping surface and final art/audio/animation before treating the GDD's complete vertical-slice definition as a production gate.
