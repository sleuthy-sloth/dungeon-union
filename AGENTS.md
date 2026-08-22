# Repository Working Agreement

Read `docs/superpowers/specs/2026-08-22-dungeon-union-design.md` before proposing architecture or gameplay changes.

## Product constraints

- Use Godot 4.x and statically typed GDScript.
- Preserve the native Apple Silicon macOS target and 60 FPS performance budget.
- Keep the game offline; do not add runtime model calls or mandatory telemetry.
- Protect the five-workplace premium scope and the Bone & Pick vertical-slice gate.
- Treat accessibility, save recovery, deterministic simulation, and content validation as required behavior.

## Model roles

- GPT-5.6 Sol owns architecture, integration, cross-system changes, difficult debugging, performance, and final review.
- OX Alpha owns bounded prototypes, alternative approaches, test ideas, balance critique, and adversarial review.
- Do not have both models edit the same feature concurrently.
- Every implementation task must name owned files, interfaces, invariants, tests, and exclusions.
- Prototype code enters production only after the integrator reviews it and relevant tests pass.

## Change discipline

- Prefer focused systems with typed public interfaces.
- Keep game logic out of presentation scenes and UI scripts.
- Store content in validated typed Resources with stable identifiers.
- Add automated coverage for deterministic rules, save behavior, and failure recovery.
- Record intentional GDD deviations in the pull request or commit message.
