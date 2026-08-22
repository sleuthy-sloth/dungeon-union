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

## External Fix Round 1 — 2026-08-22

This round superseded the earlier statements that expanded restoration and append-only incident history were deferred. Its occurrence, restoration, and worker-causality work remained valid, but the later Round 2 re-review found that the public organizing route, focused-Tab proof, and pre-settle layout claims below were overstated. Those three statements are explicitly corrected in the Round 2 section.

### Findings and implementation

1. **Atomic action integration (incomplete in this round):** `GrievanceState.transition_action()` modeled the action that ended a case, and the controller used `execute_atomically()`. However, the separate public `OrganizingService.execute()` route still applied resources without a transition. The prior “all public routes are idempotent” implication was incorrect; Round 2 removes that bypass.
2. **Authoritative worker causality:** all 12 production `WorkerDefinition` resources now author initial trust, action willingness, and issue-specific bargaining priorities. `WorkplaceSimulation.create_from_definitions()` is the sole source of worker state; organizing consumes synchronized copied views, while the new `BoneAndPickNegotiationComposer` derives evidence, participation, named-worker trust, priorities, and resources from public copied views. The acceptance facade documents the actual authored event occurrence and affected role-tag workers rather than inventing `unsafe_fumes_case` or a second worker population. Independent counterfactuals cover evidence, treasury, willingness/participation, and Nib's trust.
3. **Recurring occurrence identity:** an occurrence/grievance ID now includes the definition ID and start tick, while `runtime_id`/`definition_id` remain the stable authored event ID used for director completion and marker placement. Read views publish terminal-filtered `active_incidents` separately from `incident_history`; resolved, expired, and withdrawn cases cannot enter active cycling. The director prevents a still-active minor definition from duplicating, and terminal grievance deadlines release runtime blockers. A deterministic recurrence test resolves intervening authored occurrences, reaches the same family after its two-workday cooldown, and resolves the second unique occurrence independently.
4. **Real scene-tree input (focused-Tab proof incomplete in this round):** the mine owned a central `MineInputSurface`, and keyboard actions had named `InputMap` bindings. The initial test allowed a no-op when only one incident was active, and `_shortcut_input` ran too late to preempt GUI focus traversal. Round 2 adds an exact two-occurrence viewport-dispatch assertion and handles gameplay Tab earlier.
5. **Scale-aware accessible reflow (settlement proof incomplete in this round):** the top rail and side dockets became scrollable, but the side content remained fixed-position and the inspection method used untransformed pre-settle rectangles. The earlier “measures every visible control rectangle” statement was incorrect. Round 2 replaces side-panel positioning with container flow and measures settled, transformed, clipped rectangles using long realistic content.
6. **General durable restoration:** public restore entry points now exist for workplace simulation/worker views, grievances, organizing resources, campaign upgrades, event RNG/director progression, and runtime progression. Grievance snapshots preserve reported, documented, resolved, and expired phases, evidence, deadlines, affected workers, and resolved action. Simulation and event RNG stream states are durable. The fixture rebuilds services only through these public constructors/views and restores resources, authored workers, campaign purchases, event progression, active occurrence, strategy, and negotiation result without recomputation or dictionary mutation.

### Strict TDD evidence

The four new registered acceptance suites were written before the fixes and run against commit `b2997c6a3d39889d2a1c2c527b2a74eb006edce0`. After correcting test-only static typing so the suites parsed, the behavioral RED run exited `1` and reported:

```text
grievance records the action-aware informal transition: expected informal, got
informal terminal repeat is rejected
informal repeat cannot change resources
work_to_rule commits once
workplace separates active incidents from history
same event family can recur after two workdays
every worker definition exposes authored trust, willingness, and bargaining priorities
production negotiation composer exists
workplace owns a dedicated central GUI input surface
durable public restore API exists: workplace_simulation.gd.restore
durable public restore API exists: grievance_service.gd.restore
durable public restore API exists: organizing_service.gd.restore
durable public restore API exists: campaign_state.gd.restore
```

GREEN was reached incrementally for action/occurrence, causality, live scene input/accessibility, and durable restoration. The final registered suite exits `0`; the only console diagnostic is Godot's macOS sandbox certificate lookup warning, which is outside project code.

Fresh fix-round verification:

| Check | Result |
|---|---|
| Registered focused/full suite | PASS, exit 0 |
| 30-agent stress | PASS, exit 0; 240 ticks, 7.727 ms, backlog 0 |
| Main-scene startup `--quit-after 2` | PASS, exit 0; no project parse/resource/runtime errors |
| `git diff --check` | PASS, no whitespace errors |

Commands:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd --log-file /tmp/dungeon-union-external-fix1-full.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance/workplace_stress.gd --log-file /tmp/dungeon-union-external-fix1-stress.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2 --log-file /tmp/dungeon-union-external-fix1-startup.log
git diff --check
```

### Fix-round files

- Production worker authority: `src/content/worker_definition.gd`, `src/workers/worker_state.gd`, `src/workers/workplace_simulation.gd`, and all 12 `content/bone_and_pick/workers/*.tres`.
- Atomic grievance/organizing boundaries: `src/grievances/grievance_state.gd`, `src/grievances/grievance_service.gd`, `src/organizing/organizing_service.gd`.
- Causal bargaining: `src/negotiation/bone_and_pick_negotiation_composer.gd`.
- Occurrence/runtime/durable event progression: `src/simulation/random_streams.gd`, `src/events/workplace_director.gd`, `src/events/workplace_event_runtime.gd`, `src/app/app_root.gd`.
- Playable input/reflow/context: `src/workplace/workplace_controller.gd`, `src/workplace/workplace_view.tscn`, `src/workplace/workplace_mine_view.gd`, `src/ui/workplace_hud.gd`, `src/ui/union_hall_view.gd`.
- Acceptance: `tests/acceptance/test_action_occurrences.gd`, `test_authoritative_causality.gd`, `test_scene_accessibility.gd`, `test_durable_restoration.gd`, plus updated presentation/event tests, fixture, and runner.

### Self-review and remaining external gates

The presentation remains coherent with the labor-pamphlet/storybook direction: accessible reflow keeps the square docket/case-file silhouette, focus is still Safety Teal with a color-independent border, and active incident buttons preserve the union-red thread's worker → occurrence → grievance reading. The new worker context makes the named cast materially inspectable instead of merely decorative. At large scales the user scrolls stable regions rather than losing the right case file offscreen.

No new architectural conflict with Tasks 3–7 was found. `WorkplaceController` remains the only continuous fixed-tick bridge; `AppRoot` still has no hidden simulation loop. Public restore functions mutate only their owning service internals, and fixture/presentation code consumes commands and copied views.

The external three-player comprehension gate, final-art/audio rendered 30-agent target-Mac 60 FPS gate, arm64 export/launch gate (local Godot 4.7.2 export template still absent), and reproducible visual screenshot remain unchanged external limitations. Headless tests do not claim those gates.

## External Fix Round 2 — 2026-08-22

Round 2 addressed only the four residual re-review findings. The approved occurrence identity/history and comprehensive restoration paths were not redesigned.

### Residual fixes

1. **No public organizing bypass:** `OrganizingService` now owns or receives one authoritative `GrievanceService`. Its sole public `execute(proposal)` path preflights the proposal, commits `transition_action()` on that authoritative occurrence, and only then applies the non-failing resource delta. The optional-Callable `execute_atomically()` route was removed. Public `grievance_view()`/`grievance_views()` return copies for causality and tests. `GrievanceService.import_state()` accepts only a new occurrence, so a caller cannot re-register a stale documented snapshot to reopen a terminal case. Direct service tests execute informal, grievance, petition, and work-to-rule twice and assert terminal action state, rejected repeat, unchanged resources, stable vote, and zero evidence/no ratification for informal resolution.
2. **Fixture issue contract:** `active_occurrence_view()` publishes a copied authored occurrence. `document_issue(issue)` now returns `false` without mutation unless the requested issue exactly matches that occurrence. Acceptance first attempts `unsafe_fumes` against the authored `cave_in_prevention` occurrence and proves the entire durable snapshot is unchanged, then documents the actual issue and verifies occurrence ID and issue identity.
3. **Focused gameplay Tab:** unmodified gameplay Tab is handled in `_input()` before GUI traversal, cycles the exact next active occurrence, and calls `Viewport.set_input_as_handled()`. Modified Shift-Tab is excluded from gameplay handling and remains a GUI focus-navigation route. The real viewport test creates two simultaneous authored occurrences (`cave_in_risk@00000001` and `spontaneous_mutual_aid@00000300`), focuses Nib's button, dispatches Tab through the root viewport, and asserts the exact second occurrence ID. It then dispatches Shift-Tab and proves focus changes without cycling the incident.
4. **Settled container flow:** the left docket and right case file now use `VBoxContainer`/`GridContainer` flow inside their clipped scroll regions. Worker header, roster, grievance heading, empty/incident rows, narrative, evidence, forecasts, action grid, result, and hall route reserve real minimum heights. After text or accessibility changes, a deferred settlement sizes multiline labels from their actual line count and extends scroll content to the container minimum. `accessibility_layout_view()` publishes the transformed visible leaf rectangles clipped to each scroll viewport, calculates intersections from those same rectangles, and checks focus styles. Acceptance supplies long incident/worker content, waits two layout frames, and independently checks viewport bounds and same-region intersections at 0.75×, 1×, 1.5×, and 2×.

### Round 2 TDD evidence

The new assertions were run against Round 1 commit `ba8ca6483e40a2b4cd65b7476709fe93132c7057` before production changes. The behavioral RED run exited `1` with:

```text
organizing publishes authoritative copied grievance views
fixture exposes the copied active authored occurrence
unmodified Tab cycles to the exact next occurrence while a button owns focus:
  expected spontaneous_mutual_aid@00000300, got cave_in_risk@00000001
0.75 settled layout publishes transformed visible rectangles
1.00 settled layout publishes transformed visible rectangles
1.50 settled layout publishes transformed visible rectangles
2.00 settled layout publishes transformed visible rectangles
```

After the initial service fix, an additional direct adversarial RED proved a stale caller snapshot could still reopen the case:

```text
informal stale caller snapshot cannot reopen the authoritative grievance
informal second public execution is rejected
informal second public execution cannot change resources
grievance stale caller snapshot cannot reopen the authoritative grievance
petition stale caller snapshot cannot reopen the authoritative grievance
work_to_rule stale caller snapshot cannot reopen the authoritative grievance
```

`GrievanceService.import_state()` was then constrained to new occurrence IDs, closing that route. Each focused cycle was rerun before moving to the next residual; the final registered suite was green before verification.

Fresh Round 2 verification:

| Check | Result |
|---|---|
| Registered focused/full suite | PASS, exit 0 |
| 30-agent stress | PASS, exit 0; 240 ticks, 9.769 ms, backlog 0 |
| Main-scene startup `--quit-after 2` | PASS, exit 0; no project parse/resource/runtime errors |
| `git diff --check` | PASS, no whitespace errors |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd --log-file /tmp/dungeon-union-external-fix2-commit-full.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance/workplace_stress.gd --log-file /tmp/dungeon-union-external-fix2-commit-stress.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2 --log-file /tmp/dungeon-union-external-fix2-commit-startup.log
git diff --check
```

All three Godot commands print the known macOS sandbox CA-certificate lookup diagnostic after project output; each exits `0`, and the project logs contain no assertion, parse, resource, or runtime error.

### Round 2 self-review

- Presentation and fixture code still consume copied views and typed commands; neither reaches into service dictionaries.
- `WorkplaceController` remains the only `_process()` fixed-tick bridge. `AppRoot` still has no simulation loop.
- Container flow retains the paper-docket/cut-corner presentation rather than replacing it with generic cards. Long narrative now increases scroll extent instead of painting over evidence/actions.
- Tab and Shift-Tab have distinct, tested meanings. Buttons retain Safety Teal focus borders, so the focus-navigation route remains visible and color-independent.
- No changes were made to approved occurrence ID construction, active/history filtering, RNG durability, or campaign restoration beyond passing the existing full suite.

External limitations are unchanged: three-player comprehension, rendered final-art/audio 30-agent performance on the target Mac, arm64 export/launch without the missing Godot 4.7.2 template, and reproducible screenshot capture remain external gates.

## External Fix Round 3 — 2026-08-22

Round 3 addressed only the two residual re-review findings. Public organizing idempotence, fixture issue exactness, focused Tab/Shift-Tab behavior, recurrence identity, and durable restoration were left unchanged and remained green.

### Residual fixes and corrected claims

1. **Earned evidence is enforced at the production ratification boundary.** The authored Bone & Pick safety issue now declares that a non-zero safety concession requires earned relevant evidence. `NegotiationResolver.ratify()` evaluates that eligibility before it can return `ratified = true` and publishes deterministic `eligibility_blockers` separately from named-worker preference votes. This is not a controller guard. The direct service/composer/resolver counterexample uses three authoritative worker snapshots with trust 60, willingness 90, and safety priority 3; a reported zero-evidence grievance; and resources 39 solidarity / 15 treasury / 0 public support. One valid public informal action raises solidarity to 41 but leaves evidence at zero, and the resulting package remains rejected with `safety` named as the blocker. A second path reports and documents an occurrence through public `GrievanceService` APIs, proves the composer receives evidence strength 2, improves the deterministic offer, clears the blocker, and ratifies the prepared package without fabricated controller or fixture state.
2. **UI scale changes real settled metrics, and focus reveals clipped controls.** The HUD and Union Hall no longer scale a `ScrollContainer` direct child transform. They keep content transforms at identity and scale actual font overrides, control minimum sizes, stack widths/positions, grid and stack separations, absolute hall geometry, and content extents. The HUD's flow-based narrative height is recomputed from its scaled line metrics. Every focusable button requests `ensure_control_visible()` from its owning scroll region after focus settles, including the Union Hall route at the bottom of a long case file.
3. **Round 2 layout proof correction.** Round 2 overstated the effectiveness of its scale and geometry acceptance: Godot can reset a scroll container's direct-child transform; the live controller could replace the injected long view during awaited frames; and clipping each reported leaf rectangle hid unreachable controls. Round 3 uses a standalone, fixed 1440×900 HUD for the long-content fixture, waits three layout frames at each supported scale, and publishes both the full transformed control rectangle and its visible intersection. It verifies monotonic typography, narrative height, and scroll-extent changes at 0.75× / 1× / 1.5× / 2×, full same-region non-intersection (including the long worker header), viewport-bounded visible intersections, usable vertical scroll extent, focus borders, retained keyboard focus, and focus-driven visibility of the initially off-clip Union Hall control. The Union Hall independently reports scaled typography and content extent while receiving high contrast, reduced motion, and dyslexia-font settings.

### Round 3 strict TDD evidence

The exact zero-evidence threshold test was added before the resolver change. Against Round 2 commit `87d4893a4231690b95ae8a99836b2459b37af2ec`, the registered suite exited `1` with:

```text
earned evidence is required at the production ratification boundary
```

After the boundary became green, the standalone settled-layout assertions were added before changing either UI. The behavioral RED run exited `1`; the old clipped helper lacked a full visible rectangle, and the old reset transform did not publish or create the required real metrics:

```text
Invalid access to property or key 'visible_rect' on a base object of type 'Dictionary'.
0.75 long case file creates usable vertical scroll extent
0.75 publishes every full control rectangle, including clipped leaves
```

The test was then made tolerant of the missing key so failures stayed behavioral rather than aborting the suite. Production font/minimum-size/separation scaling, full-rectangle inspection, and focus scrolling made the focused Round 3 runner and the complete registered suite exit `0`.

### Round 3 files

- Negotiation eligibility: `src/negotiation/bargaining_issue.gd`, `src/negotiation/negotiation_resolver.gd`.
- Real accessible layout and focus scrolling: `src/ui/workplace_hud.gd`, `src/ui/union_hall_view.gd`.
- Direct threshold regression: `tests/organizing/test_escalation.gd`.
- Settled standalone long-content acceptance: `tests/acceptance/test_scene_accessibility.gd`.

### Round 3 verification

| Check | Result |
|---|---|
| Focused organizing + scene accessibility runner | PASS, exit 0 |
| Full registered suite | PASS, exit 0 |
| 30-agent stress | PASS, exit 0; 240 ticks, 5.625 ms, backlog 0 |
| Main-scene startup `--quit-after 2` | PASS, exit 0; no project parse/resource/runtime errors |
| `git diff --check` | PASS, no whitespace errors |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://work/round3_test_runner.gd --log-file /tmp/dungeon-union-external-fix3-focused.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd --log-file /tmp/dungeon-union-external-fix3-full.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance/workplace_stress.gd --log-file /tmp/dungeon-union-external-fix3-stress.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2 --log-file /tmp/dungeon-union-external-fix3-startup.log
git diff --check
```

The focused runner was a temporary reproducible verification artifact under `work/` and was removed after the successful run; it is not part of the commit. All Godot invocations still print the known macOS sandbox CA-certificate lookup diagnostic and exit `0` after the fix. No assertion, parse, resource, or project runtime error appears in the project logs.

### Round 3 self-review and external gates

- The resolver retains deterministic employer offers and named-worker votes; evidence eligibility is an authored issue rule applied only at ratification. Schedule remains evidence-independent, and maintenance evidence remains optional leverage as authored. No controller-only or fixture-only bypass exists.
- Presentation still uses the same paper docket, cut-corner case file, Safety Teal focus treatment, and color-independent hazard language. Scaling changes layout mechanics rather than replacing the visual direction with generic panels.
- Layout inspection no longer clips away evidence of unreachable leaves. Scroll regions remain fixed within the 1440×900 logical viewport, while enlarged content uses explicit extents and focus-aware scrolling.
- `WorkplaceController` remains the sole continuous fixed-tick bridge, and `AppRoot` has no simulation loop. No Task 3–7 public API conflict was encountered.

External limitations remain unchanged: the three-player comprehension gate, rendered final-art/audio 30-agent 60 FPS gate on the target Mac, arm64 export/launch pending the missing Godot 4.7.2 export template, and reproducible screenshot capture are still external and are not claimed by these headless checks.

## External Fix Round 4 — 2026-08-22

Round 4 addressed only the remaining horizontal scroll-extent residual. The earned-evidence boundary and every frozen organizing, occurrence, input, and restoration behavior were unchanged.

### Residual fix and corrected claim

`WorkplaceHUD._refresh_flow_extent()` no longer derives left/right content width from `base_size.x * ui_scale`. After container settlement it measures the stack's offset plus the greater of its actual size and combined minimum size, then adds a scaled 16-pixel edge margin. The content remains at an identity transform, keeps the approved real font/minimum-size/separation scaling, and is never narrower than its scroll viewport. Wide dyslexia-font roster rows, the complete `FAT` column, case-file headings, and focus-border gutters are therefore part of the reachable scroll range.

Round 3 correctly proved full leaf non-intersection and real metric scaling, but overstated horizontal reachability: a leaf could be measured outside its direct content node while the helper still reported its global rectangle. Round 4's standalone fixture inspects the actual scroll child and does not use the presentation helper's clipped rectangles for this contract. At 0.75×, 1×, 1.5×, and 2× it asserts every visible label/button rectangle lies within its direct content extent. It then moves both left and right scroll containers to their settled minimum and maximum horizontal positions, waits for viewport layout, and verifies the full left and right edges of the worker header/first roster row and case heading/title against the real scrollbar-reduced viewport. The edge check includes a three-pixel focus allowance, and the representative roster button retains its authored focus style.

### Round 4 strict TDD evidence

The standalone assertions were added first and run against Round 3 commit `c4080d7f0b9722e49ebcebb76e87c9638535e785`. The behavioral RED suite exited `1`. Representative failures included:

```text
0.75 full DocketHeading leaf lies inside its horizontal scroll content extent
0.75 full WorkerColumns leaf lies inside its horizontal scroll content extent
0.75 full WorkerRow00 leaf lies inside its horizontal scroll content extent
0.75 full CaseHeading leaf lies inside its horizontal scroll content extent
0.75 full CaseTitle leaf lies inside its horizontal scroll content extent
1.00 maximum scroll reveals full right edge for WorkerColumns
1.00 maximum scroll reveals full right edge for WorkerRow00
1.50 maximum scroll reveals full right edge for WorkerColumns
2.00 maximum scroll reveals full right edge for WorkerRow00
```

The minimal production change replaced only the horizontal width expression with settled stack bounds plus margin. The focused standalone runner and full registered suite then exited `0`.

### Round 4 files

- Settled horizontal extent: `src/ui/workplace_hud.gd`.
- Real scroll-content and viewport regression: `tests/acceptance/test_scene_accessibility.gd`.

### Round 4 verification

| Check | Result |
|---|---|
| Focused scene-accessibility runner | PASS, exit 0 |
| Full registered suite | PASS, exit 0 |
| 30-agent stress | PASS, exit 0; 240 ticks, 6.983 ms, backlog 0 |
| Main-scene startup `--quit-after 2` | PASS, exit 0; no project parse/resource/runtime errors |
| `git diff --check` | PASS, no whitespace errors |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://work/round4_test_runner.gd --log-file /tmp/dungeon-union-external-fix4-focused.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd --log-file /tmp/dungeon-union-external-fix4-full.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance/workplace_stress.gd --log-file /tmp/dungeon-union-external-fix4-stress.log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2 --log-file /tmp/dungeon-union-external-fix4-startup.log
git diff --check
```

The focused runner was temporary under `work/` and was removed after verification. All Godot commands exit `0` and print only the known macOS sandbox CA-certificate lookup diagnostic outside project code.

### Round 4 self-review and external gates

- The width calculation uses the actual settled container boundary rather than duplicating the font/text measurement logic, so future wider authored worker names remain reachable.
- Scaled left offset and right margin preserve the paper-docket/case-file breathing room and keep complete Safety Teal focus borders away from the content boundary.
- No negotiation, organizing, fixture, occurrence, save/restore, campaign, or fixed-tick code changed. `AppRoot` remains free of a simulation loop.

External limitations are unchanged: three-player comprehension, rendered final-art/audio 30-agent 60 FPS on the target Mac, arm64 export/launch pending the missing Godot 4.7.2 export template, and reproducible screenshot capture remain external gates.
