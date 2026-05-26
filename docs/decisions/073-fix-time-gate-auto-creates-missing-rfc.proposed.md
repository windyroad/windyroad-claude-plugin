---
status: "proposed"
date: 2026-05-26
human-oversight: confirmed
oversight-date: 2026-05-26
decision-makers: [Tom Howard]
consulted: [wr-architect:agent]
informed: []
reassessment-date: 2026-08-26
problems: [P251, P314]
---

# Fix-time gate auto-creates a missing RFC (everywhere)

> **Rewritten 2026-05-26 (P314).** The original ADR-073 chose **hard-block + skip-to-next** on the rationale that RFC scope is direction-setting (ADR-044 cat-1) and the orchestrator must not author it. That was **rejected** at the `/wr-architect:review-decisions` drain (user correction: *"No, it's supposed to create the RFC if it's missing"*, scope *"Everywhere the gate fires"*). This rewrite records auto-create-everywhere and is **born-confirmed** via direct user ratification this session. Sibling **ADR-072** (rewritten in the same pass) records the gate placement (propose-fix on a Known Error).

## Context and Problem Statement

ADR-071 makes the RFC mandatory for every fix; ADR-072 places the gate at the **propose-fix step on a Known Error**. This decides what happens when a fix is proposed on a Known Error and **no RFC exists**: block the work (and defer RFC authoring to the user), or auto-create the RFC?

## Decision Drivers

- ADR-071 has already pinned the direction: **every fix goes through an RFC**. A missing RFC is therefore not an open question — the mandatory vehicle simply needs instantiating.
- The RFC's scope is the **already-traced problem's fix** — auto-creating a problem-traced skeleton is instantiating the vehicle, not inventing direction.
- A hard-block stalls the AFK orchestrator and adds friction at the interactive surface; with the direction already pinned, blocking buys nothing.

## Considered Options

1. **Auto-create a problem-traced RFC if missing, everywhere the gate fires** (interactive `/wr-itil:manage-problem` + AFK `/wr-itil:work-problems`).
2. **Hard-block + skip-to-next** (the original ADR-073 — orchestrator refuses, advances to next-highest-WSJF candidate, surfaces a `capture-rfc` recovery prompt).
3. **Soft-route, orchestrator-only** (auto-create in the AFK loop only; hard-block at the interactive surface).

## Decision Outcome

Chosen option: **"Auto-create a problem-traced RFC if missing, everywhere the gate fires"** (user-ratified). When the propose-fix gate (ADR-072) fires on a Known Error with no RFC trace, the framework **auto-creates a problem-traced RFC** — a skeleton tracing the problem, scope = the fix, no story decomposition (`stories: []`), carrying **no decisions** (ADR-070-compliant: no "Considered Options" block). This fires at **every** fix-time surface: the interactive `/wr-itil:manage-problem` propose-fix action AND the AFK `/wr-itil:work-problems` orchestrator. A missing RFC is never a block anywhere.

### ADR-044 reclassification (load-bearing)

The original ADR-073 classified orchestrator RFC-authoring as **ADR-044 category-1 (direction-setting)** — "RFC scope is direction-setting, the orchestrator must not author it." This rewrite **reclassifies** *auto-creating a problem-traced skeleton RFC* as **framework-mediated**, not cat-1 direction-setting: the direction (every fix goes through an RFC) is already pinned by **ADR-071**, and the skeleton's scope is the already-traced problem, not new direction. This is a **scoping clarification of cat-1's boundary** — auto-creating the already-pinned mandatory vehicle is precisely the "don't re-ask a decision the framework already made" discipline (P132 / inverse-P078). **ADR-044's six-class taxonomy is unchanged** (no `amends:`); this ADR records where the cat-1 boundary sits for this surface.

This ADR records the auto-create stance. The propose-fix enforcement + auto-create mechanism ship as RFC-005's (corrected) task decomposition.

## Consequences

### Good

- The mandatory RFC vehicle (ADR-071) is always instantiated — no fix is ever stalled or skipped for a missing RFC.
- Uniform behaviour at every fix-time surface (interactive + AFK).
- The auto-created skeleton is ADR-070-compliant (problem-traced, no decisions).

### Neutral

- Auto-creation replaces the user-authors-it-first model; the user refines the skeleton's scope after the fact if needed (the RFC body, not its existence, is the editable surface).

### Bad

- An auto-created RFC could be under-scoped if the fix turns out larger than the problem trace implies — mitigated because the RFC body is then fleshed out as fix work proceeds (the RFC is a living scope artifact, not a one-shot).

## Confirmation

- The propose-fix gate (interactive + AFK) auto-creates a problem-traced skeleton RFC when none exists; it never hard-blocks for a missing RFC.
- The auto-created RFC carries no "Considered Options" block (passes the ADR-052 lint) and traces the driving problem.
- A behavioural test asserts auto-create fires at both the interactive and AFK surfaces.

## Pros and Cons of the Options

### Option 1 — auto-create everywhere (chosen)

- Good: never stalls; uniform; instantiates the ADR-071-mandatory vehicle; ADR-070-compliant skeleton.
- Bad: an auto-created RFC may be under-scoped initially (fleshed out as work proceeds).

### Option 2 — hard-block + skip (original, rejected)

- Good: forces the user to scope the RFC up front.
- Bad: stalls the loop / adds interactive friction; treats RFC creation as user-direction when ADR-071 already pinned it — re-asking a decided question.

### Option 3 — soft-route orchestrator-only (rejected)

- Good: unstalls the AFK loop.
- Bad: partial — leaves the interactive surface hard-blocking; the user wants auto-create everywhere (uniform).

## Reassessment Criteria

Revisit if auto-created RFCs are systematically under-scoped (a recurring "the auto-RFC didn't capture the real fix" signal), or if a class of fixes emerges where auto-creation produces noise rather than a useful vehicle.

## Related

- **ADR-071** — every fix goes through an RFC (pins the direction that makes auto-create framework-mediated, not direction-setting).
- **ADR-072** — RFC required at the propose-fix step on a Known Error (sibling; the gate placement this stance enforces).
- **ADR-070** — RFCs hold no independent decisions (the auto-created skeleton carries none).
- **ADR-044** — decision-delegation contract; this ADR reclassifies the cat-1 boundary for auto-creating a problem-traced skeleton (no taxonomy change).
- **ADR-060** — Problem-RFC-Story framework; its I13 invariant (rewritten under P314) cites this ADR for the auto-create behaviour.
- **JTBD-006** — Progress the Backlog While I'm Away; auto-create keeps the AFK loop moving rather than skipping RFC-less fixes.
- **P251** — RFC-first trace invariant not enforced at fix-time (driving problem).
- **P314** — the rework ticket that corrected this ADR's stance.
- **RFC-005** — ships the auto-create mechanism (corrected task decomposition).
- **RFC-006** — implementation RFC that originally extracted this decision (with the hard-block stance); P314 is its corrective follow-on.
