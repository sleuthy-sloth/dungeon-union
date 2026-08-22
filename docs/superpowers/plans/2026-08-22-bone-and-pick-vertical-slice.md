# Bone & Pick Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete 60–90-minute Bone & Pick opening chapter as a native macOS Godot vertical slice.

**Architecture:** Keep deterministic simulation and campaign data in typed, scene-independent GDScript classes. Godot scenes consume read-only view state and send typed commands; content lives in validated Resources with stable identifiers. The slice implements one workplace, twelve workers, three disputes, four escalation steps, one negotiation, save recovery, and the performance fixture.

**Tech Stack:** Godot 4.x stable, statically typed GDScript, native Godot Resource serialization, local headless test runner, macOS arm64 export.

**Spec:** `docs/superpowers/specs/2026-08-22-dungeon-union-design.md`

## Global Constraints

- Native arm64 macOS export; 60 FPS at 1440×900 logical resolution on an Apple Silicon MacBook.
- Offline single-player operation with no account, required telemetry, or runtime model API.
- Simulation results must not depend on render frame rate, pause duration, or time speed.
- Content uses typed Resources with stable string identifiers and startup validation.
- UI may issue commands but may not mutate worker, grievance, or campaign state directly.
- Accessibility, save recovery, deterministic tests, and content validation are release behavior.
- The slice contains exactly one workplace, twelve active workers, three dispute lines, six incident families, one negotiation, and a partial union hall.

---

### Task 1: Godot project, test harness, and application shell

**Files:**
- Create: `project.godot`
- Create: `src/app/app_root.gd`
- Create: `src/app/app_root.tscn`
- Create: `tests/test_case.gd`
- Create: `tests/test_runner.gd`
- Create: `tests/smoke/test_app_root.gd`

**Interfaces:**
- Produces: `TestCase.check(condition: bool, message: String)`, `TestCase.equal(actual: Variant, expected: Variant, message: String)`, and a headless test command used by every later task.
- Produces: `AppRoot.change_mode(next_mode: StringName) -> void` and signal `mode_changed(mode: StringName)`.

- [ ] **Step 1: Write the failing application-shell test**

```gdscript
# tests/smoke/test_app_root.gd
extends RefCounted

static func run(t: TestCase) -> void:
    var root := AppRoot.new()
    t.equal(root.current_mode, &"boot", "app starts in boot mode")
    root.change_mode(&"workplace")
    t.equal(root.current_mode, &"workplace", "mode transition is stored")
```

- [ ] **Step 2: Add the minimal test harness and verify the test fails**

```gdscript
# tests/test_case.gd
class_name TestCase
extends RefCounted

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func equal(actual: Variant, expected: Variant, message: String) -> void:
    check(actual == expected, "%s: expected %s, got %s" % [message, expected, actual])
```

```gdscript
# tests/test_runner.gd
extends SceneTree

func _init() -> void:
    var t := TestCase.new()
    for script_path in ["res://tests/smoke/test_app_root.gd"]:
        load(script_path).run(t)
    for failure in t.failures:
        push_error(failure)
    quit(0 if t.failures.is_empty() else 1)
```

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because `AppRoot` is undefined.

- [ ] **Step 3: Implement the application shell**

```gdscript
# src/app/app_root.gd
class_name AppRoot
extends Node

signal mode_changed(mode: StringName)

var current_mode: StringName = &"boot"

func change_mode(next_mode: StringName) -> void:
    if next_mode == current_mode:
        return
    current_mode = next_mode
    mode_changed.emit(current_mode)
```

Create `app_root.tscn` with an `AppRoot` root node, set it as `run/main_scene`, and configure a 1440×900 stretch viewport in `project.godot`.

- [ ] **Step 4: Run the headless test and launch smoke check**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: PASS.

Run: `godot --headless --path . --quit-after 2`
Expected: exit 0 with no parse errors.

- [ ] **Step 5: Commit**

```bash
git add project.godot src/app tests
git commit -m "build: create Godot application and test shell"
```

### Task 2: Typed content catalog and validation

**Files:**
- Create: `src/content/worker_definition.gd`
- Create: `src/content/job_definition.gd`
- Create: `src/content/workplace_definition.gd`
- Create: `src/content/content_catalog.gd`
- Create: `src/content/content_validator.gd`
- Create: `tests/content/test_content_validator.gd`

**Interfaces:**
- Produces: `ContentCatalog.workers: Dictionary[StringName, WorkerDefinition]` and equivalent job/workplace dictionaries.
- Produces: `ContentValidator.validate(catalog: ContentCatalog) -> Array[String]`.

- [ ] **Step 1: Write validation tests for duplicate and missing identifiers**

```gdscript
# tests/content/test_content_validator.gd
extends RefCounted

static func run(t: TestCase) -> void:
    var catalog := ContentCatalog.new()
    var worker := WorkerDefinition.new()
    worker.id = &""
    worker.display_name = "Nib"
    catalog.worker_items.append(worker)
    var errors := ContentValidator.validate(catalog)
    t.check(errors.has("worker has empty id"), "empty worker id is rejected")
```

Add this path to `tests/test_runner.gd`.

- [ ] **Step 2: Run the targeted test and confirm failure**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because the content types are undefined.

- [ ] **Step 3: Implement definitions, catalog indexing, and validation**

```gdscript
# src/content/worker_definition.gd
class_name WorkerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var species: StringName
@export var job_id: StringName
@export var traits: Array[StringName]
```

```gdscript
# src/content/content_catalog.gd
class_name ContentCatalog
extends Resource

@export var worker_items: Array[WorkerDefinition]
var workers: Dictionary[StringName, WorkerDefinition] = {}

func rebuild_indexes() -> void:
    workers.clear()
    for item in worker_items:
        if item != null and not item.id.is_empty():
            workers[item.id] = item
```

```gdscript
# src/content/content_validator.gd
class_name ContentValidator
extends RefCounted

static func validate(catalog: ContentCatalog) -> Array[String]:
    var errors: Array[String] = []
    var seen: Dictionary[StringName, bool] = {}
    for worker in catalog.worker_items:
        if worker == null or worker.id.is_empty():
            errors.append("worker has empty id")
        elif seen.has(worker.id):
            errors.append("duplicate worker id: %s" % worker.id)
        else:
            seen[worker.id] = true
    return errors
```

Implement `JobDefinition` with `id`, `display_name`, and `workstation_tags`; implement `WorkplaceDefinition` with `id`, `worker_ids`, and `job_ids`. Extend validation so every referenced worker and job exists.

- [ ] **Step 4: Run tests and validate a twelve-worker Bone & Pick fixture**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: PASS, including a fixture with twelve unique workers and no dangling job references.

- [ ] **Step 5: Commit**

```bash
git add src/content tests/content tests/test_runner.gd
git commit -m "feat: add validated typed content catalog"
```

### Task 3: Deterministic clock, random streams, and worker state

**Files:**
- Create: `src/simulation/simulation_clock.gd`
- Create: `src/simulation/random_streams.gd`
- Create: `src/workers/worker_state.gd`
- Create: `src/workers/workplace_simulation.gd`
- Create: `tests/simulation/test_deterministic_shift.gd`

**Interfaces:**
- Produces: `SimulationClock.advance(real_delta: float) -> int`, returning emitted fixed ticks.
- Produces: `RandomStreams.draw(stream: StringName, upper_bound: int) -> int`.
- Produces: `WorkplaceSimulation.apply_tick() -> Array[Dictionary]` and `worker_states: Dictionary[StringName, WorkerState]`.

- [ ] **Step 1: Write the deterministic-shift test**

```gdscript
extends RefCounted

static func run(t: TestCase) -> void:
    var a := WorkplaceSimulation.create_fixture(9917)
    var b := WorkplaceSimulation.create_fixture(9917)
    for index in 120:
        a.apply_tick()
        b.apply_tick()
    t.equal(a.snapshot(), b.snapshot(), "same seed produces same shift")
```

- [ ] **Step 2: Run and confirm the missing simulation failure**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because `WorkplaceSimulation` is undefined.

- [ ] **Step 3: Implement fixed ticks and named random streams**

```gdscript
class_name SimulationClock
extends RefCounted

const TICK_SECONDS := 0.25
var speed := 1.0
var paused := false
var accumulator := 0.0

func advance(real_delta: float) -> int:
    if paused:
        return 0
    accumulator += real_delta * speed
    var ticks := int(accumulator / TICK_SECONDS)
    accumulator -= ticks * TICK_SECONDS
    return ticks
```

```gdscript
class_name WorkerState
extends RefCounted

var id: StringName
var fatigue := 0
var trust := 50
var action_willingness := 25
var employment_state: StringName = &"active"

func apply_work_tick(load: int) -> void:
    fatigue = clampi(fatigue + load, 0, 100)
```

Implement named `RandomNumberGenerator` instances derived from the master seed plus `hash(stream)`; snapshots must sort worker IDs before serialization.

- [ ] **Step 4: Run deterministic tests with 1× and 4× clock feeds**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: PASS; feeding equivalent logical ticks through different real-delta/speed combinations produces equal snapshots.

- [ ] **Step 5: Commit**

```bash
git add src/simulation src/workers tests/simulation tests/test_runner.gd
git commit -m "feat: add deterministic workplace simulation core"
```

### Task 4: Incidents, evidence, and grievances

**Files:**
- Create: `src/grievances/incident_record.gd`
- Create: `src/grievances/evidence_record.gd`
- Create: `src/grievances/grievance_state.gd`
- Create: `src/grievances/grievance_service.gd`
- Create: `tests/grievances/test_grievance_lifecycle.gd`

**Interfaces:**
- Consumes: stable worker IDs and logical tick from Task 3.
- Produces: `GrievanceService.report(incident: IncidentRecord) -> StringName`, `add_evidence(grievance_id: StringName, evidence: EvidenceRecord)`, and `advance_deadlines(tick: int)`.

- [ ] **Step 1: Write a complete grievance-lifecycle test**

```gdscript
extends RefCounted

static func run(t: TestCase) -> void:
    var service := GrievanceService.new()
    var incident := IncidentRecord.new(&"gas_01", &"unsafe_fumes", [&"nib"], 10)
    var id := service.report(incident)
    t.equal(service.get_state(id).phase, &"reported", "new grievance is reported")
    service.add_evidence(id, EvidenceRecord.new(&"testimony", 2, 30))
    t.equal(service.get_state(id).phase, &"documented", "sufficient evidence documents case")
    service.advance_deadlines(31)
    t.equal(service.get_state(id).phase, &"expired", "deadline expiry is deterministic")
```

- [ ] **Step 2: Run and verify the missing grievance types fail**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because `IncidentRecord` is undefined.

- [ ] **Step 3: Implement immutable records and explicit state transitions**

```gdscript
class_name GrievanceState
extends RefCounted

var id: StringName
var issue: StringName
var affected_workers: Array[StringName]
var phase: StringName = &"reported"
var evidence_score := 0
var deadline_tick := 0

func add_evidence(record: EvidenceRecord) -> void:
    if phase in [&"resolved", &"expired", &"withdrawn"]:
        return
    evidence_score += record.reliability
    phase = &"documented" if evidence_score >= 2 else &"investigating"
```

Implement constructors for both record types, stable grievance IDs derived from incident IDs, terminal-state guards, and deadline handling.

- [ ] **Step 4: Run lifecycle and terminal-state tests**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: PASS; adding evidence to an expired grievance has no effect.

- [ ] **Step 5: Commit**

```bash
git add src/grievances tests/grievances tests/test_runner.gd
git commit -m "feat: model incidents evidence and grievances"
```

### Task 5: Organizing resources, participation, and escalation

**Files:**
- Create: `src/organizing/union_resources.gd`
- Create: `src/organizing/action_proposal.gd`
- Create: `src/organizing/participation_forecast.gd`
- Create: `src/organizing/organizing_service.gd`
- Create: `tests/organizing/test_escalation.gd`

**Interfaces:**
- Consumes: worker trust/willingness and documented grievance state.
- Produces: `OrganizingService.forecast(proposal: ActionProposal) -> ParticipationForecast` and `execute(proposal: ActionProposal) -> Dictionary`.

- [ ] **Step 1: Write tests for prerequisites and worker consent**

```gdscript
extends RefCounted

static func run(t: TestCase) -> void:
    var service := OrganizingService.fixture_with_workers([20, 65, 80])
    var strike := ActionProposal.new(&"strike", &"gas_case", 60)
    var forecast := service.forecast(strike)
    t.equal(forecast.ready_count, 2, "two workers meet strike threshold")
    t.check(not forecast.can_execute, "strike requires documented case and vote")
```

- [ ] **Step 2: Run and confirm failure before implementation**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because organizing types are undefined.

- [ ] **Step 3: Implement the resource and escalation rules**

```gdscript
class_name UnionResources
extends RefCounted

var solidarity := 0
var treasury := 0
var public_support := 0
var organizer_capacity := 1

func apply_delta(kind: StringName, amount: int) -> void:
    match kind:
        &"solidarity": solidarity = clampi(solidarity + amount, 0, 100)
        &"treasury": treasury = maxi(0, treasury + amount)
        &"public_support": public_support = clampi(public_support + amount, 0, 100)
```

Implement the slice escalation ranks `informal`, `grievance`, `petition`, and `work_to_rule`. Participation uses individual thresholds and returns named ready/uncertain/unwilling lists; no action directly overwrites worker consent.

- [ ] **Step 4: Run tests for all four slice actions and resource floors**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: PASS; treasury never becomes negative and unmet prerequisites explain the blocker.

- [ ] **Step 5: Commit**

```bash
git add src/organizing tests/organizing tests/test_runner.gd
git commit -m "feat: add participation and escalation rules"
```

### Task 6: Authored event engine and Bone & Pick content

**Files:**
- Create: `src/events/event_definition.gd`
- Create: `src/events/event_engine.gd`
- Create: `src/events/workplace_director.gd`
- Create: `content/bone_and_pick/workplace.tres`
- Create: `content/bone_and_pick/events/*.tres`
- Create: `content/bone_and_pick/workers/*.tres`
- Create: `tests/events/test_event_pacing.gd`
- Create: `tests/content/test_bone_and_pick_content.gd`

**Interfaces:**
- Consumes: simulation snapshots, named RNG streams, and grievance/organizing commands.
- Produces: `EventEngine.eligible(snapshot: Dictionary) -> Array[EventDefinition]` and `WorkplaceDirector.choose_next(tick: int) -> EventDefinition`.

- [ ] **Step 1: Write pacing and content-budget tests**

```gdscript
extends RefCounted

static func run(t: TestCase) -> void:
    var director := WorkplaceDirector.fixture(42)
    director.record_major_event(&"fume_leak", 100)
    t.check(director.choose_next(200) == null, "major event cooldown blocks overlap")
    t.check(director.choose_next(280) != null, "eligible event resumes after 45 seconds")
```

Add a content test asserting exactly twelve workers, three dispute IDs, and six distinct event-family tags.

- [ ] **Step 2: Run and verify failures for missing engine and content**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL on undefined `WorkplaceDirector` and absent Bone & Pick resources.

- [ ] **Step 3: Implement condition evaluation and pacing**

```gdscript
class_name EventDefinition
extends Resource

@export var id: StringName
@export var family: StringName
@export var issue: StringName
@export var minimum_tick := 0
@export var major := true
@export var required_worker_tags: Array[StringName]
```

Implement eligibility as pure checks against a snapshot. The director enforces a 180-tick major-event gap, two-workday family repetition protection, and one active major event in the slice.

- [ ] **Step 4: Author and validate the complete slice content**

Create twelve worker Resources and events for cave-in risk, lantern fumes, unpaid maintenance, adventurer alarm, foreman intimidation, and spontaneous mutual aid. Run:

`godot --headless --path . --script res://tests/test_runner.gd`

Expected: PASS with no missing IDs or invalid event roles.

- [ ] **Step 5: Commit**

```bash
git add src/events content/bone_and_pick tests/events tests/content tests/test_runner.gd
git commit -m "feat: author Bone and Pick workplace events"
```

### Task 7: Negotiation, ratification, and versioned save recovery

**Files:**
- Create: `src/negotiation/bargaining_issue.gd`
- Create: `src/negotiation/negotiation_state.gd`
- Create: `src/negotiation/negotiation_resolver.gd`
- Create: `src/save/save_service.gd`
- Create: `src/save/save_migrator.gd`
- Create: `tests/negotiation/test_bone_and_pick_contract.gd`
- Create: `tests/save/test_save_round_trip.gd`

**Interfaces:**
- Consumes: evidence, solidarity, participation, treasury, public support, and worker priorities.
- Produces: `NegotiationResolver.press(issue_id: StringName, support_id: StringName) -> Dictionary`, `ratify(package: Dictionary) -> Dictionary`, and `SaveService.save_campaign(path: String, state: Dictionary) -> Error`.

- [ ] **Step 1: Write contract and save round-trip tests**

```gdscript
extends RefCounted

static func run(t: TestCase) -> void:
    var resolver := NegotiationResolver.bone_and_pick_fixture()
    var weak := resolver.press(&"safety", &"none")
    var strong := resolver.press(&"safety", &"fume_testimony")
    t.check(strong.concession_rank > weak.concession_rank, "evidence strengthens safety demand")
```

```gdscript
var state := {"schema_version": 1, "seed": 42, "treasury": 9, "workers": {"nib": {"trust": 67}}}
t.equal(SaveService.round_trip_for_test(state), state, "save preserves durable state")
```

- [ ] **Step 2: Run and confirm negotiation/save failures**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because resolver and save service are undefined.

- [ ] **Step 3: Implement deterministic offers, votes, and atomic saves**

```gdscript
class_name SaveService
extends RefCounted

const SCHEMA_VERSION := 1

func save_campaign(path: String, state: Dictionary) -> Error:
    var payload := state.duplicate(true)
    payload["schema_version"] = SCHEMA_VERSION
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_var(payload)
    file.close()
    DirAccess.remove_absolute(path)
    return DirAccess.rename_absolute(temp, path)
```

Implement three safety-clause ranks, schedule protection, and tool-maintenance pay. Ratification evaluates each named worker's priorities and trust, returning yes/no lists and explanations. Add three rotating autosave paths and preserve a corrupt file before recovery.

- [ ] **Step 4: Run negotiation, ratification, corruption, and migration tests**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: PASS; the same state and choices produce the same contract and vote.

- [ ] **Step 5: Commit**

```bash
git add src/negotiation src/save tests/negotiation tests/save tests/test_runner.gd
git commit -m "feat: add contract negotiation and recoverable saves"
```

### Task 8: Isometric workplace UI, union hall, accessibility, and slice acceptance

**Files:**
- Create: `src/workplace/workplace_controller.gd`
- Create: `src/workplace/workplace_view.tscn`
- Create: `src/ui/workplace_hud.gd`
- Create: `src/ui/workplace_hud.tscn`
- Create: `src/ui/union_hall_view.tscn`
- Create: `src/accessibility/accessibility_settings.gd`
- Create: `tests/fixtures/bone_and_pick_fixture.gd`
- Create: `tests/acceptance/test_vertical_slice.gd`
- Create: `tests/performance/workplace_stress.gd`
- Create: `docs/PLAYTEST.md`

**Interfaces:**
- Consumes: read-only workplace, grievance, organizing, negotiation, and campaign views from Tasks 3–7.
- Produces: typed commands for select worker, inspect incident, pause, set speed, propose action, and enter negotiation.
- Produces: `BoneAndPickFixture.new(seed: int)`, `run_to_first_incident()`, `document_issue(issue: StringName)`, `complete_workdays(count: int)`, `negotiate_and_ratify(strategy: StringName) -> Dictionary`, `save_and_restore() -> BoneAndPickFixture`, and `durable_snapshot() -> Dictionary` for acceptance composition.

- [ ] **Step 1: Write the end-to-end acceptance test**

```gdscript
extends RefCounted

static func run(t: TestCase) -> void:
    var slice := BoneAndPickFixture.new(771)
    slice.run_to_first_incident()
    t.equal(slice.active_workers().size(), 12, "slice has twelve active workers")
    slice.document_issue(&"unsafe_fumes")
    slice.complete_workdays(3)
    var result := slice.negotiate_and_ratify(&"safety_first")
    t.check(result.ratified, "prepared safety package ratifies")
    var restored := slice.save_and_restore()
    t.equal(restored.durable_snapshot(), slice.durable_snapshot(), "slice survives save round trip")
```

- [ ] **Step 2: Run and confirm failure before presentation integration**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: FAIL because `BoneAndPickFixture` and presentation commands are incomplete.

- [ ] **Step 3: Implement the workplace presentation and accessibility settings**

Create the fixed-orientation isometric workplace with Y-based depth sorting, a top resource bar, left worker/grievance panel, contextual right panel, and keyboard/trackpad controls. Implement:

```gdscript
class_name AccessibilitySettings
extends Resource

@export_range(0.75, 2.0, 0.05) var ui_scale := 1.0
@export var auto_pause_major_events := true
@export var reduced_motion := false
@export var high_contrast := false
@export var dyslexia_friendly_font := false
```

The union hall exposes one upgrade in each of the five branches and applies upgrades only through campaign commands.

Implement `BoneAndPickFixture` as a test-only facade that creates the twelve-worker catalog, deterministic simulation, grievance service, organizing service, event director, negotiation resolver, and in-memory save service. Each facade method advances those production services through their public interfaces; it may not alter their internal dictionaries directly.

- [ ] **Step 4: Run full acceptance, smoke, and performance checks**

Run: `godot --headless --path . --script res://tests/test_runner.gd`
Expected: all tests PASS.

Run: `godot --headless --path . --script res://tests/performance/workplace_stress.gd`
Expected: 30-agent fixture completes with no simulation backlog or parse errors; capture frame timing on the target MacBook during the interactive profiling pass.

Follow `docs/PLAYTEST.md` with at least three external players. The production gate passes when players can identify three workers, explain one grievance, and connect their organizing choices to the negotiated result.

- [ ] **Step 5: Commit**

```bash
git add src/workplace src/ui src/accessibility tests/fixtures tests/acceptance tests/performance docs/PLAYTEST.md tests/test_runner.gd
git commit -m "feat: complete Bone and Pick vertical slice"
```

## Final Verification

- [ ] Run `godot --headless --path . --script res://tests/test_runner.gd`; expected: exit 0 and all suites PASS.
- [ ] Run `godot --headless --path . --quit-after 2`; expected: exit 0 with no resource or parse errors.
- [ ] Export the arm64 macOS development build; expected: launch, save, reload, negotiate, and quit cleanly.
- [ ] Profile the 30-agent stress fixture at 1440×900 logical resolution on the target Apple Silicon MacBook; expected: sustained 60 FPS at normal speed.
- [ ] Review the implementation against every vertical-slice requirement in the GDD and record intentional deviations before full campaign production.
