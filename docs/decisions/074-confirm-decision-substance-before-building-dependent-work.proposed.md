---
status: "proposed"
date: 2026-05-27
human-oversight: confirmed
oversight-date: 2026-05-27
decision-makers: [Tom Howard]
consulted: [wr-architect:agent]
informed: []
reassessment-date: 2026-08-27
---

# ADR-074: Confirm a decision's substance before building dependent work on it

## Context and Problem Statement

ADR-064 closed the **new-decision leak at recording time**: the architect emits a Needs-Direction verdict and the main agent confirms the options via `AskUserQuestion` *before recording* the decision. ADR-066 added the durable `human-oversight: confirmed` marker + the `/wr-architect:review-decisions` drain to catch the *existing* unconfirmed backlog ("born-`proposed`, drain later").

A gap sits **between** the two. ADR-064's "confirm before recording" was satisfied, in practice, by confirming only the **meta/grain** question while the **substance** rode unconfirmed — and nothing governed the moment a born-`proposed` decision gets **built upon**.

**Concrete instance (P315, 2026-05-26):** implementing ADR-070/071 via RFC-006, the agent extracted two genuine new decisions — **ADR-072** (fix-time gate placement) and **ADR-073** (hard-block vs auto-create). It surfaced ONE `AskUserQuestion` — the *grain* ("one ADR or two?") — and treated the decisions' *substance* as architect-resolved. It then built dependent work on them: ADR-060's **I13** invariant encoded both, the RFC-005 retrofit referenced them, and RFC-006 slices shipped. At the post-hoc `/wr-architect:review-decisions` drain the user **rejected both** — so I13 + the RFC-005 retrofit had been built on a wrong gate design (rework: P314). User (verbatim): *"I'm a bit frustrated that you didn't get my confirmation on those ADRs before you implemented them."*

The root conflation: *"don't born-confirm the marker"* (ADR-066's correct backlog model) was treated as *"OK to implement before confirmation."* ADR-064 only fires cleanly for a decision recorded on its own; a decision recorded **mid-implementation** slipped through to dependent work before its substance was ever human-confirmed.

A decision needs recording now because the "born-`proposed` + implement, drain later" pattern is the documented ADR-066 flow — so this built-on-sand failure can recur on any multi-artifact implementation that extracts/records new decisions and builds on them in the same pass.

## Decision Drivers

- A recorded decision is a load-bearing contract; building dependent artifacts (other ADRs, RFC slices, invariants, code) on an unconfirmed substantive choice means a later rejection forces built-on-sand rework (P315 → P314).
- The fix must **not** swing into over-asking — the inverse-P078 / CLAUDE.md P132 trap. The trigger must be narrow: only when *a genuine ≥2-option decision the framework cannot resolve is about to be **built on***. Never on obvious / single-option / pinned-direction cases.
- It must compose with ADR-064 (Needs-Direction names options at record time), ADR-066 (born-`proposed` marker + drain), ADR-044 (decision-delegation taxonomy + lazy-AskUserQuestion regression metric), and ADR-060 I13 (the propose-fix surface where extracted decisions get built on).
- The "decision recorded" moment (born-`proposed` marker is fine) is distinct from the "decision built upon" moment (needs substance-confirm first); the framework currently conflates them.
- Detection of "this decision is born-`proposed`, unconfirmed, and about to be built on" is mechanical/framework-mediated; only the resolution (confirm the substance) is a category-1 direction-setting `AskUserQuestion`.

## Considered Options

1. **Amend ADR-064 only** - fold the build-upon contract into ADR-064 as an extended clause. Cheapest (one file), but conflates two distinct temporal contracts (record-time vs build-time) in one ADR and gives the build-upon contract a less discoverable home buried inside a verdict-mechanics ADR.
2. **New ADR only** - establish the contract standalone, cite ADR-064 without amending it. Clean new-content home, but leaves ADR-064's Needs-Direction text still able to fire on grain-only - the literal P315 vector stays permitted by 064's own wording.
3. **New ADR + thin amend to ADR-064 + carve-out clause in ADR-066** (chosen) - new ADR establishes the record-vs-build-upon distinction and the confirm-substance-before-build contract; ADR-064 gets a one-clause amend (Needs-Direction names the *substantive* choice; "confirm before recording" is not satisfied by a meta/grain question alone); ADR-066 gets a carve-out clause (born-`proposed` marker ≠ implementation licence). Enforcement at both the architect-verdict layer and a process guard at the propose-fix / I13 surface. Mirrors ADR-044's chosen sibling-plus-thin-amend shape.

## Decision Outcome

Chosen option: **"Option 3 — New ADR + thin amend to ADR-064 + carve-out clause in ADR-066"**, confirmed by the user via `AskUserQuestion` 2026-05-27, because it is the only option that closes all three surfaces P315 names (the architect verdict's grain-vs-substance gap, the build-upon process gate, and ADR-066's marker-vs-licence conflation) and it follows the established ADR-044 sibling-plus-thin-amend precedent.

**The contract.** For a genuine choice among ≥2 viable options that the framework cannot resolve (an ADR-044 category-1 direction-setting decision), the **substantive chosen option** must be human-confirmed via `AskUserQuestion` **before any dependent work is built on it**. Confirming a meta/grain question (e.g. "one ADR or two?", file split, naming) does NOT satisfy this — the substance is the actual option selected.

- **"Decision recorded" vs "decision built upon".** Recording a decision born-`proposed` without an oversight marker remains fine (ADR-066's backlog model). The born-`proposed` marker governs the *existence/recording* of the decision; it is **not** a licence to build dependent artifacts on the decision's substance before that substance is confirmed. The build-upon moment is the gated one.

- **Enforcement surface 1 — architect-verdict layer (ADR-064 amend).** A Needs-Direction verdict must name the **substantive** choice (the options among which the user must pick), not defer to a meta/grain question. "Confirm before recording" (ADR-064) is not satisfied by confirming a grain question alone.

- **Enforcement surface 2 — process guard at the propose-fix / I13 surface.** `/wr-itil:work-problems` and `/wr-itil:manage-problem` (the propose-fix step where ADR-060 I13 auto-creates a problem-traced RFC and where dependent RFC slices / invariant edits get built) check: does this fix build on a born-`proposed` decision whose substance is unconfirmed? If so, surface the substance via `AskUserQuestion` (or, under AFK, queue to the iteration's `outstanding_questions` per ADR-044) before the dependent work lands. A PreToolUse hook is explicitly **rejected** as the primary surface — the "is this dependent work on an unconfirmed decision?" judgment is semantic, not a path/pattern match, and a hook would over-fire into the inverse-P078 trap.

- **Enforcement surface 3 — architect-review / plan-review layer (Amendment 2026-05-27, RFC-010 / P318).** The `wr-architect:agent` review (every project file edit, via the gate) and `/wr-architect:review-design` (plans) flag a change/plan that explicitly **cites or implements** an **unratified** ADR — one whose frontmatter lacks `human-oversight: confirmed` and is not `*.superseded.md` — as **ISSUES FOUND / [Unratified Dependency]**, action "ratify ADR-NNN via `/wr-architect:review-decisions` before this lands." This generalises surface 1 from *recording a new decision* to *building on an already-recorded but unratified one*, closing the residual foreground gap surface 2 leaves (work not routed through the ITIL propose-fix path). **Keyed on the oversight marker, NOT `status:`** — building on a *ratified* ADR (even `status: proposed`) passes; status (proposed/accepted) and oversight (ratified) are orthogonal axes (ADR-066). Near-zero noise in steady state (2026-05-27: 4/65 ADRs unratified). The architect agent (Read/Glob/Grep, no Bash) performs the read-only equivalent of `is-decision-unconfirmed.sh` via a frontmatter-scoped marker Grep. Substance user-pinned same-session (Tom Howard 2026-05-27 — asked for the architect to flag build-on-unratified + corrected the trigger to marker-not-status); recorded born-confirmed, not Needs-Direction.

- **ADR-066 carve-out.** ADR-066 carries a clause: the born-`proposed` marker covers recording, not implementation licence; dependent work waits for substance-confirm.

- **ADR-044 composition (load-bearing).** The substance-confirm-before-build ask is a category-1 direction-setting ask and MUST be **excluded** from the lazy-AskUserQuestion regression metric (it is a legitimate ask, not a lazy one). Detection is mechanical/framework-mediated; only the resolution is the cat-1 ask. The trigger is bounded exactly as the driver states — never obvious / single-option / pinned cases.

- **Sharpens ADR-070.** ADR-070's "every ≥2-option choice inherits the ADR-064 confirm gate" is sharpened from *intent* to *enforced-before-build*, riding ADR-060 I13's propose-fix surface.

## Consequences

### Good

- Eliminates the built-on-sand rework class (P315 → P314): a substantive choice cannot silently ride into dependent artifacts before the user confirms it.
- Gives the build-upon contract a discoverable, citable home distinct from ADR-064's record-time contract.
- Closes ADR-070's enforcement gap at the exact surface (I13 propose-fix) where extracted decisions get built on.

### Neutral

- Adds confirm asks at the build-upon moment, but only for genuine cat-1 decisions about to be built on — bounded by the ADR-044 exclusion + narrow trigger.
- The contract lives across three files (new ADR + ADR-064 amend + ADR-066 carve-out); citation churn is the cost of the most-complete closure.

### Bad

- A mis-calibrated trigger could regress toward over-asking (the inverse-P078 / P132 trap) — mitigated by the explicit narrow-trigger bound + the ADR-044 lazy-count exclusion, but it is a standing calibration risk to watch at reassessment.

## Confirmation

- A Needs-Direction verdict from `wr-architect:agent` names the substantive options (not a grain/meta question); behavioural test asserts the verdict block contains the candidate options, not "one ADR or two?".
- The propose-fix guard in `/wr-itil:work-problems` and `/wr-itil:manage-problem` halts (interactive) or queues to `outstanding_questions` (AFK) when a fix builds on a born-`proposed` decision whose substance is unconfirmed; behavioural test exercises the guard with an unconfirmed-decision fixture.
- ADR-064 carries the grain-vs-substance clause; ADR-066 carries the marker-≠-licence carve-out.
- The lazy-AskUserQuestion regression metric (`packages/retrospective/scripts/check-ask-hygiene.sh`) excludes substance-confirm-before-build asks — verified by a fixture that the ask does not increment the lazy-count.

## Pros and Cons of the Options

### Option 1 — Amend ADR-064 only

- Good: cheapest; one file.
- Bad: conflates record-time and build-time contracts in one ADR; less discoverable home; omits the standalone process guard.

### Option 2 — New ADR only

- Good: clean new-content home.
- Bad: leaves ADR-064's text still able to fire on grain-only — the literal P315 vector stays permitted.

### Option 3 — New ADR + thin amend to ADR-064 + carve-out in ADR-066 (chosen)

- Good: closes all three P315 surfaces; follows the ADR-044 sibling-plus-thin-amend precedent; build-upon contract gets its own citable home.
- Bad: most work; contract spread across three files (citation churn).

## Reassessment Criteria

Revisit if: the narrow trigger proves mis-calibrated in either direction — the lazy-AskUserQuestion count regresses (over-asking returned) OR a built-on-sand rework recurs despite the guard (under-firing); the propose-fix surface (ADR-060 I13) changes shape; or ADR-064 / ADR-066 / ADR-070 are superseded such that the amend/carve-out anchors move.

## Related

- **Problem P315** — the problem this ADR resolves (substance-confirm-before-build gap).
- **P314** — the built-on-sand rework P315 caused (the concrete instance: ADR-072/073).
- **ADR-064** — record-time confirm gate; amended by this ADR (Needs-Direction names substance not grain).
- **ADR-066** — born-`proposed` marker + drain; gains the marker-≠-licence carve-out clause.
- **ADR-044** — decision-delegation taxonomy + lazy-AskUserQuestion metric (this ask is cat-1, excluded from the lazy-count).
- **ADR-060 I13** — the propose-fix surface the process guard rides.
- **ADR-070/071** — sharpened from intent to enforced-before-build.

**Dogfood:** this ADR was itself decided through the exact substance-confirm-before-build flow it establishes — the architect named the substantive options (Needs-Direction, 2026-05-27), the user confirmed Option A via `AskUserQuestion`, and only then was any artifact built. Born `human-oversight: confirmed`.
