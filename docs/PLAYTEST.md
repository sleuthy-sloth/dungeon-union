# Bone & Pick Vertical-Slice Playtest

## Production Gate

Run the slice with at least three external players who did not implement or routinely test it. Test players individually, without explaining worker identities, grievance causes, or the intended bargaining strategy in advance. Record each session separately.

The production gate passes only when all three players can, without hints after play:

1. Identify at least three Bone & Pick workers by name or an unambiguous name-and-role description.
2. Explain one grievance as a causal chain connecting a visible incident, at least one affected worker, the disputed condition, and the remedy or collective response.
3. Connect at least one organizing choice they made to a clause, vote explanation, or other result in the negotiated agreement.

A facilitator clarification such as “What made you think that?” is allowed. Supplying a worker name, pointing to the relevant panel, naming the correct grievance, or listing possible answers counts as a hint and makes that item fail for the session.

## Session Setup

- Use a development export at 1440×900 logical resolution on an Apple Silicon MacBook.
- Start a new campaign seed and default accessibility settings unless the player requests an adjustment.
- Make headphones optional; required incident information must remain understandable with audio muted.
- Ask the player to think aloud, but do not teach controls unless they remain blocked for 60 seconds.
- Target 35–45 minutes of observed play: inspect the mine, respond to an incident, document a grievance, choose an action, enter negotiation, review the vote, and visit the union hall.
- After play, hide or move away from the game screen before asking recall questions.

Before starting, say only: “You organize the workers at Bone & Pick Excavations. Follow what happens on the mine floor and try to win an agreement the workers will accept.”

## Exact Observation Rubric

Mark each item `2`, `1`, or `0` and add a timestamp plus a short verbatim player statement.

| Item | 2 — independent evidence | 1 — partial evidence | 0 — absent or contradicted |
|---|---|---|---|
| Worker recognition | Recalls three or more named workers, or gives three descriptions that uniquely pair identity and job/species | Recalls one or two workers, or gives descriptions that could match several workers | Recalls none or treats workers only as anonymous units |
| Grievance comprehension | States incident → affected worker → disputed condition → remedy/action as one coherent chain | Identifies the incident and worker but omits or confuses either the disputed condition or remedy | Cannot explain why the grievance exists |
| Organizing-to-bargaining connection | Names one own choice and correctly connects it to evidence, leverage, a clause, or a worker vote explanation | Senses that preparation mattered but cannot identify the connecting evidence or outcome | Describes negotiation as unrelated, random, or purely dialogue-driven |
| Solidarity legibility | Correctly explains one rise/fall using a named worker, action, or participation result | Notices the change but cannot state its cause | Does not notice or gives a false cause |
| Forecast usefulness | Uses the range and blocker explanation to make a choice while still expressing uncertainty | Opens the forecast but treats it as an exact answer or ignores one explanation | Cannot find or use the forecast |
| Setback recovery | After a blocked or weak action, identifies a viable next step without facilitator instruction | Recovers after one neutral controls reminder | Stops or believes the run is irrecoverably failed |
| Teaching pace | Reaches an incident and documents a case without reporting excessive interruption | Progresses but reports one confusing or intrusive teaching moment | Cannot progress because teaching is missing or overwhelming |
| Tone | Describes the humor as supporting, or at least not weakening, concern for workers | Finds tone uneven but still takes one worker concern seriously | Says the humor makes worker harm feel disposable |

The three-player production gate uses the first three rubric rows: every player must score `2` in all three. The other rows diagnose iteration priorities and do not override a failed gate.

## Control and Accessibility Observations

During natural play, record whether the player can:

- Pause with Space and select 1×, 2×, and 4× without holding multiple keys.
- Cycle active incidents with Tab and identify the written incident equivalent.
- Pan with a mouse/trackpad drag and zoom within the bounded range without losing the mine.
- Follow a selected worker, hazard, and grievance through the union-red organizing thread.
- Distinguish the fume, collapse, wage, and alarm cues from symbols/hatching without relying on color.
- Find visible keyboard focus and use the worker, action, time, negotiation, and union-hall controls.
- Move focus with the arrow keys, activate with Enter, open the Union Hall with U, return with B, and still cycle incidents with unmodified Tab.
- Use the visible Save and Load actions, then confirm the recovered workplace, grievance, resources, event history, and negotiation result match the saved state.
- Continue after enabling UI scale, high contrast, reduced motion, dyslexia-friendly font, or auto-pause settings requested for access.

Record requested settings and any assistance. Do not ask players to disclose a diagnosis.

## Performance and Build Record

For each session record build SHA, Godot version, Mac model/chip, macOS version, display scale, observed interactive FPS at normal speed, any hitch longer than 100 ms, and whether save/reload/quit completed cleanly. The target-hardware gate remains sustained 60 FPS at 1× with the 30-agent stress setup; the automated headless backlog check does not substitute for this interactive measurement.

## Session Record

```text
Player ID:
Date / observer:
Build SHA:
Hardware / macOS / display:
Requested accessibility settings:
Start / end time:

Worker recognition (0/1/2):
Timestamp + statement:
Grievance comprehension (0/1/2):
Timestamp + statement:
Organizing-to-bargaining connection (0/1/2):
Timestamp + statement:
Solidarity legibility (0/1/2):
Forecast usefulness (0/1/2):
Setback recovery (0/1/2):
Teaching pace (0/1/2):
Tone (0/1/2):

Controls/accessibility observations:
Interactive FPS / hitches:
Save / reload / quit result:
Unprompted quotes:
Facilitator hints or interventions:
Gate result: PASS / FAIL
Follow-up change requested:
```

After three sessions, list each gate result and the shared failure pattern. Do not average scores to convert a failed player into a pass; rerun a new three-player gate after material teaching, information-design, or negotiation-feedback changes.
