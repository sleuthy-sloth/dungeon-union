# Task 1 report: Godot application shell

## What changed

- Added the Godot 4 project configuration with a 1440x900 canvas-item stretch viewport and `res://src/app/app_root.tscn` as the main scene.
- Added the typed `AppRoot` node, boot mode state, mode transition method, and `mode_changed` signal.
- Added the reusable `TestCase` assertion helper and headless `SceneTree` test runner.
- Added the application smoke test covering initial mode and mode transition.

## Files

- `project.godot`
- `src/app/app_root.gd`
- `src/app/app_root.tscn`
- `tests/test_case.gd`
- `tests/test_runner.gd`
- `tests/smoke/test_app_root.gd`

## TDD evidence

### RED

After writing the smoke test and test harness, before implementing `AppRoot`, ran:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

The expected missing-production failure was observed after Godot's class registry was initialized:

```text
SCRIPT ERROR: Parse Error: Identifier "AppRoot" not declared in the current scope.
  at: GDScript::reload (res://tests/smoke/test_app_root.gd:4)
```

This is the intended RED condition: the test references the application shell contract before the production class exists. The initial pre-import attempt failed earlier on `TestCase` registry discovery; running Godot headless editor initialization resolved the test harness class registration and exposed the intended `AppRoot` failure.

### GREEN

After implementing the shell, ran the headless test and launch smoke check:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2
```

Observed:

```text
TEST_STATUS=0 LAUNCH_STATUS=0
```

No script or parse errors were reported. Godot prints sandbox-specific user-data and macOS certificate-cache warnings in this environment; these do not affect either command's zero exit status.

## Self-review

- Public interfaces match the brief: `TestCase.check`, `TestCase.equal`, `AppRoot.change_mode`, `AppRoot.mode_changed`, and `current_mode`.
- `change_mode` avoids emitting duplicate transitions when the requested mode is already current.
- The scene references the script and is configured as the runnable main scene.
- `git diff --check` is clean.

## Concerns

- The Codex sandbox prevents Godot from creating its default macOS user-data/log directories, so every run includes environment warnings. The test and launch commands still exit 0 and have no parse errors.
- Godot's global `class_name` registry needs its normal project scan on a fresh checkout; the recorded RED/GREEN evidence includes a headless editor initialization before the first class-registry-dependent run.
