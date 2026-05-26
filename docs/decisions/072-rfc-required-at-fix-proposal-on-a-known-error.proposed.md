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

# RFC required at the propose-fix step on a Known Error

> **Rewritten 2026-05-26 (P314).** The original ADR-072 placed this gate at the `Open → Known Error` transition, on the framing "Known Error = fix is now real." That framing was **wrong** and the decision was **rejected** at the `/wr-architect:review-decisions` drain (user correction: *"A problem becomes a known error when we have a documented workaround and root cause. Once it's known error then we can propose a fix which would result in an RFC."*). The original gate placement also latently contradicted ADR-022's accepted Known Error semantics. This rewrite records the corrected placement and is **born-confirmed** via direct user ratification this session (AskUserQuestion — the user confirmed the propose-fix placement). Sibling **ADR-073** (rewritten in the same pass) records that a missing RFC is auto-created rather than blocked.

## Context and Problem Statement

ADR-071 makes the Problem→RFC trace mandatory and unconditional. **Where in the problem lifecycle is the RFC required?**

Per ADR-022, the lifecycle is `Open → Known Error → Verifying → Closed`. A problem reaches **Known Error** when its **root cause is identified and a workaround is documented** — there is no fix and no RFC yet. Only *after* Known Error do we **propose a fix**, and proposing the fix is what **produces the RFC**. Releasing the fix is the `Known Error → Verifying` transition (ADR-022) — "Fix Released" is not a separate state.

So the RFC must be required at the moment a fix is **proposed** on a Known Error — not earlier (a problem reaches Known Error with no fix) and not at fix-release (the RFC must exist *before* fix work, or the inline `## Root Cause → ## Fix Strategy` body-drift the invariant prevents has already happened).

## Decision Drivers

- The RFC must exist when fix work is **proposed/commenced**, which (per ADR-022) is *after* Known Error — gating earlier requires an RFC a Known Error problem legitimately doesn't have yet.
- Reuse the existing lifecycle ontology (ADR-060 I2) — avoid a new state that adds no semantics beyond what `Known Error` + the propose-fix act already carry.
- Conform to ADR-022's Known Error semantics (root cause + workaround; fix-release IS the `Known Error → Verifying` transition).

## Considered Options

(Evaluated against the **corrected** Known Error model — the original ADR-072's options were evaluated against a wrong model and are discarded.)

1. **The RFC is created/required at the propose-fix step on a Known Error** — a `/wr-itil:manage-problem` propose-fix action; no new lifecycle state.
2. **A new `Known Error → In Progress (fixing)` lifecycle state** — gate the new transition.
3. **At the first fix commit** for a Known Error problem — a commit-time gate.

## Decision Outcome

Chosen option: **"The RFC is created/required at the propose-fix step on a Known Error"** (user-ratified). When a fix is proposed on a Known Error (the `/wr-itil:manage-problem` propose-fix action), an RFC tracing the problem must exist; the RFC **is** the fix-proposal artifact. No new lifecycle state — `Known Error` stays, and the existing `Known Error → Verifying` (fix-released) transition is unchanged (ADR-022).

This placement is silent on whether a *missing* RFC blocks or is auto-created — that is **ADR-073**'s axis (auto-create, everywhere). The combined behaviour: proposing a fix on a Known Error auto-creates a problem-traced RFC if one doesn't exist.

This ADR records the placement decision. ADR-060's I13 invariant (rewritten under P314) cites this ADR; the propose-fix enforcement ships as RFC-005's (corrected) task decomposition.

## Consequences

### Good

- The RFC is required exactly when a fix is proposed — after root cause + workaround (Known Error), before fix work — conforming to ADR-022's Known Error semantics.
- No new lifecycle state (ADR-060 I2 preserved).
- A problem can reach Known Error (root cause + workaround) without yet needing an RFC — the gate doesn't force premature RFC creation during triage.

### Neutral

- The propose-fix step becomes the RFC-creation surface; `/wr-itil:manage-problem` gains (or formalises) a propose-fix action.

### Bad

- "Propose fix" must be an identifiable action/surface in `/wr-itil:manage-problem` for the gate to attach to (an implementation task, RFC-005).

## Confirmation

- ADR-060 I13 names the propose-fix step on a Known Error as the gate placement and cites this ADR + ADR-022.
- `/wr-itil:manage-problem`'s propose-fix surface requires/creates the RFC (auto-create per ADR-073).
- A behavioural test asserts the gate fires at propose-fix, not at `Open → Known Error`.

## Pros and Cons of the Options

### Option 1 — propose-fix step on a Known Error (chosen)

- Good: matches ADR-022 (Known Error = root cause + workaround; fix proposed after); no new state; RFC exists before fix work.
- Bad: requires a propose-fix surface in manage-problem to attach the gate to.

### Option 2 — new `Known Error → In Progress` state

- Good: an explicit "fixing" marker.
- Bad: inflates the lifecycle ontology (ADR-060 I2) with no semantics the propose-fix act doesn't already carry.

### Option 3 — at the first fix commit

- Good: catches it at the code boundary.
- Bad: the RFC arrives as the fix *lands* rather than when it's *proposed* — too late to scope the fix before work; weaker than gating the proposal.

## Reassessment Criteria

Revisit if "propose fix" proves hard to pin to a single manage-problem surface in practice, or if field use shows the RFC is consistently needed at a different point in the fix flow.

## Related

- **ADR-071** — every fix goes through an RFC (the unconditional parent this placement serves).
- **ADR-073** — fix-time gate auto-creates a missing RFC, everywhere (sibling; the block-vs-create axis, rewritten in the same pass).
- **ADR-022** — problem lifecycle / Verification Pending semantics: Known Error = root cause + workaround; fix-release IS the `Known Error → Verifying` transition. **The lifecycle authority this placement conforms to** (the original ADR-072 omitted this reference, which let the wrong-model placement land).
- **ADR-070** — RFCs hold no independent decisions (the auto-created RFC is a problem-traced skeleton, no decisions).
- **ADR-060** — Problem-RFC-Story framework; its I13 invariant (rewritten under P314) cites this ADR for the gate placement.
- **P251** — RFC-first trace invariant not enforced at fix-time (driving problem).
- **P314** — the rework ticket that corrected this ADR's placement.
- **RFC-005** — ships the propose-fix gate mechanism (corrected task decomposition).
- **RFC-006** — implementation RFC that originally extracted this decision (with the wrong placement); P314 is its corrective follow-on.
