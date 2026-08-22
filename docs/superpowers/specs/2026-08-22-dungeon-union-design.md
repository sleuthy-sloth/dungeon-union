# Dungeon Union

## Game Design Document and Production Proposal

**Document version:** 1.0  
**Date:** August 22, 2026  
**Status:** Draft for owner review; concept baseline approved  
**Engine:** Godot 4.x stable  
**Initial platform:** macOS on Apple Silicon  
**Business model:** Premium, single-player, offline game  
**Target campaign length:** 7–9 hours  
**Target price:** USD $19.99–$24.99, subject to pre-release market validation

---

## 1. Executive Proposal

### 1.1 High concept

*Dungeon Union* is an isometric workplace-management game about organizing the monsters who keep fantasy dungeons running. The player investigates unsafe conditions, builds solidarity, coordinates collective action, survives union-busting schemes, and negotiates contracts with increasingly powerful overlords.

The game combines a visible real-time-with-pause workplace simulation with authored character stories and tactical labor negotiations. Its comedy comes from applying recognizable institutional dysfunction to an absurd fantasy workplace: skeletons demand paid reassembly time, mimics dispute time-theft allegations, and imps seek protection from unsafe summoning circles. The workers and their needs remain sincere even when the circumstances are ridiculous.

### 1.2 Player fantasy

The player is the newly elected organizer of Dungeon Workers United, Local 666. They are not an omnipotent building owner. They earn influence by listening, documenting, training leaders, spending limited resources, and persuading workers to act together. A successful player turns frightened individuals into a durable organization capable of winning material improvements.

### 1.3 Product promise

The finished game will deliver:

- A complete five-workplace campaign lasting approximately eight hours.
- An isometric illustrated dungeon in which every major labor condition is visible.
- A cast of named monster workers with jobs, relationships, concerns, and memories.
- Systemic disputes that connect daily management decisions to contract negotiations.
- Meaningful setbacks without frequent campaign-ending failure screens.
- A replayable Contract Challenge mode using remixed disputes and modifiers.
- A polished native macOS experience designed for keyboard, mouse, and trackpad.

### 1.4 Audience

The primary audience enjoys approachable management games, choice-driven narrative games, workplace satire, and character-focused strategy. Players should not need prior knowledge of labor law or union organizing. Concepts are introduced through clear fantasy analogies, contextual explanations, and consequences visible in the simulation.

The intended content rating is approximately ESRB Teen. The game may depict comic fantasy violence, workplace injuries, intimidation, and references to death or resurrection. It avoids graphic gore, sexual content, and cruelty directed at real-world protected groups.

---

## 2. Design Pillars

### 2.1 People before numbers

Workers are characters rather than production units. Every consequential metric must connect to visible individual experiences. A change in solidarity is explained by named workers gaining or losing trust, not by an unexplained global modifier.

### 2.2 A visible workplace

Unsafe conditions, understaffing, raids, surveillance, favoritism, and management pressure occur on the isometric floor. The player should be able to see why a grievance exists and who is affected before opening a panel.

### 2.3 Leverage is earned

Negotiation power comes from actions taken during ordinary workdays: collecting evidence, training stewards, maintaining a strike fund, building public support, and proving that workers will act together. Negotiation is the culmination of play, not an isolated dialogue minigame.

### 2.4 Failure creates stories

Most failures alter the campaign instead of ending it. A weak contract, an injured worker, a depleted treasury, or an emboldened employer becomes the starting condition for the next problem. The game reserves complete chapter failure for local collapse through insolvency or the loss of all active membership.

### 2.5 Readable complexity

The game uses a small set of resources with explicit causes and effects. It does not add crafting, equipment rarity, worker hunger, decorative construction, or other systems that do not strengthen the organizing fantasy.

---

## 3. Game Structure

### 3.1 Modes

**Campaign** is the primary mode. It follows Local 666 through five authored workplaces. Decisions, contract outcomes, officer development, treasury, and hall upgrades persist between chapters.

**Contract Challenge** unlocks after the campaign. It creates a shorter three-workplace run from unlocked employers, disputes, modifiers, and starting conditions. A challenge run lasts two to three hours and uses a stored seed so it can be replayed or shared.

**Tutorial archive** allows players to revisit unlocked explanations and practice a negotiation without campaign consequences.

### 3.2 Campaign shape

Each workplace lasts three to five simulated workdays followed by a contract resolution. A campaign contains approximately 20 workdays and five major negotiations. The difficulty curve introduces one major concept per chapter and then recombines prior concepts in the finale.

Three elected officers travel with the player throughout the campaign. Each workplace adds a local cast of 12–20 workers. The full campaign includes approximately 52 named workers, supported by modular portraits and shared animation rigs.

### 3.3 Workday rhythm

A normal play cycle lasts 20–30 minutes:

1. **Morning assembly:** Review grievances, employer directives, rumors, and staffing.
2. **Plan the shift:** Assign organizers, prioritize investigations, schedule meetings, and allocate mutual aid.
3. **Manage the workday:** Respond to hazards, raids, intimidation, interpersonal conflict, and spontaneous worker actions in real time with pause.
4. **Build the case:** Gather testimony and evidence while improving solidarity and protecting workers from burnout.
5. **Choose escalation:** Resolve informally, file a grievance, petition, slow down, walk out, or prepare a strike.
6. **Debrief:** Review consequences, spend resources, and prepare the next shift.
7. **Negotiate:** At chapter milestones, convert the local's evidence and collective leverage into contract clauses.

The player can pause freely and select normal, double, or quadruple simulation speed. Major incidents can automatically pause according to an accessibility setting.

---

## 4. Workplace Simulation

### 4.1 Worker model

Every active worker has:

- A stable identity, species, job, pronouns, portrait recipe, and short biography.
- Two personality traits that affect behavior without determining it absolutely.
- One current personal concern selected from authored possibilities.
- Fatigue, trust in the union, and willingness to take collective action.
- Relationships with a small number of coworkers.
- Employment state: active, absent, injured, disciplined, dismissed, or on strike.
- Committee and steward assignments.
- Memory flags for major player decisions and campaign events.

The simulation does not track hunger, housing, clothing, or a general happiness meter. Fatigue represents short-term capacity; trust represents the worker's belief that the union will act competently and democratically; action willingness represents immediate risk tolerance.

### 4.2 Jobs and schedules

Each workplace defines jobs, workstations, required staffing, schedules, and hazards. Workers follow understandable schedules and visibly travel between rooms. Understaffed or overloaded stations accumulate risk. The player cannot permanently assign labor on behalf of management, but can recommend temporary swaps, coordinate refusal of unsafe work, or organize mutual aid.

### 4.3 Workplace director

The Workplace Director evaluates the current schedule, unresolved hazards, employer strategy, campaign flags, and event cooldowns. It selects valid authored incidents while enforcing pacing limits:

- No more than one major incident at a time during the first chapter.
- No more than two overlapping major incidents in later chapters.
- At least 45 simulated seconds between unrelated major incidents.
- Protection against repeating the same event family within two workdays.

Random selection uses the campaign seed and the simulation tick, making outcomes reproducible across save and load.

### 4.4 Organizer attention

Orders consume organizer attention rather than action points. An organizer can conduct one focused task at a time, such as interviewing a worker, inspecting a room, facilitating a meeting, or monitoring management. Travel and task duration are visible. Trained workplace stewards can handle routine events without consuming a traveling officer.

---

## 5. Organizing Systems

### 5.1 Core resources

The campaign uses five resources:

| Resource | Built through | Spent or damaged by | Primary use |
|---|---|---|---|
| Solidarity | Listening, shared victories, democratic decisions | Fear, favoritism, ignored concerns | Coordinated collective action |
| Evidence | Inspection, testimony, incident records | Cover-ups, deadlines, intimidation | Credible grievances and demands |
| Organizer capacity | Steward training and committees | Burnout, injury, turnover | More simultaneous tasks |
| Treasury | Dues and campaign rewards | Mutual aid, legal costs, strike support | Sustained escalation |
| Public support | Messaging and community alliances | Propaganda and harmful disruption | External pressure and endurance |

Global values are summaries, not substitutes for individual state. Expanding a resource in the interface lists the named people and events currently affecting it.

### 5.2 Conversations

Conversations are short authored exchanges with two to four responses. They reveal concerns, request consent, settle priorities, or address conflict. Responses are tagged by intent rather than obvious morality. A forceful response may reassure an angry worker and frighten a cautious one. Important choices set memory flags used in later events.

Routine conversations may be delegated to compatible stewards after the player has learned the worker's concern. Delegation reduces repetition while preserving the value of leadership development.

### 5.3 Committees and stewards

The player can form safety, communications, mutual-aid, and bargaining committees. Each committee requires at least two willing workers and one trained steward. Committees automate a narrow set of tasks and create local capacity that persists after the traveling officers leave.

Worker selection matters. A technically skilled but distrusted steward may process evidence quickly while damaging participation. A popular but exhausted steward may need workload relief before accepting responsibility.

### 5.4 Grievances

A grievance begins when an incident links an affected worker, an employer action, a contract or policy issue, and a potential remedy. Grievances move through these states:

1. Reported
2. Investigating
3. Documented
4. Submitted or escalated
5. Resolved, withdrawn, expired, or incorporated into bargaining

Evidence items have a source, reliability, relevant issue, expiration rule, and protection status. Testimony can be withdrawn if the witness is intimidated or loses trust. Physical records can be concealed by management unless copied or secured.

### 5.5 Escalation ladder

Disputes can move through:

1. Informal resolution
2. Documented grievance
3. Coordinated petition
4. Work-to-rule or slowdown
5. Walkout
6. Strike

Every action has prerequisites, a participation forecast, an employer response forecast, and a stated risk. Escalating before workers are ready can reduce solidarity and expose leaders. Waiting too long can expire evidence, normalize a hazard, or allow a worker to be dismissed.

### 5.6 Democracy and consent

Major actions require worker participation rather than a single player command. The player can recommend and campaign for a choice, but strike authorization and contract ratification use visible votes. A worker's vote derives from their concern, trust, relationships, risk tolerance, and the terms on offer. The interface explains the strongest factors without revealing exact hidden arithmetic.

---

## 6. Employer and Negotiation Systems

### 6.1 Employer strategy

Each employer has a strategy profile with priorities, pressure tolerance, preferred union-busting tactics, and exploitable contradictions. Tactics include selective concessions, favoritism, surveillance, discipline, replacement labor, propaganda, procedural delay, and manufactured emergencies.

Employer actions are authored and signaled. The player receives enough warning to make a meaningful response, though not always enough capacity to prevent every consequence.

### 6.2 Bargaining issues

Each contract contains three to five contested issues. Examples include:

- Base pay and treasure shares
- Scheduling and mandatory overtime
- Resurrection and reassembly coverage
- Adventurer hazard pay
- Anti-polymorph protections
- Just-cause discipline
- Staffing minimums
- Summoning-circle safety
- Subcontractor inclusion

Each issue has a minimum acceptable clause, one or more improved clauses, an employer cost, worker priority weights, relevant evidence, and relationships to other clauses.

### 6.3 Negotiation flow

Negotiation is a concise tactical conversation lasting approximately 8–12 minutes:

1. Workers approve bargaining priorities.
2. The employer presents an opening package.
3. The player chooses which issue to press and what support to cite.
4. The employer reacts according to its priorities and current pressure.
5. The player may trade, bundle, defer, threaten escalation, or request caucus.
6. A tentative agreement goes to a visible worker ratification vote.

There is no deck, random hand, or combat metaphor. Evidence establishes credibility. Solidarity, participation, strike readiness, treasury, and public support establish leverage. Employer pressure tolerance determines how quickly concessions become available.

The player usually cannot secure the strongest version of every clause. The design rewards a coherent package that reflects worker priorities rather than maximizing a generic score.

### 6.4 Outcomes

Negotiation produces contract clauses, worker reactions, treasury consequences, employer posture, and campaign flags. Rejection of a tentative agreement returns the player to organizing with reduced time and increased pressure. A failed strike may still win partial protections but causes fatigue, financial loss, and possible leadership turnover.

---

## 7. Campaign Content

### 7.1 Chapter one: Bone & Pick Excavations

**Workplace:** A goblin mine supplying traps and construction stone.  
**Employer:** Foreman Grint, a petty ogre franchise owner.  
**Primary lesson:** Listening, evidence, hazards, and informal action.  
**Central disputes:** Cave-in prevention, lantern fumes, unpaid tool maintenance, and adventurer alarms.  
**Climax:** The player chooses whether to accept fast safety concessions or build toward a broader first contract.

This chapter forms the 60–90-minute vertical slice. It contains 12 active workers, three major dispute lines, six incident families, one complete negotiation, and a limited union-hall sequence.

### 7.2 Chapter two: Cryptkeep Fulfillment

**Workplace:** An undead archive processing prophecies, curses, and resurrection claims.  
**Employer:** Senior Necromancer Vale, who treats undeath as exemption from break requirements.  
**Primary lesson:** Scheduling, surveillance, deadlines, and committees.  
**Central disputes:** Endless shifts, memory audits, resurrection eligibility, and spectral monitoring.  
**Climax:** A coordinated work-to-rule action can expose that management depends on undocumented worker knowledge.

### 7.3 Chapter three: Giltmaw Holdings

**Workplace:** A dragon-owned treasury and adventurer attraction.  
**Employer:** Aurix Giltmaw and a kobold management consultancy.  
**Primary lesson:** Favoritism, subcontracting, public support, and bargaining coalitions.  
**Central disputes:** Treasure-share theft, contractor exclusion, security searches, and hazardous display work.  
**Climax:** The player decides whether to include vulnerable subcontractors in the bargaining unit at significant short-term cost.

### 7.4 Chapter four: Crucible Solutions

**Workplace:** An alchemical foundry producing potions, fumes, and unstable enchantments.  
**Employer:** The Crucible Board, represented by a smiling homunculus executive.  
**Primary lesson:** Complex safety chains, retaliation, and strike preparation.  
**Central disputes:** Catastrophic exposure, species-based job segregation, falsified inspections, and replacement labor.  
**Climax:** A serious accident forces a choice between immediate shutdown and a risky evidence-gathering operation.

### 7.5 Chapter five: The Endless Depths Consortium

**Workplace:** A multi-department megadungeon combining extraction, archives, attractions, manufacturing, and logistics.  
**Employer:** A consortium led by the Infernal Efficiency Office.  
**Primary lesson:** Coordination across departments and synthesis of every prior system.  
**Central disputes:** Departmental divide-and-rule tactics, automated traps, outsourcing, and a dungeon-wide master agreement.  
**Climax:** The final campaign may culminate in a master contract, a general strike, a negotiated federation, or local collapse depending on prior choices.

### 7.6 Endings

The ending evaluates contract quality, democratic participation, local leadership capacity, worker safety, finances, and major ethical choices. It presents a montage of workplace outcomes rather than a single numerical rank.

Four broad organizational identities may emerge: democratic, pragmatic, militant, or bureaucratic. None is automatically the perfect ending. Individual epilogues reflect the actual workers, clauses, and unresolved conflicts in the completed campaign.

---

## 8. Union Hall and Progression

Between chapters, the player returns to a compact isometric union hall. The hall visually improves as membership and capacity grow. It is a progression interface and narrative gathering place, not a freeform construction game.

Contract victories and dues fund five upgrade branches:

- **Steward School:** Faster training, additional delegation, and stronger local autonomy.
- **Legal Desk:** Better evidence preservation, deadline warnings, and formal remedies.
- **Mutual-Aid Kitchen:** Lower fatigue, stronger strike endurance, and crisis recovery.
- **Print Shop:** Recruitment, public support, and counter-propaganda.
- **Organizing Workshop:** Better participation forecasts and advanced workplace actions.

Each branch contains three tiers. A normal campaign supplies enough resources to complete two branches and partially develop two others. This creates strategic identity without requiring grinding.

Won contract clauses also provide chapter-specific and occasional campaign-wide benefits. Safety language reduces injury probability. Scheduling protections slow fatigue. Just-cause language constrains arbitrary dismissal. Benefits are explained fictionally and mechanically.

---

## 9. Events and Replayability

### 9.1 Event content

The base game targets 70 authored workplace events across 18 event families. Events define eligibility conditions, involved roles, location requirements, choices, immediate effects, delayed consequences, cooldowns, and dialogue keys.

Procedural assembly may select names, valid rooms, involved workers, and compatible consequences. It does not generate dialogue at runtime. All shipped text is authored and reviewed.

### 9.2 Contract Challenge

Challenge mode selects three workplaces, employer variants, starting officers, economic conditions, and global modifiers. Example modifiers include:

- Thin strike fund
- Hostile local press
- Adventurer high season
- Inexperienced stewards
- Strong prior contract
- Fractured bargaining unit

Completion unlocks cosmetic hall elements, portrait accents, new challenge modifiers, and an archive of unusual contract clauses. It does not add power that trivializes the main campaign.

---

## 10. User Experience

### 10.1 Screen layout

The primary workplace interface uses three stable regions:

- A slim top bar for time, treasury, solidarity, and employer pressure.
- A collapsible left panel for workers, committees, and grievances.
- A contextual right panel for the selected person, room, incident, or action.

The center remains the isometric workplace. Incident markers cluster when zoomed out and separate when zoomed in. Selection outlines, floor highlights, and icons remain readable without relying on color alone.

### 10.2 Controls

The game is mouse and trackpad first:

- Primary click selects and confirms.
- Secondary click cancels or opens a concise context menu.
- Drag pans the camera.
- Pinch or wheel zooms.
- Space pauses.
- Number keys select time speed.
- Tab cycles active incidents.
- Configurable shortcuts open workers, grievances, committees, and objectives.

Edge scrolling is disabled by default for laptop use. All gameplay can be completed without holding multiple keys simultaneously.

### 10.3 Information design

Every global metric expands into an audit trail of recent changes. Forecasts use ranges and plain-language confidence rather than false precision. Hidden worker calculations expose their strongest positive and negative factors.

Tutorials appear in context, can be dismissed permanently, and remain available in the archive. The first chapter introduces no more than one new top-level system per workday.

### 10.4 Accessibility

Version 1.0 includes:

- Scalable interface and subtitle text.
- Full keyboard remapping.
- Reduced motion and screen-shake controls.
- Automatic pause for major events.
- Adjustable simulation speed.
- High-contrast selection and hazard overlays.
- Color-independent icons and patterns.
- Dyslexia-friendly font option.
- Separate music, ambience, voice-like vocalizations, and effects volume.
- Written equivalents for every audio cue.
- Hold, toggle, or timed alternatives for sustained input.

Controller support is desirable after the vertical slice but is not a macOS launch requirement.

---

## 11. Visual and Audio Direction

### 11.1 Visual language

The art direction combines illustrated labor pamphlets, fantasy storybooks, and screen-print texture. Workers use heavy silhouettes and expressive portraits. Union spaces emphasize warm reds, creams, brass, worn paper, and communal light. Employer spaces use colder palettes, hard symmetry, surveillance motifs, and excessive ornament.

Rooms and large props are hand-illustrated 2D assets positioned on an isometric diamond grid. Workers use layered 2D rigs with automatic depth sorting. Portraits use modular species components with hand-authored expressions and unique accessories for major characters.

The camera remains fixed in orientation. It supports pan and bounded zoom but no player rotation, avoiding asset multiplication and depth-sorting ambiguity.

### 11.2 Animation

Animation prioritizes readable work and emotion:

- Idle, walk, work, talk, alarm, injured, celebrate, and strike loops.
- Shared skeletal rigs within body families.
- Species-specific secondary motion such as tails, wings, flames, or floating bones.
- Short signature animations for major story characters.
- Limited portrait expression swaps during dialogue.

### 11.3 Audio

The score combines improvised folk instrumentation, work-song structures, and percussion built from workplace sounds. Each chapter has a base ambience, work layer, pressure layer, and solidarity layer. Musical voices enter as solidarity rises and drop out during demoralization.

Important incidents use distinct nonverbal cues paired with visual markers. Workers use short nonverbal vocalizations rather than full voice acting. The launch target is eight adaptive music suites, five workplace ambience sets, and a reusable library of interface and simulation effects.

---

## 12. Technical Design

### 12.1 Runtime targets

- Godot 4.x stable using GDScript with static typing enabled.
- Native arm64 macOS export, signed and notarized for public distribution.
- 60 frames per second on an Apple Silicon MacBook at 1440×900 logical resolution.
- Support for Retina scaling and common 16:10 and 16:9 aspect ratios.
- Simulation tick independent from rendering frame rate.
- Fewer than 30 simultaneously active worker agents in the densest launch scenario.
- Offline operation with no account or model API requirement.

### 12.2 System boundaries

| Component | Responsibility | Depends on |
|---|---|---|
| Simulation Clock | Ticks, pause, time speed, scheduled callbacks | Campaign settings |
| Worker Agents | Jobs, movement intent, fatigue, trust, relationships | Clock, workplace navigation |
| Workplace Director | Schedules, hazards, raids, employer interventions | Clock, event catalog, campaign state |
| Grievance System | Incidents, testimony, evidence, deadlines, remedies | Worker identities, contracts |
| Organizing System | Conversations, committees, escalation, solidarity | Workers, grievances, resources |
| Negotiation Resolver | Demands, leverage, offers, ratification | Organizing state, employer profile |
| Campaign State | Chapters, upgrades, clauses, consequences, endings | Save service |
| Event Engine | Condition validation and authored event execution | Data catalog, deterministic RNG |
| Save Service | Versioned serialization, migration, autosave, recovery | Durable state interfaces |
| Presentation Layer | Scenes, UI, animation, audio, accessibility | Read-only system views and commands |

Systems communicate through typed commands, immutable event records, and explicit query interfaces. Interface nodes do not mutate worker or campaign state directly.

### 12.3 Content resources

Content is stored in typed Godot Resources:

- WorkerDefinition
- WorkplaceDefinition
- JobDefinition
- EmployerProfile
- EventDefinition
- GrievanceDefinition
- EvidenceDefinition
- BargainingIssueDefinition
- ContractClauseDefinition
- ConversationDefinition
- UpgradeDefinition
- ChallengeModifier

Each resource has a stable string identifier. References are validated at startup and by an editor validation tool. Scenes contain presentation and navigation geometry; campaign logic is not hardcoded into scenes.

### 12.4 Data flow

During a simulation tick:

1. The clock emits a deterministic tick.
2. Schedules and active incidents update worker intentions.
3. Worker agents update logical state and request presentation changes.
4. The Workplace Director evaluates event eligibility at bounded intervals.
5. Executed events emit immutable incident records.
6. The Grievance System converts relevant incidents into cases and evidence opportunities.
7. The Organizing System updates participation, committees, and leverage.
8. Read-only view models publish changes to the interface.

At shift end, durable state is normalized before serialization. Transient paths, animation positions, open panels, and cached forecasts are reconstructed after loading.

### 12.5 Determinism

Campaign creation stores a master seed. Each workday derives a child seed from the campaign seed, chapter identifier, and day index. Random requests pass through a named stream so cosmetic choices cannot change simulation outcomes.

The simulation advances in fixed logical ticks. Pausing, changing time speed, changing frame rate, saving, or loading does not alter the resulting sequence of validated incidents.

### 12.6 Save system

Save data contains:

- Schema version and build identifier.
- Campaign seed and current chapter/day.
- Durable worker state and memory flags.
- Active and resolved grievances.
- Contract clauses and employer posture.
- Resources, upgrades, challenge unlocks, and settings references.
- A checksum and last successful save timestamp.

The game provides manual slots and three rotating autosaves. Autosaves occur at shift start, shift end, before negotiation, and after ratification. Writes use a temporary file followed by atomic replacement. A failed checksum triggers recovery from the newest valid rotating autosave.

### 12.7 Error handling

- Missing optional art or audio uses a visible development fallback and a safe release fallback.
- Invalid event definitions are logged and excluded before a campaign begins.
- A runtime event whose conditions become invalid is canceled without consuming its cooldown.
- Missing localization displays the source English string and logs the key.
- Failed navigation moves the worker to the nearest valid workstation anchor after a bounded retry.
- Save migration failure preserves the original file and offers the newest valid autosave.
- A diagnostic export packages logs, build information, and anonymized state identifiers without including user account data.

---

## 13. Testing and Quality Strategy

### 13.1 Automated tests

**Unit tests** cover formulas, event eligibility, evidence expiration, action participation, contract offers, votes, upgrades, and save migration.

**Deterministic simulation tests** replay seeded workdays and compare incident sequences, durable worker changes, and shift summaries against approved fixtures.

**Content validation tests** load every resource and verify unique identifiers, valid references, reachable conversation exits, compatible event roles, complete fallback text, and valid contract relationships.

**Save tests** serialize and restore representative states from every chapter, each negotiation phase, active strikes, collapsed locals, and challenge mode.

**Smoke tests** launch each workplace, run multiple accelerated workdays, trigger representative incidents, save, reload, and complete a negotiation.

### 13.2 Performance tests

The performance fixture contains 30 agents, the largest launch workplace, two overlapping incidents, active navigation, open worker and grievance panels, adaptive music, and maximum supported zoom. It must sustain 60 FPS on the target MacBook profile with simulation speed at normal and remain responsive at quadruple speed.

### 13.3 Playtest questions

Playtests evaluate:

- Whether players can explain why a grievance exists.
- Whether they remember individual workers after a chapter.
- Whether solidarity changes feel earned and understandable.
- Whether escalation forecasts support decisions without solving them.
- Whether negotiations reflect prior workplace actions.
- Whether setbacks feel recoverable rather than arbitrary.
- Whether the first chapter teaches systems without excessive interruption.
- Whether humor supports rather than undermines emotional stakes.

### 13.4 Definition of done

A feature is complete when its player-facing behavior is documented, content is validated, automated tests cover deterministic rules, accessibility states are supported, failure behavior is defined, and the feature performs on the target macOS profile.

---

## 14. Production Plan

### 14.1 Milestone zero: Foundations

Deliver the simulation clock, typed resource catalog, worker movement, command interfaces, deterministic random streams, save skeleton, validation tooling, and a greybox isometric room.

### 14.2 Milestone one: Vertical slice

Deliver the complete Bone & Pick chapter:

- 12 named workers and three officer roles.
- One workplace with production schedules and navigation.
- Three dispute lines and six incident families.
- Conversations, evidence, grievances, committees, and four escalation steps.
- One complete negotiation and ratification vote.
- A partial union hall with one upgrade in each branch.
- Save/load, settings, accessibility basics, and target performance.
- 60–90 minutes of polished play.

The vertical slice is the production gate. Full campaign work begins only if external playtesters understand the loop, care about workers, and report that negotiation outcomes reflect their organizing choices.

### 14.3 Milestone two: Production systems

Complete all campaign-wide systems, union-hall progression, employer strategies, full escalation ladder, strike flow, campaign consequences, content tooling, and final save schema.

### 14.4 Milestone three: Campaign content

Build chapters two through five in order, with a validation and playtest pass after each. Shared systems must stabilize before the final chapter begins.

### 14.5 Milestone four: Replayability and polish

Add Contract Challenge, final accessibility work, balance passes, performance optimization, localization preparation, achievements if platform support warrants them, signing, notarization, and release packaging.

---

## 15. AI-Assisted Development Workflow

GPT-5.6 Sol acts as lead architect and integrator. Its responsibilities include system boundaries, core simulation, difficult debugging, performance work, cross-system changes, release reviews, and final acceptance against the design.

OX Alpha acts as an independent prototyper and challenger. Its responsibilities include isolated mechanic prototypes, alternative implementations, test generation, balance critiques, content variations, and adversarial code review.

The models do not edit the same feature concurrently. Every task begins with a written contract specifying owned files, public interfaces, invariants, acceptance tests, and out-of-scope behavior. Prototype work is not merged until Sol verifies the interfaces and the automated suite passes.

Generated narrative or event content remains draft material until reviewed for consistency, tone, repetition, and unintended real-world claims. No model service is called by the shipped game.

---

## 16. Commercial and Release Scope

### 16.1 Included in version 1.0

- Native macOS single-player campaign.
- Five workplaces and approximately 52 named workers.
- Contract Challenge mode.
- Manual saves and rotating autosaves.
- English interface and dialogue with localization-ready data.
- Accessibility options listed in this document.
- Offline play with no account requirement.

### 16.2 Explicitly out of scope

- Multiplayer or cooperative play.
- Mobile or touch-first interface.
- Freeform dungeon construction.
- Endless colony simulation.
- User-generated campaigns or public mod tools.
- Full voice acting.
- Runtime generative dialogue.
- Microtransactions, battle passes, paid currency, or advertisements.
- Required telemetry or online authentication.

### 16.3 Future-compatible but uncommitted

The technical structure should not prevent Windows and Linux exports, additional challenge content, localization, or curated mod support. These are not version 1.0 commitments and may not increase the initial project scope.

---

## 17. Risk Register

| Risk | Consequence | Mitigation |
|---|---|---|
| Workers feel like numbers | Emotional premise fails | Named cast, relationship memories, explanation audit trails, attachment playtests |
| Simulation becomes overwhelming | Players pause constantly or ignore events | Incident pacing limits, steward delegation, automatic pause options |
| Negotiation feels disconnected | Core loop lacks payoff | Every bargaining input derives from visible workday systems |
| Isometric 2D sorting fails | Visual confusion and bugs | Fixed camera, bounded asset footprints, automated depth rules, stress scenes |
| Authored content workload grows | Campaign misses scope | Modular portraits, reusable event families, fixed five-chapter content budget |
| Humor trivializes harm | Tone alienates players | Workers treated sincerely, sensitivity review, jokes target institutions and bosses |
| Save changes break campaigns | Lost player progress | Stable IDs, schema versions, migrations, rotating autosaves, fixture coverage |
| Model-generated inconsistency | Code or narrative fragments diverge | Written task contracts, single integrator, tests, reviewed production content |
| MacBook performance degrades | Launch target is missed | 30-agent cap, fixed-tick simulation, early target-hardware profiling |

---

## 18. Acceptance Criteria for the Game

The 1.0 design is fulfilled when:

1. A new player can complete the five-workplace campaign on a supported Apple Silicon Mac without an online account or model API.
2. The median first campaign lasts between seven and nine hours in external testing.
3. Every contract outcome can be traced to documented evidence, worker participation, resources, employer priorities, and player choices.
4. Every required incident and audio cue has a color-independent visual or written equivalent.
5. Saving and loading during every supported campaign phase preserves durable outcomes and deterministic event order.
6. The densest supported workplace maintains the stated performance target on the target MacBook profile.
7. External playtesters can identify at least three workers from the first chapter and explain one consequence of their own organizing strategy.
8. Campaign setbacks remain recoverable unless the local explicitly collapses under the documented conditions.
9. All shipped content passes resource validation and all deterministic smoke tests pass in the release build.
10. The release contains none of the features explicitly excluded from version 1.0.

---

## 19. Design Summary

*Dungeon Union* succeeds if organizing is both emotionally human and mechanically legible. The workplace simulation creates problems, relationships give those problems meaning, organizing converts concern into collective capacity, and negotiation turns that capacity into durable change. The five-chapter campaign supplies a finishable premium scope; challenge mode supplies replayability without expanding the core simulation into an endless sandbox.

Every production decision should protect that chain. Features that do not strengthen visible working conditions, worker attachment, collective decision-making, or earned contract outcomes should remain outside version 1.0.
