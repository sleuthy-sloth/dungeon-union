# Final Fix Report — Bone & Pick Vertical Slice

## Outcome

This single final branch-wide fix wave addresses all six accepted Important findings against base commit `4ce2d6af149a1846b0a0b46d32114d5516b0ef12`. The playable controller now distinguishes positive events from grievances, preserves authoritative evidence identities through bargaining, implements a non-terminal four-step escalation ladder, owns production save/recovery orchestration, shares authored evidence lifetimes with the acceptance facade, and provides a complete single-key keyboard route while preserving unmodified Tab incident cycling.

The wave also updates the stale README status and the playtest guide. It intentionally does not address the deferred Minor findings listed under “Scope discipline.”

## TDD method

The pre-fix registered suite was run first and exited `0`, establishing a clean baseline with only Godot's known macOS CA-certificate lookup diagnostic. For every accepted finding, tests were added or migrated first and observed failing against the old production boundary. Production code was then changed in the smallest coherent step, and the registered suite was rerun to GREEN before moving to the next finding.

Three edge cases found during final diff review also received their own RED/GREEN cycles:

- A major event beginning exactly at a shift boundary skipped the shift-end/start autosaves because auto-pause broke the tick loop first. The RED named missing `.autosave_1` and `.autosave_2`; GREEN moves the already-recorded occurrence into both boundary snapshots before pausing.
- A rejected ratification wrote the pre-negotiation autosave but not the post-vote outcome. The RED recovered an empty `negotiation` dictionary; GREEN autosaves every completed ratification vote, accepted or rejected.
- A positive event was internally classified correctly but the HUD still rendered `⚠ … REPORTED`, and acknowledged history existed only in the controller view. The RED named the wrong glyph/status and absent persistent history; GREEN renders `✦ … ACTIVE`, exposes the acknowledgement action, and retains the latest completion in the visible history line.

## Finding 1 — Positive event classification and routing

### RED

New content and acceptance assertions initially failed because `EventDefinition` had no authored `event_kind` or presentation fields, `WorkplaceCommands` had no typed acknowledgement command, and every started occurrence was unconditionally reported to `GrievanceService`. The positive-event fixture could not prove a separate completion path, an evidence/resource-free outcome, or continued major-event scheduling.

The final HUD audit additionally observed these real failures before its production change:

```text
HUD labels mutual aid with its positive-event glyph
HUD labels mutual aid active instead of reported as a grievance
acknowledged mutual aid remains in persistent player-visible HUD history
HUD history names the positive completion state
```

### GREEN implementation

- `EventDefinition` now authors and validates `grievance` or `positive`, complete player-facing copy, and typed evidence metadata.
- All five dispute events are authored as grievances. `spontaneous_mutual_aid` is authored as positive and cannot reference a dispute or grievance evidence.
- `runtime_copy()` and `occurrence_view()` copy validated Resource data. The controller no longer reconstructs event definitions or presentation strings with hardcoded event-ID switches.
- The controller reports only grievance occurrences to `GrievanceService`.
- `AcknowledgeEventCommand` completes only an active positive occurrence, records `completion = acknowledged` and `completed_tick`, releases the runtime, and changes no evidence or organizing resources.
- Positive selection publishes no grievance forecasts, grievance commands reject it with a plain blocker, and a still-active positive occurrence does not occupy the director's major-event slot.
- The HUD exposes `ACKNOWLEDGE EVENT`, a positive glyph/status, explicit “no grievance or evidence” copy, and persistent recent history after acknowledgement.

### Tests and files

- New: `tests/acceptance/test_positive_event_routing.gd`.
- Expanded: `tests/content/test_bone_and_pick_content.gd`, `tests/test_runner.gd`.
- Production/content: `src/events/event_definition.gd`, `src/events/workplace_event_runtime.gd`, `src/content/content_validator.gd`, `src/workplace/workplace_commands.gd`, `src/workplace/workplace_controller.gd`, `src/ui/workplace_hud.gd`, and all six `content/bone_and_pick/events/*.tres` resources.

## Finding 2 — Authoritative evidence and resolver-issued agreements

### RED

The evidence tests initially failed because grievance views exposed only an aggregate score and the composer synthesized generic `fume_testimony` / `tool_ledger` entries from issue names. The resolver accepted caller-created package ranks and clauses directly. New adversarial tests demonstrated the absent evidence-record list and issued-agreement boundary, then exercised forged maximum safety terms, altered ranks, altered clause IDs, stale agreements, foreign-resolver agreements, copied agreements, irrelevant evidence, and a real documented record.

Final relevance hardening was also observed RED before its fix:

```text
safety cannot count fume evidence with missing relevance: expected 6, got 9
safety terms reject fume evidence with missing relevance: expected [&"safety"], got []
```

### GREEN implementation

- `EvidenceRecord` now carries stable `id`, authored `kind`, named `source`, reliability, deadline, and relevant dispute; snapshots and dictionaries preserve every field defensively.
- `GrievanceState` owns copied evidence records in addition to its compatibility aggregate score. Save/restore and public views preserve exact records and reject duplicate evidence IDs.
- Authored event resources supply real evidence kinds and sources. Controller documentation creates the occurrence's actual evidence ID rather than a generic score token.
- `BoneAndPickNegotiationComposer` passes complete evidence records from documented/submitted/escalated/resolved grievances. It never invents support IDs from issue plus score.
- `NegotiationState` keys leverage by evidence identity and publishes copied record queries. Legacy aggregate dictionaries remain accepted for storage compatibility, but their missing authored relevance prevents them from manufacturing leverage.
- `BargainingIssue` validates both evidence kind and relevant dispute.
- `NegotiationResolver.press()` records exact resolver-issued offers. `issue_tentative_agreement()` accepts only unchanged offers issued by that resolver, stamps a private resolver/generation identity, and supersedes older agreements. `ratify()` accepts only the newest exact issued agreement; an unchanged deep copy remains valid.
- The controller and facade obtain real evidence IDs, request exact terms, issue the tentative agreement, and ratify that issued agreement.

### Tests and files

- Expanded: `tests/grievances/test_grievance_lifecycle.gd`, `tests/negotiation/test_bone_and_pick_contract.gd`, `tests/acceptance/test_authoritative_causality.gd`, `tests/organizing/test_escalation.gd`.
- Production: `src/grievances/evidence_record.gd`, `src/grievances/grievance_state.gd`, `src/negotiation/bargaining_issue.gd`, `src/negotiation/negotiation_state.gd`, `src/negotiation/bone_and_pick_negotiation_composer.gd`, `src/negotiation/negotiation_resolver.gd`, `src/workplace/workplace_controller.gd`.

## Finding 3 — Real escalation ladder and settlement

### RED

The lifecycle and action suites initially encoded each action as an alternative terminal resolution. New tests failed because there was no `action_history`, no `submitted`/`escalated` progression, no ordered prerequisite blocker, and no separate public remedy command. Repeated or out-of-order actions could not be checked as individually idempotent steps because the first action ended the entire case.

### GREEN implementation

- `GrievanceState.ACTION_SEQUENCE` defines `informal → grievance → petition → work_to_rule`.
- Successful steps append exactly once to ordered history. Formal grievance enters `submitted`; petition and work-to-rule enter/remain `escalated`. None resolves the case.
- `action_blocker()` reports terminal, unknown, out-of-order, evidence, phase, participation, and resource prerequisites in plain language.
- `OrganizingService.execute()` preflights the authoritative state, commits one transition, then applies the authored resource effect once. Failed/repeated/out-of-order attempts mutate neither state nor resources.
- `ApplyRemedyCommand` and `OrganizingService.apply_remedy()` are the separate public settlement transition. A non-empty remedy after at least one escalation step sets `resolved` and records the real remedy ID. Resolved, expired, and withdrawn cases reject further escalation/remedies.
- Runtime completion happens on acknowledgement, remedy, or terminal deadline/withdrawal—not when an organizing step is filed.
- HUD forecasts remain available after each successful step, show the next blocker/ready count, render action history, and expose `APPLY REMEDY / SETTLE` separately.

### Tests and files

- Expanded: `tests/grievances/test_grievance_lifecycle.gd`, `tests/organizing/test_escalation.gd`, `tests/acceptance/test_action_occurrences.gd`, `tests/acceptance/test_workplace_presentation.gd`, `tests/acceptance/test_durable_restoration.gd`.
- Production: `src/grievances/grievance_state.gd`, `src/grievances/grievance_service.gd`, `src/organizing/organizing_service.gd`, `src/workplace/workplace_commands.gd`, `src/workplace/workplace_controller.gd`, `src/ui/workplace_hud.gd`.

The tests cover the full four-step path, each phase, exact ordered history, resource deltas after every step, repeat/out-of-order/terminal rejection, separate remedy resolution, runtime release only at closure, and save/restore of submitted/escalated history.

## Finding 4 — Production persistence and recovery

### RED

The production-persistence acceptance initially failed because the playable command script had no manual save/load types, `WorkplaceController` had no durable snapshot/restore boundary, `AppRoot` had no production `user://` path or recovery configuration, and the HUD had no Save/Load actions.

The completed controller was then tested on disk before implementation of each recovery edge. Two late REDs were:

```text
shift-end/start autosave survives boundary auto-pause: ...boundary.save.autosave_1
shift-end/start autosave survives boundary auto-pause: ...boundary.save.autosave_2
post-ratification autosave preserves a rejected vote ... expected {strategy, issued_agreement, ratification_outcome}, got {}
```

### GREEN implementation

- `AppRoot` owns the production default `user://dungeon_union/campaign.save` and startup-recovery switch. Tests inject repository-local temporary paths; the test runner's `DUNGEON_UNION_SAVE_PATH=disabled` override applies only when the default production path is otherwise unchanged.
- `ManualSaveCommand` and `ManualLoadCommand` drive public controller actions; the HUD exposes visible Save and Load buttons.
- `SaveService` creates the nested destination directory before its existing temporary-write/atomic-rename publication.
- The controller snapshot includes controller version, seed, logical tick/workday, deferred ticks, clock speed/pause/accumulator, complete worker simulation and RNG state, grievance/evidence/action history, resources, occurrences and completion history, event-director/RNG/active runtime state, issued negotiation agreement and ratification outcome, campaign upgrades, and accessibility settings.
- Public restore reconstructs service owners from durable views, restores both RNG systems and pending logical time, and deliberately resets transient selection, camera drag/pan/zoom, action acknowledgement, and hall visibility before rebuilding presentation.
- Startup uses existing `SaveService` validation/preservation behavior and recovers the newest valid rotating autosave when the primary is corrupt or future/incompatible.
- Exactly three rotating autosave paths are used. Saves occur at initial shift start, twice at each logical shift boundary (old-shift end and new-shift start), before negotiation, and after every ratification outcome. A boundary major event is recorded and autosaved before auto-pause breaks the tick loop.

### Tests and files

- New: `tests/acceptance/test_production_persistence.gd`.
- Expanded: `tests/acceptance/test_durable_restoration.gd`, `tests/test_runner.gd`.
- Production: `src/app/app_root.gd`, `src/save/save_service.gd`, `src/accessibility/accessibility_settings.gd`, `src/workplace/workplace_commands.gd`, `src/workplace/workplace_controller.gd`, `src/ui/workplace_hud.gd`, `src/ui/union_hall_view.gd`.

The scene-level test writes an injected disk save, mutates/advances the live scene, loads it through the visible command route, proves exact durable equality, then advances a separately restored controller by the same fractional frame and proves deterministic equality. It also covers one purchased upgrade, authoritative evidence, escalation history, issued agreement/outcome, corrupt-primary preservation, rotating recovery, rejected-ratification recovery, and boundary auto-pause.

## Finding 5 — Shared authored evidence lifetime

### RED

The equivalence suite initially failed because `EventDefinition` had no authored evidence window, the controller hardcoded a one-workday deadline, the facade hardcoded five workdays, and the facade did not expose production-clock advancement. The old fixture also completed event runtimes directly instead of using the playable command path.

### GREEN implementation

- Every grievance event authors a validated `evidence_window_ticks = 960`; positive mutual aid authors zero evidence lifetime. Validation rejects non-positive grievance windows and any positive-event evidence/window data.
- Controller documentation calculates the deadline solely from the occurrence's copied authored window.
- `BoneAndPickFixture` now wraps `AppRoot` plus the production `WorkplaceController`. Its existing public plan-facing methods delegate to production commands/views/snapshot/restore.
- `complete_workdays()` advances the production clock. Intervening grievances are documented if needed, escalated informally, and settled through `ApplyRemedyCommand`; positives are acknowledged through `AcknowledgeEventCommand`. It never calls runtime completion directly.
- The required `document → complete_workdays(3) → negotiate` flow remains valid. At the exact authored deadline, both facade and production remain documented; one tick later both become exactly equal expired cases.

### Tests and files

- New: `tests/acceptance/test_evidence_window_equivalence.gd`.
- Expanded: `tests/acceptance/test_vertical_slice.gd`, `tests/content/test_bone_and_pick_content.gd`, `tests/fixtures/bone_and_pick_fixture.gd`.
- Production/content: `src/events/event_definition.gd`, `src/content/content_validator.gd`, `src/workplace/workplace_controller.gd`, all six event resources.

## Finding 6 — Keyboard accessibility

### RED

The real viewport keyboard acceptance initially failed because the explicit focus/activate/back actions did not exist, HUD/hall focus movement APIs and neighbors were absent, and the scene did not assign initial focus. Shift+Tab was the only general GUI traversal route even though unmodified Tab was reserved for incident cycling.

### GREEN implementation

- The controller configures explicit remappable `InputMap` actions for Down/Up/Right/Left focus movement, Enter activation, U union hall, and B back, alongside existing Space/time keys and unmodified Tab incident cycling.
- Unmodified Tab is handled before GUI traversal and continues to cycle incidents. Modified key chords are not treated as the single-key gameplay route.
- The HUD assigns automatic initial focus to the first visible worker and maintains a circular explicit neighbor chain across visible workers, active incidents, document/acknowledge, the four organizing actions, remedy, negotiation, union hall, Save, and Load.
- The union hall focuses the first available upgrade, links all available upgrades plus Return, and restores focus to the mine-side hall button on B/close.
- Focus entry calls each containing `ScrollContainer.ensure_control_visible()`. Existing Safety Teal focus styleboxes remain visible at every step.

### Tests and files

- New: `tests/acceptance/test_keyboard_accessibility.gd`.
- Production: `src/workplace/workplace_controller.gd`, `src/ui/workplace_hud.gd`, `src/ui/union_hall_view.gd`.

The test dispatches only viewport key events and proves the complete path: automatic worker focus → Enter worker selection → Down to incident → Enter inspection → Down/Enter documentation → Down/Enter informal action → U hall → Enter upgrade → B back → unmodified Tab incident cycle. It also asserts every named action/binding, visible focus style, and explicit neighbor path.

## Documentation

- `README.md` no longer claims that gameplay code is absent. It identifies the playable Bone & Pick implementation and keeps final art/audio, target performance, external playtest, and export validation explicit.
- `docs/PLAYTEST.md` adds the arrow/Enter/U/B/Tab keyboard route and visible Save/Load recovery observation.

## Compatibility

- Existing `WorkplaceController.configure(root, catalog, seed)` callers remain valid because save path and recovery are optional trailing parameters.
- The facade's public `run_to_first_incident`, `active_workers`, `active_occurrence_view`, `document_issue`, `complete_workdays`, `negotiate_and_ratify`, `save_and_restore`, and `durable_snapshot` API remains available, but now uses production orchestration.
- The original three-argument `EvidenceRecord(source, reliability, deadline)` construction remains accepted for old unit callers. Such aggregate-compatible records intentionally lack authored dispute relevance and therefore cannot create new bargaining leverage.
- Plan-facing bargaining terms remain dictionaries. Callers add one explicit `issue_tentative_agreement(terms)` step; direct caller-forged dictionaries now reject by design. Deep-copied exact issued agreements remain valid.
- `GrievanceState.resolve()` remains as a compatibility alias for a named settlement remedy; playable code uses the explicit `apply_remedy` boundary.
- Save schema remains version 1, preserving existing `SaveService` migration/checksum/ring behavior. The complete controller payload adds its own `controller_version = 1` and stable nested views.
- No hidden simulation loop was added to `AppRoot`; `WorkplaceController` remains the sole continuous fixed-tick bridge.

## Verification

Fresh pre-commit verification from the final worktree:

| Check | Result |
|---|---|
| Registered full suite | PASS, exit `0` |
| 30-agent deterministic stress | PASS, exit `0`; 30 agents, 240 ticks, `5.720 ms`, backlog `0.000000` |
| Main-scene startup | PASS, exit `0`; sandbox save writes disabled through the test-only path override |
| Export preset probe | Expected external block: preset recognized; missing Godot `4.7.2.stable/macos.zip` template |
| `git diff --check` | PASS before report authoring; rerun before commit |
| Post-commit clean-tree check | Required and reported in the final handoff |

Commands:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/test_runner.gd \
  --log-file /tmp/dungeon-union-final-fix-full.log

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/performance/workplace_stress.gd \
  --log-file /tmp/dungeon-union-final-fix-stress.log

DUNGEON_UNION_SAVE_PATH=disabled \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --quit-after 2 \
  --log-file /tmp/dungeon-union-final-fix-startup.log

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-debug "macOS arm64 Development" "work/export/Dungeon Union.app" \
  --log-file /tmp/dungeon-union-final-fix-export.log

git diff --check
```

The three runnable Godot gates emit only the known host CA-certificate lookup diagnostic and exit `0`. The export probe also emits sandbox inability to write Godot editor/user metadata, but the only project export configuration blocker is the already-known absent macOS template:

```text
No export template found at the expected path:
/Users/spkoehl/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip
```

The export scan generated untracked `.gd.uid` cache files; they were removed immediately and are not part of this wave.

## Scope discipline

The explicitly deferred Minor findings remain untouched: broad workplace duplicate/empty-reference validation, release-safe `RandomStreams.draw()` bounds, save rename-failure injection and schema-zero disk integration, duplicate incident conflict behavior, and unrelated UID additions. None was mechanically required by the accepted fixes.

## Remaining external gates and concerns

1. Install the Godot 4.7.2 stable macOS export template, export the recognized arm64 preset, launch the exported app, and verify disk save/reload, recovery, negotiation, ratification, and clean quit in the export. Exported save/reload cannot be honestly verified before the template exists.
2. Run the documented three-player comprehension gate with people who did not implement or routinely test the slice.
3. Profile the rendered 30-agent scene with final art/audio on the target Apple Silicon MacBook and prove sustained 60 FPS at 1×. The headless zero-backlog stress result is not rendered-FPS evidence.
4. Complete final authored art, animation, and audio, then capture/review reproducible target-resolution screenshots. The current procedural presentation is still a polished integration greybox.
5. Build and validate the complete settings/remapping UI. This wave supplies the required explicit remappable bindings and keyboard route, but not the full settings surface.
